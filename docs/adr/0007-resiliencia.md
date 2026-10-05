# ADR 0007 — Estrategia de resiliencia y operación offline

Estado: Aceptado · Fecha: 2026-10-05

> Estado de implementación: ✅ cache Firestore + stale, last-known-good SDUI, timeouts, retry con
> backoff, kill switches, bloqueo offline de transferencias, circuit breaker por servicio y Network
> Lab (F7, verificado en emulador contra el backend desplegado). Detalle por escenario en
> [docs/resilience.md](../resilience.md).

## Problema

Los usuarios usan la app con conectividad móvil inestable, y cualquier dependencia (BFF, SDUI,
micro-app, asistente) puede degradarse. La app debe seguir siendo útil (ver saldos, navegar) sin
conexión o con un servicio caído, sin nunca comprometer la integridad del dinero: una transferencia
no puede ejecutarse dos veces ni quedar "en cola" sin que el usuario sepa su resultado.

## Alternativas evaluadas

| Alternativa | Pros | Contras |
|---|---|---|
| Sin caché (todo online) | Simple, siempre fresco | App inútil sin red; home en blanco si el BFF falla |
| Cola offline de transferencias | Parece "funcionar" sin red | Ejecución diferida con saldo desactualizado, duplicados, usuario sin certeza; riesgo regulatorio |
| **Lecturas cacheadas + escrituras online idempotentes + degradación explícita** | Útil offline, dinero seguro, estados honestos | Más estados de UI que diseñar y probar |

## Opción seleccionada

Implementado (✅):

- **Lecturas offline:** cuentas y movimientos con `snapshots(includeMetadataChanges: true)`; si
  `isFromCache` la UI muestra banner "sin conexión / datos guardados"
  (`apps/mobile/lib/features/accounts/data/firestore_accounts_repository.dart`).
- **Home nunca en blanco:** cascada BFF → last-known-good por segmento → JSON embebido
  ([ADR 0005](0005-sdui-propio.md)).
- **Timeouts y reintentos:** `ApiClient` con connect 5 s / receive 10 s
  (`packages/core/lib/src/network/api_client.dart`); `RetryInterceptor`
  (`packages/core/lib/src/network/interceptors.dart`) con backoff exponencial + equal jitter (base
  400 ms, tope 4 s, máx. 3 reintentos), solo GET/HEAD o requests marcadas idempotentes; reintenta
  errores de red/timeouts y 502/503/504; respeta `Retry-After` corto y abandona si es largo.
- **Transferencias:** `idempotencyKey` uuid v4 por intento, reutilizada ante resultado incierto
  (red/timeout/5xx) y deduplicada en el BFF. **Offline se bloquean, no se encolan** (decisión de
  producto), con mensaje explícito (`transfer_cubit.dart`).
- **Kill switches sin release:** `PUT /admin/flags` con `degradedServices`
  (`onboarding`, `experience`, `transfers`, `micro_apps`, `assistant`) y `assistantEnabled`; el
  middleware `requireService` responde 503 + `Retry-After` y la app muestra "en mantenimiento"
  (`backend/functions/src/http/middleware.ts`).

Implementado en F7:

- **Circuit breaker por servicio** (`packages/core/lib/src/network/circuit_breaker.dart`, aplicado en
  `ApiClient._send`, fuera de Dio para contar el resultado tras los reintentos): abre tras 3 fallas de
  infraestructura seguidas, falla rápido 30 s y luego permite una prueba (half-open). Los 4xx no cuentan.
- **Network Lab** (solo dev, `apps/mobile/lib/features/network_lab/`): offline simulado, latencia +3 s
  y 503 forzado vía `ChaosSettings` + `ChaosInterceptor`, ubicado antes del `RetryInterceptor`.

## Trade-offs

- **A favor:** el usuario siempre ve datos (marcados como guardados) y nunca un estado de dinero
  ambiguo.
- **En contra:** no se puede transferir offline; es una pérdida de conveniencia aceptada.
- **En contra:** la caché de Firestore en disco no está cifrada; mitigación: solo datos del propio
  usuario y `clearPersistence` en logout.
- **En contra:** los reintentos aumentan la latencia percibida en fallos; acotados por el tope de 4 s
  y por abandonar ante `Retry-After` largo.

## Impacto a largo plazo

- El kill switch por servicio es la base de un runbook de incidentes (degradar en lugar de caer).
- El circuit breaker y el Network Lab permiten demostrar y probar escenarios de caos de forma
  reproducible; evolución: chaos testing en CI.
- Si negocio exigiera transferencias offline, requeriría un diseño distinto (autorización previa,
  límites, reconciliación), no una cola en el cliente.
