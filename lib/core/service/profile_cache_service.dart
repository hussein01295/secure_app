import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:silencia/core/config/api_config.dart';

/// Service de cache pour les données de profil utilisateur
/// Permet l'accès aux profils même quand le serveur est hors service
class ProfileCacheService {
  static const _storage = FlutterSecureStorage();
  static final _instance = ProfileCacheService._internal();
  factory ProfileCacheService() => _instance;
  ProfileCacheService._internal();

  // Clés de cache
  static const String _userProfilePrefix = 'profile_user_';
  static const String _myProfileKey = 'profile_me';
  static const String _friendsListKey = 'friends_list';
  static const String _profileStatsPrefix = 'profile_stats_';


  // Durée de validité du cache (7 jours)
  static const Duration _cacheValidityDuration = Duration(days: 7);

  /// Sauvegarde les données de profil de l'utilisateur connecté
  Future<void> saveMyProfile({
    required String userId,
    required String username,
    String? displayName,
    String? profileImageUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final profileData = {
        'userId': userId,
        'username': username,
        'displayName': displayName,
        'profileImageUrl': profileImageUrl,
        'additionalData': additionalData ?? {},
        'lastUpdated': DateTime.now().toIso8601String(),
        'isCurrentUser': true,
      };

      await _storage.write(
        key: _myProfileKey,
        value: jsonEncode(profileData),
      );

      // Sauvegarder aussi dans SharedPreferences pour accès rapide
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_username', username);
      await prefs.setString('cached_display_name', displayName ?? '');
      await prefs.setString('cached_user_id', userId);

      if (kDebugMode) {
        print('💾 Profil utilisateur sauvegardé en cache: $username');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur sauvegarde profil: $e');
    }
  }

  /// Récupère les données de profil de l'utilisateur connecté
  Future<Map<String, dynamic>?> getMyProfile() async {
    try {
      // Essayer d'abord le cache sécurisé
      final cachedData = await _storage.read(key: _myProfileKey);
      if (cachedData != null) {
        final profileData = jsonDecode(cachedData);
        
        // Vérifier la validité du cache
        final lastUpdated = DateTime.parse(profileData['lastUpdated']);
        if (DateTime.now().difference(lastUpdated) < _cacheValidityDuration) {
          if (kDebugMode) print('💾 Profil chargé depuis le cache');
          return Map<String, dynamic>.from(profileData);
        }
      }

      // Fallback vers SharedPreferences si pas de cache sécurisé
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('cached_username');
      final displayName = prefs.getString('cached_display_name');
      final userId = prefs.getString('cached_user_id');

      if (username != null && userId != null) {
        if (kDebugMode) print('💾 Profil chargé depuis SharedPreferences');
        return {
          'userId': userId,
          'username': username,
          'displayName': displayName,
          'profileImageUrl': null,
          'additionalData': {},
          'lastUpdated': DateTime.now().toIso8601String(),
          'isCurrentUser': true,
          'fromFallback': true,
        };
      }

      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Erreur lecture profil: $e');
      return null;
    }
  }

  /// Sauvegarde les données d'un autre utilisateur
  Future<void> saveUserProfile({
    required String userId,
    required String username,
    String? displayName,
    String? profileImageUrl,
    String? relationStatus,
    String? relationId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final profileData = {
        'userId': userId,
        'username': username,
        'displayName': displayName,
        'profileImageUrl': profileImageUrl,
        'relationStatus': relationStatus,
        'relationId': relationId,
        'additionalData': additionalData ?? {},
        'lastUpdated': DateTime.now().toIso8601String(),
        'isCurrentUser': false,
      };

      await _storage.write(
        key: '$_userProfilePrefix$userId',
        value: jsonEncode(profileData),
      );

      if (kDebugMode) {
        print('💾 Profil utilisateur $username sauvegardé en cache');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur sauvegarde profil utilisateur: $e');
    }
  }

  /// Récupère les données d'un autre utilisateur
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final cachedData = await _storage.read(key: '$_userProfilePrefix$userId');
      if (cachedData != null) {
        final profileData = jsonDecode(cachedData);
        
        // Vérifier la validité du cache
        final lastUpdated = DateTime.parse(profileData['lastUpdated']);
        if (DateTime.now().difference(lastUpdated) < _cacheValidityDuration) {
          if (kDebugMode) print('💾 Profil utilisateur chargé depuis le cache');
          return Map<String, dynamic>.from(profileData);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Erreur lecture profil utilisateur: $e');
      return null;
    }
  }

  /// Sauvegarde la liste des amis
  Future<void> saveFriendsList(List<dynamic> friends) async {
    try {
      final friendsData = {
        'friends': friends,
        'count': friends.length,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      await _storage.write(
        key: _friendsListKey,
        value: jsonEncode(friendsData),
      );

      // Sauvegarder aussi le nombre d'amis dans SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cached_friends_count', friends.length);

      if (kDebugMode) {
        print('💾 Liste d\'amis sauvegardée: ${friends.length} amis');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur sauvegarde amis: $e');
    }
  }

  /// Récupère la liste des amis
  Future<Map<String, dynamic>?> getFriendsList() async {
    try {
      final cachedData = await _storage.read(key: _friendsListKey);
      if (cachedData != null) {
        final friendsData = jsonDecode(cachedData);
        
        // Vérifier la validité du cache
        final lastUpdated = DateTime.parse(friendsData['lastUpdated']);
        if (DateTime.now().difference(lastUpdated) < _cacheValidityDuration) {
          if (kDebugMode) print('💾 Amis chargés depuis le cache');
          return Map<String, dynamic>.from(friendsData);
        }
      }

      // Fallback vers SharedPreferences pour le nombre d'amis
      final prefs = await SharedPreferences.getInstance();
      final friendsCount = prefs.getInt('cached_friends_count') ?? 0;
      
      if (friendsCount > 0) {
        return {
          'friends': [],
          'count': friendsCount,
          'lastUpdated': DateTime.now().toIso8601String(),
          'fromFallback': true,
        };
      }

      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Erreur lecture amis: $e');
      return null;
    }
  }

  /// Sauvegarde les statistiques de profil
  Future<void> saveProfileStats({
    required String userId,
    int? totalMessages,
    int? totalGroups,
    DateTime? lastSeen,
    bool? isOnline,
    String? customStatus,
    String? statusEmoji,
  }) async {
    try {
      final statsData = {
        'totalMessages': totalMessages,
        'totalGroups': totalGroups,
        'lastSeen': lastSeen?.toIso8601String(),
        'isOnline': isOnline,
        'customStatus': customStatus,
        'statusEmoji': statusEmoji,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      await _storage.write(
        key: '$_profileStatsPrefix$userId',
        value: jsonEncode(statsData),
      );

      if (kDebugMode) {
        print('💾 Statistiques profil sauvegardées pour $userId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur sauvegarde stats: $e');
    }
  }

  /// Récupère les statistiques de profil
  Future<Map<String, dynamic>?> getProfileStats(String userId) async {
    try {
      final cachedData = await _storage.read(key: '$_profileStatsPrefix$userId');
      if (cachedData != null) {
        final statsData = jsonDecode(cachedData);
        
        // Vérifier la validité du cache
        final lastUpdated = DateTime.parse(statsData['lastUpdated']);
        if (DateTime.now().difference(lastUpdated) < _cacheValidityDuration) {
          if (kDebugMode) print('💾 Stats profil chargées depuis le cache');
          return Map<String, dynamic>.from(statsData);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Erreur lecture stats: $e');
      return null;
    }
  }

  /// Vérifie la connectivité et synchronise si possible
  Future<bool> syncWithServerIfOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (kDebugMode) print('📱 Mode offline - pas de synchronisation');
        return false;
      }

      // Essayer de synchroniser le profil utilisateur
      await _syncMyProfileFromServer();
      await _syncFriendsFromServer();

      if (kDebugMode) print('🔄 Synchronisation profil terminée');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Erreur synchronisation: $e');
      return false;
    }
  }

  /// Synchronise le profil utilisateur depuis le serveur
  Future<void> _syncMyProfileFromServer() async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/me'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        await saveMyProfile(
          userId: userData['id'],
          username: userData['username'],
          displayName: userData['displayName'],
          profileImageUrl: userData['profileImageUrl'],
          additionalData: userData,
        );
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur sync profil: $e');
    }
  }

  /// Synchronise la liste d'amis depuis le serveur
  Future<void> _syncFriendsFromServer() async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/relations/friends'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final friends = jsonDecode(response.body);
        await saveFriendsList(friends);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur sync amis: $e');
    }
  }

  /// Nettoie le cache expiré
  Future<void> cleanExpiredCache() async {
    try {
      // Cette méthode pourrait être étendue pour nettoyer
      // automatiquement les données expirées
      if (kDebugMode) print('🧹 Nettoyage du cache profil');
    } catch (e) {
      if (kDebugMode) print('❌ Erreur nettoyage cache: $e');
    }
  }

  /// Efface tout le cache de profil
  Future<void> clearAllCache() async {
    try {
      await _storage.delete(key: _myProfileKey);
      await _storage.delete(key: _friendsListKey);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_username');
      await prefs.remove('cached_display_name');
      await prefs.remove('cached_user_id');
      await prefs.remove('cached_friends_count');

      if (kDebugMode) print('🗑️ Cache profil effacé');
    } catch (e) {
      if (kDebugMode) print('❌ Erreur effacement cache: $e');
    }
  }

  /// Supprimer le cache d'un utilisateur spécifique
  Future<void> clearUserCache(String userId) async {
    try {
      // Supprimer le profil de l'utilisateur
      await _storage.delete(key: '$_userProfilePrefix$userId');

      // Supprimer les statistiques de l'utilisateur
      await _storage.delete(key: '$_profileStatsPrefix$userId');

      // Supprimer le cache de la liste d'amis pour forcer un refresh
      await _storage.delete(key: _friendsListKey);

      if (kDebugMode) {
        print('🗑️ Cache supprimé pour l\'utilisateur $userId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur suppression cache utilisateur: $e');
    }
  }
}
