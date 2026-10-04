import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_core/nexo_core.dart';

import 'fake_adapter.dart';

/// Ejecuta un request contra [reply] y devuelve el Failure mapeado.
Future<Failure> mapReply(FakeReply reply) async {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeAdapter([reply]);
  try {
    await dio.get<Object?>('/x');
  } on DioException catch (e) {
    return ErrorMapper.map(e);
  }
  fail('se esperaba un DioException');
}

void main() {
  group('ErrorMapper (tabla de docs/api.md)', () {
    test('400 invalid_request -> ValidationFailure con código', () async {
      final f = await mapReply(
        JsonReply(400, errorEnvelope('invalid_request', message: 'Datos')),
      );
      expect(f, isA<ValidationFailure>());
      expect((f as ValidationFailure).code, 'invalid_request');
      expect(f.message, 'Datos');
    });

    for (final code in ['unauthenticated', 'app_check_failed']) {
      test('401 $code -> UnauthorizedFailure', () async {
        final f = await mapReply(JsonReply(401, errorEnvelope(code)));
        expect(f, isA<UnauthorizedFailure>());
      });
    }

    test('404 *_not_found -> ServerFailure con código y requestId', () async {
      final f = await mapReply(
        JsonReply(404, errorEnvelope('account_not_found', requestId: 'r-1')),
      );
      expect(f, isA<ServerFailure>());
      f as ServerFailure;
      expect(f.code, 'account_not_found');
      expect(f.requestId, 'r-1');
    });

    test('409 onboarding_required -> ValidationFailure(code)', () async {
      final f = await mapReply(
        JsonReply(409, errorEnvelope('onboarding_required')),
      );
      expect((f as ValidationFailure).code, 'onboarding_required');
    });

    test('422 insufficient_funds -> ValidationFailure(code)', () async {
      final f = await mapReply(
        JsonReply(
          422,
          errorEnvelope('insufficient_funds', message: 'Saldo insuficiente'),
        ),
      );
      expect((f as ValidationFailure).code, 'insufficient_funds');
      expect(f.message, 'Saldo insuficiente');
    });

    test(
      '503 -> ServiceUnavailableFailure con Retry-After y servicio',
      () async {
        final f = await mapReply(
          JsonReply(
            503,
            errorEnvelope(
              'service_unavailable',
              details: {'service': 'transfers'},
            ),
            {'retry-after': '120'},
          ),
        );
        expect(f, isA<ServiceUnavailableFailure>());
        f as ServiceUnavailableFailure;
        expect(f.retryAfter, const Duration(seconds: 120));
        expect(f.service, 'transfers');
        expect(f.isRetryable, isTrue);
      },
    );

    test('500 -> ServerFailure con requestId del header', () async {
      final f = await mapReply(
        JsonReply(500, errorEnvelope('internal_error'), {
          'x-request-id': 'hdr-9',
        }),
      );
      f as ServerFailure;
      expect(f.code, 'internal_error');
      expect(f.requestId, 'hdr-9');
    });

    test('cuerpo no JSON en 5xx -> ServerFailure sin romper', () async {
      final f = await mapReply(JsonReply(502));
      expect(f, isA<ServerFailure>());
    });

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      test('$type -> TimeoutFailure', () async {
        expect(await mapReply(TransportError(type)), isA<TimeoutFailure>());
      });
    }

    test('sin red -> NetworkFailure', () async {
      expect(
        await mapReply(TransportError(DioExceptionType.connectionError)),
        isA<NetworkFailure>(),
      );
    });
  });

  test('parseRetryAfter acepta segundos y descarta basura', () {
    expect(ErrorMapper.parseRetryAfter('30'), const Duration(seconds: 30));
    expect(ErrorMapper.parseRetryAfter(' 5 '), const Duration(seconds: 5));
    expect(ErrorMapper.parseRetryAfter('abc'), isNull);
    expect(ErrorMapper.parseRetryAfter('-1'), isNull);
    expect(ErrorMapper.parseRetryAfter(null), isNull);
  });
}
