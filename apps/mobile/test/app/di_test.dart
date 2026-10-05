import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/app/di.dart';
import 'package:nexo_mobile/app/env.dart';
import 'package:nexo_mobile/app/session/session_cubit.dart';
import 'package:nexo_mobile/features/onboarding/domain/profile_repository.dart';

import '../helpers/fakes.dart';

class _MockAuthTokens extends Mock implements AuthTokenProvider {}

class _MockAppCheckTokens extends Mock implements AppCheckTokenProvider {}

void main() {
  const env = AppEnv(
    flavor: AppFlavor.dev,
    apiBaseUrl: 'http://10.0.2.2:5001/p/us-east1/api',
    useEmulators: true,
  );
  late GetIt di;

  setUp(() {
    di = GetIt.asNewInstance();
    registerAppDependencies(
      di,
      env: env,
      authTokens: _MockAuthTokens(),
      appCheckTokens: _MockAppCheckTokens(),
      authRepository: FakeAuthRepository(),
      biometric: FakeBiometricAuthenticator(),
      biometricPrefs: FakeBiometricPreferences(),
    );
  });

  test('resuelve el grafo sin Firebase', () {
    expect(di<AppEnv>(), same(env));
    expect(di<GoRouter>(), isA<GoRouter>());
    expect(di<ApiClient>(), same(di<ApiClient>()));
    expect(di<ProfileRepository>(), isNotNull);
  });

  test('SessionSignals es la misma instancia que SessionCubit', () {
    expect(di<SessionSignals>(), same(di<SessionCubit>()));
  });

  test('el ApiClient apunta a API_BASE_URL con el caos inyectado', () {
    final dio = di<ApiClient>().dio;

    expect(dio.options.baseUrl, env.apiBaseUrl);
    expect(dio.interceptors, contains(di<ChaosInterceptor>()));
  });
}
