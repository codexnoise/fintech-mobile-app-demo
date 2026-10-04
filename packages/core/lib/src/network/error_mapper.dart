import 'dart:convert';

import 'package:dio/dio.dart';

import '../result.dart';
import 'interceptors.dart';

/// Traduce errores de transporte y el sobre de error del BFF
/// (`{ "error": { code, message, requestId, details } }`) a [Failure].
/// Tabla de mapeo: docs/api.md § Errores.
abstract final class ErrorMapper {
  static Failure map(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutFailure();
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        return _fromResponse(e);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return UnknownFailure(e.message);
    }
  }

  static Failure _fromResponse(DioException e) {
    final response = e.response;
    final status = response?.statusCode ?? 0;
    final envelope = _envelope(response?.data);
    final code = envelope?['code'] as String?;
    final message = envelope?['message'] as String?;
    final requestId =
        envelope?['requestId'] as String? ??
        response?.headers.value(RequestIdInterceptor.header) ??
        e.requestOptions.headers[RequestIdInterceptor.header] as String?;

    return switch (status) {
      401 || 403 => UnauthorizedFailure(message),
      400 ||
      409 ||
      422 => ValidationFailure(code ?? 'invalid_request', message),
      429 || 503 => ServiceUnavailableFailure(
        service: _service(envelope?['details']),
        retryAfter: parseRetryAfter(response?.headers.value('retry-after')),
        message: message,
      ),
      _ => ServerFailure(
        code: code ?? 'http_$status',
        requestId: requestId,
        message: message,
      ),
    };
  }

  static Map<String, Object?>? _envelope(Object? data) {
    var body = data;
    if (body is String && body.isNotEmpty) {
      try {
        body = jsonDecode(body);
      } on FormatException {
        return null;
      }
    }
    if (body is Map && body['error'] is Map) {
      return (body['error'] as Map).cast<String, Object?>();
    }
    return null;
  }

  static String? _service(Object? details) =>
      details is Map ? details['service'] as String? : null;

  /// `Retry-After` en segundos (el BFF no usa la forma HTTP-date).
  static Duration? parseRetryAfter(String? value) {
    final seconds = int.tryParse(value?.trim() ?? '');
    if (seconds == null || seconds < 0) return null;
    return Duration(seconds: seconds);
  }
}
