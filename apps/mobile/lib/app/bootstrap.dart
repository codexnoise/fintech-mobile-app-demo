import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:nexo_core/nexo_core.dart';

import '../firebase_options.dart';
import 'app.dart';
import 'di.dart';
import 'env.dart';
import 'session/auto_lock.dart';
import 'session/deep_link_gate.dart';
import 'session/session_cubit.dart';
import 'session/session_status.dart';
import '../features/notifications/presentation/push_coordinator.dart';

/// Punto de entrada común de `main_dev.dart` y `main_prod.dart`.
Future<void> bootstrap(AppFlavor flavor) async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final env = AppEnv.fromEnvironment(fallback: flavor);
      Intl.defaultLocale = 'es';
      await initializeDateFormatting('es');

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await _configureCrashlytics(env);
      await _activateAppCheck(env);
      if (env.useEmulators) await _useEmulators();

      configureDependencies(env);
      final session = getIt<SessionCubit>()..start();
      final router = getIt<GoRouter>();
      AutoLock(onLock: session.lock).attach();
      _wirePush(session, router);
      _wireObservability(session);
      runApp(NexoApp(router: router, session: session));
    },
    (error, stack) {
      if (Firebase.apps.isEmpty) {
        // Falló antes de Firebase: no hay a dónde reportar.
        debugPrint('Error de arranque: $error\n$stack');
        return;
      }
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

/// Push: el token se registra cuando hay sesión con perfil, y el tap pasa por
/// [DeepLinkGate] para abrirse recién con la app visible y la sesión lista
/// (después de /lock si correspondía).
void _wirePush(SessionCubit session, GoRouter router) {
  final push = getIt<PushCoordinator>();
  final gate = DeepLinkGate(
    currentStatus: () => session.state,
    isForeground: () =>
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    navigate: router.push,
  );
  AppLifecycleListener(onResume: gate.onResumed);
  push.routes.listen(gate.add);

  void onStatus(SessionStatus status) {
    if (status is SessionReady) unawaited(push.onSessionReady());
    gate.onStatus(status);
  }

  session.stream.listen(onStatus);
  onStatus(session.state);
  unawaited(push.start());
}

/// Segmento como contexto de Crashlytics y user property de Analytics
/// (dimensión para comparar experiencias por segmento). Sin PII.
void _wireObservability(SessionCubit session) {
  final analytics = getIt<AnalyticsTracker>();
  void onStatus(SessionStatus status) {
    final String? segment;
    if (status is SessionReady) {
      segment = status.profile.segment.wire;
    } else if (status is SessionUnauthenticated) {
      segment = null;
    } else {
      return;
    }
    analytics.setUserProperty('segment', segment);
    FirebaseCrashlytics.instance.setCustomKey('segment', segment ?? 'none');
  }

  session.stream.listen(onStatus);
  onStatus(session.state);
}

Future<void> _configureCrashlytics(AppEnv env) async {
  final crashlytics = FirebaseCrashlytics.instance;
  // En dev no se envían reportes; los errores igual se ven en consola.
  await crashlytics.setCrashlyticsCollectionEnabled(!env.isDev);
  FlutterError.onError = (details) {
    if (env.isDev) FlutterError.presentError(details);
    crashlytics.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}

Future<void> _activateAppCheck(AppEnv env) {
  return FirebaseAppCheck.instance.activate(
    providerAndroid: env.isDev
        ? AndroidDebugProvider(debugToken: env.appCheckDebugToken)
        : const AndroidPlayIntegrityProvider(),
    providerApple: env.isDev
        ? AppleDebugProvider(debugToken: env.appCheckDebugToken)
        : const AppleDeviceCheckProvider(),
  );
}

/// Emuladores locales (puertos de firebase.json). El emulador de Android
/// llega al host por 10.0.2.2.
Future<void> _useEmulators() async {
  final host = defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
}
