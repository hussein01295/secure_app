import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service de cache pour les groupes et messages de groupe
/// Permet un accès hors ligne aux données des groupes
class GroupsCacheService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _groupsKey = 'cached_groups';
  static const String _groupsMetaKey = 'cached_groups_meta';
  static const String _groupMessagesPrefix = 'cached_group_messages_';
  static const String _groupMessagesMetaPrefix = 'cached_group_messages_meta_';
  static const Duration _cacheValidityDuration = Duration(days: 7);

  /// Sauvegarder la liste des groupes
  Future<void> saveGroups(List<Map<String, dynamic>> groups) async {
    try {
      final groupsJson = jsonEncode(groups);
      final metadata = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'count': groups.length,
        'version': '1.0',
      };

      await _secureStorage.write(key: _groupsKey, value: groupsJson);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_groupsMetaKey, jsonEncode(metadata));

      if (kDebugMode) {
        print('💾 Groupes sauvegardés en cache: ${groups.length} groupes');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur sauvegarde groupes: $e');
    }
  }

  /// Récupérer la liste des groupes depuis le cache
  Future<Map<String, dynamic>?> getGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metaJson = prefs.getString(_groupsMetaKey);
      
      if (metaJson == null) {
        if (kDebugMode) print('📭 Aucune métadonnée de cache groupes trouvée');
        return null;
      }

      final metadata = jsonDecode(metaJson) as Map<String, dynamic>;
      final timestamp = metadata['timestamp'] as int;
      final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      
      // Vérifier si le cache est encore valide
      if (DateTime.now().difference(cacheDate) > _cacheValidityDuration) {
        if (kDebugMode) print('⏰ Cache groupes expiré');
        return null;
      }

      final groupsJson = await _secureStorage.read(key: _groupsKey);
      if (groupsJson == null) {
        if (kDebugMode) print('📭 Aucune donnée de cache groupes trouvée');
        return null;
      }

      final groups = jsonDecode(groupsJson) as List<dynamic>;
      
      if (kDebugMode) {
        print('💾 Groupes chargés depuis le cache: ${groups.length} groupes');
      }

      return {
        'groups': groups,
        'metadata': metadata,
        'fromCache': true,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Erreur lecture cache groupes: $e');
      return null;
    }
  }

  /// Sauvegarder les messages d'un groupe
  Future<void> saveGroupMessages(String groupId, List<Map<String, dynamic>> messages) async {
    try {
      final messagesJson = jsonEncode(messages);
      final metadata = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'count': messages.length,
        'groupId': groupId,
        'version': '1.0',
      };

      await _secureStorage.write(
        key: '$_groupMessagesPrefix$groupId', 
        value: messagesJson
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_groupMessagesMetaPrefix$groupId', 
        jsonEncode(metadata)
      );

      if (kDebugMode) {
        print('💾 Messages du groupe $groupId sauvegardés: ${messages.length} messages');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur sauvegarde messages groupe $groupId: $e');
    }
  }

  /// Récupérer les messages d'un groupe depuis le cache
  Future<Map<String, dynamic>?> getGroupMessages(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metaJson = prefs.getString('$_groupMessagesMetaPrefix$groupId');
      
      if (metaJson == null) {
        if (kDebugMode) print('📭 Aucune métadonnée de cache messages pour groupe $groupId');
        return null;
      }

      final metadata = jsonDecode(metaJson) as Map<String, dynamic>;
      final timestamp = metadata['timestamp'] as int;
      final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      
      // Vérifier si le cache est encore valide
      if (DateTime.now().difference(cacheDate) > _cacheValidityDuration) {
        if (kDebugMode) print('⏰ Cache messages groupe $groupId expiré');
        return null;
      }

      final messagesJson = await _secureStorage.read(key: '$_groupMessagesPrefix$groupId');
      if (messagesJson == null) {
        if (kDebugMode) print('📭 Aucune donnée de cache messages pour groupe $groupId');
        return null;
      }

      final messages = jsonDecode(messagesJson) as List<dynamic>;
      
      if (kDebugMode) {
        print('💾 Messages du groupe $groupId chargés depuis le cache: ${messages.length} messages');
      }

      return {
        'messages': messages,
        'metadata': metadata,
        'fromCache': true,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Erreur lecture cache messages groupe $groupId: $e');
      return null;
    }
  }

  /// Ajouter un nouveau message au cache d'un groupe
  Future<void> addMessageToGroupCache(String groupId, Map<String, dynamic> message) async {
    try {
      final cachedData = await getGroupMessages(groupId);
      List<Map<String, dynamic>> messages = [];
      
      if (cachedData != null) {
        messages = List<Map<String, dynamic>>.from(cachedData['messages'] ?? []);
      }
      
      messages.add(message);
      await saveGroupMessages(groupId, messages);
      
      if (kDebugMode) {
        print('💾 Nouveau message ajouté au cache du groupe $groupId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur ajout message cache groupe $groupId: $e');
    }
  }

  /// Données par défaut pour les groupes en cas d'absence de cache
  Map<String, dynamic> getDefaultGroupsData() {
    return {
      'groups': <Map<String, dynamic>>[],
      'metadata': {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'count': 0,
        'version': '1.0',
        'fromFallback': true,
      },
      'fromFallback': true,
    };
  }

  /// Données par défaut pour les messages d'un groupe en cas d'absence de cache
  Map<String, dynamic> getDefaultGroupMessagesData(String groupId) {
    return {
      'messages': <Map<String, dynamic>>[],
      'metadata': {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'count': 0,
        'groupId': groupId,
        'version': '1.0',
        'fromFallback': true,
      },
      'fromFallback': true,
    };
  }

  /// Nettoyer le cache expiré
  Future<void> cleanExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_groupsMetaKey) || key.startsWith(_groupMessagesMetaPrefix)) {
          final metaJson = prefs.getString(key);
          if (metaJson != null) {
            final metadata = jsonDecode(metaJson) as Map<String, dynamic>;
            final timestamp = metadata['timestamp'] as int;
            final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
            
            if (DateTime.now().difference(cacheDate) > _cacheValidityDuration) {
              await prefs.remove(key);
              
              // Supprimer aussi les données correspondantes
              if (key == _groupsMetaKey) {
                await _secureStorage.delete(key: _groupsKey);
              } else if (key.startsWith(_groupMessagesMetaPrefix)) {
                final groupId = key.replaceFirst(_groupMessagesMetaPrefix, '');
                await _secureStorage.delete(key: '$_groupMessagesPrefix$groupId');
              }
              
              if (kDebugMode) print('🧹 Cache expiré supprimé: $key');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur nettoyage cache: $e');
    }
  }

  /// Vider tout le cache des groupes
  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_groupsMetaKey) || key.startsWith(_groupMessagesMetaPrefix)) {
          await prefs.remove(key);
        }
      }
      
      await _secureStorage.delete(key: _groupsKey);
      
      // Supprimer tous les messages de groupes
      final secureKeys = await _secureStorage.readAll();
      for (final key in secureKeys.keys) {
        if (key.startsWith(_groupMessagesPrefix)) {
          await _secureStorage.delete(key: key);
        }
      }
      
      if (kDebugMode) print('🧹 Tout le cache des groupes a été vidé');
    } catch (e) {
      if (kDebugMode) print('❌ Erreur vidage cache: $e');
    }
  }
}
