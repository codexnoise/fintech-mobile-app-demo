# Prompts para Claude Code — bloques Flutter

Prompts versionados para construir la app con Claude Code. Son parte de la evidencia de
"uso controlado de IA": cada bloque define alcance, restricciones, criterios de aceptación
y plan de commits. **Ejecutarlos en orden**, uno por sesión, revisando cada diff.

**Precondiciones generales**
- Leer `CLAUDE.md`, `docs/api.md` y el spec local `docs/private/spec.md`.
- Diseños de Stitch en `~/Documents/claude/stitch/` (tokens ya cargados en `nexo_design_system`; ajustarlos si los diseños difieren).
- Flutter 3.47.4 vía FVM. Agregar dependencias con `fvm flutter pub add` (resuelve la última versión compatible).
- Antes de cada commit: `make format analyze test`. Commits pequeños (cada 20-30 min).
- Backend local: `firebase emulators:start` (Auth 9099, Firestore 8080, Functions 5001, Hosting 5000).

---

## F1 — Bootstrap de la app (≈1 h)

```
Contexto: lee CLAUDE.md y docs/api.md. Vamos a crear el esqueleto de apps/mobile.

Tareas:
1. Dependencias en apps/mobile: flutter_bloc, get_it, go_router, dio, uuid, intl, connectivity_plus,
   flutter_secure_storage, shared_preferences, firebase_core, firebase_auth, cloud_firestore,
   firebase_app_check, firebase_crashlytics, firebase_analytics, firebase_performance,
   firebase_remote_config; dev: bloc_test, mocktail.
   En packages/core: dio, connectivity_plus, uuid.
2. Entornos: lib/main_dev.dart y lib/main_prod.dart que llaman a bootstrap(AppEnv).
   AppEnv lee --dart-define-from-file (env/dev.json, env/prod.json; versionar solo *.example.json):
   API_BASE_URL, USE_EMULATORS (bool), APP_ENV (dev|prod).
   En dev con USE_EMULATORS: conectar Auth/Firestore a emuladores (10.0.2.2 en Android) y App Check
   con AndroidProvider.debug / AppleProvider.debug. En prod: playIntegrity / deviceCheck.
3. bootstrap(): WidgetsFlutterBinding, Firebase.initializeApp(DefaultFirebaseOptions),
   App Check, Crashlytics (FlutterError.onError + PlatformDispatcher.onError), runZonedGuarded, DI.
4. packages/core — red:
   - ApiClient (Dio) con interceptores en este orden: RequestIdInterceptor (uuid v4 por request,
     header X-Request-Id), AuthInterceptor (ID token de FirebaseAuth; en 401 refresca 1 vez),
     AppCheckInterceptor (header X-Firebase-AppCheck), ChaosInterceptor (inyectable, ver F7),
     RetryInterceptor (backoff exponencial + jitter, máx 3, solo GET y requests marcados como
     idempotentes vía options.extra['idempotent']=true).
   - Timeouts: connect 5s, receive 10s.
   - ErrorMapper: DioException/sobre de error del BFF -> Failure de nexo_core según tabla de docs/api.md
     (incluye requestId y Retry-After). El ApiClient expone Future<Result<T>>.
   - Abstraer el proveedor de tokens (interfaces) para que core NO dependa de Firebase.
5. DI con get_it en lib/app/di.dart. Router go_router en lib/app/router.dart con rutas:
   /splash, /login, /register, /onboarding, /lock, /home, /accounts/:id, /transfers/new,
   /micro-apps/:appId, /assistant, /dev/network-lab (solo APP_ENV=dev).
6. App: MaterialApp.router con NexoTheme.light(), locale es, pantallas placeholder.
7. Tests unitarios de ErrorMapper y RetryInterceptor (mocktail).

Aceptación: la app corre en el emulador Android contra emuladores de Firebase; make test verde.
Commits sugeridos: "build(mobile): add dependencies and environments", "feat(core): add ApiClient
with interceptors and error mapping", "feat(mobile): bootstrap Firebase, App Check, Crashlytics and DI",
"feat(mobile): add router and app shell". Registra la fila en docs/ai/ai-log.md.
```

## F2 — Auth, onboarding, biometría y auto-lock (≈1.5 h) · ⚠️ revisión humana obligatoria

```
Contexto: CLAUDE.md marca features/auth como sensible. Muéstrame el plan antes de editar.

Feature auth (domain/data/presentation, Cubit + sealed states):
- Registro y login con email/contraseña (FirebaseAuth). Validación de formulario en UI.
  Mensajes de error humanos (no códigos de Firebase).
- Onboarding 3 pasos (nombre → año de nacimiento + ocupación → rango de ingreso) con barra de progreso
  -> POST /onboarding/complete. Si GET /me devuelve onboarding_required, el router redirige a /onboarding.
- Biometría con local_auth detrás de una interfaz BiometricAuthenticator (para poder usar un fake en E2E):
  - Tras el primer login, ofrecer "Activar ingreso con biometría". Guardar el flag en flutter_secure_storage
    (Android: encryptedSharedPreferences; iOS: first_unlock_this_device).
  - biometricOnly: true, sin fallback a PIN del dispositivo para operaciones sensibles.
  - En aperturas siguientes con sesión Firebase vigente: /lock exige biometría antes de mostrar datos.
- Auto-lock: AppLifecycleListener; si la app pasa a background > 30 s, al volver ir a /lock.
- Logout: signOut + limpiar secure storage, cache SDUI y Firestore (clearPersistence tras terminate).
- Android: MainActivity debe extender FlutterFragmentActivity (requisito de local_auth);
  permiso USE_BIOMETRIC. iOS: NSFaceIDUsageDescription en Info.plist.
- Tests: AuthCubit, OnboardingCubit, LockCubit (bloc_test); widget test del formulario de login
  (validaciones) y del onboarding (avance de pasos).

Aceptación: registro → onboarding → home; cerrar y abrir → pide biometría; background 30 s → lock.
Commits: uno por sub-feature (login/registro, onboarding, biometría, auto-lock).
```

## F3 — Cuentas, movimientos y transferencias (≈1.5 h)

```
Feature accounts:
- AccountsRepository lee Firestore directo (solo lectura, reglas ya lo restringen):
  users/{uid}/accounts y users/{uid}/accounts/{id}/movements orderBy createdAt desc limit 50 (paginación).
- Exponer si el dato viene de cache: snapshot.metadata.isFromCache + updatedAt -> estado "stale" con
  etiqueta "Actualizado hace X". Montos con Money (int cents) y formateo intl es.
- UI: lista de cuentas (alias, ****1234, saldo grande), detalle con movimientos agrupados por día,
  skeleton, vacío, error con reintento. Semantics en montos ("saldo, mil doscientos dólares con cincuenta").
Feature transfers:
- Formulario: origen, destino (cuentas propias distintas), AmountField estilo cajero (Money.fromTypedDigits),
  nota opcional -> bottom sheet de confirmación -> POST /transfers con idempotencyKey (uuid v4 generado
  UNA vez por intento y reutilizado si el usuario reintenta) -> pantalla de éxito.
- Marcar el request como idempotente para el RetryInterceptor.
- Errores 422 con mensaje del backend; 503 -> estado "Transferencias en mantenimiento".
- Sin conexión: deshabilitar el botón y explicar que no se encolan transferencias offline (decisión de producto).
- Tests: TransferCubit (éxito, insuficiente, 503, reintento conserva la misma key), widget test del AmountField.

Aceptación: transferir mueve saldos en tiempo real (stream) y aparece el movimiento.
```

## F4 — SDUI renderer + Home personalizada (≈2 h)

```
packages/sdui_engine ya tiene el contrato y el parser (con tests). Falta el render:
- SduiRegistry: Map<String, SduiWidgetBuilder>, con builders para greeting_header, balance_summary,
  quick_actions, promo_banner, insight_card, micro_app_tile, tip_list, spending_bars (usar nexo_design_system).
  balance_summary NO recibe montos del JSON: recibe un builder/slot inyectado por la app que lee AccountsRepository.
- SduiActionDispatcher: callback (SduiAction) -> la app traduce a go_router. Las acciones pasan por
  SduiParser.parseAction (allowlist); si es null, el widget se renderiza sin acción.
- SduiView(document) que dibuja la lista de componentes; un componente que falla al construir se reemplaza
  por SizedBox.shrink y se reporta a Crashlytics como no fatal (nunca rompe la pantalla).
En la app, feature experience:
- ExperienceRepository con cascada: GET /experience -> guardar como last-known-good (shared_preferences,
  por segmento) -> si falla: last-known-good -> si no hay: assets/sdui/default_home.json (embebido).
  Exponer la fuente (remote | cache | bundled) para mostrar un indicador sutil y medir en analytics.
- HomeCubit con pull-to-refresh y respeto del ttl.
- Tests: widget tests del SduiView (render por tipo, tipo desconocido ignorado, acción fuera de allowlist
  sin onTap, componente que lanza no rompe), test de la cascada de fallback, y un test de accesibilidad
  con meetsGuideline(androidTapTargetGuideline), textContrastGuideline y labeledTapTargetGuideline.

Aceptación: con la app abierta, `PUT /admin/experiences` + pull-to-refresh cambia la home; cambiar de
segmento cambia la home completa.
```

## F5 — Notificaciones push (≈1 h)

```
- firebase_messaging + flutter_local_notifications. Canales Android: "transactions" (alta prioridad) y
  "campaigns". Permiso POST_NOTIFICATIONS (Android 13+) pedido en contexto (después del onboarding,
  explicando el valor), no al abrir la app.
- Registrar token: POST /devices (deviceId estable guardado en secure storage), y en onTokenRefresh.
- Foreground: mostrar notificación local. Tap (foreground/background/terminated): navegar a data.route.
- iOS: solo compilar (sin APNs).
- Tests: NotificationRouter (data -> ruta) unitario.
Aceptación: una transferencia dispara un push y el tap abre la cuenta; una campaña por segmento
(POST /admin/campaigns) llega solo al segmento correcto.
```

## F6 — Host de micro-apps (≈1 h) · ⚠️ revisión humana obligatoria

```
Feature micro_apps con webview_flutter. Contrato del bridge en micro_apps/travel_insurance/README.md.
- Registry de micro-apps: appId -> { url, allowedHost }. Solo travel_insurance.
- Al abrir: POST /micro-apps/context-token. Si falla o 503 -> estado "Servicio no disponible" con reintento.
- WebView endurecido: NavigationDelegate bloquea todo host != allowedHost (y esquemas no https salvo
  emulador en dev); sin acceso a archivos; JavaScriptChannel "NexoBridge"; timeout de carga 10 s.
- Al recibir {type:'ready'}: generar nonce aleatorio y llamar
  runJavaScript("window.nexo.receive(<json>)") con {v:1,type:'context',nonce,token,apiBase}.
- Mensajes entrantes: parsear con schema estricto; descartar v != 1, type fuera de
  {ready, quote_accepted, close, error} o nonce distinto. quote_accepted -> cerrar y mostrar confirmación nativa.
- Tests unitarios del BridgeMessageParser (válido, nonce incorrecto, tipo desconocido, JSON inválido).
```

## F7 — Resiliencia y Network Lab (≈1.25 h)

```
- ChaosInterceptor (packages/core): configuración en memoria {offline, latency, errorRateByService}.
  Servicio inferido por path (/experience, /transfers, /micro-apps, /assistant).
- CircuitBreaker por servicio en core: abre tras 3 fallos consecutivos, half-open a los 30 s;
  abierto -> ServiceUnavailableFailure inmediato sin red.
- ConnectivityCubit (connectivity_plus + último resultado real de red) -> StatusBanner global
  "Sin conexión" / "Conexión lenta" / "Servicio en mantenimiento".
- Pantalla /dev/network-lab (solo APP_ENV=dev, accesible con long-press en el logo): toggles de
  offline, latencia 0/2/5 s, error 0/30/100 % por servicio, y botón para resetear circuit breakers.
- Tests: CircuitBreaker (transiciones), ChaosInterceptor, banner según estado.
Aceptación: cada escenario de docs/resilience.md se reproduce desde el Network Lab.
```

## F8 — Observabilidad (≈0.75 h)

```
- Crashlytics: setUserIdentifier con uid hasheado (no email), custom keys segment, app_env, último requestId.
  ErrorMapper registra no fatales para 5xx con requestId.
- Performance: traces custom sdui_load, transfer_submit, micro_app_open (con atributo source/result).
- Analytics: screen views vía observer de go_router; eventos onboarding_step, onboarding_completed,
  transfer_started/completed/failed(code), sdui_component_tap(type,id), sdui_fallback_used(source),
  micro_app_opened/quote_accepted, network_lab_toggle. Nada de PII.
- Tests: que el AnalyticsService (interfaz) se llame en el TransferCubit (mock).
```

## F9 — E2E crítico + accesibilidad (≈1.25 h)

```
integration_test/critical_flow_test.dart contra emuladores de Firebase:
registro → onboarding → (biometría con FakeBiometricAuthenticator inyectado por DI en test) → home
→ transferencia de USD 10 checking→savings → verificar saldos actualizados y movimiento visible.
Agregar target en Makefile: `make e2e` (requiere emuladores corriendo y un emulador Android).
Agregar tests de accesibilidad (meetsGuideline) en login y transferencia.
Documentar en docs/testing.md la pirámide, cómo correr cada nivel y la cobertura.
```

## F10 — Integración nativa: protección de pantalla (≈0.75 h) · P1

```
MethodChannel "dev.codexnoise.nexo/screen_security" con setSecure(bool):
- Android (Kotlin, MainActivity): window.addFlags/clearFlags(WindowManager.LayoutParams.FLAG_SECURE).
- iOS (Swift, AppDelegate): al pasar a background (sceneWillResignActive / applicationWillResignActive)
  superponer una vista con blur para ocultar el contenido en el app switcher; quitarla al volver.
- Dart: ScreenSecurity service; activarlo en home, cuentas y transferencias; desactivarlo en login.
- Test unitario del service con TestDefaultBinaryMessenger.
Aceptación: en Android una captura de pantalla de una cuenta sale negra/bloqueada.
```

## F11 — Asistente (≈0.75 h) · P2

```
Pantalla /assistant: chips con los 3 promptId; al tocar -> POST /assistant -> renderizar el documento
con el mismo SduiView (tip_list, spending_bars, insight_card). Mostrar una etiqueta "Generado con IA ·
cifras verificadas" si source == "model", o "Resumen automático" si es fallback. 503 -> "no disponible".
Sin texto libre (decisión de seguridad). Tests del AssistantCubit.
```
