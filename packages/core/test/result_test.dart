import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_core/nexo_core.dart';

void main() {
  group('Result', () {
    test('fold sobre Ok', () {
      const Result<int> r = Result.ok(2);
      expect(r.fold(ok: (v) => v * 2, err: (_) => -1), 4);
      expect(r.valueOrNull, 2);
    });

    test('fold sobre Err', () {
      const Result<int> r = Result.err(NetworkFailure());
      expect(r.fold(ok: (v) => v, err: (f) => -1), -1);
      expect(r.valueOrNull, isNull);
    });

    test('map preserva el failure', () {
      const Result<int> r = Result.err(TimeoutFailure());
      final mapped = r.map((v) => '$v');
      expect(mapped.isErr, isTrue);
    });

    test('failures reintentables', () {
      expect(const NetworkFailure().isRetryable, isTrue);
      expect(const TimeoutFailure().isRetryable, isTrue);
      expect(const ServiceUnavailableFailure().isRetryable, isTrue);
      expect(
        const ValidationFailure('insufficient_funds').isRetryable,
        isFalse,
      );
      expect(const UnauthorizedFailure().isRetryable, isFalse);
    });
  });
}
