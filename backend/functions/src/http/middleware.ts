import { randomUUID } from 'node:crypto';
import type { NextFunction, Request, Response } from 'express';
import type { ZodType } from 'zod';
import { AppError } from '../errors';
import { hashUid, log } from '../logger';
import type { Deps } from '../ports';

declare module 'express-serve-static-core' {
  interface Request {
    requestId: string;
    uid?: string;
  }
}

const REQUEST_ID = /^[A-Za-z0-9-]{8,64}$/;

/** Correlation id: viene de la app (X-Request-Id) o se genera. Se devuelve siempre. */
export function requestId(req: Request, res: Response, next: NextFunction): void {
  const incoming = req.header('x-request-id');
  req.requestId = incoming && REQUEST_ID.test(incoming) ? incoming : randomUUID();
  res.setHeader('X-Request-Id', req.requestId);
  const started = Date.now();
  res.on('finish', () =>
    log(res.statusCode >= 500 ? 'ERROR' : 'INFO', 'http_request', {
      requestId: req.requestId,
      method: req.method,
      path: req.path,
      status: res.statusCode,
      latencyMs: Date.now() - started,
      uid: req.uid ? hashUid(req.uid) : undefined,
    }),
  );
  next();
}

/** Headers de seguridad mínimos para una API JSON. */
export function securityHeaders(_req: Request, res: Response, next: NextFunction): void {
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'");
  next();
}

/** App Check: solo apps genuinas (Play Integrity / DeviceCheck) llaman al BFF. */
export function appCheck(deps: Deps) {
  return async (req: Request, _res: Response, next: NextFunction) => {
    if (!deps.config.appCheckEnforced) return next();
    const token = req.header('x-firebase-appcheck');
    if (!token || !(await deps.identity.verifyAppCheck(token).catch(() => false))) {
      throw new AppError(401, 'app_check_failed', 'Aplicación no verificada.');
    }
    next();
  };
}

/** Verifica el ID token de Firebase Auth (Authorization: Bearer <token>). */
export function authenticate(deps: Deps) {
  return async (req: Request, _res: Response, next: NextFunction) => {
    const header = req.header('authorization') ?? '';
    const [scheme, token] = header.split(' ');
    if (scheme !== 'Bearer' || !token) throw new AppError(401, 'unauthenticated', 'Tu sesión expiró. Ingresa nuevamente.');
    try {
      req.uid = (await deps.identity.verifyIdToken(token)).uid;
    } catch {
      throw new AppError(401, 'unauthenticated', 'Tu sesión expiró. Ingresa nuevamente.');
    }
    next();
  };
}

/**
 * Kill switch operativo: si el servicio está en `ops/flags.degradedServices`
 * respondemos 503 + Retry-After y la app muestra un estado de mantenimiento.
 */
export function requireService(deps: Deps, service: string) {
  return async (_req: Request, _res: Response, next: NextFunction) => {
    const flags = await deps.flags.get();
    if (flags.degradedServices.includes(service)) {
      throw new AppError(503, 'service_unavailable', 'Este servicio está en mantenimiento. Intenta en unos minutos.', { service }, 120);
    }
    next();
  };
}

export function validate<T>(schema: ZodType<T>, source: 'body' | 'query' = 'body') {
  return (req: Request): T => {
    const result = schema.safeParse(req[source]);
    if (!result.success) {
      throw new AppError(
        400,
        'invalid_request',
        'Revisa los datos enviados.',
        result.error.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
      );
    }
    return result.data;
  };
}

export function notFound(): never {
  throw new AppError(404, 'not_found', 'Recurso no encontrado.');
}

/** Respuestas de error uniformes. Nunca expone stack traces ni mensajes internos. */
export function errorHandler(error: unknown, req: Request, res: Response, _next: NextFunction): void {
  if (error instanceof SyntaxError && 'body' in error) {
    error = new AppError(400, 'invalid_json', 'El cuerpo de la solicitud no es JSON válido.');
  }
  const appError =
    error instanceof AppError ? error : new AppError(500, 'internal_error', 'Ocurrió un error inesperado. Intenta nuevamente.');
  if (!(error instanceof AppError)) {
    log('ERROR', 'unhandled_error', { requestId: req.requestId, error: error instanceof Error ? error.stack : String(error) });
  }
  if (appError.retryAfterSeconds) res.setHeader('Retry-After', String(appError.retryAfterSeconds));
  res.status(appError.status).json({
    error: {
      code: appError.code,
      message: appError.message,
      requestId: req.requestId,
      ...(appError.details ? { details: appError.details } : {}),
    },
  });
}

