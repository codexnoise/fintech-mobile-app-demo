import 'package:cloud_firestore/cloud_firestore.dart';

/// Borra la caché local de Firestore al cerrar sesión para que el siguiente
/// usuario del dispositivo no vea datos del anterior.
///
/// `clearPersistence` solo se permite con la instancia terminada. FlutterFire
/// recrea la instancia nativa en el siguiente uso y conserva los settings
/// (verificado en emulador: logout -> login -> lectura de cuentas).
Future<void> clearFirestoreCache(FirebaseFirestore firestore) async {
  await firestore.terminate();
  await firestore.clearPersistence();
}
