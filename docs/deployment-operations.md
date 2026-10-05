# Despliegue y operación

Entornos, despliegue, release, palancas operativas sin publicar la app y runbooks.
Estado: ✅ implementado · 📄 propuesto para producción real.

## Entornos

| Entorno | App (`apps/mobile/env/`) | Backend | Uso |
|---|---|---|---|
| Emuladores | `dev.example.json` (`USE_EMULATORS=true`, BFF en `http://10.0.2.2:5001/nexo-fintech-demo/us-east1/api`) | `firebase emulators:start` (Auth 9099, Firestore 8080, Functions 5001, Hosting 5000, UI 4000) | Desarrollo diario, tests manuales sin costo |
| dev-cloud | `dev-cloud.example.json` (`APP_ENV=dev`, BFF desplegado) | Proyecto `nexo-fintech-demo` | Probar push, App Check y micro-app reales con build dev + debug token |
| prod | `prod.example.json` (`APP_ENV=prod`) | Proyecto `nexo-fintech-demo` | Build release del tag (`main_prod.dart`) |

Cada archivo `.example.json` se copia a `env/<nombre>.json` (ignorado por git) y se pasa con `--dart-define-from-file`.
La app selecciona comportamiento por entrypoint: `lib/main_dev.dart` (debug provider de App Check, Crashlytics apagado,
Network Lab) y `lib/main_prod.dart` (Play Integrity, Crashlytics activo).

```bash
cd apps/mobile && fvm flutter run -t lib/main_dev.dart --dart-define-from-file=env/dev.json
```

**Un solo proyecto Firebase** (`.firebaserc` → `nexo-fintech-demo`): para la prueba técnica reduce setup (un
`flutterfire configure`, un set de secrets) y se compensa con entrypoints en vez de flavors nativos. **En producción real**
serían proyectos separados `nexo-dev` / `nexo-staging` / `nexo-prod` (aislamiento de datos, IAM y cuotas), con flavors
nativos y un `google-services.json` por flavor. 📄

## Despliegue del backend

Functions v2 (`api`, región `us-east1`, Node 22), reglas e índices de Firestore y Hosting de la micro-app:

```bash
(cd backend/functions && npm ci && npm test)
firebase functions:secrets:set MICROAPP_SIGNING_KEY   # openssl rand -base64 48
firebase functions:secrets:set ADMIN_API_KEY
firebase functions:secrets:set GEMINI_API_KEY         # o "disabled" → fallback determinista
cp backend/functions/.env.example backend/functions/.env.nexo-fintech-demo   # MICROAPP_ORIGINS, APP_CHECK_ENFORCED
firebase deploy --only functions,firestore,hosting
```

- El `predeploy` de `firebase.json` compila TypeScript; el deploy falla si falta alguno de los tres secrets.
- **Secrets nunca en el repo**: viven en Secret Manager. Para emuladores se usa `backend/functions/.secret.local` (ignorado; plantilla `.secret.local.example`).
- `firebase deploy` lo ejecuta un humano: está bloqueado para agentes de IA en `.claude/settings.json`.

## CI/CD y release

- **CI** (`.github/workflows/ci.yml`, cada push a `main` y PR): Flutter format, analyze y tests con coverage de los 4 miembros; backend typecheck + coverage (vitest); `node --check` de la micro-app. Localmente: `make check`.
- **Release** (`.github/workflows/release.yml`, tag `vX.Y.Z` sobre `main`): APK release con `main_prod.dart`, `--obfuscate --split-debug-info` y `env/prod.example.json`, adjunto al GitHub Release con notas generadas.
- Job `deploy-firebase` del release: despliega `functions,firestore,hosting` con una service account. Está **desactivado** salvo que la variable `ENABLE_FIREBASE_DEPLOY=true` y los secrets `FIREBASE_SERVICE_ACCOUNT` / `FIREBASE_PROJECT_ID` existan; hoy el deploy es manual.
- Trunk Based Development: commits pequeños a `main`, siempre verde; trabajo incompleto detrás de rutas dev o flags.

### Staged rollout propuesto (📄)
1. AAB firmado con Play App Signing → pista interna (QA) → producción **1 % → 10 % → 50 % → 100 %**.
2. Avanzar de etapa solo si en 24 h: sesiones sin crash ≥ 99.5 %, sin nuevos issues fatales y 5xx del BFF estables (ver [observabilidad](observability.md)).
3. Si una etapa falla: detener el rollout en Play Console y apagar la funcionalidad con un kill switch mientras se prepara el fix.
4. Backend compatible hacia atrás: el BFF filtra componentes por `minAppVersion`, así conviven versiones de app durante el rollout.

## Palancas operativas sin publicar la app

Todas requieren `X-Admin-Key` (en producción real: backoffice con IAM y auditoría 📄).

```bash
API=https://us-east1-nexo-fintech-demo.cloudfunctions.net/api
H=(-H "X-Admin-Key: $ADMIN_API_KEY" -H "Content-Type: application/json")
curl -X PUT "$API/admin/flags" "${H[@]}" -d '{"degradedServices":["transfers"]}'   # kill switch
curl -X PUT "$API/admin/flags" "${H[@]}" -d '{"microAppsEnabled":false}'          # retira micro-apps
curl -X PUT "$API/admin/experiences" "${H[@]}" -d @experience.json                # publica SDUI
```

- **Kill switches** (`ops/flags`): `degradedServices` ∈ `onboarding | experience | transfers | micro_apps | assistant` → 503 + `Retry-After`; `microAppsEnabled` / `assistantEnabled` también retiran tiles y acciones del documento SDUI. Efecto en ≤ 30 s (caché de flags por instancia).
- **Rollback de experiencias SDUI**: `PUT /admin/experiences` sobrescribe `experiences/{segment}__{screen}` tras validar el contrato con zod. Volver atrás = publicar de nuevo el JSON de la versión anterior con su `version` (los defaults versionados están en `backend/functions/src/experience/defaults/`). Si se borra el documento en Firestore, el BFF sirve el default del código. Hoy no se guarda historial en Firestore; 📄 colección `experiences_history` + endpoint de rollback por versión.

## Runbooks

### Transferencias fallando
1. Logs: `jsonPayload.path="/transfers" AND jsonPayload.status>=500`. Revisar `unhandled_error` con el mismo `requestId`.
2. Si son 422 masivos, revisar el `code` (p. ej. `exceeds_daily_limit`) antes de asumir un incidente.
3. Si el error es del backend o de Firestore: activar `{"degradedServices":["transfers"]}`. La app muestra "en mantenimiento" y no reintenta; el dinero no queda en estado incierto gracias a la idempotencia.
4. Corregir, desplegar `--only functions`, verificar con una transferencia de prueba y retirar el flag.

### Home vacía o con fallback
1. Síntoma: usuarios ven "Mostrando una versión básica…" o "Estamos actualizando tu inicio…".
2. Logs: `jsonPayload.path="/experience"` (status) y `experience_config_invalid` (configuración publicada rota → el BFF ya sirve el default).
3. Si la última publicación es la causa, republicar la versión anterior con `PUT /admin/experiences`.
4. Verificar `ops/flags`: un `experience` olvidado en `degradedServices` produce exactamente este síntoma.

### Micro-app caída
1. Comprobar Hosting (`https://nexo-fintech-demo.web.app`) y `POST /micro-apps/context-token` / `introspect` en logs.
2. Mitigar: `{"microAppsEnabled":false}` → el tile desaparece de la home en el siguiente refresh; el resto de la app sigue.
3. Rollback de Hosting desde la consola (versiones anteriores) o `firebase deploy --only hosting` con el fix; reactivar el flag.

### Pico de crashes
1. Crashlytics: identificar el issue, versión y dispositivos afectados (con símbolos de `--split-debug-info`).
2. Si está ligado a un componente SDUI, los crashes de build ya se omiten y llegan como no fatales; retirarlo con `PUT /admin/experiences`.
3. Si está ligado a un servicio, apagarlo con su kill switch. Con staged rollout, detener la etapa.
4. Fix → tag `vX.Y.Z+1` → release.

### App Check rechazando
1. Síntoma: `401 app_check_failed` en logs para clientes legítimos.
2. Build dev: registrar el debug token del dispositivo en Console → App Check → Manage debug tokens.
3. Build release fuera de Play: Play Integrity falla por diseño; distribuir por Play (pista interna) o usar build dev para demo.
4. Emergencia de producción: desplegar con `APP_CHECK_ENFORCED=false` en `.env.<project>` de forma temporal, registrarlo como incidente y revertir al resolver. El ID token se sigue exigiendo.

Relacionado: [resiliencia](resilience.md) · [observabilidad](observability.md) · [seguridad](security-owasp.md) · [contrato del BFF](api.md).
