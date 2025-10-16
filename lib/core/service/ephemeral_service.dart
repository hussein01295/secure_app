import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:silencia/core/config/api_config.dart';

class EphemeralService {
  static String get _baseUrl => '${ApiConfig.baseUrl}/ephemeral';
  static const _secure = FlutterSecureStorage();

  // 🔥 Obtenir le token d'authentification
  static Future<String?> _getToken() async {
    final token = await _secure.read(key: 'token');

    // 🔍 DEBUG: Logs pour diagnostiquer le problème d'authentification
    debugPrint('🔍 DEBUG: _getToken appelé');
    debugPrint('🔍 DEBUG: token = ${token != null ? "${token.substring(0, 20)}..." : "null"}');

    return token;
  }

  // 🔥 Headers avec authentification
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 🔥 Obtenir les paramètres de messages éphémères pour une relation
  static Future<Map<String, dynamic>> getSettings(String relationId) async {
    try {
      final headers = await _getHeaders();
      final url = '$_baseUrl/settings/$relationId';

      // 🔍 DEBUG: Logs pour diagnostiquer le problème d'authentification
      debugPrint('🔍 DEBUG: EphemeralService.getSettings appelé');
      debugPrint('🔍 DEBUG: relationId = $relationId');
      debugPrint('🔍 DEBUG: url = $url');
      debugPrint('🔍 DEBUG: headers = $headers');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint('🔍 DEBUG: response.statusCode = ${response.statusCode}');
      debugPrint('🔍 DEBUG: response.body = ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['settings'] ?? {};
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des paramètres éphémères: $e');
      throw Exception('Impossible de récupérer les paramètres: $e');
    }
  }

  // 🔥 Mettre à jour les paramètres de messages éphémères
  static Future<Map<String, dynamic>> updateSettings(
    String relationId,
    Map<String, dynamic> settings,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/settings/$relationId'),
        headers: headers,
        body: json.encode(settings),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['settings'] ?? {};
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la mise à jour des paramètres éphémères: $e');
      throw Exception('Impossible de mettre à jour les paramètres: $e');
    }
  }

  // 🔥 Marquer un message comme lu (pour déclencher la suppression si nécessaire)
  static Future<Map<String, dynamic>> markMessageAsRead(String messageId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/mark-read/$messageId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du marquage comme lu: $e');
      throw Exception('Impossible de marquer le message comme lu: $e');
    }
  }

  // 🔥 Obtenir les statistiques des messages éphémères
  static Future<Map<String, dynamic>> getStatistics(String relationId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/stats/$relationId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['stats'] ?? {};
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des statistiques: $e');
      throw Exception('Impossible de récupérer les statistiques: $e');
    }
  }

  // 🔥 Nettoyer manuellement les messages éphémères expirés
  static Future<Map<String, dynamic>> cleanupExpiredMessages() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/cleanup'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du nettoyage: $e');
      throw Exception('Impossible de nettoyer les messages: $e');
    }
  }

  // 🔥 Vérifier si les messages éphémères sont activés pour une relation
  static Future<bool> isEphemeralEnabled(String relationId) async {
    try {
      final settings = await getSettings(relationId);
      return settings['enabled'] ?? false;
    } catch (e) {
      debugPrint('❌ Erreur lors de la vérification des paramètres éphémères: $e');
      return false;
    }
  }

  // 🔥 Obtenir la durée d'expiration pour une relation
  static Future<int?> getExpirationDuration(String relationId) async {
    try {
      final settings = await getSettings(relationId);
      if (settings['enabled'] != true) return null;
      
      final durationType = settings['durationType'] ?? 'timer';
      
      switch (durationType) {
        case 'after_read':
          return null; // Pas de durée fixe
        case 'custom':
          return settings['customDuration'];
        case 'timer':
        default:
          return settings['timerDuration'] ?? 86400000; // 24h par défaut
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération de la durée: $e');
      return null;
    }
  }

  // 🔥 Formater la durée en texte lisible
  static String formatDuration(int durationMs) {
    final duration = Duration(milliseconds: durationMs);
    
    if (duration.inDays > 0) {
      return '${duration.inDays} jour${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} heure${duration.inHours > 1 ? 's' : ''}';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    } else {
      return '${duration.inSeconds} seconde${duration.inSeconds > 1 ? 's' : ''}';
    }
  }

  // 🔥 Calculer le temps restant avant expiration
  static String? getTimeUntilExpiration(DateTime? expiresAt) {
    if (expiresAt == null) return null;
    
    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    
    if (difference.isNegative) {
      return 'Expiré';
    }
    
    if (difference.inDays > 0) {
      return '${difference.inDays}j ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ${difference.inSeconds % 60}s';
    } else {
      return '${difference.inSeconds}s';
    }
  }

  // 🔥 Vérifier si un message est expiré
  static bool isMessageExpired(DateTime? expiresAt) {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt);
  }

  // 🔥 Obtenir l'icône appropriée pour le type de message éphémère
  static String getEphemeralIcon(Map<String, dynamic> settings) {
    if (settings['enabled'] != true) return '';
    
    final durationType = settings['durationType'] ?? 'timer';
    
    switch (durationType) {
      case 'after_read':
        return '👁️'; // Œil pour "après lecture"
      case 'timer':
      case 'custom':
        return '⏰'; // Horloge pour durée
      default:
        return '🔥'; // Feu pour éphémère
    }
  }

  // 🔥 Obtenir la description du type de message éphémère
  static String getEphemeralDescription(Map<String, dynamic> settings) {
    if (settings['enabled'] != true) return 'Messages normaux';
    
    final durationType = settings['durationType'] ?? 'timer';
    
    switch (durationType) {
      case 'after_read':
        return 'Supprimé après lecture';
      case 'timer':
        final duration = settings['timerDuration'] ?? 86400000;
        return 'Supprimé après ${formatDuration(duration)}';
      case 'custom':
        final duration = settings['customDuration'];
        if (duration != null) {
          return 'Supprimé après ${formatDuration(duration)}';
        }
        return 'Durée personnalisée';
      default:
        return 'Messages éphémères';
    }
  }

  // 🔥 Constantes pour les durées prédéfinies
  static const Map<int, String> durationLabels = {
    3600000: '1 heure',
    43200000: '12 heures',
    86400000: '24 heures',
    604800000: '7 jours',
    1209600000: '14 jours',
    2678400000: '31 jours',
    7776000000: '90 jours',
  };

  // 🔥 Obtenir les durées disponibles
  static List<Map<String, dynamic>> getAvailableDurations() {
    return durationLabels.entries.map((entry) => {
      'value': entry.key,
      'label': entry.value,
    }).toList();
  }

  // 🔥 Envoyer un message d'aide sur les messages éphémères
  static Future<void> sendHelpMessage(String relationId) async {
    try {
      final headers = await _getHeaders();
      final url = '$_baseUrl/help/$relationId';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception('Erreur ${response.statusCode}: ${errorData['message']}');
      }
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi du message d\'aide: $e');
    }
  }
}
