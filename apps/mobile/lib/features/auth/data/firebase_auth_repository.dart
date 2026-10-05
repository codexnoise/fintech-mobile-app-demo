import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexo_core/nexo_core.dart';

import '../domain/auth_repository.dart';

final class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<AuthUser?> userChanges() =>
      _auth.authStateChanges().map((u) => u == null ? null : _toUser(u));

  @override
  AuthUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _toUser(user);
  }

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) => _guard(() async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _toUser(cred.user!);
  });

  @override
  Future<Result<AuthUser>> register({
    required String email,
    required String password,
  }) => _guard(() async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _toUser(cred.user!);
  });

  @override
  Future<Result<void>> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // No revelar si la cuenta existe (enumeración de usuarios).
      if (e.code != 'user-not-found') return Result.err(mapAuthException(e));
    }
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> reauthenticate(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      return const Result.err(ValidationFailure(AuthErrorCodes.noSession));
    }
    return _guard(() async {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    });
  }

  @override
  Future<void> signOut() => _auth.signOut();

  static AuthUser _toUser(User u) => AuthUser(uid: u.uid, email: u.email);

  static Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Result.ok(await body());
    } on FirebaseAuthException catch (e) {
      return Result.err(mapAuthException(e));
    }
  }
}

/// Traduce errores de Firebase Auth a [Failure] de dominio.
Failure mapAuthException(FirebaseAuthException e) => switch (e.code) {
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' ||
  'INVALID_LOGIN_CREDENTIALS' => const ValidationFailure(
    AuthErrorCodes.invalidCredentials,
  ),
  'email-already-in-use' => const ValidationFailure(AuthErrorCodes.emailInUse),
  'invalid-email' => const ValidationFailure(AuthErrorCodes.invalidEmail),
  'weak-password' => const ValidationFailure(AuthErrorCodes.weakPassword),
  'too-many-requests' => const ValidationFailure(
    AuthErrorCodes.tooManyRequests,
  ),
  'user-disabled' => const ValidationFailure(AuthErrorCodes.userDisabled),
  'network-request-failed' => const NetworkFailure(),
  _ => UnknownFailure(e.code),
};
