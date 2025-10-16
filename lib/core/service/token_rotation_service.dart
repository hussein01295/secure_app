import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

/// Service de rotation automatique des tokens
/// Gère la rotation tous les 14 jours avec détection proactive
class TokenRotationService {
  static const _secure = FlutterSecureStorage();
  
  /// Intercepte les réponses HTTP pour détecter les rotations automatiques
  static Future<http.Response> interceptResponse(http.Response response) async {
    // Vérifier si le serveur a envoyé un nouveau token
    final newToken = response.headers['x-new-token'];
    final tokenRotated = response.headers['x-token-rotated'];
    final rotationReason = response.headers['x-rotation-reason'];
    
    if (newToken != null && tokenRotated == 'true') {
      debugPrint('🔄 Rotation automatique détectée: $rotationReason');

      // Sauvegarder le nouveau token
      await _secure.write(key: 'token', value: newToken);

      // Log pour debug
      final tokenAge = _getTokenAgeInDays(newToken);
      debugPrint('✅ Nouveau token sauvegardé (âge: $tokenAge jours)');
      
      // Notifier les autres services si nécessaire
      _notifyTokenRotation(newToken, rotationReason ?? 'unknown');
    }
    
    return response;
  }
  
  /// Effectue une requête HTTP avec gestion automatique de la rotation
  static Future<http.Response> makeRequest({
    required String method,
    required String endpoint,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final token = await _secure.read(key: 'token');
    
    // Préparer les headers avec le token
    final requestHeaders = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };
    
    http.Response response;
    
    // Effectuer la requête selon la méthode
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}$endpoint'),
          headers: requestHeaders,
        );
        break;
      case 'POST':
        response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}$endpoint'),
          headers: requestHeaders,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          Uri.parse('${ApiConfig.baseUrl}$endpoint'),
          headers: requestHeaders,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(
          Uri.parse('${ApiConfig.baseUrl}$endpoint'),
          headers: requestHeaders,
        );
        break;
      default:
        throw ArgumentError('Méthode HTTP non supportée: $method');
    }
    
    // Intercepter la réponse pour la rotation automatique
    return await interceptResponse(response);
  }
  
  /// Vérifie l'âge du token actuel
  static Future<Map<String, dynamic>?> checkTokenAge() async {
    try {
      final response = await makeRequest(
        method: 'GET',
        endpoint: '/auth/token-age',
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur lors de la vérification de l\'âge du token: $e');
      return null;
    }
  }
  
  /// Force la rotation manuelle du token
  static Future<bool> forceRotation() async {
    try {
      final response = await makeRequest(
        method: 'POST',
        endpoint: '/auth/rotate-token',
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['accessToken'];
        
        if (newToken != null) {
          await _secure.write(key: 'token', value: newToken);
          debugPrint('🔄 Rotation manuelle effectuée avec succès');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erreur lors de la rotation manuelle: $e');
      return false;
    }
  }
  
  /// Démarre la vérification périodique de l'âge du token
  static void startPeriodicCheck() {
    // Vérifier l'âge du token toutes les 6 heures
    Stream.periodic(Duration(hours: 6)).listen((_) async {
      final tokenAge = await checkTokenAge();
      if (tokenAge != null) {
        final rotationStatus = tokenAge['rotationStatus'];
        if (rotationStatus['shouldPreRotate'] == true) {
          debugPrint('⚠️ Token approche de la rotation (${tokenAge['tokenAge']['formatted']})');
          // Optionnel: forcer la rotation proactive
          // await forceRotation();
        }
      }
    });
  }
  
  /// Obtient l'âge du token en jours (méthode locale)
  static int _getTokenAgeInDays(String? token) {
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
  
  /// Notifie les autres services de la rotation du token
  static void _notifyTokenRotation(String newToken, String reason) {
    // Ici, on pourrait notifier d'autres services
    // Par exemple, mettre à jour les connexions WebSocket
    debugPrint('📢 Notification de rotation: $reason');

    // 🔥 NOUVEAU : Notifier le SocketService du nouveau token
    try {
      // Import dynamique pour éviter les dépendances circulaires
      final socketService = _getSocketService();
      if (socketService != null) {
        socketService.updateToken(newToken);
        debugPrint('✅ SocketService notifié du nouveau token');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la notification du SocketService: $e');
    }
  }

  /// Obtient l'instance du SocketService de manière sécurisée
  static dynamic _getSocketService() {
    try {
      // Import dynamique pour éviter les dépendances circulaires
      return null; // TODO: Implémenter si nécessaire
    } catch (e) {
      return null;
    }
  }
  
  /// Obtient les statistiques des tokens depuis le serveur
  static Future<Map<String, dynamic>?> getTokenStats() async {
    try {
      final response = await makeRequest(
        method: 'GET',
        endpoint: '/auth/token-stats',
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des statistiques: $e');
      return null;
    }
  }
}
