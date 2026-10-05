import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_core/nexo_core.dart';

void main() {
  test('ejecuta todas las limpiezas aunque una falle', () async {
    final registry = SessionCleanupRegistry();
    final ran = <String>[];
    registry
      ..register(() async => ran.add('a'))
      ..register(() async => throw StateError('boom'))
      ..register(() async => ran.add('c'));

    final errors = await registry.runAll();

    expect(ran, ['a', 'c']);
    expect(errors.single, isA<StateError>());
  });
}
