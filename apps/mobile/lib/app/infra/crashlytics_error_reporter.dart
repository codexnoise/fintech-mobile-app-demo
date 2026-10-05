import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:nexo_core/nexo_core.dart';

final class CrashlyticsErrorReporter implements ErrorReporter {
  const CrashlyticsErrorReporter(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  void report(
    Object error,
    StackTrace? stack, {
    String? reason,
    String? requestId,
  }) {
    // Custom key para buscar el mismo id en los logs del BFF.
    if (requestId != null) _crashlytics.setCustomKey('request_id', requestId);
    _crashlytics.recordError(error, stack, reason: reason);
  }
}
