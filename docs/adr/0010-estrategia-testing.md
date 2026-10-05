# ADR 0010 — Estrategia de testing: pirámide con fakes y adaptadores en memoria

Estado: Aceptado · Fecha: 2026-10-05

## Problema

El sistema mueve dinero y toma decisiones de seguridad (guards de sesión, allowlists SDUI y del bridge,
idempotencia). Con trunk-based development y commits frecuentes a `main`, cada cambio debe validarse en
minutos y de forma determinista, sin depender de servicios desplegados ni de un dispositivo.

## Alternativas evaluadas

| Alternativa | Pros | Contras |
|---|---|---|
| Mocks de todo (incluido dominio) | Rápido de escribir | Tests acoplados a implementación; falsa confianza |
| E2E contra producción | Realismo máximo | Lento, frágil, ensucia datos reales, riesgo de seguridad |
| Solo pruebas manuales | Sin costo inicial | No escala, no protege `main` |
| **Pirámide: unit/widget con fakes + backend con adaptadores en memoria + emuladores para integración** | Rápido, determinista, cubre la lógica crítica | E2E automatizado pendiente |

## Opción seleccionada

- **Dominio y reglas puras** con tests unitarios: `Money`, `Result`, interceptores y `ErrorMapper` en
  `packages/core/test`; parser y render SDUI en `packages/sdui_engine/test`; contraste AA en
  `packages/design_system/test`.
- **App:** Cubits con `bloc_test` + `mocktail`, `sessionRedirect` como función pura, parser del bridge,
  cascada SDUI y widgets clave, con fakes compartidos (`apps/mobile/test/helpers/fakes.dart`). Las
  dependencias de plataforma (reloj, `sleep`, conectividad, generador de idempotency key) se inyectan.
- **Backend:** vitest sobre el dominio (`backend/functions/test/domain.test.ts`) y la API HTTP con
  supertest usando adaptadores en memoria (`backend/functions/test/api.test.ts`,
  `backend/functions/src/adapters/memory.ts`), posible gracias a la arquitectura hexagonal.
- **Integración manual** con Firebase Emulator Suite (Auth, Firestore, Functions) y verificación en el
  entorno desplegado.
- **CI** (`.github/workflows/ci.yml`): format, analyze y test con coverage de los cuatro miembros Flutter;
  typecheck y coverage del backend; chequeo de sintaxis de la micro-app.

Volumen al cierre: 262 tests Flutter (core 59, design_system 14, sdui_engine 18, mobile 171) y 56 tests
de backend. Detalle en [docs/testing.md](../testing.md).

## Trade-offs

- **A favor:** la suite completa corre en local y en CI sin red ni credenciales.
- **A favor:** inyectar reloj y `sleep` hace deterministas el backoff, el TTL SDUI y el auto-lock.
- **En contra:** las reglas de Firestore no tienen tests automatizados con el emulador; se validan con
  el emulador manualmente y por diseño deny-by-default.
- **E2E (F9):** `apps/mobile/integration_test/app_test.dart` recorre login → home SDUI → transferencia sobre el
  grafo real de la app con adaptadores en memoria, más guidelines de accesibilidad. **En contra (📄):** no corre
  contra Emulator Suite ni en CI; el recorrido contra el backend real se valida a mano.
- Los fakes pueden divergir del comportamiento real de Firebase; se mitiga probando contra emuladores y
  producción en los flujos críticos.

## Impacto a largo plazo

- Próximos pasos: tests de reglas con `@firebase/rules-unit-testing`, E2E con `integration_test` +
  emuladores en un job de CI opcional, y golden tests de componentes SDUI.
- Todo cambio de lógica viene con su test (`CLAUDE.md`); esto también acota el riesgo del código
  generado con IA.
