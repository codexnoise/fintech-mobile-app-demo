# Contrato del BFF (`api`)

Base URL:
- Producción: `https://us-east1-<project-id>.cloudfunctions.net/api`
- Emulador: `http://127.0.0.1:5001/<project-id>/us-east1/api` (Android emulator: `10.0.2.2` en lugar de `127.0.0.1`)

## Headers

| Header | Requerido | Descripción |
|---|---|---|
| `Authorization: Bearer <Firebase ID token>` | Rutas autenticadas | Verificado con chequeo de revocación |
| `X-Firebase-AppCheck: <token>` | Rutas autenticadas (prod) | Play Integrity / DeviceCheck; debug provider en dev |
| `X-Request-Id: <uuid>` | Recomendado | Correlación app ↔ backend; se devuelve en la respuesta |
| `X-Admin-Key` | Solo `/admin/*` | Operación interna / demo |

## Errores (sobre uniforme)

```json
{ "error": { "code": "insufficient_funds", "message": "Saldo insuficiente en la cuenta de origen.", "requestId": "…", "details": [] } }
```
`message` es seguro para mostrar al usuario. `503` incluye `Retry-After` (segundos).

| HTTP | code | Mapeo sugerido en la app (`Failure`) |
|---|---|---|
| 400 | `invalid_request`, `invalid_json` | `ValidationFailure` |
| 401 | `unauthenticated`, `app_check_failed` | `UnauthorizedFailure` |
| 404 | `*_not_found` | `ServerFailure` |
| 409 (404 en `GET /me`) | `onboarding_required`, `already_onboarded` | `ValidationFailure(code)` — la app los reconoce por `code`, no por status |
| 422 | reglas de negocio (ver transfers) | `ValidationFailure(code)` |
| 503 | `service_unavailable` | `ServiceUnavailableFailure(retryAfter)` |
| 5xx | `internal_error` | `ServerFailure(requestId)` |
| — | timeout / sin red | `TimeoutFailure` / `NetworkFailure` |

## Endpoints

### `GET /health` (público)
`{ "status": "ok", "time": "…" }`

### `POST /onboarding/complete` → 201
```json
{ "firstName": "Diego", "birthYear": 2001, "occupation": "employee", "incomeRange": "medium" }
```
`occupation`: `student | employee | business_owner | freelancer | retired | other` · `incomeRange`: `low | medium | high` · mayor de 18.
Respuesta: `UserProfile` con `segment` (`young_digital | entrepreneur | premium`) y `segmentReason`. Siembra 2 cuentas (`checking`, `savings`) y ~30 días de movimientos.

### `GET /me` → `UserProfile` (404 `onboarding_required` si no completó registro)

### `GET /experience?screen=home&appVersion=1.0.0` → documento SDUI
```json
{ "schemaVersion": 1, "screen": "home", "segment": "premium", "version": "2026-10-04.1", "ttlSeconds": 300,
  "components": [ { "id": "greeting", "type": "greeting_header", "props": { "title": "Buenas, Diego", "subtitle": "…" } } ] }
```
Tipos: `greeting_header`, `balance_summary`, `quick_actions`, `promo_banner`, `insight_card`, `micro_app_tile`, `tip_list`, `spending_bars`.
Acciones (`props.action` / `props.actions[].action`): `navigate{route}`, `open_micro_app{appId}`, `open_assistant{promptId}`.

### `POST /transfers` → 201 (200 si es reintento idempotente)
```json
{ "fromAccountId": "checking", "toAccountId": "savings", "amountCents": 2500, "note": "Ahorro", "idempotencyKey": "<uuid v4>" }
```
Respuesta: `{ transferId, status, fromAccountId, toAccountId, amountCents, debitMovementId, creditMovementId, fromBalanceCents, toBalanceCents, createdAt, replayed }`.
Errores 422: `same_account`, `invalid_amount`, `exceeds_per_transfer_limit` (USD 5.000), `exceeds_daily_limit` (USD 10.000), `insufficient_funds`, `idempotency_key_reused`.
**La app genera el `idempotencyKey` una vez por intento de transferencia y lo reutiliza en reintentos.**

### `POST /devices` → `{ "topics": ["segment_premium"] }`
`{ "deviceId": "…", "fcmToken": "…", "platform": "android", "appVersion": "1.0.0" }`

### `POST /micro-apps/context-token` → `{ "token": "<jwt>", "expiresIn": 300 }`
`{ "appId": "travel_insurance" }`

### `POST /micro-apps/introspect` (público, CORS para la micro-app)
`{ "token": "…", "appId": "travel_insurance" }` → `{ "active": true, "firstName": "Diego", "segment": "premium" }`

### `POST /assistant` → documento SDUI de solo lectura + `source: "model" | "deterministic_fallback"`
`{ "promptId": "monthly_summary" | "spending_breakdown" | "savings_tips" }`

### Admin (`X-Admin-Key`)
- `PUT /admin/experiences` — publica una config SDUI (validada contra el contrato).
- `PUT /admin/flags` — `{ "degradedServices": ["transfers"], "microAppsEnabled": false, "assistantEnabled": true }`
- `POST /admin/campaigns` — `{ "segment": "premium", "title": "…", "body": "…", "route": "/home" }`

## Datos que la app lee directo de Firestore (solo lectura)

- `users/{uid}` — perfil
- `users/{uid}/accounts/{accountId}` — `{ id, type, alias, maskedNumber, balanceCents, currency, updatedAt }`
- `users/{uid}/accounts/{accountId}/movements` — ordenar por `createdAt desc`, `limit <= 100` (exigido por reglas)
