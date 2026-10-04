import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_sdui_engine/nexo_sdui_engine.dart';

void main() {
  const parser = SduiParser(
    supportedTypes: {'greeting_header', 'promo_banner', 'quick_actions'},
    allowedRoutes: {'/transfers/new'},
    allowedMicroApps: {'travel_insurance'},
  );

  Map<String, Object?> doc(List<Object?> components, {Object? schema = 1}) => {
    'schemaVersion': schema,
    'screen': 'home',
    'segment': 'premium',
    'ttlSeconds': 120,
    'components': components,
  };

  group('SduiParser.parse', () {
    test('parsea un documento válido', () {
      final result = parser.parse(
        doc([
          {
            'id': 'g',
            'type': 'greeting_header',
            'props': {'title': 'Hola'},
          },
        ]),
        appVersion: '1.0.0',
      );
      expect(result.document.components, hasLength(1));
      expect(result.document.segment, 'premium');
      expect(result.document.ttl, const Duration(seconds: 120));
      expect(result.warnings, isEmpty);
    });

    test('ignora tipos desconocidos sin romper la pantalla', () {
      final result = parser.parse(
        doc([
          {'id': 'x', 'type': 'crypto_wallet'},
          {'id': 'g', 'type': 'greeting_header'},
        ]),
        appVersion: '1.0.0',
      );
      expect(result.document.components.single.id, 'g');
      expect(result.warnings.single, contains('unknown type'));
    });

    test('omite componentes que requieren una versión superior', () {
      final result = parser.parse(
        doc([
          {'id': 'p', 'type': 'promo_banner', 'minAppVersion': '2.0.0'},
        ]),
        appVersion: '1.4.9+12',
      );
      expect(result.document.components, isEmpty);
      expect(result.warnings.single, contains('requires app 2.0.0'));
    });

    test('descarta ids duplicados y props inválidas', () {
      final result = parser.parse(
        doc([
          {'id': 'a', 'type': 'promo_banner'},
          {'id': 'a', 'type': 'promo_banner'},
          {'id': 'b', 'type': 'promo_banner', 'props': 'nope'},
        ]),
        appVersion: '1.0.0',
      );
      expect(result.document.components, hasLength(1));
      expect(result.warnings, hasLength(2));
    });

    test('lanza SduiFormatException si el contrato mínimo no se cumple', () {
      expect(
        () => parser.parse('not a map', appVersion: '1.0.0'),
        throwsA(isA<SduiFormatException>()),
      );
      expect(
        () => parser.parse(doc([], schema: 99), appVersion: '1.0.0'),
        throwsA(isA<SduiFormatException>()),
      );
      expect(
        () => parser.parse({'schemaVersion': 1}, appVersion: '1.0.0'),
        throwsA(isA<SduiFormatException>()),
      );
    });

    test('usa ttl por defecto si viene inválido', () {
      final result = parser.parse({
        'schemaVersion': 1,
        'screen': 'home',
        'components': <Object?>[],
        'ttlSeconds': -5,
      }, appVersion: '1.0.0');
      expect(result.document.ttl, const Duration(seconds: 300));
      expect(result.document.segment, 'default');
    });
  });

  group('SduiParser.parseAction (allowlist)', () {
    test('acepta rutas y micro-apps registradas', () {
      expect(
        parser.parseAction({'type': 'navigate', 'route': '/transfers/new'}),
        isA<NavigateAction>(),
      );
      expect(
        parser.parseAction({
          'type': 'open_micro_app',
          'appId': 'travel_insurance',
        }),
        isA<OpenMicroAppAction>(),
      );
    });

    test('rechaza rutas, apps y tipos no permitidos', () {
      expect(
        parser.parseAction({'type': 'navigate', 'route': '/admin'}),
        isNull,
      );
      expect(
        parser.parseAction({'type': 'open_micro_app', 'appId': 'evil'}),
        isNull,
      );
      expect(
        parser.parseAction({'type': 'open_url', 'url': 'https://evil.com'}),
        isNull,
      );
      expect(parser.parseAction(null), isNull);
    });
  });

  group('compareSemver', () {
    test('compara correctamente', () {
      expect(compareSemver('1.0.0', '1.0.0'), 0);
      expect(compareSemver('1.2.0', '1.10.0'), lessThan(0));
      expect(compareSemver('2.0', '1.9.9'), greaterThan(0));
      expect(compareSemver('1.0.0+5', '1.0.0'), 0);
    });
  });
}
