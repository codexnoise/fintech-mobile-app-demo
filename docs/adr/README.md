# Architecture Decision Records (ADRs)

Decisiones de arquitectura de Nexo. Formato de cada ADR: **Problema · Alternativas evaluadas · Opción
seleccionada · Trade-offs · Impacto a largo plazo**. Contexto general en
[docs/architecture.md](../architecture.md) y contrato del BFF en [docs/api.md](../api.md).

| # | Título | Estado |
|---|---|---|
| [0001](0001-monorepo-pub-workspaces.md) | Monorepo liviano con pub workspaces y Makefile | Aceptado |
| [0002](0002-clean-architecture-feature-first.md) | Clean Architecture feature-first | Aceptado |
| [0003](0003-cubit-get-it-go-router.md) | Cubit + get_it + go_router | Aceptado |
| [0004](0004-firebase-functions-bff.md) | Firebase + Cloud Functions como BFF, escrituras solo server-side | Aceptado |
| [0005](0005-sdui-propio.md) | Server-Driven UI propio para personalización sin publicar | Aceptado |
| [0006](0006-micro-apps-webview-bridge.md) | Micro-apps vía WebView endurecido + bridge con nonce + token de contexto | Aceptado |
| [0007](0007-resiliencia.md) | Estrategia de resiliencia y operación offline | Aceptado |
| [0008](0008-seguridad-owasp-mobile.md) | Postura de seguridad móvil (OWASP Mobile Top 10 2024) | Aceptado |
| [0009](0009-observabilidad-correlation-id.md) | Observabilidad con la suite Firebase + correlation id | Aceptado |
| [0010](0010-estrategia-testing.md) | Estrategia de testing: pirámide con fakes y adaptadores en memoria | Aceptado |
| [0011](0011-dinero-en-enteros.md) | Dinero en enteros (centavos) | Aceptado |
| [0012](0012-ia-acotada-solo-lectura.md) | IA generativa acotada a un asistente de solo lectura | Aceptado |
| [0013](0013-entrypoints-en-vez-de-flavors.md) | Entrypoints + `--dart-define-from-file` en vez de flavors nativos | Aceptado |

Leyenda: ✅ implementado · 🚧 en implementación · 📄 documentado como evolución.

Para una decisión nueva: copiar la estructura de un ADR existente, numerar en secuencia y, si reemplaza
a otro, marcar el anterior como "Reemplazado por ADR NNNN".
