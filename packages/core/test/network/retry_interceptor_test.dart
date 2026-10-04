import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexo_core/nexo_core.dart';

import 'fake_adapter.dart';

class _MockRandom extends Mock implements Random {}

void main() {
  late List<Duration> sleeps;
  late _MockRandom random;

  setUp(() {
    sleeps = [];
    random = _MockRandom();
    when(() => random.nextDouble()).thenReturn(0.5);
  });

  (Dio, FakeAdapter) build(List<FakeReply> replies, {int maxRetries = 3}) {
    final adapter = FakeAdapter(replies);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        maxRetries: maxRetries,
        baseDelay: const Duration(milliseconds: 100),
        maxDelay: const Duration(seconds: 2),
        random: random,
        sleep: (d) async => sleeps.add(d),
      ),
    );
    return (dio, adapter);
  }

  test('GET reintenta errores de red hasta tener éxito', () async {
    final (dio, adapter) = build([
      TransportError(DioExceptionType.connectionError),
      TransportError(DioExceptionType.receiveTimeout),
      JsonReply(200, {'ok': true}),
    ]);

    final res = await dio.get<Object?>('/me');

    expect(res.statusCode, 200);
    expect(adapter.requests, hasLength(3));
  });

  test('backoff exponencial con jitter', () async {
    final (dio, _) = build([
      TransportError(DioExceptionType.connectionError),
      TransportError(DioExceptionType.connectionError),
      TransportError(DioExceptionType.connectionError),
      JsonReply(200, {}),
    ]);

    await dio.get<Object?>('/me');

    // Equal jitter: d/2 + random * d/2, con random = 0.5 -> 0.75 * d.
    expect(sleeps, const [
      Duration(milliseconds: 75),
      Duration(milliseconds: 150),
      Duration(milliseconds: 300),
    ]);
  });

  test('corta tras maxRetries y propaga el último error', () async {
    final (dio, adapter) = build([
      TransportError(DioExceptionType.connectionError),
    ]);

    await expectLater(
      dio.get<Object?>('/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.connectionError,
        ),
      ),
    );
    expect(adapter.requests, hasLength(4)); // 1 intento + 3 reintentos
  });

  test('POST sin marca idempotente NO se reintenta', () async {
    final (dio, adapter) = build([
      TransportError(DioExceptionType.connectionError),
      JsonReply(201, {}),
    ]);

    await expectLater(dio.post<Object?>('/transfers'), throwsA(anything));
    expect(adapter.requests, hasLength(1));
  });

  test('POST marcado como idempotente sí se reintenta', () async {
    final (dio, adapter) = build([
      TransportError(DioExceptionType.connectionError),
      JsonReply(201, {}),
    ]);

    final res = await dio.post<Object?>(
      '/transfers',
      options: Options(extra: {RetryInterceptor.idempotentKey: true}),
    );

    expect(res.statusCode, 201);
    expect(adapter.requests, hasLength(2));
  });

  test('errores de negocio (4xx) no se reintentan', () async {
    final (dio, adapter) = build([
      JsonReply(422, errorEnvelope('insufficient_funds')),
    ]);

    await expectLater(dio.get<Object?>('/x'), throwsA(isA<DioException>()));
    expect(adapter.requests, hasLength(1));
  });

  test('503 con Retry-After corto espera lo indicado y reintenta', () async {
    final (dio, adapter) = build([
      JsonReply(503, errorEnvelope('service_unavailable'), {
        'retry-after': '1',
      }),
      JsonReply(200, {}),
    ]);

    await dio.get<Object?>('/experience');

    expect(adapter.requests, hasLength(2));
    expect(sleeps, const [Duration(seconds: 1)]);
  });

  test('503 con Retry-After mayor al tope no se reintenta', () async {
    final (dio, adapter) = build([
      JsonReply(503, errorEnvelope('service_unavailable'), {
        'retry-after': '120',
      }),
    ]);

    await expectLater(dio.get<Object?>('/x'), throwsA(isA<DioException>()));
    expect(adapter.requests, hasLength(1));
    expect(sleeps, isEmpty);
  });

  test('conserva el X-Request-Id entre reintentos', () async {
    final adapter = FakeAdapter([
      TransportError(DioExceptionType.connectionError),
      JsonReply(200, {}),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.addAll([
      RequestIdInterceptor(),
      RetryInterceptor(dio: dio, random: random, sleep: (_) async {}),
    ]);

    await dio.get<Object?>('/me');

    final ids = adapter.requests
        .map((r) => r.headers[RequestIdInterceptor.header])
        .toList();
    expect(ids, hasLength(2));
    expect(ids.first, isNotNull);
    expect(ids.first, ids.last);
  });
}
