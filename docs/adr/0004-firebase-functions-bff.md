# ADR 0004 — Firebase + Cloud Functions como BFF, escrituras solo server-side

Estado: Aceptado · Fecha: 2026-10-04

## Problema

La plataforma necesita autenticación, datos en tiempo real, push, hosting de la micro-app y un backend
donde ejecutar reglas de negocio sensibles (transferencias atómicas e idempotentes, segmentación,
emisión de tokens para micro-apps, asistente IA) sin operar infraestructura propia y en un plazo de días.
El cliente móvil no es confiable: cualquier escritura de dinero o de configuración desde la app es un
vector de fraude.

## Alternativas evaluadas

| Alternativa | Pros | Contras |
|---|---|---|
| Backend propio (NestJS en Cloud Run) | Control total, portable | Más infraestructura (auth, DB, push) que construir y operar |
| Supabase | Postgres, RLS, auth incluidos | Menos integración nativa con FCM, App Check y Crashlytics |
| Firestore con escritura directa desde el cliente | Mínimo backend | Reglas complejas para transacciones; lógica de dinero en el cliente |
| **Firebase + Functions como BFF; cliente solo lee** | Servicios gestionados + un único punto de escritura validado | Lock-in a Firebase/GCP; cold starts |

## Opción seleccionada

- **Firebase** (plan Blaze): Auth email/contraseña, Firestore, FCM, Hosting, App Check, Crashlytics.
- **Un único BFF HTTP** (`api`) en Cloud Functions v2, región `us-east1`, Express + TypeScript
  (`backend/functions/src/index.ts`, `backend/functions/src/http/app.ts`).
- **Arquitectura hexagonal:** dominio puro (`backend/functions/src/domain/*.ts`), casos de uso
  (`backend/functions/src/application/use-cases.ts`), puertos (`backend/functions/src/ports.ts`) y
  adaptadores Firebase/memoria (`backend/functions/src/adapters/firebase.ts`, `.../memory.ts`).
- **Middleware en orden:** `requestId` → `securityHeaders` → (rutas autenticadas) `appCheck` →
  `authenticate` (ID token) → `requireService` (kill switch) → validación zod
  (`backend/functions/src/http/middleware.ts`).
- **Escrituras solo server-side:** `firebase/firestore.rules` permite al cliente solo leer sus propios
  documentos (`users/{uid}`, `accounts`, `movements` con `limit <= 100`); todo lo demás es deny-by-default.
  Las transferencias corren en `runTransaction` con documento de idempotencia `idempotency/{uid}_{key}`.
- **Lecturas** de cuentas y movimientos directo desde Firestore (tiempo real + caché offline); el resto
  vía BFF. Contrato completo en [docs/api.md](../api.md).
- Secretos en Secret Manager (`MICROAPP_SIGNING_KEY`, `ADMIN_API_KEY`, `GEMINI_API_KEY`) vía
  `defineSecret`.

## Trade-offs

- **A favor:** una sola función centraliza seguridad, correlación y degradación; el dominio se testea
  con adaptadores en memoria (56 tests vitest, sin emuladores).
- **A favor:** las reglas de Firestore son simples porque no permiten escrituras del cliente.
- **En contra:** lock-in con Firebase; mitigado porque el dominio y los puertos no dependen del SDK.
- **En contra:** cold starts de Functions; una sola función los reduce pero no los elimina.
- **En contra:** los endpoints `/admin/*` usan una API key (`X-Admin-Key`) para la demo; en producción
  serían un backoffice con IAM.

## Impacto a largo plazo

- Los adaptadores pueden reemplazarse (p. ej. Postgres en Cloud Run) sin tocar dominio ni contrato.
- El BFF es el lugar natural para agregar rate limiting, auditoría y antifraude por transacción.
- Si el tráfico crece, separar la función en servicios por dominio (transfers, experience, assistant)
  es mecánico gracias a los casos de uso independientes.
