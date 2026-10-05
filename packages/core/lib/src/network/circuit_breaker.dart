import '../result.dart';

enum CircuitState { closed, open, halfOpen }

/// Circuit breaker por servicio (primer segmento de la ruta del BFF).
/// Tras [failureThreshold] fallos seguidos se abre y falla rápido durante
/// [openFor]; luego deja pasar una sola prueba (half-open).
class CircuitBreaker {
  CircuitBreaker({
    this.failureThreshold = 3,
    this.openFor = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int failureThreshold;
  final Duration openFor;
  final DateTime Function() _now;

  final _circuits = <String, _Circuit>{};

  CircuitState stateOf(String service) =>
      _circuits[service]?.state ?? CircuitState.closed;

  /// Estado de todos los servicios vistos (para el Network Lab).
  Map<String, CircuitState> get snapshot => {
    for (final MapEntry(:key, :value) in _circuits.entries) key: value.state,
  };

  bool allows(String service) {
    final circuit = _circuits[service];
    if (circuit == null) return true;
    switch (circuit.state) {
      case CircuitState.closed:
        return true;
      case CircuitState.halfOpen:
        return false; // Ya hay una prueba en curso.
      case CircuitState.open:
        if (_now().difference(circuit.openedAt!) < openFor) return false;
        circuit.state = CircuitState.halfOpen;
        return true;
    }
  }

  void recordSuccess(String service) => _circuits.remove(service);

  void recordFailure(String service) {
    final circuit = _circuits.putIfAbsent(service, _Circuit.new);
    circuit.failures++;
    if (circuit.state == CircuitState.halfOpen ||
        circuit.failures >= failureThreshold) {
      circuit
        ..state = CircuitState.open
        ..openedAt = _now();
    }
  }

  void reset() => _circuits.clear();

  /// Solo fallas de infraestructura abren el circuito; los rechazos de
  /// negocio (4xx) son respuestas sanas del servicio.
  static bool countsAsFailure(Failure failure) => switch (failure) {
    NetworkFailure() || TimeoutFailure() || ServiceUnavailableFailure() => true,
    ServerFailure(:final code) =>
      code == 'internal_error' || (code?.startsWith('http_5') ?? false),
    _ => false,
  };
}

class _Circuit {
  CircuitState state = CircuitState.closed;
  int failures = 0;
  DateTime? openedAt;
}
