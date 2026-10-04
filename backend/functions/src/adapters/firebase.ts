/**
 * Adaptadores de producción sobre Firebase Admin SDK.
 * Las reglas de Firestore bloquean escrituras del cliente: todo cambio de
 * datos de dinero pasa por aquí (Admin SDK) dentro de transacciones.
 */
import { randomUUID } from 'node:crypto';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getAppCheck } from 'firebase-admin/app-check';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { GoogleGenAI } from '@google/genai';
import { jwtVerify, SignJWT } from 'jose';
import { IdempotencyConflictError, TransferRejectedError } from '../errors';
import { evaluateTransfer, toResult, type TransferCommand, type TransferResult } from '../domain/transfer';
import type { Account, Movement, OpsFlags, Segment, UserProfile } from '../domain/types';
import { DEFAULT_OPS_FLAGS } from '../domain/types';
import type { ExperienceConfig } from '../domain/experience';
import type {
  AssistantModel,
  ContextClaims,
  ContextTokenService,
  DeviceInfo,
  DeviceRegistry,
  ExperienceStore,
  IdentityVerifier,
  IdGenerator,
  Ledger,
  Notifier,
  OpsFlagsProvider,
  PushMessage,
  UserRepository,
} from '../ports';

export function firebaseApp() {
  return getApps()[0] ?? initializeApp();
}

const strip = <T extends object>(value: T) => JSON.parse(JSON.stringify(value)) as T; // elimina undefined

export class FirestoreUsers implements UserRepository, Ledger {
  constructor(private readonly db: Firestore) {}

  private user = (uid: string) => this.db.collection('users').doc(uid);

  async getProfile(uid: string) {
    const snap = await this.user(uid).get();
    return snap.exists ? (snap.data() as UserProfile) : null;
  }

  async createWithSeed(profile: UserProfile, accounts: Account[], movements: Movement[]) {
    const batch = this.db.batch();
    batch.create(this.user(profile.uid), strip({ ...profile, daily: { date: null, usedCents: 0 } }));
    for (const account of accounts) batch.create(this.user(profile.uid).collection('accounts').doc(account.id), strip(account));
    for (const m of movements) {
      batch.create(this.user(profile.uid).collection('accounts').doc(m.accountId).collection('movements').doc(m.id), strip(m));
    }
    await batch.commit();
  }

  async listAccounts(uid: string) {
    const snap = await this.user(uid).collection('accounts').get();
    return snap.docs.map((d) => d.data() as Account);
  }

  async listMovements(uid: string) {
    // Pocas cuentas por usuario: una consulta acotada por cuenta (últimos 200).
    const accounts = await this.user(uid).collection('accounts').listDocuments();
    const pages = await Promise.all(
      accounts.map((ref) => ref.collection('movements').orderBy('createdAt', 'desc').limit(200).get()),
    );
    return pages.flatMap((page) => page.docs.map((d) => d.data() as Movement));
  }

  async updateSegment(uid: string, segment: Segment, reason: string) {
    await this.user(uid).update({ segment, segmentReason: reason });
  }

  async executeTransfer(cmd: TransferCommand, fingerprint: string): Promise<TransferResult> {
    const userRef = this.user(cmd.uid);
    const idemRef = this.db.collection('idempotency').doc(`${cmd.uid}_${cmd.idempotencyKey}`);
    const fromRef = userRef.collection('accounts').doc(cmd.fromAccountId);
    const toRef = userRef.collection('accounts').doc(cmd.toAccountId);

    return this.db.runTransaction(async (tx) => {
      const idem = await tx.get(idemRef);
      if (idem.exists) {
        const stored = idem.data() as { fingerprint: string; result: TransferResult };
        if (stored.fingerprint !== fingerprint) throw new IdempotencyConflictError();
        return { ...stored.result, replayed: true };
      }
      const [userSnap, fromSnap, toSnap] = await Promise.all([tx.get(userRef), tx.get(fromRef), tx.get(toRef)]);
      const daily = (userSnap.get('daily') as { date: string | null; usedCents: number } | undefined) ?? { date: null, usedCents: 0 };
      const decision = evaluateTransfer(cmd, {
        from: fromSnap.exists ? (fromSnap.data() as Account) : null,
        to: toSnap.exists ? (toSnap.data() as Account) : null,
        dailyDate: daily.date,
        dailyUsedCents: daily.usedCents,
      });
      if (!decision.ok) throw new TransferRejectedError(decision.code);
      const { plan } = decision;
      const now = cmd.now.toISOString();
      tx.update(fromRef, { balanceCents: plan.fromBalanceCents, updatedAt: now });
      tx.update(toRef, { balanceCents: plan.toBalanceCents, updatedAt: now });
      tx.create(fromRef.collection('movements').doc(plan.debit.id), strip(plan.debit));
      tx.create(toRef.collection('movements').doc(plan.credit.id), strip(plan.credit));
      tx.update(userRef, { daily: { date: plan.dailyDate, usedCents: plan.dailyUsedCents } });
      const result = toResult(cmd, plan);
      // `expireAt` + política TTL de Firestore => las keys se limpian solas (24 h).
      tx.create(idemRef, { fingerprint, result, uid: cmd.uid, expireAt: new Date(cmd.now.getTime() + 86_400_000) });
      return result;
    });
  }
}

export class FirestoreExperiences implements ExperienceStore {
  constructor(private readonly db: Firestore) {}
  async get(segment: string, screen: string) {
    const snap = await this.db.collection('experiences').doc(`${segment}__${screen}`).get();
    return snap.exists ? (snap.get('payload') ?? null) : null;
  }
  async put(config: ExperienceConfig) {
    await this.db
      .collection('experiences')
      .doc(`${config.segment}__${config.screen}`)
      .set({ payload: config, version: config.version, updatedAt: FieldValue.serverTimestamp() });
  }
}

/** Flags operativos en `ops/flags` con cache de 30 s (evita una lectura por request). */
export class FirestoreFlags implements OpsFlagsProvider {
  private cache: { value: OpsFlags; at: number } | null = null;
  constructor(private readonly db: Firestore, private readonly ttlMs = 30_000) {}
  async get() {
    if (this.cache && Date.now() - this.cache.at < this.ttlMs) return this.cache.value;
    const snap = await this.db.collection('ops').doc('flags').get();
    const value = { ...DEFAULT_OPS_FLAGS, ...((snap.data() as Partial<OpsFlags>) ?? {}) };
    this.cache = { value, at: Date.now() };
    return value;
  }
  async set(patch: Partial<OpsFlags>) {
    await this.db.collection('ops').doc('flags').set(patch, { merge: true });
    this.cache = null;
  }
}

export class FirestoreDevices implements DeviceRegistry {
  constructor(private readonly db: Firestore) {}
  private col = (uid: string) => this.db.collection('users').doc(uid).collection('devices');
  async upsert(uid: string, device: DeviceInfo) {
    await this.col(uid).doc(device.deviceId).set({ ...device, updatedAt: FieldValue.serverTimestamp() });
  }
  async tokens(uid: string) {
    const snap = await this.col(uid).get();
    return snap.docs.map((d) => d.get('fcmToken') as string).filter(Boolean);
  }
  async removeTokens(uid: string, tokens: string[]) {
    const snap = await this.col(uid).where('fcmToken', 'in', tokens.slice(0, 30)).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
}

const INVALID_TOKEN_CODES = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']);

export class FcmNotifier implements Notifier {
  private messaging = getMessaging(firebaseApp());
  async sendToTokens(tokens: string[], message: PushMessage) {
    const response = await this.messaging.sendEachForMulticast({
      tokens,
      notification: { title: message.title, body: message.body },
      data: message.data,
      android: { priority: 'high', notification: { channelId: 'transactions' } },
    });
    const invalidTokens = response.responses
      .map((r, i) => (!r.success && r.error && INVALID_TOKEN_CODES.has(r.error.code) ? tokens[i] : null))
      .filter((t): t is string => t !== null);
    return { invalidTokens };
  }
  async subscribeToTopic(tokens: string[], topic: string) {
    await this.messaging.subscribeToTopic(tokens, topic);
  }
  async sendToTopic(topic: string, message: PushMessage) {
    return this.messaging.send({
      topic,
      notification: { title: message.title, body: message.body },
      data: message.data,
      android: { notification: { channelId: 'campaigns' } },
    });
  }
}

export class FirebaseIdentity implements IdentityVerifier {
  async verifyIdToken(token: string) {
    // checkRevoked=true: un logout remoto/cuenta deshabilitada corta la sesión de inmediato.
    const decoded = await getAuth(firebaseApp()).verifyIdToken(token, true);
    return { uid: decoded.uid };
  }
  async verifyAppCheck(token: string) {
    await getAppCheck(firebaseApp()).verifyToken(token);
    return true;
  }
}

/** JWT HS256 de corta duración para micro-apps (audiencia = appId). */
export class JwtContextTokens implements ContextTokenService {
  private readonly key: Uint8Array;
  constructor(secret: string, private readonly ttlSeconds = 300) {
    this.key = new TextEncoder().encode(secret);
  }
  async issue(claims: ContextClaims, audience: string) {
    const token = await new SignJWT({ firstName: claims.firstName, segment: claims.segment })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(claims.sub)
      .setIssuer('nexo-bff')
      .setAudience(audience)
      .setIssuedAt()
      .setJti(randomUUID())
      .setExpirationTime(`${this.ttlSeconds}s`)
      .sign(this.key);
    return { token, expiresIn: this.ttlSeconds };
  }
  async verify(token: string, audience: string) {
    try {
      const { payload } = await jwtVerify(token, this.key, { issuer: 'nexo-bff', audience });
      return { sub: String(payload.sub), firstName: String(payload.firstName), segment: String(payload.segment) };
    } catch {
      return null;
    }
  }
}

export class GeminiAssistantModel implements AssistantModel {
  private readonly client: GoogleGenAI;
  constructor(apiKey: string, readonly name = 'gemini-2.5-flash') {
    this.client = new GoogleGenAI({ apiKey });
  }
  async complete(input: { system: string; user: string; responseSchema: object }) {
    const response = await this.client.models.generateContent({
      model: this.name,
      contents: input.user,
      config: {
        systemInstruction: input.system,
        responseMimeType: 'application/json',
        responseSchema: input.responseSchema as never,
        temperature: 0.3,
        maxOutputTokens: 800,
      },
    });
    const text = response.text;
    if (!text) throw new Error('empty model response');
    return text;
  }
}

export class UuidIds implements IdGenerator {
  next(prefix: string) {
    return `${prefix}_${randomUUID()}`;
  }
}
