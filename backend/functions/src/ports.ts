/**
 * Puertos (interfaces) del BFF. Los casos de uso dependen de estas
 * abstracciones; hay adaptadores Firebase (producción) y en memoria (tests).
 */
import type { Account, Movement, OpsFlags, Segment, UserProfile } from './domain/types';
import type { TransferCommand, TransferResult } from './domain/transfer';
import type { ExperienceConfig } from './domain/experience';

export interface UserRepository {
  getProfile(uid: string): Promise<UserProfile | null>;
  /** Crea perfil + cuentas + movimientos de forma atómica. Falla si ya existe. */
  createWithSeed(profile: UserProfile, accounts: Account[], movements: Movement[]): Promise<void>;
  listAccounts(uid: string): Promise<Account[]>;
  listMovements(uid: string): Promise<Movement[]>;
  updateSegment(uid: string, segment: Segment, reason: string): Promise<void>;
}

export interface Ledger {
  /**
   * Ejecuta la transferencia de forma atómica e idempotente.
   * - Misma key + mismo payload => devuelve el resultado original (replayed: true).
   * - Misma key + payload distinto => IdempotencyConflictError.
   * - Regla de negocio violada => TransferRejectedError.
   */
  executeTransfer(cmd: TransferCommand, fingerprint: string): Promise<TransferResult>;
}

export interface ExperienceStore {
  get(segment: string, screen: string): Promise<unknown | null>;
  put(config: ExperienceConfig): Promise<void>;
}

export interface OpsFlagsProvider {
  get(): Promise<OpsFlags>;
  set(patch: Partial<OpsFlags>): Promise<void>;
}

export interface DeviceInfo {
  deviceId: string;
  fcmToken: string;
  platform: 'android' | 'ios';
  appVersion: string;
}

export interface DeviceRegistry {
  upsert(uid: string, device: DeviceInfo): Promise<void>;
  tokens(uid: string): Promise<string[]>;
  removeTokens(uid: string, tokens: string[]): Promise<void>;
}

export interface PushMessage {
  title: string;
  body: string;
  /** Deep link y metadatos; solo strings (restricción de FCM). */
  data: Record<string, string>;
}

export interface Notifier {
  sendToTokens(tokens: string[], message: PushMessage): Promise<{ invalidTokens: string[] }>;
  subscribeToTopic(tokens: string[], topic: string): Promise<void>;
  sendToTopic(topic: string, message: PushMessage): Promise<string>;
}

export interface VerifiedIdentity {
  uid: string;
}

export interface IdentityVerifier {
  verifyIdToken(token: string): Promise<VerifiedIdentity>;
  verifyAppCheck(token: string): Promise<boolean>;
}

export interface ContextClaims {
  sub: string;
  firstName: string;
  segment: string;
}

export interface ContextTokenService {
  issue(claims: ContextClaims, audience: string): Promise<{ token: string; expiresIn: number }>;
  verify(token: string, audience: string): Promise<ContextClaims | null>;
}

export interface AssistantModel {
  readonly name: string;
  /** Devuelve el texto JSON crudo del modelo (se valida afuera). */
  complete(input: { system: string; user: string; responseSchema: object }): Promise<string>;
}

export interface Clock {
  now(): Date;
}

export interface IdGenerator {
  next(prefix: string): string;
}

export interface Deps {
  users: UserRepository;
  ledger: Ledger;
  experiences: ExperienceStore;
  flags: OpsFlagsProvider;
  devices: DeviceRegistry;
  notifier: Notifier;
  identity: IdentityVerifier;
  contextTokens: ContextTokenService;
  assistantModel: AssistantModel | null;
  clock: Clock;
  ids: IdGenerator;
  config: {
    appCheckEnforced: boolean;
    adminApiKey: string;
    microAppOrigins: string[];
    assistantTimeoutMs: number;
  };
}
