# ADR 0001 — Monorepo liviano con pub workspaces y Makefile

Estado: Aceptado · Fecha: 2026-10-04

## Problema

Nexo combina una app Flutter, tres librerías Dart reutilizables (dominio común, design system y motor
SDUI), un BFF en Cloud Functions, una micro-app web y la configuración de Firebase. Con un equipo pequeño
y un plazo corto, se necesita que un cambio transversal (p. ej. un contrato del BFF y su consumo en la
app) viaje en un solo commit, que la dirección de dependencias entre módulos sea verificable y que el
tooling no consuma horas de configuración.

## Alternativas evaluadas

| Alternativa | Pros | Contras |
|---|---|---|
| App única (todo en `apps/mobile/lib`) | Cero configuración | Sin fronteras físicas; el design system y el SDUI terminan acoplados a features |
| Package por feature | Aislamiento máximo, ownership por equipo | Mucho boilerplate (pubspec, exports, DI) para 7 features en días |
| Multirepo (app, packages, backend por separado) | Ciclos de release independientes | Cambios de contrato en varios PRs; versionado de packages desde el día 1 |
| Monorepo con Melos | Scripts y versionado maduros | Otra herramienta y config; los pub workspaces nativos ya resuelven dependencias |
| **Monorepo con pub workspaces nativos + Makefile** | Un solo `pub get` y un solo `pubspec.lock`; scripts triviales | Sin versionado/publicación de packages automatizado |

## Opción seleccionada

Monorepo con **pub workspaces** de Dart (`pubspec.yaml` raíz, `workspace:` con `apps/mobile`,
`packages/core`, `packages/design_system`, `packages/sdui_engine`) y un `Makefile` con los atajos
(`get`, `format`, `analyze`, `test`, `coverage`, `functions-test`, `check`). Flutter fijado en 3.47.4 vía
FVM (`.fvmrc`).

Estructura:

- `apps/mobile` — app Flutter (features, DI, router).
- `packages/core` (`nexo_core`) — `Money`, `Result`/`Failure`, `ApiClient` e interceptores, contratos.
- `packages/design_system` (`nexo_design_system`) — tokens, tema, componentes.
- `packages/sdui_engine` (`nexo_sdui_engine`) — modelos, parser, registry y renderer SDUI.
- `backend/functions` — BFF en Node 22 + TypeScript (fuera del workspace Dart, con su `package-lock.json`).
- `micro_apps/travel_insurance` — micro-app web estática.
- `firebase/` — reglas e índices de Firestore.

Dirección de dependencias: `apps/mobile → packages/*`; `sdui_engine → design_system → core`. Se
declara con `path:` en cada `pubspec.yaml` y se refuerza en `CLAUDE.md`.

Melos (cambio respecto al plan inicial) queda como evolución si aparecen necesidades de versionado y
publicación de packages.

## Trade-offs

- **A favor:** un solo `fvm dart pub get` en la raíz resuelve todo; un único lockfile evita drift de
  versiones entre miembros; CI (`.github/workflows/ci.yml`) analiza y prueba todos los miembros en un job.
- **En contra:** el `Makefile` itera miembros de forma secuencial (`make test`) y no detecta qué cambió;
  no hay changelogs/versionado automático (los `CHANGELOG.md` de packages son manuales).
- La dirección de dependencias no la valida una herramienta: depende de revisión y de que un package no
  pueda importar lo que no declara en su `pubspec.yaml`.
- Los miembros no tienen `pubspec.lock` propio; ejecutar `pub get` dentro de un miembro es un error común.

## Impacto a largo plazo

- La frontera física de packages permite extraer `nexo_core`, `nexo_design_system` y `nexo_sdui_engine`
  a un registry privado cuando haya varios equipos o varias apps, sin reescribir imports.
- Escalar a package-per-feature es incremental: mover `apps/mobile/lib/features/<x>` a `packages/<x>`.
- Al crecer el número de miembros, convendrá Melos (o similar) para ejecución selectiva por cambios y
  versionado; el `Makefile` es reemplazable sin tocar código.
- Ver [arquitectura](../architecture.md) §2 para el diagrama de contenedores.
