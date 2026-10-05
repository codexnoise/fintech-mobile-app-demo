# Estrategia de pruebas

> Leyenda: ✅ implementado y verde en `main` · 🚧 en curso · 📄 documentado, pendiente / evolución.

## Pirámide real

| Nivel | Qué cubre | Herramientas | Cantidad | Estado |
|---|---|---|---|---|
| Unit (Dart) | `Money`, `Result/Failure`, mensajes de error, `ApiClient` + interceptores (request-id, auth con refresh en 401, retry con backoff y `Retry-After`), `ErrorMapper`, registro de limpiezas de sesión, parser SDUI (allowlist, forward-compat, `minAppVersion`), cubits (sesión, login/registro, biometría, onboarding, cuentas, transferencias, home), cascada SDUI remoto → last-known-good → embebido y `ttl`, mapeo de errores de Firebase Auth y parseo de documentos de Firestore, `sessionRedirect` (guards), auto-lock, `DeepLinkGate`, parser del bridge de micro-apps, validación de deep links de push | `flutter_test`, `bloc_test`, fakes propios | parte de los 238 | ✅ |
| Widget | Formularios de login/onboarding y campo de contraseña, componentes del design system, `SduiView` (render, componente que lanza se omite, guidelines de accesibilidad) | `flutter_test`, `meetsGuideline` | parte de los 238 | ✅ |
| Backend | Dominio puro (segmentación, seed, transferencia, insights, experiencia SDUI) y API HTTP (seguridad del BFF, onboarding, SDUI, transferencias con idempotencia, push por segmento, micro-apps, asistente acotado, endpoints admin) | `vitest` + `supertest` con adaptadores en memoria | 56 | ✅ |
| Integración manual | App real contra Firebase Emulator Suite (Auth, Firestore, Functions, Hosting) y contra el backend desplegado | Emulador Android + `adb` + Dart MCP | — | ✅ (manual, por bloque) |
| E2E automatizado | `integration_test/critical_flow_test.dart`: registro → onboarding → home → transferencia contra emuladores | `integration_test` | 0 | 📄 F9 |

### Conteos por miembro (verificados ejecutando las suites)

| Miembro | Tests | Archivos de test |
|---|---|---|
| `packages/core` | 59 | `money`, `result`, `failure_messages`, `session_cleanup_registry`, `network/{api_client, error_mapper, retry_interceptor, resilience}` (circuit breaker + caos) |
| `packages/design_system` | 13 | `theme_test` (contraste AA), `components_test` (etiquetas `Semantics` de montos, contraste) |
| `packages/sdui_engine` | 18 | `sdui_parser_test`, `sdui_view_test` (tap targets, labels, contraste) |
| `apps/mobile` | 163 | `test/app/**` (DI, router, sesión, auto-lock, deep links, tokens de Firebase) y `test/features/**` (auth, onboarding, accounts, transfers, experience, notifications, micro_apps) |
| **Total Flutter** | **253** | |
| `backend/functions` | 56 | `test/domain.test.ts` (dominio puro), `test/api.test.ts` (HTTP de punta a punta con `supertest`) |

## Decisiones

- **Fakes antes que mocks.** `apps/mobile/test/helpers/fakes.dart` reúne implementaciones en memoria de los
  contratos de dominio (`FakeAuthRepository`, `FakeBiometricAuthenticator`, `FakeBiometricPreferences`,
  `FakeProfileRepository`, `FakeAccountsRepository`, `FakeCurrentUser`). Los cubits se prueban contra estos fakes
  con `bloc_test`, sin Firebase ni plataforma. Es posible porque `domain` es Dart puro (ver
  [arquitectura](architecture.md)).
- **Backend hexagonal = tests deterministas.** `test/helpers.ts` arma la app Express con adaptadores en memoria
  (`MemoryStore`, `FixedClock`, `SequentialIds`, `RecordingNotifier`, `FakeIdentity`…). Los tests del backend
  **no** levantan emuladores: el comportamiento de Firestore real (transacciones, reglas) se valida en la
  integración manual. Un defecto real lo encontraron estos tests: el adaptador en memoria devolvía referencias
  mutables.
- **Accesibilidad como test.** `meetsGuideline(textContrastGuideline)` en el tema y los componentes del design
  system; `androidTapTargetGuideline`, `labeledTapTargetGuideline` y `textContrastGuideline` sobre una pantalla
  SDUI renderizada. Las etiquetas de montos se prueban textualmente (`"8740 dólares con 25 centavos"`).
- **Dinero.** Toda la aritmética usa `Money` (centavos `int`) y tiene tests propios; las validaciones de la
  transferencia en el cliente (límite USD 5.000, saldo, cuentas distintas) espejan las del BFF y se prueban en
  `transfer_cubit_test.dart`, incluida la reutilización del `idempotencyKey` ante resultado incierto.
- **TDD en lo crítico.** La capa de red de `core` se escribió test-first (F1); los bugs hallados en emulador se
  corrigieron con su test (p. ej. `deep_link_gate_test.dart` para el deep link perdido tras el auto-lock).

## Cómo correr

```bash
# Flutter: los 4 miembros del workspace
make test                      # o: cd packages/core && fvm flutter test
make coverage                  # genera coverage/lcov.info por miembro
make analyze && make format

# Backend
cd backend/functions && npm ci && npm test        # 56 tests
npm run coverage                                  # cobertura v8
npm run typecheck

# Todo junto (format + analyze + test Flutter + test backend)
make check
```

**Emuladores de Firebase** (integración manual, requiere Java 21 para firebase-tools):

```bash
cp backend/functions/.secret.local.example backend/functions/.secret.local
(cd backend/functions && npm ci && npm run build)
firebase emulators:start           # Auth 9099 · Firestore 8080 · Functions 5001 · Hosting 5000 · UI 4000
cd apps/mobile && fvm flutter run -t lib/main_dev.dart --dart-define-from-file=env/dev.json
```

En emuladores el backend omite App Check (`FUNCTIONS_EMULATOR`) y el emulador Android llega al host por
`10.0.2.2` (cleartext permitido solo a ese host y `localhost` en el `network_security_config` de debug).

## CI

`.github/workflows/ci.yml` en cada push a `main` y PR: `dart format --set-exit-if-changed`, `flutter analyze`,
`flutter test --coverage` por miembro (sube `lcov.info` como artefacto), `npm run typecheck` + `npm run coverage`
en el backend, y chequeo de sintaxis de la micro-app. No se publica un porcentaje de cobertura en este documento
porque no se midió como métrica objetivo.

## Verificación manual en emulador (cada bloque F1–F6)

Cada bloque se cerró con la app corriendo en un emulador Android:

1. `fvm flutter run` vivo + **Dart MCP** (`.mcp.json` → `fvm dart mcp-server`): `dtd` para conectarse,
   `get_runtime_errors` tras cada cambio, `widget_inspector` para revisar el árbol, `hot_reload` / `hot_restart`.
2. **`adb`** para recorrer el flujo real: capturas de pantalla, input de texto/taps, envío de la app a background
   (auto-lock), apertura de notificaciones y deep links.
3. Emulator Suite o backend desplegado según el caso (push por segmento y micro-app se verificaron en producción).

Defectos hallados así (registrados en [ai-log](ai/ai-log.md)): orden de foco del teclado, copy de error en
`/lock`, "Ver cuenta" sin back, contraste del ícono de débitos y el deep link perdido tras el auto-lock.

## Pendiente

- 📄 **F9 E2E**: `integration_test/critical_flow_test.dart` contra emuladores, con `FakeBiometricAuthenticator`
  inyectado por DI, y target `make e2e`. En CI quedaría como job opcional (`workflow_dispatch`) con
  `android-emulator-runner` + Emulator Suite.
- 📄 Tests de accesibilidad (`meetsGuideline`) sobre las pantallas de login y transferencia completas.
- 📄 Tests de reglas de Firestore con `@firebase/rules-unit-testing`.
- ✅ Tests del circuit breaker y del `ChaosInterceptor` (`packages/core/test/network/resilience_test.dart`); el Network Lab se verificó en emulador.
