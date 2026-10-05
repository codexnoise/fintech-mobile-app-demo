# ADR 0008 — Postura de seguridad móvil (OWASP Mobile Top 10 2024)

Estado: Aceptado · Fecha: 2026-10-05

> ADR de postura. La matriz completa M1–M10 con estado por control (✅ implementado / 📄 documentado
> como evolución) está en [docs/security-owasp.md](../security-owasp.md).

## Problema

Una app bancaria es objetivo de fraude, ingeniería inversa y abuso de APIs. Con recursos limitados hay
que decidir qué controles implementar ahora, cuáles documentar como evolución, y bajo qué principios se
toman decisiones de seguridad en todo el sistema (app, BFF, reglas, micro-apps, IA).

## Alternativas evaluadas

| Enfoque | Pros | Contras |
|---|---|---|
| Seguridad "al final" (checklist previo a release) | Rápido al inicio | Retrabajo; decisiones de arquitectura ya tomadas sin seguridad |
| Implementar todos los controles avanzados (pinning, RASP, root detection) | Cobertura máxima | Fuera de plazo; algunos con costo operativo alto (rotación de certificados) |
| **Defensa en profundidad con el servidor como fuente de verdad + matriz OWASP explícita** | Controles de mayor impacto primero, trazables | Algunos controles quedan como evolución documentada |

## Opción seleccionada

Principios:

1. **El cliente no es confiable:** toda escritura pasa por el BFF; Firestore deny-by-default
   (`firebase/firestore.rules`); validación zod e idempotencia en servidor ([ADR 0004](0004-firebase-functions-bff.md)).
2. **Cero secretos en el binario:** solo configuración pública por `--dart-define-from-file`; secretos en
   Secret Manager.
3. **Superficie remota acotada:** SDUI con registry cerrado y acciones allowlisted; bridge de micro-apps
   con nonce, schema estricto y token de contexto con audiencia ([ADR 0005](0005-sdui-propio.md),
   [ADR 0006](0006-micro-apps-webview-bridge.md)); el LLM no emite UI ni acciones ([ADR 0012](0012-ia-acotada-solo-lectura.md)).
4. **Sesión protegida en el dispositivo.**

Controles implementados (resumen):

- Firebase Auth + verificación de ID token en cada endpoint; App Check (Play Integrity en prod, debug
  provider en dev); backend desplegado con `APP_CHECK_ENFORCED=true`.
- Biometría `biometricOnly` (sin fallback al PIN del dispositivo; ante lockout, contraseña de Nexo),
  flags en `flutter_secure_storage`, auto-lock a los 30 s en background, logout con limpieza de cachés.
- Reset de contraseña sin enumeración de usuarios.
- Deep links de push con allowlist de rutas y apertura solo con sesión lista.
- Release con `--obfuscate --split-debug-info` (`.github/workflows/release.yml`); `allowBackup=false`;
  cleartext solo hacia emuladores en debug (`network_security_config`); Dependabot.
- Logs del backend sin PII (uid pseudonimizado), `X-Powered-By` deshabilitado, headers de seguridad.

Documentado como evolución (📄): certificate/SPKI pinning, detección de root/jailbreak, `FLAG_SECURE` y
ocultar contenido en el app switcher.

## Trade-offs

- **A favor:** los controles con mayor reducción de riesgo (autorización en servidor, integridad de la
  app, validación) están implementados y verificados en producción (p. ej. `/me` sin App Check → 401).
- **En contra:** sin pinning ni detección de root la app es más expuesta a MITM en dispositivos
  comprometidos; mitigado parcialmente por App Check y TLS.
- **En contra:** la caché de Firestore y el last-known-good SDUI no están cifrados; se limpian en logout.
- **En contra:** Play Integrity falla en APKs instalados fuera de Play; la demo usa build dev con debug
  token.

## Impacto a largo plazo

- La matriz OWASP es un artefacto vivo: cada control 📄 tiene dueño y criterio para pasar a ✅.
- Antes de producción real: pinning con estrategia de rotación, RASP/root detection, `FLAG_SECURE`,
  pentest externo y proyectos Firebase separados por entorno ([ADR 0013](0013-entrypoints-en-vez-de-flavors.md)).
- Los archivos sensibles (reglas, transfers, middleware, auth, bridge) requieren aprobación humana
  explícita para cambios, también cuando los propone un agente de IA (`CLAUDE.md`).
