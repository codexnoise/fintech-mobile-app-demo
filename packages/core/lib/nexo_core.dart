/// Núcleo transversal de Nexo.
///
/// Regla de dependencias: este package no depende de ningún otro package de
/// Nexo. Todos los demás pueden depender de él.
library;

export 'src/money.dart';
export 'src/result.dart';
export 'src/network/api_client.dart';
export 'src/network/error_mapper.dart';
export 'src/network/interceptors.dart';
export 'src/network/token_providers.dart';
export 'src/navigation/nexo_routes.dart';
export 'src/session/session_contracts.dart';
export 'src/failure_messages.dart';
export 'src/connectivity.dart';
export 'src/contracts/accounts.dart';
export 'src/error_reporter.dart';
export 'src/network/circuit_breaker.dart';
export 'src/analytics.dart';
