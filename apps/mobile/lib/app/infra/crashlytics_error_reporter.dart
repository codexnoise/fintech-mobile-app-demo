import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:nexo_core/nexo_core.dart';

final class CrashlyticsErrorReporter implements ErrorReporter {
  const CrashlyticsErrorReporter(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  void report(Object error, StackTrace? stack, {String? reason}) =>
      _crashlytics.recordError(error, stack, reason: reason);
}
