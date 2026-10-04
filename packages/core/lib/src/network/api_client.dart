import 'package:dio/dio.dart';

import '../result.dart';
import 'error_mapper.dart';
import 'interceptors.dart';
import 'token_providers.dart';

/// Convierte el JSON decodificado de la respuesta en el modelo de la capa data.
/// Puede lanzar [FormatException] o [TypeError] si el contrato no se cumple.
typedef JsonDecoder<T> = T Function(Object? json);

/// Cliente HTTP del BFF. Nunca lanza por errores esperados: devuelve
/// [Result] con un [Failure] tipado.
final class ApiClient {
  ApiClient({
    required String baseUrl,
    required AuthTokenProvider authTokens,
    required AppCheckTokenProvider appCheckTokens,
    ChaosInterceptor? chaos,
    HttpClientAdapter? adapter,
    Future<void> Function(Duration)? sleep,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 5),
           receiveTimeout: const Duration(seconds: 10),
           contentType: Headers.jsonContentType,
           responseType: ResponseType.json,
         ),
       ) {
    if (adapter != null) dio.httpClientAdapter = adapter;
    // Orden: id de correlación -> credenciales -> caos -> reintentos.
    dio.interceptors.addAll([
      RequestIdInterceptor(),
      AuthInterceptor(dio: dio, tokens: authTokens),
      AppCheckInterceptor(appCheckTokens),
      chaos ?? ChaosInterceptor(),
      RetryInterceptor(dio: dio, sleep: sleep),
    ]);
  }

  final Dio dio;

  Future<Result<T>> get<T>(
    String path, {
    Map<String, Object?>? query,
    required JsonDecoder<T> decode,
  }) => _send(() => dio.get<Object?>(path, queryParameters: query), decode);

  /// [idempotent] habilita reintentos automáticos: úsalo solo si el BFF
  /// deduplica el request (ej. transferencias con `idempotencyKey`).
  Future<Result<T>> post<T>(
    String path, {
    Object? body,
    bool idempotent = false,
    required JsonDecoder<T> decode,
  }) => _send(
    () => dio.post<Object?>(
      path,
      data: body,
      options: Options(extra: {RetryInterceptor.idempotentKey: idempotent}),
    ),
    decode,
  );

  Future<Result<T>> put<T>(
    String path, {
    Object? body,
    required JsonDecoder<T> decode,
  }) => _send(
    () => dio.put<Object?>(
      path,
      data: body,
      // PUT es idempotente por definición.
      options: Options(extra: {RetryInterceptor.idempotentKey: true}),
    ),
    decode,
  );

  Future<Result<T>> _send<T>(
    Future<Response<Object?>> Function() request,
    JsonDecoder<T> decode,
  ) async {
    final Response<Object?> response;
    try {
      response = await request();
    } on DioException catch (e) {
      return Result.err(ErrorMapper.map(e));
    }
    try {
      return Result.ok(decode(response.data));
    } on FormatException catch (e) {
      return Result.err(_invalidResponse(response, e.message));
    } on TypeError catch (e) {
      return Result.err(_invalidResponse(response, e.toString()));
    }
  }

  static ServerFailure _invalidResponse(Response<Object?> r, String detail) =>
      ServerFailure(
        code: 'invalid_response',
        requestId:
            r.headers.value(RequestIdInterceptor.header) ??
            r.requestOptions.headers[RequestIdInterceptor.header] as String?,
        message: detail,
      );
}
