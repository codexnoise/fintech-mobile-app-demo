import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_sdui_engine/nexo_sdui_engine.dart';

import '../features/accounts/data/firestore_accounts_repository.dart';
import '../features/accounts/domain/accounts_repository.dart';
import '../features/auth/data/firebase_auth_repository.dart';
import '../features/auth/data/local_biometrics.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/domain/biometrics.dart';
import '../features/auth/domain/logout.dart';
import '../features/experience/data/cascading_experience_repository.dart';
import '../features/experience/domain/experience.dart';
import '../features/notifications/data/push_adapters.dart';
import '../features/notifications/presentation/push_coordinator.dart';
import '../features/onboarding/data/api_profile_repository.dart';
import '../features/onboarding/domain/profile_repository.dart';
import '../features/transfers/data/api_transfers_repository.dart';
import '../features/transfers/domain/transfer.dart';
import 'env.dart';
import 'infra/crashlytics_error_reporter.dart';
import 'infra/firebase_analytics_tracker.dart';
import 'infra/firebase_current_user.dart';
import 'infra/firebase_token_providers.dart';
import 'infra/firestore_cleanup.dart';
import 'router.dart';
import 'sdui_actions.dart';
import 'session/session_cubit.dart';

final getIt = GetIt.instance;

/// Registra las dependencias de la app sobre Firebase ya inicializado.
void configureDependencies(AppEnv env) {
  final auth = FirebaseAuth.instance;
  // Accessor (no singleton): tras logout Firestore se termina y se recrea.
  getIt.registerFactory<FirebaseFirestore>(() => FirebaseFirestore.instance);
  registerAppDependencies(
    getIt,
    env: env,
    authTokens: FirebaseAuthTokenProvider(auth),
    appCheckTokens: FirebaseAppCheckTokenProvider(FirebaseAppCheck.instance),
    authRepository: FirebaseAuthRepository(auth),
    currentUser: FirebaseCurrentUser(auth),
    biometric: LocalAuthBiometricAuthenticator(LocalAuthentication()),
    biometricPrefs: SecureBiometricPreferences(
      SecureBiometricPreferences.createStorage(),
    ),
    errorReporter: CrashlyticsErrorReporter(FirebaseCrashlytics.instance),
    analytics: FirebaseAnalyticsTracker(FirebaseAnalytics.instance),
  );
  getIt.registerLazySingleton<PushCoordinator>(
    () => PushCoordinator(
      messaging: FirebasePushMessaging(FirebaseMessaging.instance),
      local: LocalNotificationsNotifier(FlutterLocalNotificationsPlugin()),
      devices: ApiDevicesRepository(getIt()),
      deviceIds: SecureDeviceIdStore(
        SecureBiometricPreferences.createStorage(),
      ),
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      appVersion: env.appVersion,
      errorReporter: getIt(),
    ),
  );
  getIt<SessionCleanupRegistry>()
    ..register(() => clearFirestoreCache(getIt<FirebaseFirestore>()))
    // El dispositivo deja de recibir push del usuario que cerró sesión.
    ..register(() => getIt<PushCoordinator>().onLogout());
}

/// Composición sin dependencias directas de Firebase; los tests la usan con
/// fakes.
void registerAppDependencies(
  GetIt di, {
  required AppEnv env,
  required AuthTokenProvider authTokens,
  required AppCheckTokenProvider appCheckTokens,
  required AuthRepository authRepository,
  required BiometricAuthenticator biometric,
  required BiometricPreferences biometricPrefs,
  required CurrentUserProvider currentUser,
  ProfileRepository? profileRepository,
  AccountsRepository? accountsRepository,
  ExperienceCache? experienceCache,
  // Overrides para el E2E (adaptadores en memoria, sin red).
  TransfersRepository? transfersRepository,
  ConnectivityMonitor? connectivity,
  Future<Result<Object?>> Function(String screen)? fetchExperience,
  ErrorReporter errorReporter = const PrintErrorReporter(),
  AnalyticsTracker analytics = const NoopAnalytics(),
}) {
  di
    ..registerSingleton<AppEnv>(env)
    ..registerSingleton<ErrorReporter>(errorReporter)
    ..registerSingleton<AnalyticsTracker>(analytics)
    ..registerSingleton<AuthTokenProvider>(authTokens)
    ..registerSingleton<AppCheckTokenProvider>(appCheckTokens)
    ..registerSingleton<SessionCleanupRegistry>(SessionCleanupRegistry())
    // Resiliencia: caos solo configurable desde el Network Lab (dev).
    ..registerSingleton<ChaosSettings>(ChaosSettings())
    ..registerLazySingleton<ChaosInterceptor>(
      () => ChaosInterceptor(settings: di()),
    )
    ..registerSingleton<CircuitBreaker>(CircuitBreaker())
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(
        baseUrl: env.apiBaseUrl,
        authTokens: di(),
        appCheckTokens: di(),
        chaos: di(),
        breaker: di(),
        errorReporter: di(),
      ),
    )
    // auth
    ..registerSingleton<AuthRepository>(authRepository)
    ..registerSingleton<BiometricAuthenticator>(biometric)
    ..registerSingleton<BiometricPreferences>(biometricPrefs)
    ..registerLazySingleton<LogoutUseCase>(
      () => LogoutUseCase(
        di(),
        di(),
        di(),
        onCleanupError: (e) => errorReporter.report(e, null, reason: 'logout'),
      ),
    )
    // onboarding
    ..registerLazySingleton<ProfileRepository>(
      () => profileRepository ?? ApiProfileRepository(di()),
    )
    // accounts
    ..registerSingleton<CurrentUserProvider>(currentUser)
    ..registerLazySingleton<AccountsRepository>(
      () =>
          accountsRepository ??
          FirestoreAccountsRepository(() => di<FirebaseFirestore>(), di()),
    )
    ..registerLazySingleton<AccountsSource>(() => di<AccountsRepository>())
    ..registerLazySingleton<ConnectivityMonitor>(
      () => connectivity ?? ConnectivityPlusMonitor(),
    )
    // transfers
    ..registerLazySingleton<TransfersRepository>(
      () => transfersRepository ?? ApiTransfersRepository(di()),
    )
    // experience (SDUI)
    ..registerLazySingleton<SduiParser>(
      () => SduiParser(
        supportedTypes: SduiRegistry.standardTypes,
        allowedRoutes: sduiAllowedRoutes,
        allowedMicroApps: sduiAllowedMicroApps,
      ),
    )
    ..registerLazySingleton<SduiRegistry>(SduiRegistry.standard)
    ..registerLazySingleton<ExperienceCache>(
      () => experienceCache ?? SharedPrefsExperienceCache(),
    )
    ..registerLazySingleton<ExperienceRepository>(
      () => CascadingExperienceRepository(
        fetchRemote:
            fetchExperience ??
            CascadingExperienceRepository.remoteFrom(di(), env.appVersion),
        cache: di(),
        loadBundled: (screen) =>
            rootBundle.loadString('assets/sdui/default_$screen.json'),
        parser: di(),
        appVersion: env.appVersion,
      ),
    )
    // sesión y navegación
    ..registerLazySingleton<SessionCubit>(
      () => SessionCubit(
        auth: di(),
        profiles: di(),
        biometric: di(),
        biometricPrefs: di(),
      ),
    )
    ..registerLazySingleton<SessionSignals>(() => di<SessionCubit>())
    ..registerLazySingleton<GoRouter>(
      () => buildRouter(env: env, session: di(), di: di),
    );
  // El último home guardado incluye el nombre del usuario.
  di<SessionCleanupRegistry>().register(() => di<ExperienceCache>().clear());
}
