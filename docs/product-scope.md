# Alcance de producto: construido, cortado y por qué

> Estado al 5 oct 2026. Leyenda: ✅ construido y verificado · ⚠️ parcial · 🚧 en curso · 📄 documentado, no
> implementado (evolución).

## Criterio de priorización

Primero lo que **mueve o muestra dinero** y lo que demuestra **"cambiar la experiencia sin publicar"**; después lo
que hace creíble la operación (push, micro-app, resiliencia, observabilidad); al final los extras. P0 = obligatorio,
P1 = suma fuerte, P2 = bonus cortable.

**Regla de corte** (plan de trabajo): el orden es F1 → F11 con un checkpoint tras F4 (registro → home SDUI →
transferencia funcionando). *Si el lunes a las 14h00 no está terminado F7 (resiliencia), se cortan F11
(asistente) primero y F10 (protección de pantalla nativa) después.* F8 (observabilidad) tiene un recorte
predefinido: Crashlytics + 3 eventos. La documentación (D1) no se corta. El objetivo es entregar un núcleo P0
completo y verificable en lugar de muchas piezas a medias.

## Requisitos de la prueba

| # | Requisito | Prioridad | Estado | Qué hay realmente |
|---|---|---|---|---|
| R1 | Onboarding y autenticación | P0 | ✅ | Registro/login email+contraseña (Firebase Auth), reset sin enumeración de usuarios, onboarding de 3 pasos → `POST /onboarding/complete` con segmentación determinista en backend, biometría opcional (`local_auth` en modo solo biometría, sin PIN del dispositivo), `/lock` al reabrir y auto-lock tras 30 s en background, logout con limpieza de caché, tokens y flags. |
| R2 | Cuentas, saldos y movimientos | P0 | ✅ | Cuentas `checking`/`savings` sembradas por el backend, lectura en tiempo real desde Firestore, movimientos agrupados por día (50 → máx. 100 por regla), detalle y transferencia entre cuentas propias idempotente y atómica en el BFF. |
| R3 | Personalización dinámica | P0 | ✅ | SDUI propio: `GET /experience` por segmento, 8 componentes cerrados, acciones allowlisted, cascada remoto → last-known-good → embebido. Cambio en vivo con `PUT /admin/experiences` (validado con zod) + pull-to-refresh. |
| R4 | Integración de servicio/micro-app externo | P0 | ✅ (versión simple) | Micro-app "Viaja Seguro" en WebView con allowlist de host, token de contexto JWT 5 min con claims mínimos, bridge v1 con nonce y parser estricto, limpieza de cookies/caché al cerrar. Verificada en producción (descuento Premium). |
| R5 | Notificaciones push | P0 | ✅ | FCM con canales, opt-in en contexto, push al completar transferencia y campaña por segmento (topics), deep links con allowlist que respetan el bloqueo. Verificado en producción. |
| R6 | Monitoreo en producción | P0 (impl. mínima) | ✅ | ✅ Crashlytics (fatales y no fatales) con custom keys `request_id` y `segment`, logs JSON estructurados en Functions, correlation id `X-Request-Id` app↔backend, eventos de Analytics (`transfer_completed`, `sdui_fallback_used`, `micro_app_quote_accepted`) y user property `segment` (F8 mínimo). 📄 Performance traces. Ver [observability](observability.md). |
| R7 | Conectividad limitada / latencia / caída parcial | P0 | ✅ | ✅ Caché offline de Firestore con banner stale, last-known-good del SDUI, timeouts + retry con backoff y jitter (solo idempotentes), kill switches por servicio (`PUT /admin/flags` → 503 → "en mantenimiento"), transferencias bloqueadas offline. ✅ F7: Network Lab (offline, +3 s, forzar 503) y circuit breaker por servicio, verificados en emulador. Ver [resilience](resilience.md). |
| R8 | Tests unit + widget + 1 E2E | P0 | ⚠️ | ✅ 253 tests Flutter + 56 backend. 📄 E2E con `integration_test` (F9). Ver [testing](testing.md). |
| R9 | Uso de IA e impacto | P0 | ✅ | [ai-log](ai/ai-log.md) por tarea + [resumen medido](ai/ai-usage.md). |
| R10 | Decisiones de arquitectura (ADRs) | P0 | ✅ | 13 ADRs en [`adr/`](adr/), formato Problema · Alternativas · Opción · Trade-offs · Impacto. |
| R11 | README reproducible, arquitectura, despliegue y operación | P0 | ✅ | [README](../README.md), [architecture](architecture.md), [api](api.md), [deployment-operations](deployment-operations.md). |
| R12 | Trunk Based Development + historial | P0 | ✅ | Commits pequeños a `main` con Conventional Commits, CI en cada push. |
| R13 | Demostración funcional (video) | P0 | 🚧 | Se graba al cierre, en Android. |
| B1 | Integración nativa (`FLAG_SECURE` / app switcher) | P1 | 📄 | F10, segundo candidato a corte. |
| B2 | Asistente generativo | P2 | ⚠️ | ✅ Backend `POST /assistant` acotado con fallback determinista (Gemini deshabilitado en el despliegue). 📄 Pantalla en la app (F11, primer candidato a corte): la ruta `/assistant` hoy abre un placeholder. |
| B3 | Automatizaciones dev/test/deploy/docs | P1 | ✅ | CI (format/analyze/test/coverage), release por tag con APK ofuscado y deploy opcional de Firebase, hook de Claude Code que formatea cada `.dart`, Dart MCP, Dependabot, prompts versionados. 📄 comando para ADRs y changelog automático. |

## Cortado o fuera de alcance, y por qué

| Ítem | Por qué |
|---|---|
| KYC / biometría facial, transferencias a terceros | Requieren proveedor externo y riesgo regulatorio; no agregan señal técnica distinta a la transferencia propia idempotente. |
| Certificate pinning, detección root/jailbreak | Coste de mantenimiento (rotación de certificados) y falsos positivos; App Check + Play Integrity cubren la atestación en este alcance. Ver [security-owasp](security-owasp.md). |
| Encolar transferencias offline | Decisión de producto: mover dinero con un saldo posiblemente desactualizado y ejecutarlo más tarde sorprende al usuario. Se bloquea con mensaje claro. |
| `genui` / LLM que emite UI | En banca el modelo no debe generar UI ni acciones; el asistente responde con datos estructurados verificados que el servidor convierte en SDUI de solo lectura. |
| Flavors nativos y proyectos Firebase separados | Entrypoints `main_dev`/`main_prod` + `--dart-define-from-file` sobre un solo proyecto; flavors nativos en iOS cuestan horas. En producción real: un proyecto por entorno. |
| iOS compilado y push en iOS | Android es la plataforma de la demo; iOS queda configurado pero no se compiló en esta iteración. |
| Multi-país / multimoneda | Un país (Ecuador), USD. `Money` en centavos permite extenderlo. |
| Melos, feature-per-package | Pub workspaces + Makefile bastan para 4 miembros; se evalúa al crecer el equipo. |
| Micro-app: timeout de carga, validación completa del payload, modo emulador | Alcance de F6 reducido por deadline; registrado como deuda en [risks-assumptions](risks-assumptions.md). |

## Valor entregado

- **Negocio sin release:** el home por segmento y sus ofertas se cambian en segundos desde el backend, con
  validación previa y sin riesgo de romper la app (componentes desconocidos se ignoran, documentos inválidos
  no pisan el último bueno).
- **Dinero correcto:** enteros en centavos, validación en cliente y servidor, transferencia atómica e idempotente
  (reintentos seguros), nada se escribe desde el cliente.
- **Ecosistema abierto con control:** terceros entran como micro-apps aisladas con identidad de vida corta y un
  contrato de mensajes estricto.
- **Operable:** kill switches por servicio, mensajes de mantenimiento, crash reporting y correlación de requests
  extremo a extremo.
