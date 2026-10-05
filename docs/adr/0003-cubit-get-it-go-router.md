# ADR 0003 — Cubit + get_it + go_router

Estado: Aceptado · Fecha: 2026-10-04

## Problema

Hay que elegir cómo manejar estado, inyección de dependencias y navegación en una app bancaria donde:
el estado de sesión (bloqueada, sin onboarding, lista…) decide qué pantallas son accesibles; cada
pantalla debe modelar explícitamente loading/vacío/offline/stale/error; los deep links de push deben
pasar por los mismos guards; y todo debe testearse sin widgets cuando sea posible.

## Alternativas evaluadas

| Alternativa | Pros | Contras |
|---|---|---|
| Bloc con eventos en todas partes | Trazabilidad de eventos, estándar en banca | Boilerplate alto para pantallas con 2–3 intenciones |
| Riverpod | DI y estado unificados, compile-safe | Curva y estilo distinto; mezcla DI con estado reactivo |
| Provider | Simple, oficial | Poco estructurado para máquinas de estado complejas |
| GetX | Muy rápido de escribir | Acopla navegación, DI y estado; difícil de testear y auditar |
| **Cubit (`flutter_bloc`) + `get_it` + `go_router`** | Estados explícitos con sealed classes, testeables con `bloc_test`; DI simple; router declarativo con `redirect` | Service locator global; sin generación de código para DI |

## Opción seleccionada

- **Estado:** Cubit de `flutter_bloc`, con estados como `sealed class` y `switch` exhaustivo en la UI
  (p. ej. `apps/mobile/lib/app/session/session_status.dart`,
  `apps/mobile/lib/features/transfers/presentation/transfer_cubit.dart`,
  `apps/mobile/lib/features/experience/presentation/home_cubit.dart`). Tests con `bloc_test` + `mocktail`.
- **DI:** `get_it` configurado a mano en `apps/mobile/lib/app/di.dart` (`configureDependencies(env)`),
  sin `injectable`: el grafo es pequeño y explícito.
- **Navegación:** `go_router` en `apps/mobile/lib/app/router.dart` con `refreshListenable` atado al
  stream de `SessionCubit` y un `redirect` que delega en la función pura `sessionRedirect`
  (`apps/mobile/lib/app/session/session_redirect.dart`). Así los guards (login, onboarding, setup
  biométrico, `/lock`) se testean como función, sin widgets.
- Las rutas válidas están centralizadas en `packages/core/lib/src/navigation/nexo_routes.dart`, que
  también usan el allowlist SDUI y el de deep links.

## Trade-offs

- **A favor:** la máquina de sesión (`loading`, `unauthenticated`, `needsOnboarding`,
  `needsBiometricSetup`, `locked`, `ready`, `profileUnavailable`) es un único lugar de verdad para guards,
  auto-lock y `DeepLinkGate` (`apps/mobile/lib/app/session/deep_link_gate.dart`).
- **A favor:** la exhaustividad de sealed classes obliga a dibujar todos los estados de cada pantalla.
- **En contra:** `get_it` es un service locator global; el riesgo de dependencias ocultas se mitiga
  resolviendo solo en el borde (router/páginas) y pasando dependencias por constructor a los Cubits.
- **En contra (conocido):** `go_router` evalúa `redirect` con la URI base; tras un auto-lock desde una
  pantalla apilada, al desbloquear se vuelve a Inicio en lugar de a la pantalla previa. Aceptado para
  esta iteración.

## Impacto a largo plazo

- Migrar un Cubit a Bloc con eventos es local, si alguna feature necesita trazabilidad de eventos
  (p. ej. auditoría de transferencias).
- Con más módulos, `get_it` puede organizarse por scopes o migrarse a `injectable` sin cambiar los Cubits.
- El patrón "redirect puro + estado de sesión" escala a nuevos estados (p. ej. dispositivo no confiable)
  agregando un caso al sealed y una regla testeada.
