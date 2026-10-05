# ADR 0002 — Clean Architecture feature-first

Estado: Aceptado · Fecha: 2026-10-04

## Problema

La app tiene dominios con reglas propias (sesión y biometría, cuentas, transferencias, experiencia SDUI,
notificaciones, micro-apps, onboarding) y fuentes de datos heterogéneas (BFF HTTP, Firestore en tiempo
real, almacenamiento seguro, plugins nativos). Se necesita poder testear la lógica sin Firebase ni
dispositivo, cambiar una fuente de datos sin tocar la UI y que varios desarrolladores (o agentes de IA)
trabajen en features distintas sin pisarse.

## Alternativas evaluadas

| Alternativa | Pros | Contras |
|---|---|---|
| Layer-first (`lib/data`, `lib/domain`, `lib/presentation`) | Familiar, simple al inicio | Un cambio de feature toca tres carpetas lejanas; ownership difuso |
| MVC / widgets que llaman a Firebase directo | Rápido para prototipos | Lógica no testeable sin plugins; acoplamiento a proveedores |
| **Clean Architecture feature-first** | Cohesión por feature, dominio puro testeable, fronteras claras | Más archivos y contratos por feature |

## Opción seleccionada

Cada feature vive en `apps/mobile/lib/features/<feature>/{domain,data,presentation}`:

- `domain`: entidades, contratos de repositorio y casos de uso en Dart puro (sin Flutter ni Firebase).
  Ej.: `features/accounts/domain/accounts_repository.dart`, `features/transfers/domain/transfer.dart`,
  `features/auth/domain/logout.dart`.
- `data`: implementaciones que adaptan Dio o Firestore y devuelven `Result<T>`
  (`packages/core/lib/src/result.dart`). Ej.: `features/accounts/data/firestore_accounts_repository.dart`,
  `features/transfers/data/api_transfers_repository.dart`,
  `features/experience/data/cascading_experience_repository.dart`.
- `presentation`: Cubits con estados en sealed classes, páginas y widgets.

Reglas:

- Las features **no se importan entre sí**; se comunican por rutas (`go_router`) y por contratos en
  `nexo_core` (`packages/core/lib/src/contracts/accounts.dart`, `packages/core/lib/src/navigation/nexo_routes.dart`,
  `packages/core/lib/src/session/session_contracts.dart`).
- Lo transversal de la app (DI, router, sesión, bootstrap, adaptadores de infraestructura) vive en
  `apps/mobile/lib/app/`.
- Errores esperados como `Result<T>` + `Failure` tipados; excepciones solo para bugs.

Verificado al cierre: ningún archivo de `lib/features/<a>` importa `lib/features/<b>`, y ningún `domain/`
importa `package:flutter` ni Firebase.

## Trade-offs

- **A favor:** la lógica (validaciones de transferencia, máquina de sesión, cascada SDUI, parser del
  bridge) se prueba con fakes (`apps/mobile/test/helpers/fakes.dart`) sin emuladores.
- **A favor:** sustituir Firestore por el BFF en lecturas, o viceversa, es local a `data/`.
- **En contra:** más indirección (contrato + implementación + registro en DI) incluso para features
  pequeñas; para la feature `notifications` el beneficio es menor.
- La regla "features no se importan" obliga a subir contratos a `nexo_core`, que puede crecer como
  cajón de sastre si no se cuida.

## Impacto a largo plazo

- Cada feature es candidata a extraerse como package (ver [ADR 0001](0001-monorepo-pub-workspaces.md))
  y a tener ownership por equipo de dominio.
- El dominio puro permite reutilizar reglas en otras superficies (otra app, web) y facilita auditorías.
- Conviene agregar una verificación automática de imports (lint o test de arquitectura) cuando el número
  de features crezca; hoy la regla se sostiene con revisión y `CLAUDE.md`.
