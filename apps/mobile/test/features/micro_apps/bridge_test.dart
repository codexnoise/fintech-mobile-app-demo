import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_mobile/features/micro_apps/domain/micro_app.dart';

String msg(Map<String, Object?> m) => jsonEncode(m);

void main() {
  group('parseBridgeMessage', () {
    test('ready llega sin nonce (aún no lo tiene)', () {
      expect(
        parseBridgeMessage(msg({'v': 1, 'type': 'ready', 'nonce': null})),
        isA<BridgeReady>(),
      );
    });

    test('quote_accepted válido con el nonce correcto', () {
      final m = parseBridgeMessage(
        msg({
          'v': 1,
          'type': 'quote_accepted',
          'nonce': 'n-1',
          'payload': {
            'plan': 'plus',
            'destination': 'europe',
            'priceCents': 4212,
          },
        }),
        expectedNonce: 'n-1',
      );

      expect(m, isA<BridgeQuoteAccepted>());
      m as BridgeQuoteAccepted;
      expect(m.plan, 'plus');
      expect(m.priceCents, 4212);
    });

    test('nonce incorrecto o ausente se descarta', () {
      expect(
        parseBridgeMessage(
          msg({'v': 1, 'type': 'close', 'nonce': 'otro'}),
          expectedNonce: 'n-1',
        ),
        isNull,
      );
      expect(
        parseBridgeMessage(
          msg({'v': 1, 'type': 'close'}),
          expectedNonce: 'n-1',
        ),
        isNull,
      );
    });

    test('tipo desconocido o versión distinta se descarta', () {
      expect(
        parseBridgeMessage(
          msg({'v': 1, 'type': 'transfer', 'nonce': 'n-1'}),
          expectedNonce: 'n-1',
        ),
        isNull,
      );
      expect(
        parseBridgeMessage(
          msg({'v': 2, 'type': 'close', 'nonce': 'n-1'}),
          expectedNonce: 'n-1',
        ),
        isNull,
      );
    });

    test('JSON inválido, no-objeto o demasiado grande se descarta', () {
      expect(parseBridgeMessage('{no json'), isNull);
      expect(parseBridgeMessage('[1,2]'), isNull);
      expect(
        parseBridgeMessage(msg({'v': 1, 'type': 'ready', 'pad': 'x' * 9000})),
        isNull,
      );
    });

    test('quote_accepted con payload no-objeto se descarta', () {
      expect(
        parseBridgeMessage(
          msg({'v': 1, 'type': 'quote_accepted', 'nonce': 'n', 'payload': 'x'}),
          expectedNonce: 'n',
        ),
        isNull,
      );
    });
  });

  group('política de navegación', () {
    final app = microApps['travel_insurance']!;

    test('solo https al host permitido', () {
      expect(isNavigationAllowed(app, app.url), isTrue);
      expect(
        isNavigationAllowed(
          app,
          Uri.parse('https://nexo-fintech-demo.web.app/x'),
        ),
        isTrue,
      );
      expect(
        isNavigationAllowed(
          app,
          Uri.parse('http://nexo-fintech-demo.web.app/'),
        ),
        isFalse,
      );
      expect(isNavigationAllowed(app, Uri.parse('https://evil.com/')), isFalse);
      expect(isNavigationAllowed(app, Uri.parse('intent://x')), isFalse);
      expect(isNavigationAllowed(app, Uri.parse('file:///etc/hosts')), isFalse);
    });
  });

  test('el contexto se inyecta como JSON (sin concatenar strings)', () {
    final script = contextScript(
      nonce: 'n',
      token: "a');alert(1);//",
      apiBase: 'https://api',
    );

    expect(script, startsWith('window.nexo.receive('));
    final json = script.substring(
      'window.nexo.receive('.length,
      script.length - 2,
    );
    expect(jsonDecode(json), {
      'v': 1,
      'type': 'context',
      'nonce': 'n',
      'token': "a');alert(1);//",
      'apiBase': 'https://api',
    });
  });

  test('nonces aleatorios y distintos', () {
    expect(newNonce(), isNot(newNonce()));
    expect(newNonce().length, greaterThanOrEqualTo(20));
  });
}
