import 'dart:math';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'error_mapper.dart';
import 'token_providers.dart';

/// Correlation id por request lógico. Si ya existe (reintento) se conserva,
/// para que todos los intentos se crucen con la misma traza del backend.
final class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor({this._uuid = const Uuid()});

  static const header = 'X-Request-Id';

  final Uuid _uuid;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent(header, _uuid.v4);
    handler.next(options);
  }
}

/// Agrega el ID token. Ante un 401 pide un token nuevo y reintenta una sola
/// vez; si vuelve a fallar, el 401 sube como [UnauthorizedFailure].
final class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this._dio, required this._tokens});

  static const _retriedKey = 'nexo.authRetried';

  final Dio _dio;
  final AuthTokenProvider _tokens;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[_retriedKey] != true) {
      final token = await _tokens.getIdToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || options.extra[_retriedKey] == true) {
      return handler.next(err);
    }
    final String? fresh;
    try {
      fresh = await _tokens.getIdToken(forceRefresh: true);
    } on Object {
      return handler.next(err);
    }
    if (fresh == null) return handler.next(err);

    options
      ..extra[_retriedKey] = true
      ..headers['Authorization'] = 'Bearer $fresh';
    try {
      handler.resolve(await _dio.fetch<Object?>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Agrega el token de App Check. Si la atestación falla el request sale sin
/// el header: el BFF decide (rechaza si `APP_CHECK_ENFORCED`).
final class AppCheckInterceptor extends Interceptor {
  AppCheckInterceptor(this._tokens);

  static const header = 'X-Firebase-AppCheck';

  final AppCheckTokenProvider _tokens;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _tokens.getToken();
      if (token != null) options.headers[header] = token;
    } on Object {
      // Sin token: el servidor responderá 401 app_check_failed si lo exige.
    }
    handler.next(options);
  }
}

/// Punto de inyección de fallas para el Network Lab (F7). Por ahora no altera
/// el tráfico; va antes del [RetryInterceptor] para que los reintentos
/// también atraviesen el caos.
class ChaosInterceptor extends Interceptor {}

/// Reintentos con backoff exponencial + jitter. Solo para operaciones seguras
/// de repetir: GET/HEAD o requests marcados con [idempotentKey].
final class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this._dio,
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 400),
    this.maxDelay = const Duration(seconds: 4),
    Random? random,
    Future<void> Function(Duration)? sleep,
  }) : _random = random ?? Random(),
       _sleep = sleep ?? Future<void>.delayed;

  /// `options.extra[idempotentKey] = true` habilita reintentos en POST/PUT.
  static const idempotentKey = 'idempotent';
  static const _attemptKey = 'nexo.retryAttempt';

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;
  final Random _random;
  final Future<void> Function(Duration) _sleep;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;
    final delay = _delayFor(err, attempt);
    if (attempt >= maxRetries || !_isSafe(options) || delay == null) {
      return handler.next(err);
    }

    await _sleep(delay);
    options.extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<Object?>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _isSafe(RequestOptions o) {
    final method = o.method.toUpperCase();
    return method == 'GET' ||
        method == 'HEAD' ||
        o.extra[idempotentKey] == true;
  }

  /// Espera antes del siguiente intento, o `null` si el error no se reintenta.
  Duration? _delayFor(DioException err, int attempt) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return _backoff(attempt);
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        if (status == 502 || status == 504) return _backoff(attempt);
        if (status != 503) return null;
        final retryAfter = ErrorMapper.parseRetryAfter(
          err.response?.headers.value('retry-after'),
        );
        if (retryAfter == null) return _backoff(attempt);
        // Mantenimiento largo: no bloquear la UI, mostrar estado degradado.
        return retryAfter <= maxDelay ? retryAfter : null;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return null;
    }
  }

  /// Equal jitter: d/2 + random(0, d/2), con d = min(max, base * 2^attempt).
  Duration _backoff(int attempt) {
    final exp = baseDelay.inMicroseconds * pow(2, attempt);
    final capped = min(exp, maxDelay.inMicroseconds).toDouble();
    final half = capped / 2;
    return Duration(microseconds: (half + _random.nextDouble() * half).round());
  }
}
