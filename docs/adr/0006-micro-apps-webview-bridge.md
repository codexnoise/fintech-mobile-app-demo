# ADR 0006 — Micro-apps vía WebView endurecido + bridge con nonce + token de contexto

Estado: Aceptado · Fecha: 2026-10-05

## Problema

Se necesita integrar experiencias de terceros o de otros equipos (caso: seguro de viaje "Viaja
Seguro") que se despliegan con su propio ciclo, sin exponer la sesión bancaria ni dar a ese código
acceso a datos o acciones del banco más allá de lo mínimo necesario.

## Alternativas evaluadas

| Alternativa | Pros | Contras |
|---|---|---|
| Packages Flutter internos | UX nativa, tipado | Se publican con la app; no son independientes |
| Deferred components (Android) | Descarga bajo demanda | Solo Android, sigue atado al release de la tienda |
| Flutter add-to-app / módulos nativos | Rendimiento nativo | Mismo ciclo de release; complejidad de build |
| Module Federation / super-app web | Despliegue independiente | Requiere que el host sea web |
| **WebView endurecido + bridge acotado** | Despliegue independiente, aislamiento por origen | UX web; el bridge es superficie de ataque a cuidar |

## Opción seleccionada

Versión simple acordada para esta iteración:

- **Micro-app web** estática en `micro_apps/travel_insurance/public/` servida por Firebase Hosting
  (sitio default `nexo-fintech-demo.web.app`) con CSP estricta (`firebase.json`).
- **Host WebView** (`apps/mobile/lib/features/micro_apps/presentation/micro_app_page.dart`): navegación
  solo `https` al host permitido (`apps/mobile/lib/features/micro_apps/domain/micro_app.dart`), sin
  acceso a archivos/content; al cerrar borra cookies, caché y local storage.
- **Token de contexto:** `POST /micro-apps/context-token` emite un JWT HS256 de 5 min con
  `aud = travel_insurance` y claims mínimos (`JwtContextTokens` en `backend/functions/src/adapters/firebase.ts`).
  La micro-app lo valida por introspección (`POST /micro-apps/introspect`, CORS por allowlist de
  orígenes). Nunca recibe el ID token ni la sesión del banco.
- **Bridge v1:** la micro-app envía `ready`; el host genera un nonce con `Random.secure`, inyecta
  contexto con `jsonEncode` y desde ahí exige el nonce. Parser estricto: `v == 1`, tipos en allowlist,
  tamaño ≤ 8 KB (`parseBridgeMessage` en `micro_app.dart`). Las acciones con efecto (aceptar
  cotización) muestran una confirmación nativa referencial.

Verificado en producción: la micro-app aplica el descuento Premium a partir del claim del token y
`quote_accepted` vuelve a la app.

## Trade-offs

- **A favor:** la micro-app se despliega sin release de la app y queda aislada por origen y por token.
- **A favor:** el contrato del bridge es pequeño y testeable (tests en `apps/mobile/test/features/micro_apps`).
- **En contra (conocido):** sin timeout de carga en el WebView, validación parcial del payload de los
  mensajes y sin modo emulador para la micro-app.
- **En contra:** la UX es web dentro de la app; accesibilidad depende de la micro-app.
- **En contra:** el circuit breaker por servicio para la micro-app está en implementación
  ([ADR 0007](0007-resiliencia.md)); hoy existe el kill switch `micro_apps`.

## Impacto a largo plazo

- El patrón (token de contexto con audiencia + bridge versionado + allowlist) escala a varias
  micro-apps registrando `appId`, host y tipos de mensaje.
- Evoluciones: catálogo de micro-apps servido por backend, firma de mensajes, timeout y estado de
  error de carga, y micro-apps nativas (packages) para casos de alto uso.
- Cambios incompatibles del bridge suben `v`; el host debe soportar versiones en paralelo.
