# Supuestos, riesgos y mitigaciones

> Leyenda: ✅ mitigación implementada · 🚧 en curso · 📄 propuesta / evolución.

## Supuestos

| Supuesto | Implicación |
|---|---|
| **Core bancario simulado en Firestore.** El BFF (Cloud Functions) actúa como core: siembra cuentas `checking`/`savings` deterministas por `uid` y ejecuta transferencias en transacciones de Firestore. | Los contratos (`docs/api.md`) se diseñaron como fachada: en producción el adaptador de Firestore se reemplaza por uno contra el core real sin tocar la app (arquitectura hexagonal). |
| **KYC fuera de alcance.** El registro es email + contraseña; no hay verificación de identidad ni biometría facial. | Un cliente real pasaría por un proveedor KYC antes de habilitar transferencias. |
| **Un país, una moneda:** Ecuador, USD. | `Money` en centavos `int` y textos en español; multimoneda requiere código de moneda en el modelo. |
| **Solo cuentas propias.** No hay transferencias a terceros ni límites diarios acumulados. | El límite es por transferencia (USD 5.000), validado en cliente y servidor. |
| **Un solo proyecto Firebase** para dev-cloud y prod; dev local usa Emulator Suite. | En producción real: proyecto por entorno (ver [ADR de entrypoints](adr/) y [deployment-operations](deployment-operations.md)). |
| **Android es la plataforma principal.** | iOS tiene configuración (Firebase, Face ID) pero no se compiló en esta iteración. |
| **Segmentación determinista** (young_digital / entrepreneur / premium) a partir del onboarding. | Reglas testeadas en backend; un modelo de comportamiento real reemplazaría la función de dominio. |

## Riesgos y mitigación

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Caché offline de Firestore **sin cifrar** en el dispositivo (saldos y movimientos). | Exposición de datos financieros en un dispositivo comprometido. | ✅ `terminate` + `clearPersistence` en logout; `allowBackup=false`; flags biométricos en Keystore/Keychain. 📄 Desactivar persistencia o cifrar la caché en producción. |
| **Play Integrity** probablemente falla en un APK instalado fuera de Play Store. | El backend (App Check exigido) responde 401 `app_check_failed`. | ✅ Demo con build dev + debug provider y debug token registrado en consola. 📄 Distribución por Play (internal testing) para validar con Play Integrity. |
| **Certificate pinning no implementado.** | MITM con CA instalada por el usuario o maliciosa. | ✅ TLS del sistema, cleartext prohibido salvo `10.0.2.2`/`localhost` en debug, App Check. 📄 Pinning con rotación planificada. |
| **Sin detección root/jailbreak** ni `FLAG_SECURE`. | Capturas de pantalla / app switcher con saldos; ejecución en entornos manipulados. | ✅ Play Integrity vía App Check en prod. 📄 F10 (`FLAG_SECURE` + ocultar en app switcher), detección root como señal de riesgo. |
| **WebView como superficie de ataque** (micro-apps). | Robo de token o acciones no autorizadas desde código de terceros. | ✅ Allowlist de host https, sin acceso a archivos/content, token JWT de 5 min con audiencia y claims mínimos, bridge con nonce por sesión, parser estricto (versión, tipos allowlisted, ≤ 8 KB), inyección con `jsonEncode`, limpieza de cookies/caché/storage al cerrar, CSP estricta en Hosting, confirmación nativa. ⚠️ Pendiente: timeout de carga, validación completa del payload, modo emulador (la app siempre carga la micro-app desplegada). |
| **Redirects de go_router evaluados con la URI base.** | Tras un auto-lock desde una pantalla apilada, al desbloquear se vuelve a Inicio. | ✅ Aceptado como comportamiento (seguro); los deep links de push sí se preservan con `DeepLinkGate`. |
| **Transferencia con resultado incierto** (timeout, 5xx). | Doble débito si se reintenta. | ✅ `idempotencyKey` uuid v4 por intento, reutilizado ante incertidumbre; el BFF rechaza la misma key con otro monto (422). Retry automático solo en GET/HEAD/idempotentes. |
| **Contrato SDUI roto o servidor caído.** | Home vacío o crash. | ✅ Parser con allowlist y forward-compat, componente que falla se omite (reporte no fatal), last-known-good por segmento, JSON embebido. |
| **Caída de un servicio del BFF** | Reintentos inútiles contra un servicio caído. | ✅ Timeouts, backoff con jitter, `Retry-After`, kill switches y circuit breaker por servicio (F7); Network Lab para demostrarlo. |
| **Observabilidad parcial** (sin Performance ni Analytics). | Sin métricas de latencia percibida ni funnels. | ✅ Crashlytics, logs estructurados, `X-Request-Id`. 📄 F8. Ver [observability](observability.md). |
| **LLM en banca** (asistente). | Cifras inventadas o UI/acciones generadas por el modelo. | ✅ Structured output, verificación de cifras contra datos reales, el servidor arma SDUI de solo lectura, fallback determinista (hoy Gemini está deshabilitado). |
| **Dependencia de un solo desarrollador + IA** con deadline fijo. | Código generado sin revisión suficiente. | ✅ CLAUDE.md con zonas que requieren aprobación humana, TDD, verificación en emulador por bloque, CI en `main`. Ver [ai-usage](ai/ai-usage.md). |

## Qué haría con más tiempo

1. **Cerrar F7–F11:** Network Lab y circuit breaker, Performance + Analytics con funnels, E2E en CI con
   emuladores, `FLAG_SECURE`, pantalla del asistente.
2. **Seguridad:** certificate pinning con rotación, detección root/jailbreak como señal de riesgo al backend,
   cifrado o desactivación de la caché offline, re-autenticación biométrica para montos altos.
3. **Entornos reales:** proyectos Firebase dev/staging/prod, flavors nativos, staged rollout en Play Console,
   App Distribution para QA.
4. **Micro-apps:** timeout y pantalla de error propia, validación de esquema completa del payload, manifiesto
   firmado por micro-app, modo emulador.
5. **Backend:** tests de reglas de Firestore, versionado y rollback de experiencias SDUI con historial,
   límites diarios y antifraude, rate limiting por usuario.
6. **Producto:** transferencias a terceros con KYC, tema oscuro, textos escalables verificados, iOS con push.
