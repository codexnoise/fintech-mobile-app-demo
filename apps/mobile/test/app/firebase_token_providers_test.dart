import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexo_mobile/app/infra/firebase_token_providers.dart';

class _MockAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockAppCheck extends Mock implements FirebaseAppCheck {}

void main() {
  group('FirebaseAuthTokenProvider', () {
    late _MockAuth auth;

    setUp(() => auth = _MockAuth());

    test('sin sesión devuelve null', () async {
      when(() => auth.currentUser).thenReturn(null);

      expect(await FirebaseAuthTokenProvider(auth).getIdToken(), isNull);
    });

    test('propaga forceRefresh al SDK', () async {
      final user = _MockUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.getIdToken(true)).thenAnswer((_) async => 'fresh');

      final token = await FirebaseAuthTokenProvider(auth)
          .getIdToken(forceRefresh: true);

      expect(token, 'fresh');
      verify(() => user.getIdToken(true)).called(1);
    });
  });

  test('FirebaseAppCheckTokenProvider delega en App Check', () async {
    final appCheck = _MockAppCheck();
    when(appCheck.getToken).thenAnswer((_) async => 'ac');

    expect(await FirebaseAppCheckTokenProvider(appCheck).getToken(), 'ac');
  });
}
