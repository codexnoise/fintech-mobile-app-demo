import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/app/app.dart';
import 'package:nexo_mobile/app/env.dart';
import 'package:nexo_mobile/app/router.dart';
import 'package:nexo_mobile/app/session/session_cubit.dart';
import 'package:nexo_mobile/app/session/session_status.dart';
import 'package:nexo_mobile/features/accounts/domain/accounts_repository.dart';
import 'package:nexo_mobile/features/accounts/presentation/account_detail_page.dart';
import 'package:nexo_mobile/features/auth/domain/auth_repository.dart';

import '../helpers/fakes.dart';

class MockSession extends MockCubit<SessionStatus> implements SessionCubit {}

const _dev = AppEnv(
  flavor: AppFlavor.dev,
  apiBaseUrl: 'http://localhost',
  useEmulators: false,
);
const _prod = AppEnv(
  flavor: AppFlavor.prod,
  apiBaseUrl: 'https://api',
  useEmulators: false,
);

Future<MockSession> pumpAt(
  WidgetTester tester,
  AppEnv env,
  String location, {
  SessionStatus status = const SessionReady(testProfile),
}) async {
  final session = MockSession();
  when(() => session.state).thenReturn(status);
  whenListen(
    session,
    const Stream<SessionStatus>.empty(),
    initialState: status,
  );
  await tester.pumpWidget(
    NexoApp(
      router: buildRouter(
        env: env,
        session: session,
        di: GetIt.asNewInstance()
          ..registerSingleton<AuthRepository>(FakeAuthRepository())
          ..registerSingleton<AccountsRepository>(FakeAccountsRepository())
          ..registerSingleton<AccountsSource>(FakeAccountsRepository()),
        initialLocation: location,
      ),
      session: session,
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

void main() {
  testWidgets('resuelve rutas con parámetros', (tester) async {
    await pumpAt(tester, _dev, NexoRoutes.account('savings'));

    expect(find.byType(AccountDetailPage), findsOneWidget);
  });

  testWidgets('Network Lab existe en dev', (tester) async {
    await pumpAt(tester, _dev, NexoRoutes.networkLab);

    expect(find.text('Network Lab'), findsWidgets);
  });

  testWidgets('Network Lab no existe en prod', (tester) async {
    await pumpAt(tester, _prod, NexoRoutes.networkLab);

    expect(find.text('Página no encontrada'), findsWidgets);
  });

  testWidgets('aplica el guard de sesión', (tester) async {
    await pumpAt(
      tester,
      _dev,
      NexoRoutes.home,
      status: const SessionUnauthenticated(),
    );

    expect(find.text('Bienvenido a Nexo'), findsOneWidget);
  });

  testWidgets('splash muestra el error del perfil con reintento', (
    tester,
  ) async {
    final session = await pumpAt(
      tester,
      _dev,
      NexoRoutes.home,
      status: const SessionProfileUnavailable(NetworkFailure()),
    );
    when(session.retry).thenAnswer((_) async {});

    await tester.tap(find.text('Reintentar'));

    verify(session.retry).called(1);
  });

  testWidgets('usa locale es_EC', (tester) async {
    await pumpAt(tester, _dev, NexoRoutes.accounts);

    final context = tester.element(find.byType(Scaffold));
    expect(Localizations.localeOf(context), NexoApp.locale);
  });
}
