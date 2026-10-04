/**
 * Adaptadores en memoria: implementan los mismos puertos que Firebase para
 * tests rápidos y deterministas (y para explicar la arquitectura hexagonal).
 */
import { IdempotencyConflictError, TransferRejectedError } from '../errors';
import { evaluateTransfer, toResult, type TransferCommand, type TransferResult } from '../domain/transfer';
import type { Account, Movement, OpsFlags, Segment, UserProfile } from '../domain/types';
import { DEFAULT_OPS_FLAGS } from '../domain/types';
import type { ExperienceConfig } from '../domain/experience';
import type {
  AssistantModel,
  Clock,
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

interface UserRecord {
  profile: UserProfile;
  accounts: Map<string, Account>;
  movements: Movement[];
  daily: { date: string | null; usedCents: number };
}

export class MemoryStore implements UserRepository, Ledger {
  readonly users = new Map<string, UserRecord>();
  readonly idempotency = new Map<string, { fingerprint: string; result: TransferResult }>();

  async getProfile(uid: string) {
    return this.users.get(uid)?.profile ?? null;
  }

  async createWithSeed(profile: UserProfile, accounts: Account[], movements: Movement[]) {
    if (this.users.has(profile.uid)) throw new Error('already exists');
    this.users.set(profile.uid, {
      profile,
      accounts: new Map(accounts.map((a) => [a.id, { ...a }])),
      movements: movements.map((m) => ({ ...m })),
      daily: { date: null, usedCents: 0 },
    });
  }

  async listAccounts(uid: string) {
    return [...(this.users.get(uid)?.accounts.values() ?? [])].map((a) => ({ ...a }));
  }

  async listMovements(uid: string) {
    return (this.users.get(uid)?.movements ?? []).map((m) => ({ ...m }));
  }

  async updateSegment(uid: string, segment: Segment, reason: string) {
    const record = this.users.get(uid);
    if (record) record.profile = { ...record.profile, segment, segmentReason: reason };
  }

  async executeTransfer(cmd: TransferCommand, fingerprint: string): Promise<TransferResult> {
    const key = `${cmd.uid}_${cmd.idempotencyKey}`;
    const previous = this.idempotency.get(key);
    if (previous) {
      if (previous.fingerprint !== fingerprint) throw new IdempotencyConflictError();
      return { ...previous.result, replayed: true };
    }
    const record = this.users.get(cmd.uid);
    const decision = evaluateTransfer(cmd, {
      from: record?.accounts.get(cmd.fromAccountId) ?? null,
      to: record?.accounts.get(cmd.toAccountId) ?? null,
      dailyDate: record?.daily.date ?? null,
      dailyUsedCents: record?.daily.usedCents ?? 0,
    });
    if (!decision.ok) throw new TransferRejectedError(decision.code);
    const { plan } = decision;
    record!.accounts.get(cmd.fromAccountId)!.balanceCents = plan.fromBalanceCents;
    record!.accounts.get(cmd.toAccountId)!.balanceCents = plan.toBalanceCents;
    record!.movements.push(plan.debit, plan.credit);
    record!.daily = { date: plan.dailyDate, usedCents: plan.dailyUsedCents };
    const result = toResult(cmd, plan);
    this.idempotency.set(key, { fingerprint, result });
    return result;
  }
}

export class MemoryExperienceStore implements ExperienceStore {
  readonly configs = new Map<string, unknown>();
  async get(segment: string, screen: string) {
    return this.configs.get(`${segment}__${screen}`) ?? null;
  }
  async put(config: ExperienceConfig) {
    this.configs.set(`${config.segment}__${config.screen}`, config);
  }
}

export class MemoryFlags implements OpsFlagsProvider {
  flags: OpsFlags = { ...DEFAULT_OPS_FLAGS };
  async get() {
    return this.flags;
  }
  async set(patch: Partial<OpsFlags>) {
    this.flags = { ...this.flags, ...patch };
  }
}

export class MemoryDevices implements DeviceRegistry {
  readonly byUser = new Map<string, Map<string, DeviceInfo>>();
  async upsert(uid: string, device: DeviceInfo) {
    const devices = this.byUser.get(uid) ?? new Map<string, DeviceInfo>();
    devices.set(device.deviceId, device);
    this.byUser.set(uid, devices);
  }
  async tokens(uid: string) {
    return [...(this.byUser.get(uid)?.values() ?? [])].map((d) => d.fcmToken);
  }
  async removeTokens(uid: string, tokens: string[]) {
    const devices = this.byUser.get(uid);
    if (!devices) return;
    for (const [id, d] of devices) if (tokens.includes(d.fcmToken)) devices.delete(id);
  }
}

export class RecordingNotifier implements Notifier {
  readonly sent: Array<{ tokens: string[]; message: PushMessage }> = [];
  readonly topicMessages: Array<{ topic: string; message: PushMessage }> = [];
  readonly subscriptions: Array<{ tokens: string[]; topic: string }> = [];
  invalid = new Set<string>();
  async sendToTokens(tokens: string[], message: PushMessage) {
    this.sent.push({ tokens, message });
    return { invalidTokens: tokens.filter((t) => this.invalid.has(t)) };
  }
  async subscribeToTopic(tokens: string[], topic: string) {
    this.subscriptions.push({ tokens, topic });
  }
  async sendToTopic(topic: string, message: PushMessage) {
    this.topicMessages.push({ topic, message });
    return `msg-${this.topicMessages.length}`;
  }
}

/** Tokens de la forma `valid:<uid>`; App Check válido si es `appcheck-ok`. */
export class FakeIdentity implements IdentityVerifier {
  async verifyIdToken(token: string) {
    if (!token.startsWith('valid:')) throw new Error('invalid token');
    return { uid: token.slice('valid:'.length) };
  }
  async verifyAppCheck(token: string) {
    return token === 'appcheck-ok';
  }
}

export class FakeContextTokens implements ContextTokenService {
  async issue(claims: ContextClaims, audience: string) {
    return { token: Buffer.from(JSON.stringify({ ...claims, aud: audience })).toString('base64url'), expiresIn: 300 };
  }
  async verify(token: string, audience: string) {
    try {
      const payload = JSON.parse(Buffer.from(token, 'base64url').toString()) as ContextClaims & { aud: string };
      return payload.aud === audience ? { sub: payload.sub, firstName: payload.firstName, segment: payload.segment } : null;
    } catch {
      return null;
    }
  }
}

export class StubAssistantModel implements AssistantModel {
  readonly name = 'stub-model';
  constructor(private readonly reply: () => Promise<string>) {}
  complete() {
    return this.reply();
  }
}

export class FixedClock implements Clock {
  constructor(public current: Date) {}
  now() {
    return this.current;
  }
}

export class SequentialIds implements IdGenerator {
  private n = 0;
  next(prefix: string) {
    this.n += 1;
    return `${prefix}_${String(this.n).padStart(4, '0')}`;
  }
}
