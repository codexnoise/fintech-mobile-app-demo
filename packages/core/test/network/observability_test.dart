import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexo_core/nexo_core.dart';

import 'fake_adapter.dart';

class _MockAuth extends Mock implements AuthTokenProvider {}

class _MockAppCheck extends Mock implements AppCheckTokenProvider {}

final class _RecordingReporter implements ErrorReporter {
  final reports = <({Object error, String? reason, String? requestId})>[];

  @override
  void report(
    Object error,
    StackTrace? stack, {
    String? reason,
    String? requestId,
  }) => reports.add((error: error, reason: reason, requestId: requestId));
}

void main() {
  late _MockAuth auth;
  late _MockAppCheck appCheck;
  late _RecordingReporter reporter;

  setUp(() {
    auth = _MockAuth();
    appCheck = _MockAppCheck();
    reporter = _RecordingReporter();
    when(() => auth.getIdToken(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => 't');
    when(() => appCheck.getToken()).thenAnswer((_) async => 'a');
  });

  ApiClient client(FakeReply reply) => ApiClient(
    baseUrl: 'https://api.test',
    authTokens: auth,
    appCheckTokens: appCheck,
    adapter: FakeAdapter([reply]),
    sleep: (_) async {},
    errorReporter: reporter,
  );

  test(
    'un 5xx del BFF se reporta con su requestId para cruzar con logs',
    () async {
      await client(
        JsonReply(500, errorEnvelope('internal_error', requestId: 'req-42')),
      ).get('/me', decode: (j) => j);

      final report = reporter.reports.single;
      expect(report.requestId, 'req-42');
      expect(report.reason, contains('/me'));
    },
  );

  test('una respuesta con contrato roto también se reporta', () async {
    await client(JsonReply(200, ['no', 'es', 'objeto']))
        .get('/me', decode: (j) => (j! as Map)['id']);

    expect(reporter.reports.single.reason, contains('invalid_response'));
  });

  test('errores de negocio y de red no se reportan (son esperados)', () async {
    await client(JsonReply(422, errorEnvelope('insufficient_funds')))
        .post('/transfers', body: {}, decode: (j) => j);
    await client(TransportError(DioExceptionType.connectionError))
        .get('/me', decode: (j) => j);

    expect(reporter.reports, isEmpty);
  });
}
