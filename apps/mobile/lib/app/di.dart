import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nexo_core/nexo_core.dart';

import '../features/auth/data/firebase_auth_repository.dart';
import '../features/auth/data/local_biometrics.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/domain/biometrics.dart';
import '../features/auth/domain/logout.dart';
import '../features/onboarding/data/api_profile_repository.dart';
import '../features/onboarding/domain/profile_repository.dart';
import 'env.dart';
import 'infra/firebase_token_providers.dart';
import 'infra/firestore_cleanup.dart';
import 'router.dart';
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
    biometric: LocalAuthBiometricAuthenticator(LocalAuthentication()),
    biometricPrefs: SecureBiometricPreferences(
      SecureBiometricPreferences.createStorage(),
    ),
    reportError: (e) => FirebaseCrashlytics.instance.recordError(e, null),
  );
  getIt<SessionCleanupRegistry>().register(
    () => clearFirestoreCache(getIt<FirebaseFirestore>()),
  );
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
  ProfileRepository? profileRepository,
  void Function(Object error) reportError = _debugReport,
}) {
  di
    ..registerSingleton<AppEnv>(env)
    ..registerSingleton<AuthTokenProvider>(authTokens)
    ..registerSingleton<AppCheckTokenProvider>(appCheckTokens)
    ..registerSingleton<SessionCleanupRegistry>(SessionCleanupRegistry())
    ..registerLazySingleton<ChaosInterceptor>(ChaosInterceptor.new)
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(
        baseUrl: env.apiBaseUrl,
        authTokens: di(),
        appCheckTokens: di(),
        chaos: di(),
      ),
    )
    // auth
    ..registerSingleton<AuthRepository>(authRepository)
    ..registerSingleton<BiometricAuthenticator>(biometric)
    ..registerSingleton<BiometricPreferences>(biometricPrefs)
    ..registerLazySingleton<LogoutUseCase>(
      () => LogoutUseCase(di(), di(), di(), onCleanupError: reportError),
    )
    // onboarding
    ..registerLazySingleton<ProfileRepository>(
      () => profileRepository ?? ApiProfileRepository(di()),
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
}

void _debugReport(Object error) => debugPrint('Error no fatal: $error');
