import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:nexo_core/nexo_core.dart';

final class FirebaseAnalyticsTracker implements AnalyticsTracker {
  const FirebaseAnalyticsTracker(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  void track(String event, [Map<String, Object> params = const {}]) {
    // Analytics solo acepta String/num: los bool viajan como texto.
    _analytics.logEvent(
      name: event,
      parameters: {
        for (final MapEntry(:key, :value) in params.entries)
          key: value is num || value is String ? value : '$value',
      },
    );
  }

  @override
  void setUserProperty(String name, String? value) =>
      _analytics.setUserProperty(name: name, value: value);
}
