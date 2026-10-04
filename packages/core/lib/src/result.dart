/// Errores de dominio tipados. La capa de presentación decide el mensaje
/// humano; aquí solo describimos qué pasó.
sealed class Failure {
  const Failure([this.message]);

  final String? message;

  /// Si es razonable reintentar automáticamente la operación.
  bool get isRetryable => false;
}

/// Sin conexión o host inalcanzable.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message]);

  @override
  bool get isRetryable => true;
}

/// La operación excedió el tiempo máximo (alta latencia).
final class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message]);

  @override
  bool get isRetryable => true;
}

/// Sesión inválida o expirada.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message]);
}

/// Datos de entrada rechazados por reglas de negocio (ej. saldo insuficiente).
final class ValidationFailure extends Failure {
  const ValidationFailure(this.code, [super.message]);

  final String code;
}

/// Servicio degradado o en mantenimiento (HTTP 503, circuit breaker abierto
/// o kill switch de operaciones).
final class ServiceUnavailableFailure extends Failure {
  const ServiceUnavailableFailure({this.service, this.retryAfter, String? message})
    : super(message);

  final String? service;
  final Duration? retryAfter;

  @override
  bool get isRetryable => true;
}

/// Error inesperado del servidor.
final class ServerFailure extends Failure {
  const ServerFailure({this.code, this.requestId, String? message}) : super(message);

  final String? code;

  /// Correlation id para cruzar con logs de backend.
  final String? requestId;
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message]);
}

/// Resultado de una operación que puede fallar, sin excepciones en el flujo
/// normal de negocio.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  R fold<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) => switch (this) {
    Ok<T>(:final value) => ok(value),
    Err<T>(:final failure) => err(failure),
  };

  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Result.ok(transform(value)),
    Err<T>(:final failure) => Result.err(failure),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
