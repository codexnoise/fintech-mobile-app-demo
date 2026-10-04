/// Proveedor del ID token del usuario. La app lo implementa con Firebase Auth;
/// core no conoce Firebase.
abstract interface class AuthTokenProvider {
  /// `null` si no hay sesión. [forceRefresh] pide un token nuevo al servidor.
  Future<String?> getIdToken({bool forceRefresh = false});
}

/// Proveedor del token de atestación (Firebase App Check en la app).
abstract interface class AppCheckTokenProvider {
  /// `null` si no hay token disponible.
  Future<String?> getToken();
}
