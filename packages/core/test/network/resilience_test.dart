import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexo_core/nexo_core.dart';

import 'fake_adapter.dart';

class _MockAuth extends Mock implements AuthTokenProvider {}

class _MockAppCheck extends Mock implements AppCheckTokenProvider {}

void main() {
  group('CircuitBreaker', () {
    late DateTime now;
    late CircuitBreaker breaker;

    setUp(() {
      now = DateTime(2026, 10, 5, 12);
      breaker = CircuitBreaker(now: () => now);
    });

    test('se abre tras 3 fallos seguidos del mismo servicio', () {
      for (var i = 0; i < 3; i++) {
        expect(breaker.allows('transfers'), isTrue);
        breaker.recordFailure('transfers');
      }

      expect(breaker.allows('transfers'), isFalse);
      expect(breaker.allows('experience'), isTrue, reason: 'por servicio');
    });

    test('un éxito reinicia el conteo', () {
      breaker
        ..recordFailure('x')
        ..recordFailure('x')
        ..recordSuccess('x')
        ..recordFailure('x');

      expect(breaker.allows('x'), isTrue);
    });

    test('tras 30 s deja pasar una prueba (half-open)', () {
      for (var i = 0; i < 3; i++) {
        breaker.recordFailure('x');
      }
      now = now.add(const Duration(seconds: 31));

      expect(breaker.allows('x'), isTrue);
      expect(breaker.allows('x'), isFalse, reason: 'solo una prueba a la vez');

      breaker.recordSuccess('x');
      expect(breaker.allows('x'), isTrue);
      expect(breaker.stateOf('x'), CircuitState.closed);
    });

    test('si la prueba falla vuelve a abrirse', () {
      for (var i = 0; i < 3; i++) {
        breaker.recordFailure('x');
      }
      now = now.add(const Duration(seconds: 31));
      breaker
        ..allows('x')
        ..recordFailure('x');

      expect(breaker.stateOf('x'), CircuitState.open);
    });
  });

  group('ApiClient con caos y breaker', () {
    late _MockAuth auth;
    late _MockAppCheck appCheck;
    late ChaosSettings chaos;

    setUp(() {
      auth = _MockAuth();
      appCheck = _MockAppCheck();
      when(() => auth.getIdToken(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => 't');
      when(() => appCheck.getToken()).thenAnswer((_) async => 'a');
      chaos = ChaosSettings();
    });

    (ApiClient, FakeAdapter) build({CircuitBreaker? breaker}) {
      final adapter = FakeAdapter([
        JsonReply(200, {'ok': true}),
      ]);
      return (
        ApiClient(
          baseUrl: 'https://api.test',
          authTokens: auth,
          appCheckTokens: appCheck,
          chaos: ChaosInterceptor(settings: chaos, delay: (_) async {}),
          adapter: adapter,
          sleep: (_) async {},
          breaker: breaker,
        ),
        adapter,
      );
    }

    Failure? failureOf(Result<Object?> r) =>
        r.fold(ok: (_) => null, err: (f) => f);

    test('sin caos todo pasa', () async {
      final (client, _) = build();
      expect((await client.get('/me', decode: (j) => j)).isOk, isTrue);
    });

    test('modo sin conexión -> NetworkFailure sin tocar la red', () async {
      chaos.offline = true;
      final (client, adapter) = build();

      final r = await client.get('/me', decode: (j) => j);

      expect(failureOf(r), isA<NetworkFailure>());
      expect(adapter.requests, isEmpty);
    });

    test('forzar 503 -> ServiceUnavailable con Retry-After', () async {
      chaos.force503 = true;
      final (client, _) = build();

      final r = await client.get('/experience', decode: (j) => j);

      final failure = failureOf(r);
      expect(failure, isA<ServiceUnavailableFailure>());
      expect(
        (failure! as ServiceUnavailableFailure).retryAfter,
        const Duration(seconds: 60),
      );
    });

    test('latencia inyectada pasa por el delay configurado', () async {
      chaos.extraLatency = const Duration(seconds: 3);
      final delays = <Duration>[];
      final adapter = FakeAdapter([JsonReply(200, {})]);
      final client = ApiClient(
        baseUrl: 'https://api.test',
        authTokens: auth,
        appCheckTokens: appCheck,
        chaos: ChaosInterceptor(
          settings: chaos,
          delay: (d) async => delays.add(d),
        ),
        adapter: adapter,
      );

      await client.get('/me', decode: (j) => j);

      expect(delays, [const Duration(seconds: 3)]);
    });

    test('breaker abierto: falla rápido sin llamar al BFF', () async {
      chaos.offline = true;
      final breaker = CircuitBreaker();
      final (client, adapter) = build(breaker: breaker);
      for (var i = 0; i < 3; i++) {
        await client.get('/experience', decode: (j) => j);
      }
      chaos.offline = false;

      final r = await client.get('/experience', decode: (j) => j);

      expect(failureOf(r), isA<ServiceUnavailableFailure>());
      expect(adapter.requests, isEmpty);
      expect(breaker.stateOf('experience'), CircuitState.open);
    });

    test('errores de negocio (4xx) no abren el breaker', () async {
      final breaker = CircuitBreaker();
      final adapter = FakeAdapter([
        JsonReply(422, errorEnvelope('insufficient_funds')),
      ]);
      final client = ApiClient(
        baseUrl: 'https://api.test',
        authTokens: auth,
        appCheckTokens: appCheck,
        adapter: adapter,
        breaker: breaker,
      );
      for (var i = 0; i < 4; i++) {
        await client.post('/transfers', body: {}, decode: (j) => j);
      }

      expect(breaker.stateOf('transfers'), CircuitState.closed);
    });
  });
}
