import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:silencia/core/config/api_config.dart'; // <-- Ajout de l'import

class AuthService {
  static const _secure = FlutterSecureStorage();

  static Future<void> saveLogin(String accessToken, String refreshToken, String userId, String username) async {
    await _secure.write(key: 'token', value: accessToken);
    await _secure.write(key: 'refreshToken', value: refreshToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setString('username', username);
  }

  static bool isTokenExpired(String? token) {
    if (token == null) return true;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload['exp'];
      if (exp == null) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return true;
    }
  }

  static Future<bool> refreshTokenIfNeeded() async {
    final token = await _secure.read(key: 'token');
    final refreshToken = await _secure.read(key: 'refreshToken');
    if (refreshToken == null) {
      await logout();
      return false;
    }
    if (!isTokenExpired(token)) return true;

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/auth/refresh"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['accessToken'];
        final newRefreshToken = data['refreshToken'];

        if (newAccessToken != null) {
          await _secure.write(key: 'token', value: newAccessToken);
          // 🔥 NOUVEAU : Notifier le SocketService du nouveau token
          try {
            // Import dynamique pour éviter les dépendances circulaires
            // On utilisera une approche différente dans la reconnexion
            debugPrint("🔄 Token rafraîchi automatiquement - SocketService sera mis à jour lors de la prochaine reconnexion");
          } catch (e) {
            debugPrint("⚠️ Erreur lors de la notification du SocketService: $e");
          }
        }
        if (newRefreshToken != null) {
          await _secure.write(key: 'refreshToken', value: newRefreshToken);
        }
        debugPrint("🔄 Token rafraîchi automatiquement");
        return true;
      }
      await logout();
      return false;
    } catch (e) {
      debugPrint("❌ Erreur réseau durant le refresh : $e");
      return true;
    }
  }

  /// Vérifie si le token doit être rotationné (> 14 jours)
  static bool shouldRotateToken(String? token) {
    if (token == null) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final iat = payload['iat'];
      if (iat == null) return false;
      final issuedAt = DateTime.fromMillisecondsSinceEpoch(iat * 1000);
      final tokenAge = DateTime.now().difference(issuedAt);
      return tokenAge.inDays > 25;
    } catch (_) {
      return false;
    }
  }

  /// Vérifie si le token approche de la rotation (> 12 jours)
  static bool shouldPreRotateToken(String? token) {
    if (token == null) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final iat = payload['iat'];
      if (iat == null) return false;
      final issuedAt = DateTime.fromMillisecondsSinceEpoch(iat * 1000);
      final tokenAge = DateTime.now().difference(issuedAt);
      return tokenAge.inDays > 20;
    } catch (_) {
      return false;
    }
  }

  /// Obtient l'âge du token en jours
  static int getTokenAgeInDays(String? token) {
    if (token == null) return 0;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return 0;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final iat = payload['iat'];
      if (iat == null) return 0;
      final issuedAt = DateTime.fromMillisecondsSinceEpoch(iat * 1000);
      final tokenAge = DateTime.now().difference(issuedAt);
      return tokenAge.inDays;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> logout() async {
    final refreshToken = await _secure.read(key: 'refreshToken');
    if (refreshToken != null) {
      try {
        await http.post(
          Uri.parse("${ApiConfig.baseUrl}/auth/logout"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );
      } catch (_) {}
    }
    await _secure.delete(key: 'token');
    await _secure.delete(key: 'refreshToken');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('username');
  }

  static Future<String?> getToken() async {
    return await _secure.read(key: 'token');
  }

  static Future<String?> getRefreshToken() async {
    return await _secure.read(key: 'refreshToken');
  }

  static Future<Map<String, String>?> getAuthorizedHeaders({BuildContext? context}) async {
    final ok = await refreshTokenIfNeeded();
    if (!ok) {
      if (context != null && context.mounted) {
        context.go('/login');
      }
      return null;
    }
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>?> getSavedUser() async {
    final token = await _secure.read(key: 'token');
    final refreshToken = await _secure.read(key: 'refreshToken');
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final username = prefs.getString('username');

    if (token != null && refreshToken != null && userId != null && username != null) {
      return {
        'token': token,
        'refreshToken': refreshToken,
        'userId': userId,
        'username': username,
      };
    }
    return null;
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  static Future<bool> changePassword(String oldPwd, String newPwd) async {
    final headers = await getAuthorizedHeaders();
    if (headers == null) return false;
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/users/change-password"),
        headers: headers,
        body: jsonEncode({
          'oldPassword': oldPwd,
          'newPassword': newPwd,
        }),
      );
      // Log les infos pour comprendre
      debugPrint("Réponse changement mdp: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) return true;
      if (response.statusCode == 401) throw "Ancien mot de passe incorrect";
      // Affiche le message backend sinon
      throw jsonDecode(response.body)['message'] ?? "Erreur inconnue";
    } catch (e) {
      rethrow;
    }
  }
}
