import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_design_system/nexo_design_system.dart';
import 'package:nexo_sdui_engine/nexo_sdui_engine.dart';

final _parser = SduiParser(
  supportedTypes: {...SduiRegistry.standardTypes, 'exploding'},
  allowedRoutes: {'/transfers/new'},
  allowedMicroApps: {'travel_insurance'},
);

SduiDocument doc(List<Map<String, Object?>> components) => _parser.parse({
  'schemaVersion': 1,
  'screen': 'home',
  'components': components,
}, appVersion: '1.0.0').document;

Future<({List<SduiAction> actions, List<String> errors})> pump(
  WidgetTester tester,
  SduiDocument document, {
  SduiRegistry? registry,
  Map<String, SduiSlotBuilder> slots = const {},
}) async {
  final actions = <SduiAction>[];
  final errors = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: NexoTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SduiView(
            document: document,
            registry: registry ?? SduiRegistry.standard(),
            context: SduiRenderContext(
              parser: _parser,
              onAction: actions.add,
              slots: slots,
              onComponentError: (component, _, _) => errors.add(component.id),
            ),
          ),
        ),
      ),
    ),
  );
  return (actions: actions, errors: errors);
}

final _allTypes = [
  {
    'id': 'greeting',
    'type': 'greeting_header',
    'props': {'title': 'Hola, Ana', 'subtitle': 'Tu dinero, simple'},
  },
  {
    'id': 'balance',
    'type': 'balance_summary',
    'props': {'source': 'accounts'},
  },
  {
    'id': 'actions',
    'type': 'quick_actions',
    'props': {
      'actions': [
        {
          'label': 'Transferir',
          'icon': 'swap_horiz',
          'action': {'type': 'navigate', 'route': '/transfers/new'},
        },
        {
          'label': 'Seguro de viaje',
          'icon': 'flight',
          'action': {'type': 'open_micro_app', 'appId': 'travel_insurance'},
        },
      ],
    },
  },
  {
    'id': 'insight',
    'type': 'insight_card',
    'props': {'title': 'Tus hábitos', 'text': 'Gastaste menos en comida.'},
  },
  {
    'id': 'promo',
    'type': 'promo_banner',
    'props': {
      'title': '¿Viaje en vacaciones?',
      'body': 'Cotiza tu seguro en 1 minuto.',
      'cta': 'Cotizar',
      'tone': 'brand',
      'action': {'type': 'open_micro_app', 'appId': 'travel_insurance'},
    },
  },
  {
    'id': 'tile',
    'type': 'micro_app_tile',
    'props': {
      'title': 'Seguro de viaje Premium',
      'body': 'Cobertura internacional.',
      'action': {'type': 'open_micro_app', 'appId': 'travel_insurance'},
    },
  },
  {
    'id': 'tips',
    'type': 'tip_list',
    'props': {
      'title': 'Sugerencias',
      'items': ['Ahorra el 10 %', 'Revisa suscripciones'],
    },
  },
  {
    'id': 'spending',
    'type': 'spending_bars',
    'props': {
      'title': 'Gastos por categoría',
      'bars': [
        {'label': 'Comida', 'amountCents': 12000, 'formatted': r'$120.00'},
        {'label': 'Transporte', 'amountCents': 4000, 'formatted': r'$40.00'},
      ],
    },
  },
];

void main() {
  testWidgets('dibuja cada tipo del contrato', (tester) async {
    await pump(
      tester,
      doc(_allTypes),
      slots: {'balance_summary': (_, _) => const Text('SALDO-SLOT')},
    );

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('SALDO-SLOT'), findsOneWidget);
    expect(find.text('Transferir'), findsOneWidget);
    expect(find.text('Gastaste menos en comida.'), findsOneWidget);
    expect(find.text('Cotizar'), findsOneWidget);
    expect(find.text('Seguro de viaje Premium'), findsOneWidget);
    expect(find.text('Revisa suscripciones'), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
  });

  testWidgets('las acciones permitidas llegan al dispatcher', (tester) async {
    final result = await pump(tester, doc(_allTypes));

    await tester.tap(find.text('Transferir'));
    await tester.tap(find.text('Cotizar'));

    expect(result.actions, [
      isA<NavigateAction>().having((a) => a.route, 'route', '/transfers/new'),
      isA<OpenMicroAppAction>(),
    ]);
  });

  testWidgets('acción fuera del allowlist: se dibuja sin onTap', (
    tester,
  ) async {
    final result = await pump(
      tester,
      doc([
        {
          'id': 'promo',
          'type': 'promo_banner',
          'props': {
            'title': 'Promo',
            'body': 'Texto',
            'cta': 'Ir',
            'action': {'type': 'navigate', 'route': '/admin'},
          },
        },
      ]),
    );

    expect(find.text('Promo'), findsOneWidget);
    expect(find.text('Ir'), findsNothing, reason: 'sin acción no hay CTA');
    expect(result.actions, isEmpty);
  });

  testWidgets('tipo desconocido se ignora (parser) sin romper la pantalla', (
    tester,
  ) async {
    await pump(
      tester,
      doc([
        {'id': 'x', 'type': 'hologram', 'props': {}},
        {
          'id': 'greeting',
          'type': 'greeting_header',
          'props': {'title': 'Hola'},
        },
      ]),
    );

    expect(find.text('Hola'), findsOneWidget);
  });

  testWidgets('un componente que lanza se omite y se reporta', (tester) async {
    final registry = SduiRegistry({
      ...SduiRegistry.standard().builders,
      'exploding': (_, _, _) => throw StateError('boom'),
    });
    final result = await pump(
      tester,
      doc([
        {'id': 'bad', 'type': 'exploding', 'props': {}},
        {
          'id': 'greeting',
          'type': 'greeting_header',
          'props': {'title': 'Sigo aquí'},
        },
      ]),
      registry: registry,
    );

    expect(find.text('Sigo aquí'), findsOneWidget);
    expect(result.errors, ['bad']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('props inválidas (falta título) se omiten y se reportan', (
    tester,
  ) async {
    final result = await pump(
      tester,
      doc([
        {
          'id': 'greeting',
          'type': 'greeting_header',
          'props': {'title': 3},
        },
      ]),
    );

    expect(result.errors, ['greeting']);
  });

  testWidgets('balance_summary sin slot no dibuja nada', (tester) async {
    final result = await pump(
      tester,
      doc([
        {'id': 'balance', 'type': 'balance_summary', 'props': {}},
      ]),
    );

    expect(result.errors, isEmpty);
  });

  testWidgets('accesibilidad: tap targets, etiquetas y contraste', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, doc(_allTypes));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
