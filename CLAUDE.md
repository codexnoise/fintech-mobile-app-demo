# Nexo — reglas para agentes de IA

Plataforma financiera digital (prueba técnica Banco Internacional). Spec de trabajo (local, no versionado)
en `docs/private/spec.md`; arquitectura en `docs/architecture.md`. Este archivo manda sobre cualquier preferencia del agente.

## Comandos
- SIEMPRE `fvm flutter …` / `fvm dart …` (Flutter 3.47.4 vía `.fvmrc`). Nunca binarios globales.
- Dependencias (raíz, pub workspace): `fvm dart pub get`
- Agregar dependencia a un miembro: `cd apps/mobile && fvm flutter pub add <pkg>`
- Tests por miembro: `make test` (o `cd packages/core && fvm flutter test`)
- Análisis: `make analyze` · Formato: `make format`
- Backend: `cd backend/functions && npm test` · Emuladores: `firebase emulators:start`
- Run: `cd apps/mobile && fvm flutter run -t lib/main_dev.dart --dart-define-from-file=env/dev.json`

## Arquitectura (no negociable)
- Monorepo con pub workspaces: `apps/mobile` + `packages/{core,design_system,sdui_engine}` + `backend/functions` + `micro_apps/*`.
- Dirección de dependencias: `apps/mobile → packages/*`; `sdui_engine → design_system → core`. Nunca al revés.
- Clean Architecture feature-first en `apps/mobile/lib/features/<feature>/{domain,data,presentation}`.
  - `domain`: entidades, contratos de repositorio, casos de uso. Dart puro, sin Flutter ni Firebase.
  - `data`: DTOs, datasources (Dio / Firestore), implementaciones de repositorio. Devuelven `Result<T>`.
  - `presentation`: Cubit + estados con sealed classes, pages, widgets.
- Features NO se importan entre sí. Se comunican por rutas (go_router) y contratos en `core`.
- Estado: Cubit (`flutter_bloc`). DI: `get_it`. Navegación: `go_router`.
- Dinero SIEMPRE en `int` (centavos) con `Money` de `nexo_core`. Nunca `double`.
- Errores esperados: `Result<T>` + `Failure` tipados. Excepciones solo para bugs.

## Seguridad (requiere aprobación humana explícita antes de editar)
- `firebase/firestore.rules`
- `backend/functions/src/**/transfers*`, `backend/functions/src/http/middleware/**`
- `apps/mobile/lib/features/auth/**`, `apps/mobile/lib/features/micro_apps/**` (bridge)
- Nunca escribir secretos, API keys ni datos personales reales. Nunca desactivar App Check,
  validaciones, reglas ni ofuscación. Nunca agregar acciones SDUI fuera del allowlist.

## UX y accesibilidad
- Todo widget usa tokens de `nexo_design_system` (nada de colores/espaciados hardcodeados).
- Montos con `Semantics(label: …)` legible. Tap targets >= 48dp. Contraste AA.
- Toda pantalla define sus estados: loading (skeleton), vacío, offline, stale, degradado, error.

## Calidad y versionamiento
- Todo cambio de lógica viene con su test. `make format analyze test` sin errores antes de commit.
- Trunk Based Development: commits pequeños y frecuentes a `main`, siempre verde.
- Conventional Commits: `feat(scope): …`, `fix`, `test`, `docs`, `refactor`, `chore`, `ci`.
- Al cerrar una tarea, agrega una fila a `docs/ai/ai-log.md` (tarea, herramienta, estimado sin IA,
  real, % generado, retrabajo/defectos, nota).
