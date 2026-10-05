// E2E del flujo crítico: login -> home SDUI -> transferencia.
//
// Corre sobre el grafo real de la app (router, guards de sesión, cubits, SDUI,
// design system) con adaptadores de datos en memoria: determinista y sin red.
// El mismo recorrido contra el backend desplegado se verificó manualmente
// (ver docs/testing.md).
//
//   cd apps/mobile && fvm flutter test integration_test -d <emulador>
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/app/app.dart';
import 'package:nexo_mobile/app/di.dart';
import 'package:nexo_mobile/app/env.dart';
import 'package:nexo_mobile/app/session/session_cubit.dart';
import 'package:nexo_mobile/features/experience/domain/experience.dart';

import '../test/helpers/fakes.dart';
import 'support/in_memory_bank.dart';

final class _NoTokens implements AuthTokenProvider, AppCheckTokenProvider {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => null;

  @override
  Future<String?> getToken() async => null;
}

final class _AlwaysOnline implements ConnectivityMonitor {
  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onlineChanges => const Stream.empty();
}

final class _MemoryCache implements ExperienceCache {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> clear() async => _values.clear();
}

Future<InMemoryBank> pumpNexo(WidgetTester tester) async {
  final bank = InMemoryBank(balances: {'checking': 453585, 'savings': 1515000});
  final di = GetIt.asNewInstance();
  registerAppDependencies(
    di,
    env: const AppEnv(
      flavor: AppFlavor.prod,
      apiBaseUrl: 'http://127.0.0.1:9',
      useEmulators: false,
    ),
    authTokens: _NoTokens(),
    appCheckTokens: _NoTokens(),
    authRepository: FakeAuthRepository(),
    biometric: FakeBiometricAuthenticator(),
    biometricPrefs: FakeBiometricPreferences(),
    currentUser: FakeCurrentUser(),
    profileRepository: FakeProfileRepository(),
    accountsRepository: bank,
    transfersRepository: bank,
    connectivity: _AlwaysOnline(),
    experienceCache: _MemoryCache(),
    // El "servidor" sirve el home embebido: mismo contrato que GET /experience.
    fetchExperience: (screen) async => Result.ok(
      jsonDecode(
        await rootBundle.loadString('assets/sdui/default_$screen.json'),
      ),
    ),
  );
  final session = di<SessionCubit>()..start();
  await tester.pumpWidget(NexoApp(router: di(), session: session));
  await tester.pumpAndSettle();
  return bank;
}

Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('login -> home SDUI -> transferencia de \$50', (tester) async {
    final semantics = tester.ensureSemantics();
    final bank = await pumpNexo(tester);

    // 1. Login (sin sesión el guard lleva a /login).
    expect(find.text('Bienvenido a Nexo'), findsOneWidget);
    await expectAccessible(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'ana@nexo.ec',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'Clave1234',
    );
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    // 2. Oferta de biometría (una sola vez): "Ahora no".
    expect(find.text('Ingresa más rápido'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();

    // 3. Home compuesta por SDUI con saldos reales del slot.
    expect(find.text('Hola 👋'), findsOneWidget);
    expect(find.text(r'$19,685.85'), findsOneWidget);
    await expectAccessible(tester);

    // 4. Transferencia desde la acción rápida del servidor.
    await tester.tap(find.text('Transferir'));
    await tester.pumpAndSettle();
    expect(find.text('Entre cuentas propias'), findsOneWidget);
    await expectAccessible(tester);

    await tester.tap(find.text(r'+$50'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar transferencia'));
    await tester.pumpAndSettle();
    expect(find.text('Confirma tu transferencia'), findsOneWidget);
    await tester.tap(find.text('Confirmar y transferir'));
    await tester.pumpAndSettle();

    // 5. Comprobante y saldos actualizados.
    expect(find.text('Transferencia exitosa'), findsOneWidget);
    expect(bank.balanceOf('checking'), const Money(448585));
    expect(bank.balanceOf('savings'), const Money(1520000));

    await tester.tap(find.text('Volver al inicio'));
    await tester.pumpAndSettle();
    expect(find.text(r'$4,485.85'), findsOneWidget);
    expect(find.text(r'$15,200.00'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('saldo insuficiente se explica sin llamar al backend', (
    tester,
  ) async {
    await pumpNexo(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'ana@nexo.ec',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'Clave1234',
    );
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transferir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Todo'));
    await tester.tap(find.text(r'+$50'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar transferencia'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Saldo insuficiente'), findsOneWidget);
    expect(find.text('Confirma tu transferencia'), findsNothing);
  });
}
