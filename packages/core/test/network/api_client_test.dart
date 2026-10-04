import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexo_core/nexo_core.dart';

import 'fake_adapter.dart';

class _MockAuth extends Mock implements AuthTokenProvider {}

class _MockAppCheck extends Mock implements AppCheckTokenProvider {}

void main() {
  late _MockAuth auth;
  late _MockAppCheck appCheck;

  setUp(() {
    auth = _MockAuth();
    appCheck = _MockAppCheck();
    when(() => auth.getIdToken(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => 'token-1');
    when(() => appCheck.getToken()).thenAnswer((_) async => 'ac-1');
  });

  (ApiClient, FakeAdapter) build(List<FakeReply> replies) {
    final adapter = FakeAdapter(replies);
    final client = ApiClient(
      baseUrl: 'https://api.test',
      authTokens: auth,
      appCheckTokens: appCheck,
      adapter: adapter,
      sleep: (_) async {},
    );
    return (client, adapter);
  }

  test('agrega Authorization, App Check y X-Request-Id', () async {
    final (client, adapter) = build([
      JsonReply(200, {'id': 'u1'}),
    ]);

    final res = await client.get('/me', decode: (j) => (j! as Map)['id']);

    expect(res.valueOrNull, 'u1');
    final headers = adapter.requests.single.headers;
    expect(headers['Authorization'], 'Bearer token-1');
    expect(headers['X-Firebase-AppCheck'], 'ac-1');
    expect(headers['X-Request-Id'], isA<String>());
  });

  test('en 401 refresca el token una sola vez y reintenta', () async {
    when(() => auth.getIdToken(forceRefresh: true))
        .thenAnswer((_) async => 'token-2');
    final (client, adapter) = build([
      JsonReply(401, errorEnvelope('unauthenticated')),
      JsonReply(200, {'ok': true}),
    ]);

    final res = await client.get('/me', decode: (j) => j);

    expect(res.isOk, isTrue);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.last.headers['Authorization'], 'Bearer token-2');
    verify(() => auth.getIdToken(forceRefresh: true)).called(1);
  });

  test('401 persistente -> UnauthorizedFailure sin loop', () async {
    final (client, adapter) = build([
      JsonReply(401, errorEnvelope('unauthenticated')),
    ]);

    final res = await client.get('/me', decode: (j) => j);

    expect(
      res.fold(ok: (_) => null, err: (f) => f),
      isA<UnauthorizedFailure>(),
    );
    expect(adapter.requests, hasLength(2));
  });

  test('sin sesión no envía Authorization', () async {
    when(() => auth.getIdToken(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => null);
    final (client, adapter) = build([JsonReply(200, {})]);

    await client.get('/health', decode: (j) => j);

    expect(adapter.requests.single.headers['Authorization'], isNull);
  });

  test('si App Check falla el request sale igual (el BFF decide)', () async {
    when(() => appCheck.getToken()).thenThrow(Exception('attestation'));
    final (client, adapter) = build([JsonReply(200, {})]);

    final res = await client.get('/me', decode: (j) => j);

    expect(res.isOk, isTrue);
    expect(adapter.requests.single.headers['X-Firebase-AppCheck'], isNull);
  });

  test('error del BFF -> Result.err con Failure tipado', () async {
    final (client, _) = build([
      JsonReply(422, errorEnvelope('insufficient_funds')),
    ]);

    final res = await client.post(
      '/transfers',
      body: {'amountCents': 100},
      decode: (j) => j,
    );

    final failure = res.fold(ok: (_) => null, err: (f) => f);
    expect((failure! as ValidationFailure).code, 'insufficient_funds');
  });

  test('post idempotente se reintenta ante caída de red', () async {
    final (client, adapter) = build([
      TransportError(DioExceptionType.connectionError),
      JsonReply(201, {'id': 't1'}),
    ]);

    final res = await client.post(
      '/transfers',
      body: {'idempotencyKey': 'k'},
      idempotent: true,
      decode: (j) => (j! as Map)['id'],
    );

    expect(res.valueOrNull, 't1');
    expect(adapter.requests, hasLength(2));
  });

  test(
    'respuesta con forma inesperada -> ServerFailure invalid_response',
    () async {
      final (client, _) = build([
        JsonReply(200, ['no', 'es', 'mapa']),
      ]);

      final res = await client.get('/me', decode: (j) => (j! as Map)['id']);

      final failure = res.fold(ok: (_) => null, err: (f) => f);
      expect((failure! as ServerFailure).code, 'invalid_response');
    },
  );
}
