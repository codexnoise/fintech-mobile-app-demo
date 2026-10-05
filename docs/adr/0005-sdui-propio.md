# ADR 0005 — Server-Driven UI propio para personalización sin publicar

Estado: Aceptado · Fecha: 2026-10-04

## Problema

La prueba exige personalizar la experiencia por segmento (joven digital, emprendedor, premium) y
cambiarla **sin publicar una nueva versión** de la app. En banca, además, el contenido remoto no puede
convertirse en un vector para ejecutar acciones arbitrarias, mostrar saldos manipulados o dejar la home
en blanco si el servidor falla.

## Alternativas evaluadas

| Alternativa | Pros | Contras |
|---|---|---|
| Solo Remote Config (flags + strings) | Gestionado, simple | Solo parámetros; no permite reordenar ni componer pantallas |
| WebView para la home | Cambios totales sin release | UX y accesibilidad inferiores; superficie de ataque web en la pantalla principal |
| GenUI / LLM como núcleo de la UI | Personalización dinámica | No determinista, no auditable; `genui` en alpha |
| Shorebird / code push | Cambia código Dart sin tienda | Cambia lógica, no solo presentación; políticas de tiendas y auditoría de código |
| **SDUI propio con registry cerrado** | Determinista, testeable, nativo, auditable | Solo compone lo que el binario ya sabe dibujar |

## Opción seleccionada

Motor propio `nexo_sdui_engine` (`packages/sdui_engine`):

- **Contrato JSON** versionado (`schemaVersion`, `screen`, `segment`, `ttlSeconds`, `components[]`);
  el BFF lo sirve en `GET /experience` ([docs/api.md](../api.md)).
- **Registry cerrado** de 8 tipos (`packages/sdui_engine/lib/src/sdui_render.dart`): `greeting_header`,
  `balance_summary`, `quick_actions`, `promo_banner`, `insight_card`, `micro_app_tile`, `tip_list`,
  `spending_bars`. Tipos desconocidos se ignoran (forward-compat).
- **Parser defensivo** (`packages/sdui_engine/lib/src/sdui_parser.dart`): rechaza documentos sin el
  contrato mínimo, omite componentes inválidos o con `minAppVersion` mayor a la instalada y descarta
  acciones fuera del allowlist (`navigate` a rutas registradas, `open_micro_app` a apps registradas,
  `open_assistant`). Nunca URLs arbitrarias ni código.
- **Render tolerante a fallos:** si un builder lanza, se omite ese componente y se reporta como no fatal
  a Crashlytics (`onComponentError` en `apps/mobile/lib/features/experience/presentation/home_page.dart`).
- **Los saldos nunca viajan en el SDUI:** `balance_summary` es un slot que la app llena desde su
  repositorio de cuentas. El servidor controla presentación, no cifras de dinero.
- **Cascada de fallback** (`apps/mobile/lib/features/experience/data/cascading_experience_repository.dart`):
  BFF → last-known-good por segmento (`shared_preferences`, solo documentos que pasaron el parser) →
  JSON embebido (`apps/mobile/assets/sdui/default_home.json`). `ttlSeconds` se respeta; pull-to-refresh
  lo fuerza.
- **Publicación en vivo:** `PUT /admin/experiences` valida el documento con zod antes de guardarlo.
  Verificado en emulador: el cambio aparece tras pull-to-refresh.

## Trade-offs

- **A favor:** cambios de orden, copy, banners y acciones por segmento sin release, con validación en
  servidor y cliente.
- **A favor:** el mismo renderer dibuja la respuesta del asistente IA ([ADR 0012](0012-ia-acotada-solo-lectura.md)).
- **En contra:** un componente nuevo requiere release; `minAppVersion` evita que apps viejas lo reciban.
- **En contra:** el last-known-good guarda el documento (incluye el saludo con el nombre) en
  `shared_preferences` sin cifrar; se borra en logout.
- **En contra:** no hay aún versionado con rollback ni A/B en el backend; el documento se sobrescribe.

## Impacto a largo plazo

- Evolución natural: historial de versiones por experiencia con rollback, A/B por porcentaje y
  herramienta de edición para negocio con preview.
- Agregar un tipo es un cambio acotado (builder + registro + test), lo que facilita sumar componentes
  por equipo.
- El contrato debe gobernarse como API pública: cambios incompatibles suben `schemaVersion`.
