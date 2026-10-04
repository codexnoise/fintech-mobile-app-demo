import { createHash } from 'node:crypto';

type Severity = 'DEBUG' | 'INFO' | 'WARNING' | 'ERROR';

/**
 * Logger estructurado (JSON) compatible con Cloud Logging: el campo `severity`
 * se indexa y `requestId` permite correlacionar app <-> backend.
 * Regla: NUNCA loggear PII (nombres, emails, tokens, montos asociados a identidad).
 * El uid se registra hasheado.
 */
export function log(severity: Severity, message: string, fields: Record<string, unknown> = {}): void {
  if (process.env.NODE_ENV === 'test' || process.env.VITEST) return;
  const entry = { severity, message, ...fields, timestamp: new Date().toISOString() };
  const line = JSON.stringify(entry);
  if (severity === 'ERROR') console.error(line);
  else console.log(line);
}

export const hashUid = (uid: string) => createHash('sha256').update(uid).digest('hex').slice(0, 12);
