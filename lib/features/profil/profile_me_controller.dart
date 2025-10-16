import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/service/profile_cache_service.dart';
import 'package:silencia/core/service/messages_cache_service.dart';
import 'package:silencia/core/service/image_cache_service.dart';
import 'package:flutter/foundation.dart';

abstract class ProfileController {
  Future<void> fetchInitial();
}

class ProfileMeController extends ProfileController {
  List<dynamic> friends = [];
  int friendsCount = 0;
  final ProfileCacheService _cacheService = ProfileCacheService();

  @override
  Future<void> fetchInitial() async {
    await fetchFriends();
  }

  Future<void> fetchFriends() async {
    try {
      // 1. Charger d'abord depuis le cache
      final cachedFriends = await _cacheService.getFriendsList();
      if (cachedFriends != null) {
        friends = cachedFriends['friends'] ?? [];
        friendsCount = cachedFriends['count'] ?? 0;

        if (kDebugMode) {
          print('💾 Amis chargés depuis le cache: $friendsCount amis');
        }

        // Si on a des données du cache, on peut s'arrêter là
        // La synchronisation se fera en arrière-plan
        if (!cachedFriends.containsKey('fromFallback')) {
          _syncFriendsInBackground();
          return;
        }
      }

      // 2. Si pas de cache ou fallback, essayer le serveur
      await _fetchFriendsFromServer();
    } catch (e) {
      if (kDebugMode) print('❌ Erreur fetchFriends: $e');

      // En cas d'erreur, utiliser les données par défaut
      friends = [];
      friendsCount = 0;
    }
  }

  Future<void> _fetchFriendsFromServer() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/relations/friends'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        friends = jsonDecode(res.body);
        friendsCount = friends.length;

        // Sauvegarder en cache pour la prochaine fois
        await _cacheService.saveFriendsList(friends);

        if (kDebugMode) {
          print('🌐 Amis chargés depuis le serveur: $friendsCount amis');
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur serveur fetchFriends: $e');
    }
  }

  /// Synchronise les amis en arrière-plan sans bloquer l'UI
  void _syncFriendsInBackground() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        await _fetchFriendsFromServer();
      } catch (e) {
        if (kDebugMode) print('❌ Erreur sync background: $e');
      }
    });
  }
}

class ProfileUserController extends ProfileController {
  String? relationStatus;
  String? relationId;
  final String? userId;
  final ProfileCacheService _cacheService = ProfileCacheService();
  final MessagesCacheService _messagesCacheService = MessagesCacheService();
  final ImageCacheService _imageCacheService = ImageCacheService();

  ProfileUserController({required this.userId});

  @override
  Future<void> fetchInitial() async {
    await fetchRelationStatus();
  }

  Future<void> fetchRelationStatus() async {
    try {
      // 1. Charger d'abord depuis le cache
      if (userId != null) {
        final cachedProfile = await _cacheService.getUserProfile(userId!);
        if (cachedProfile != null) {
          relationStatus = cachedProfile['relationStatus'];
          relationId = cachedProfile['relationId'];

          if (kDebugMode) {
            print('💾 Relation chargée depuis le cache: $relationStatus');
          }

          // Si on a des données du cache, synchroniser en arrière-plan
          if (!cachedProfile.containsKey('fromFallback')) {
            _syncRelationInBackground();
            return;
          }
        }
      }

      // 2. Si pas de cache, essayer le serveur
      await _fetchRelationFromServer();
    } catch (e) {
      if (kDebugMode) print('❌ Erreur fetchRelationStatus: $e');

      // En cas d'erreur, utiliser les valeurs par défaut
      relationStatus = 'none';
      relationId = null;
    }
  }

  Future<void> _fetchRelationFromServer() async {
    try {
      final token = await AuthService.getToken();
      final myId = await AuthService.getUserId();

      if (token == null || myId == null || userId == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/relations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List relations = jsonDecode(response.body);
        for (var rel in relations) {
          if ((rel['user1']['_id'] == myId && rel['user2']['_id'] == userId) ||
              (rel['user2']['_id'] == myId && rel['user1']['_id'] == userId)) {
            relationId = rel['_id'];
            if (rel['status'] == 'accepted') {
              relationStatus = 'accepted';
            } else if (rel['user1']['_id'] == myId) {
              relationStatus = 'sent';
            } else {
              relationStatus = 'received';
            }

            // Sauvegarder en cache
            await _cacheService.saveUserProfile(
              userId: userId!,
              username: rel['user1']['_id'] == userId
                ? rel['user1']['username']
                : rel['user2']['username'],
              displayName: rel['user1']['_id'] == userId
                ? rel['user1']['displayName']
                : rel['user2']['displayName'],
              relationStatus: relationStatus,
              relationId: relationId,
            );

            if (kDebugMode) {
              print('🌐 Relation chargée depuis le serveur: $relationStatus');
            }
            return;
          }
        }
        relationStatus = 'none';
      } else {
        relationStatus = 'none';
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur serveur fetchRelation: $e');
      relationStatus = 'none';
    }
  }

  /// Synchronise la relation en arrière-plan sans bloquer l'UI
  void _syncRelationInBackground() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        await _fetchRelationFromServer();
      } catch (e) {
        if (kDebugMode) print('❌ Erreur sync relation background: $e');
      }
    });
  }

  Future<bool> sendFriendRequest() async {
    final token = await AuthService.getToken();
    if (token == null || userId == null) return false;

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/relations'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'receiver': userId}),
    );

    if (response.statusCode == 201) {
      relationStatus = 'sent';
      return true;
    }
    return false;
  }

  Future<bool> acceptFriendRequest() async {
    final token = await AuthService.getToken();
    if (token == null || relationId == null) return false;

    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/relations/$relationId/accept'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      relationStatus = 'accepted';
      return true;
    }
    return false;
  }

  Future<bool> deleteFriend() async {
    final token = await AuthService.getToken();
    if (token == null || relationId == null || userId == null) return false;

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/relations/$relationId/remove-friend'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      // Supprimer tout le cache lié à cet ami
      await _clearFriendCache();

      relationStatus = 'none';
      relationId = null;
      return true;
    }
    return false;
  }

  /// Supprimer tout le cache lié à cet ami
  Future<void> _clearFriendCache() async {
    if (userId == null || relationId == null) return;

    try {
      // Supprimer le cache des messages de cette relation
      await _messagesCacheService.clearRelationCache(relationId!);

      // Supprimer le cache du profil de cet utilisateur
      await _cacheService.clearUserCache(userId!);

      // Supprimer les images en cache de cet utilisateur
      await _imageCacheService.clearUserImages(userId!);

      if (kDebugMode) {
        print('🗑️ Cache complet supprimé pour l\'ami $userId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur suppression cache ami: $e');
    }
  }
}
