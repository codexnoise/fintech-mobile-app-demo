import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_mobile/app/app.dart';
import 'package:nexo_mobile/app/env.dart';
import 'package:nexo_mobile/app/router.dart';

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

Future<void> pumpAt(WidgetTester tester, AppEnv env, String location) async {
  await tester.pumpWidget(
    NexoApp(
      router: buildRouter(env: env, initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('arranca en splash con el índice de rutas en dev', (
    tester,
  ) async {
    await pumpAt(tester, _dev, AppRoutes.splash);

    expect(find.text('Nexo'), findsOneWidget);
    expect(find.text(AppRoutes.home), findsOneWidget);
  });

  testWidgets('el splash de prod no expone el índice de rutas', (tester) async {
    await pumpAt(tester, _prod, AppRoutes.splash);

    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('resuelve rutas con parámetros', (tester) async {
    await pumpAt(tester, _dev, AppRoutes.account('savings'));

    expect(find.text('Detalle de cuenta'), findsWidgets);
    expect(find.text('/accounts/savings'), findsOneWidget);
  });

  testWidgets('Network Lab existe en dev', (tester) async {
    await pumpAt(tester, _dev, AppRoutes.networkLab);

    expect(find.text('Network Lab'), findsWidgets);
  });

  testWidgets('Network Lab no existe en prod', (tester) async {
    await pumpAt(tester, _prod, AppRoutes.networkLab);

    expect(find.text('Página no encontrada'), findsWidgets);
  });

  testWidgets('navega desde el índice de dev', (tester) async {
    await pumpAt(tester, _dev, AppRoutes.splash);

    await tester.tap(find.text('Nueva transferencia'));
    await tester.pumpAndSettle();

    expect(find.text(AppRoutes.transferNew), findsOneWidget);
  });

  testWidgets('usa locale es_EC', (tester) async {
    await pumpAt(tester, _dev, AppRoutes.home);

    final context = tester.element(find.byType(Scaffold));
    expect(Localizations.localeOf(context), NexoApp.locale);
  });
}
