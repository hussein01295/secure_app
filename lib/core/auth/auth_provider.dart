import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider {
  static const _secure = FlutterSecureStorage();

  /// Vérifie si un token est présent dans le stockage sécurisé
  static Future<bool> isLoggedIn() async {
    final token = await _secure.read(key: 'token');
    return token != null;
  }

  /// Récupère le token si présent
  static Future<String?> getToken() async {
    return await _secure.read(key: 'token');
  }

  /// Enregistre un token
  static Future<void> saveToken(String token) async {
    await _secure.write(key: 'token', value: token);
  }

  /// Supprime le token (utilisé lors du logout)
  static Future<void> clearToken() async {
    await _secure.delete(key: 'token');
  }
}
