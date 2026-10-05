import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexo_core/nexo_core.dart';

final class FirebaseCurrentUser implements CurrentUserProvider {
  const FirebaseCurrentUser(this._auth);

  final FirebaseAuth _auth;

  @override
  String? get uid => _auth.currentUser?.uid;
}
