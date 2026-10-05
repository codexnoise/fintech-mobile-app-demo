# Uso de IA: impacto medido y control

Resumen calculado a partir de las 14 filas de [`ai-log.md`](./ai-log.md) (4–5 oct 2026, hasta F6 y el deploy
verificado). Los bloques posteriores (D1, F7 en adelante) se agregan al log al cerrarse y no están en estas cifras.
Los estimados "sin IA" son del propio desarrollador; son juicio experto, no una línea base medida.

## Números

| Métrica | Valor |
|---|---|
| Tareas registradas | 14 |
| Estimado sin IA (suma) | **47.5 h** |
| Tiempo real (suma) | **13.7 h** |
| Factor de aceleración | **≈ 3.5×** (ahorro ≈ 33.8 h, 71 %) |
| % de código/texto generado por IA | **88 %** promedio simple · **87 %** ponderado por horas reales |
| Defectos / retrabajo registrados | **18** (ver clasificación) |

Por tipo de tarea (estimado → real): spec y arquitectura 4 → 1.5 h; backend BFF + 56 tests 8 → 1.5 h (el mayor
ahorro); bloques Flutter F1–F6 27 → 8.7 h; packages base, reglas, micro-app web, CI, prompts y validación 8.5 → 2 h.

### De dónde salieron los defectos

Clasificación de la columna "Retrabajo / defectos" del log:

| Detectados por | # | Ejemplos |
|---|---|---|
| El agente (análisis, compilación, revisión propia) | 8 | `release.yml` sin `--dart-define-from-file` (el APK abortaba), falta permiso `INTERNET` en release, `DioExceptionType.transformTimeout` nuevo en Dio 5.11, `/me` responde 404 y no 409, choque de nombre `LockState` con Flutter, conflicto de versiones `connectivity_plus`/`flutter_local_notifications`, `PUT` vs `POST /devices`, lints incompatibles con el formatter |
| Tests automáticos | 4 | Adaptador en memoria con referencias mutables (backend), recarga de perfil de más tras la oferta biométrica, parser SDUI que rechazaba mapas no tipados (bug real de código previo), `ttl` que comparaba relojes distintos |
| Prueba manual en emulador / producción | 6 | Foco del teclado al botón del ojo, copy de error en `/lock`, pista de la barra de progreso, "Ver cuenta" sin back, contraste del ícono de débitos, **deep link perdido tras el auto-lock** (hallado probando la campaña push en producción) |

Lectura: los tests atraparon bugs de lógica; la prueba manual atrapó **todos** los problemas de UX y el bug de
integración más serio (go_router + auto-lock + push). Ninguno de los dos niveles reemplaza al otro. Además se
registraron incidentes de entorno no atribuibles al código (Java 17 vs 21 para firebase-tools, AVD con ruta rota,
emulador con pantalla bloqueada).

## Cómo se controló la IA

- **Reglas versionadas en [`CLAUDE.md`](../../CLAUDE.md):** dirección de dependencias, dinero en `int`,
  `Result<T>`, Cubit/get_it/go_router, tokens del design system, Conventional Commits. Se cargan en cada sesión.
- **Zonas con aprobación humana explícita:** `firestore.rules`, transferencias y middleware del backend,
  `features/auth/**` y el bridge de micro-apps. En F2 el plan se aprobó antes de tocar `features/auth`; reglas,
  transferencias y middleware se revisaron línea por línea.
- **Permisos del agente** (`.claude/settings.json`): comandos de test/análisis pre-aprobados; lectura de secretos y
  `env/*.json` denegada; `firebase deploy` y `git push --force` bloqueados (el deploy lo hace el humano).
- **Hook de formato** (`tool/hooks/format_dart.js`) en cada `.dart` editado.
- **TDD en lo crítico:** capa de red de `core` (41 tests en F1), `Money`, parser SDUI, idempotencia de
  transferencias. Todo cambio de lógica llega con su test; `make format analyze test` antes de cada commit.
- **Verificación en emulador por bloque** con el **Dart MCP** (`.mcp.json`: `get_runtime_errors`,
  `widget_inspector`, `hot_reload`/`hot_restart`) y `adb` para recorrer el flujo real. Ver [testing](../testing.md).
- **Prompts versionados** en [`docs/ai/prompts/flutter-blocks.md`](prompts/flutter-blocks.md): un prompt por
  bloque (F1–F11) con restricciones y criterios de aceptación; el spec y las decisiones se escribieron antes del
  código.
- **Decisiones humanas** donde había trade-off de producto o riesgo: arquitectura hexagonal, no encolar
  transferencias offline, contraseña en `/lock` sin biometría, alcance reducido de la micro-app.

## IA en el producto

Acotada por diseño: el asistente (`POST /assistant`) usa structured output, cada cifra se verifica contra los
agregados reales y el servidor arma un documento SDUI de solo lectura; el modelo no emite UI ni acciones. En el
despliegue actual Gemini está deshabilitado y responde el fallback determinista.

## Lecciones

1. **El mayor retorno está en código con contrato claro** (backend hexagonal, parser, red): la IA genera rápido y
   los tests confirman. En UI el ahorro es menor porque la validación visual es humana.
2. **Escribir el contrato primero** (`docs/api.md`, prompts con criterios de aceptación) reduce el retrabajo:
   el Dart escrito sin compilar en la primera sesión pasó análisis y tests con solo cambios de formato.
3. **La prueba manual no es opcional.** Los errores de integración entre librerías (go_router, FCM, ciclo de vida)
   solo aparecieron ejecutando el flujo real, incluso en producción.
4. **El agente detecta bien lo que puede ejecutar** (compilación, versiones de dependencias, contratos HTTP) y
   mal lo que requiere criterio de UX: ahí la revisión humana sigue siendo necesaria.
5. **Restringir permisos y zonas sensibles** permitió delegar mucho sin perder control sobre secretos, deploy y
   código de seguridad.
