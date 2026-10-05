# Observabilidad

Qué se mide hoy en Nexo, cómo se correlaciona un error de la app con el backend y qué se propone para
operar en producción. Estado: ✅ implementado · 📄 propuesto (bloque F8, no implementado).

## Implementado (✅)

### App: Crashlytics + `ErrorReporter`

- `apps/mobile/lib/app/bootstrap.dart` captura los tres caminos de error fatal: `FlutterError.onError`,
  `PlatformDispatcher.instance.onError` y `runZonedGuarded`.
- La colección está **apagada en dev** (`setCrashlyticsCollectionEnabled(!env.isDev)`); en dev el error se ve en consola.
- Errores **no fatales** pasan por el contrato `ErrorReporter` de `nexo_core`
  (`packages/core/lib/src/error_reporter.dart`), implementado con Crashlytics en
  `apps/mobile/lib/app/infra/crashlytics_error_reporter.dart`. Así las features no dependen de Firebase. Hoy se reporta:
  - componente SDUI que falla al construirse (`reason: 'sdui <type>/<id>'`), que se omite sin romper la home;
  - fallas de limpieza en logout (`reason: 'logout'`);
  - fallas al registrar el token de push (`reason: 'push register'`).
- Release con `--obfuscate --split-debug-info=build/symbols` (`.github/workflows/release.yml`). Los símbolos
  quedan en el runner; subirlos a Crashlytics (`firebase crashlytics:symbols:upload`) es un paso pendiente 📄.

### Backend: logs JSON estructurados

`backend/functions/src/logger.ts` escribe una línea JSON por evento, compatible con Cloud Logging (`severity` indexado).
El middleware `requestId` (`backend/functions/src/http/middleware.ts`) registra al terminar cada request:

```json
{ "severity": "INFO", "message": "http_request", "requestId": "3f1c…", "method": "POST",
  "path": "/transfers", "status": 201, "latencyMs": 412, "uid": "a1b2c3d4e5f6", "timestamp": "…" }
```

- `uid` pseudonimizado: SHA-256 truncado a 12 hex (`hashUid`). Nunca nombres, correos, tokens ni montos asociados a identidad.
- Status ≥ 500 se registra con `severity: ERROR`; las excepciones no controladas agregan `unhandled_error` con el stack (solo en logs, nunca en la respuesta).
- Eventos de negocio relevantes, p. ej. `experience_config_invalid` (WARNING) cuando una configuración SDUI publicada no pasa el contrato.

### Correlation id `X-Request-Id` extremo a extremo

1. `RequestIdInterceptor` (`packages/core/lib/src/network/interceptors.dart`) genera un uuid v4 por request lógico y lo **conserva en los reintentos**.
2. El BFF acepta el header si cumple `^[A-Za-z0-9-]{8,64}$` (si no, genera uno), lo devuelve en `X-Request-Id` y lo incluye en el log y en el sobre de error (`error.requestId`).
3. `ErrorMapper` lleva el `requestId` a `ServerFailure(requestId)` en la app.

## Cómo cruzar un error de la app con el log del backend

1. Obtener el `requestId`: viaja en el header `X-Request-Id` y en `error.requestId` de la respuesta, y la app lo
   conserva en `ServerFailure.requestId`. Hoy la app no lo muestra ni lo registra, así que se obtiene en debug
   (inspector del Dart MCP / breakpoint) o reproduciendo con `curl -i`.
2. En Cloud Logging (Logs Explorer), filtrar:
   ```
   resource.type="cloud_run_revision"
   jsonPayload.requestId="<requestId>"
   ```
   Se obtienen la línea `http_request` (status, latencia, `uid` hasheado) y, si hubo, `unhandled_error` con el stack.
3. Para ver todos los requests de un usuario sin exponer su uid, calcular `hashUid(uid)` y filtrar por `jsonPayload.uid`.

Limitación actual: el `requestId` todavía no se adjunta como *custom key* en Crashlytics, así que el cruce desde un
reporte no fatal todavía no es directo. Es el primer punto de la propuesta F8.

## Propuesto (📄 F8)

Las dependencias `firebase_analytics` y `firebase_performance` ya están en `apps/mobile/pubspec.yaml` y el plugin
Gradle de Performance está aplicado, pero **no hay instrumentación en código**.

### Crashlytics enriquecido
- Custom keys `requestId` (último request fallido), `segment`, `sduiVersion`, `appEnv`; `setUserIdentifier` con el uid pseudonimizado.

### Performance traces
| Trace | Inicio → fin | Atributos |
|---|---|---|
| `sdui_load` | `HomeCubit.refresh` → documento renderizado | `source` (remote/cache/bundled), `segment` |
| `transfer_submit` | Confirmar → respuesta del BFF | `outcome` (ok/422/503/uncertain), `replayed` |
| `micro_app_open` | Tap en el tile → `ready` del bridge | `appId`, `outcome` |

Más las métricas HTTP automáticas de Performance para Dio (vía interceptor) y el tiempo de arranque.

### Eventos de Analytics
- Onboarding: `onboarding_step_completed{step}`, `onboarding_completed{segment}`.
- Transferencias: `transfer_started`, `transfer_completed`, `transfer_failed{code}`.
- SDUI: `sdui_component_tap{componentId, type, segment, version}` para medir qué experiencia funciona por segmento; `sdui_fallback_used{source, reason}`.
- Micro-apps y push: `micro_app_opened{appId}`, `quote_accepted`, `push_opened{type}`, `push_opt_in{granted}`.
- Sin PII en parámetros; ids de usuario pseudónimos.

### SLOs propuestos
| SLO | Objetivo | Fuente |
|---|---|---|
| Sesiones sin crash | ≥ 99.5 % | Crashlytics |
| Latencia p95 `POST /transfers` | < 1.5 s | `latencyMs` en logs (métrica basada en logs) |
| Éxito de transferencias (excluye 422 de negocio) | ≥ 99.9 % | logs `path=/transfers` |
| Tasa de fallback SDUI | < 2 % | `sdui_fallback_used` / cargas de home |

### Alertas (Cloud Monitoring)
- Pico de 5xx: > 1 % de requests con `status >= 500` en 5 min.
- Fallback SDUI > 5 % en 15 min.
- Latencia p95 de `/transfers` > 1.5 s sostenida 10 min.
- Nuevo issue o regresión en Crashlytics (alerta nativa de velocidad).
- Picos de `401 app_check_failed` (posible cliente no genuino o problema de atestación).

### Detección de problemas de UX
- Abandono por paso del onboarding (funnel de Analytics).
- Errores visibles por pantalla: evento `error_shown{screen, code}` cuando un estado de error o banner aparece.
- Tiempo a interacción de la home (trace `sdui_load`) y tasa de reintentos manuales (pull-to-refresh tras error).

Relacionado: [resiliencia](resilience.md) · [operación y runbooks](deployment-operations.md) · [seguridad](security-owasp.md).
