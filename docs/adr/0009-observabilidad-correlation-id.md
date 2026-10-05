# ADR 0009 — Observabilidad con la suite Firebase + correlation id

Estado: Aceptado · Fecha: 2026-10-05

## Problema

Cuando un usuario reporta "la transferencia falló" hay que poder reconstruir qué pasó en la app y en el
backend para esa misma operación, detectar crashes y errores no fatales (p. ej. un componente SDUI que
no se pudo dibujar) y medir latencia, sin enviar PII a herramientas de terceros.

## Alternativas evaluadas

| Alternativa | Pros | Contras |
|---|---|---|
| Sentry / Datadog | APM y trazas distribuidas maduras | Otro proveedor, costo, configuración y DPA adicionales |
| Logs solo locales (`print`) | Cero costo | Inútil en producción; sin correlación |
| **Crashlytics + Cloud Logging estructurado + `X-Request-Id`** | Integrado con el stack (ADR 0004), sin costo extra, correlación simple | Sin trazas distribuidas automáticas ni dashboards unificados |

## Opción seleccionada

Implementado (✅):

- **Correlation id:** `RequestIdInterceptor` (`packages/core/lib/src/network/interceptors.dart`) agrega
  `X-Request-Id` (uuid v4) y lo **conserva en reintentos**, de modo que todos los intentos de una
  operación lógica comparten id. El middleware `requestId`
  (`backend/functions/src/http/middleware.ts`) lo acepta si es válido (o genera uno), lo devuelve en la
  respuesta y lo incluye en el sobre de error; `ErrorMapper` lo lleva a `ServerFailure.requestId` en la
  app.
- **Logs estructurados del backend** (`backend/functions/src/logger.ts`): JSON compatible con Cloud
  Logging (`severity`), un evento `http_request` por request con `requestId`, método, ruta, `status`,
  `latencyMs` y `uid` pseudonimizado (SHA-256 truncado). Regla: nunca PII ni tokens. El asistente
  registra `verifiedClaims`/`droppedClaims` y el fallback.
- **Crashlytics en la app** (`apps/mobile/lib/app/bootstrap.dart`): `FlutterError.onError`,
  `PlatformDispatcher.onError` y `runZonedGuarded`; colección apagada en dev. No fatales vía la
  interfaz `ErrorReporter` de `nexo_core` (`packages/core/lib/src/error_reporter.dart`) con
  implementación `CrashlyticsErrorReporter` (p. ej. componentes SDUI que fallan al dibujarse).

No implementado (📄, propuesto en [docs/observability.md](../observability.md)): trazas de Firebase
Performance y eventos de Analytics (los paquetes están declarados en `apps/mobile/pubspec.yaml` pero no
se instrumentaron), dashboards y alertas.

## Trade-offs

- **A favor:** con un `requestId` se cruza el error visto en la app con el log exacto del backend.
- **A favor:** sin proveedor adicional ni nuevos acuerdos de tratamiento de datos.
- **En contra:** no hay tracing distribuido automático (spans); la correlación es manual por id.
- **En contra:** sin métricas de producto (Analytics) ni de rendimiento (Performance) en esta iteración.
- **En contra:** el `requestId` no se adjunta aún como custom key en los reportes de Crashlytics.

## Impacto a largo plazo

- Cloud Logging permite crear métricas basadas en logs (tasa de 5xx, p95 de `latencyMs` por ruta) y
  alertas sin cambiar código.
- El `X-Request-Id` es compatible con una futura migración a OpenTelemetry/Cloud Trace.
- Al agregar Analytics, usar IDs pseudónimos y un catálogo de eventos versionado.
