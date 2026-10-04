# Nexo — plataforma financiera digital

Prueba técnica · Senior Flutter Mobile Developer · Banco Internacional.

Nexo es una plataforma financiera **100% digital** cuya experiencia se adapta a cada segmento de
cliente y puede evolucionar **sin publicar una nueva versión**: el servidor compone la UI (SDUI),
terceros se integran como micro-apps aisladas y todo lo que mueve dinero se resuelve en el backend
de forma atómica e idempotente.

> 🚧 README en construcción: instrucciones finales de ejecución y demo se completan al cierre.

## Contenido

| Ruta | Qué es |
|---|---|
| `apps/mobile` | App Flutter (shell + features, Clean Architecture feature-first, Cubit) |
| `packages/core` | `Money`, `Result/Failure`, cliente HTTP y resiliencia |
| `packages/design_system` | Tokens (Google Stitch), tema y componentes accesibles |
| `packages/sdui_engine` | Contrato Server-Driven UI, parser seguro con allowlist, renderer |
| `backend/functions` | BFF en Cloud Functions (Node 22 + TypeScript), arquitectura hexagonal |
| `micro_apps/travel_insurance` | Micro-app de un aliado (web) integrada vía WebView + bridge |
| `firebase/` | Reglas de Firestore (deny-by-default) e índices |
| `docs/` | Arquitectura, ADRs, API, seguridad, resiliencia, observabilidad, IA |

## Requisitos

[FVM](https://fvm.app) (Flutter 3.47.4 fijado en `.fvmrc`) · Node 22 · Firebase CLI · Java 17 · Android SDK.

## Inicio rápido

```bash
fvm install && fvm dart pub get          # workspace completo
make test                                # tests Flutter de todos los miembros
cd backend/functions && npm ci && npm test   # backend (56 tests)
```

Documentación: [arquitectura](docs/architecture.md) · [API](docs/api.md) · [uso de IA](docs/ai/ai-log.md).
