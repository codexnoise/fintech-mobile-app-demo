import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Respuesta programada para [FakeAdapter]: una respuesta HTTP o un error de
/// transporte.
sealed class FakeReply {}

final class JsonReply extends FakeReply {
  JsonReply(this.status, [this.body, this.headers = const {}]);

  final int status;
  final Object? body;
  final Map<String, String> headers;
}

final class TransportError extends FakeReply {
  TransportError(this.type);

  final DioExceptionType type;
}

/// Adapter HTTP en memoria: devuelve [replies] en orden y registra cada
/// request recibido.
final class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(List<FakeReply> replies) : _replies = List.of(replies);

  final List<FakeReply> _replies;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_replies.isEmpty) {
      throw StateError('FakeAdapter sin respuestas para ${options.uri}');
    }
    final reply = _replies.length == 1 ? _replies.first : _replies.removeAt(0);
    switch (reply) {
      case TransportError(:final type):
        throw DioException(requestOptions: options, type: type);
      case JsonReply(:final status, :final body, :final headers):
        return ResponseBody.fromString(
          body == null ? '' : jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            for (final e in headers.entries) e.key: [e.value],
          },
        );
    }
  }

  @override
  void close({bool force = false}) {}
}

/// Sobre de error del BFF (docs/api.md).
Map<String, Object?> errorEnvelope(
  String code, {
  String message = 'mensaje',
  String? requestId,
  Object? details,
}) => {
  'error': {
    'code': code,
    'message': message,
    'requestId': ?requestId,
    'details': ?details,
  },
};
