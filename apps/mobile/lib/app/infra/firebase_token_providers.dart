import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexo_core/nexo_core.dart';

/// ID token de Firebase Auth para el [AuthInterceptor] de nexo_core.
final class FirebaseAuthTokenProvider implements AuthTokenProvider {
  const FirebaseAuthTokenProvider(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      _auth.currentUser?.getIdToken(forceRefresh);
}

/// Token de Firebase App Check para el [AppCheckInterceptor] de nexo_core.
final class FirebaseAppCheckTokenProvider implements AppCheckTokenProvider {
  const FirebaseAppCheckTokenProvider(this._appCheck);

  final FirebaseAppCheck _appCheck;

  @override
  Future<String?> getToken() => _appCheck.getToken();
}
