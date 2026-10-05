import 'package:cloud_firestore/cloud_firestore.dart';

/// Borra la caché local de Firestore al cerrar sesión para que el siguiente
/// usuario del dispositivo no vea datos del anterior.
///
/// `clearPersistence` solo se permite con la instancia terminada. Pendiente de
/// validar en F3 (primera lectura de Firestore tras un logout) que FlutterFire
/// recrea la instancia nativa y conserva los settings del emulador.
Future<void> clearFirestoreCache(FirebaseFirestore firestore) async {
  await firestore.terminate();
  await firestore.clearPersistence();
}
