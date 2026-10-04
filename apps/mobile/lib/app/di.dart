import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:nexo_core/nexo_core.dart';

import 'env.dart';
import 'infra/firebase_token_providers.dart';
import 'router.dart';

final getIt = GetIt.instance;

/// Registra las dependencias de la app sobre Firebase ya inicializado.
void configureDependencies(AppEnv env) {
  getIt
    ..registerSingleton<FirebaseAuth>(FirebaseAuth.instance)
    ..registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);
  registerAppDependencies(
    getIt,
    env: env,
    authTokens: FirebaseAuthTokenProvider(getIt()),
    appCheckTokens: FirebaseAppCheckTokenProvider(FirebaseAppCheck.instance),
  );
}

/// Parte de la composición que no toca Firebase; los tests la usan con fakes.
void registerAppDependencies(
  GetIt di, {
  required AppEnv env,
  required AuthTokenProvider authTokens,
  required AppCheckTokenProvider appCheckTokens,
}) {
  di
    ..registerSingleton<AppEnv>(env)
    ..registerSingleton<AuthTokenProvider>(authTokens)
    ..registerSingleton<AppCheckTokenProvider>(appCheckTokens)
    ..registerLazySingleton<ChaosInterceptor>(ChaosInterceptor.new)
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(
        baseUrl: env.apiBaseUrl,
        authTokens: di(),
        appCheckTokens: di(),
        chaos: di(),
      ),
    )
    ..registerLazySingleton<GoRouter>(() => buildRouter(env: env));
}
