# ADR 0013 — Entrypoints + `--dart-define-from-file` en vez de flavors nativos

Estado: Aceptado · Fecha: 2026-10-04

## Problema

La app necesita al menos dos entornos: desarrollo (emuladores locales o backend desplegado, App Check
con debug provider, Crashlytics apagado, herramientas de diagnóstico) y producción (Play Integrity,
Crashlytics activo, build ofuscado). El plan original preveía flavors nativos (product flavors en
Android y schemes/configurations en iOS), cuyo setup en iOS cuesta horas que no había en el plazo.

## Alternativas evaluadas

| Alternativa | Pros | Contras |
|---|---|---|
| Flavors nativos + un proyecto Firebase por entorno | Apps instalables lado a lado, aislamiento total de datos y credenciales | Horas de configuración (Xcode schemes, `google-services.json` por flavor) |
| Variables de entorno en tiempo de ejecución (archivo remoto) | Cambiable sin rebuild | Configuración sensible a manipulación; arranque depende de red |
| **Entrypoints `main_dev.dart` / `main_prod.dart` + `--dart-define-from-file`, un solo proyecto Firebase** | Setup en minutos, configuración en compilación, sin código nativo | Un solo `applicationId`; dev y prod comparten proyecto Firebase |

## Opción seleccionada

- Dos entrypoints (`apps/mobile/lib/main_dev.dart`, `apps/mobile/lib/main_prod.dart`) que llaman a
  `bootstrap(AppFlavor.dev|prod)` (`apps/mobile/lib/app/bootstrap.dart`).
- Configuración pública por compilación con `--dart-define-from-file=env/<entorno>.json`, leída en
  `AppEnv.fromEnvironment` (`apps/mobile/lib/app/env.dart`): `APP_ENV`, `API_BASE_URL`,
  `USE_EMULATORS`, `APP_CHECK_DEBUG_TOKEN`. Plantillas versionadas: `env/dev.example.json`
  (emuladores), `env/dev-cloud.example.json` (backend desplegado) y `env/prod.example.json`.
- Salvaguardas en código: en `prod` nunca se usan emuladores ni debug token aunque el archivo los pida;
  sin `API_BASE_URL` la app falla al arrancar con un mensaje claro.
- Diferencias por entorno en `bootstrap`: App Check debug provider (dev) vs Play Integrity/DeviceCheck
  (prod); colección de Crashlytics apagada en dev; herramientas como el Network Lab solo en dev.
- **Un solo proyecto Firebase** (`nexo-fintech-demo`) para todos los entornos.
- `release.yml` compila `main_prod.dart` con `env/prod.example.json`, `--obfuscate` y
  `--split-debug-info`.

## Trade-offs

- **A favor:** cambiar de entorno es cambiar dos argumentos de `flutter run`; nada de configuración
  nativa duplicada.
- **A favor:** los `.json` solo contienen configuración pública; los secretos siguen en el servidor.
- **En contra:** dev y prod comparten Auth, Firestore y FCM: datos y usuarios de prueba conviven con los
  "productivos". Aceptable para una demo, **no** para producción real.
- **En contra:** no se pueden instalar dev y prod a la vez en un dispositivo (mismo `applicationId`).
- **En contra:** olvidar el `--dart-define-from-file` produce un error en arranque (mitigado con el
  mensaje explícito y el README).

## Impacto a largo plazo

- **Recomendación para producción real:** proyectos Firebase separados por entorno (dev, staging,
  prod), con su propio `firebase_options` y servicios aislados, más flavors nativos para instalar
  variantes en paralelo y separar credenciales de App Check y FCM.
- La migración es aditiva: los entrypoints y `AppEnv` se conservan; se agregan flavors y la selección de
  `firebase_options` por entorno.
- Ver [ADR 0008](0008-seguridad-owasp-mobile.md) (misconfiguration) y la guía de despliegue.
