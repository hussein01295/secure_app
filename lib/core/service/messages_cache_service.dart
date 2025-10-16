import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de cache pour les messages et conversations
/// Permet l'accès offline aux conversations et messages
class MessagesCacheService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const Duration _cacheValidityDuration = Duration(days: 7);

  // Clés de cache
  static const String _conversationsKey = 'cached_conversations';
  static const String _conversationsMetaKey = 'cached_conversations_meta';
  static const String _messagesPrefix = 'cached_messages_';
  static const String _messagesMetaPrefix = 'cached_messages_meta_';

  /// Sauvegarder la liste des conversations
  Future<void> saveConversations(List<dynamic> conversations) async {
    try {
      final conversationsJson = jsonEncode(conversations);
      final metadata = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'count': conversations.length,
      };

      // Sauvegarder les conversations dans le stockage sécurisé
      await _secureStorage.write(
        key: _conversationsKey,
        value: conversationsJson,
      );

      // Sauvegarder les métadonnées dans SharedPreferences pour un accès rapide
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_conversationsMetaKey, jsonEncode(metadata));

      if (kDebugMode) {
        print('💾 Conversations sauvegardées en cache: ${conversations.length} conversations');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur sauvegarde conversations: $e');
    }
  }

  /// Récupérer la liste des conversations depuis le cache
  Future<Map<String, dynamic>?> getConversations() async {
    try {
      // Vérifier d'abord les métadonnées
      final prefs = await SharedPreferences.getInstance();
      final metaJson = prefs.getString(_conversationsMetaKey);
      
      if (metaJson == null) return null;

      final metadata = jsonDecode(metaJson);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(metadata['timestamp']);
      
      // Vérifier si le cache est encore valide
      if (DateTime.now().difference(timestamp) > _cacheValidityDuration) {
        if (kDebugMode) print('💾 Cache conversations expiré');
        return null;
      }

      // Récupérer les conversations depuis le stockage sécurisé
      final conversationsJson = await _secureStorage.read(key: _conversationsKey);
      if (conversationsJson == null) return null;

      final conversations = jsonDecode(conversationsJson) as List<dynamic>;

      if (kDebugMode) {
        print('💾 Conversations chargées depuis le cache: ${conversations.length} conversations');
      }

      return {
        'conversations': conversations,
        'count': metadata['count'],
        'timestamp': timestamp,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Erreur lecture conversations cache: $e');
      return null;
    }
  }

  /// Sauvegarder les messages d'une conversation
  Future<void> saveMessages(String relationId, List<Map<String, dynamic>> messages) async {
    try {
      final messagesJson = jsonEncode(messages);
      final metadata = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'count': messages.length,
        'relationId': relationId,
      };

      // Sauvegarder les messages dans le stockage sécurisé
      await _secureStorage.write(
        key: '$_messagesPrefix$relationId',
        value: messagesJson,
      );

      // Sauvegarder les métadonnées dans SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_messagesMetaPrefix$relationId', jsonEncode(metadata));

      if (kDebugMode) {
        print('💾 Messages sauvegardés en cache pour relation $relationId: ${messages.length} messages');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur sauvegarde messages: $e');
    }
  }

  /// Récupérer les messages d'une conversation depuis le cache
  Future<Map<String, dynamic>?> getMessages(String relationId) async {
    try {
      // Vérifier d'abord les métadonnées
      final prefs = await SharedPreferences.getInstance();
      final metaJson = prefs.getString('$_messagesMetaPrefix$relationId');
      
      if (metaJson == null) return null;

      final metadata = jsonDecode(metaJson);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(metadata['timestamp']);
      
      // Vérifier si le cache est encore valide
      if (DateTime.now().difference(timestamp) > _cacheValidityDuration) {
        if (kDebugMode) print('💾 Cache messages expiré pour relation $relationId');
        return null;
      }

      // Récupérer les messages depuis le stockage sécurisé
      final messagesJson = await _secureStorage.read(key: '$_messagesPrefix$relationId');
      if (messagesJson == null) return null;

      final messages = jsonDecode(messagesJson) as List<dynamic>;

      if (kDebugMode) {
        print('💾 Messages chargés depuis le cache pour relation $relationId: ${messages.length} messages');
      }

      return {
        'messages': messages.cast<Map<String, dynamic>>(),
        'count': metadata['count'],
        'timestamp': timestamp,
        'relationId': relationId,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Erreur lecture messages cache: $e');
      return null;
    }
  }

  /// Ajouter un nouveau message au cache d'une conversation
  Future<void> addMessageToCache(String relationId, Map<String, dynamic> message) async {
    try {
      // Récupérer les messages existants
      final cachedData = await getMessages(relationId);
      List<Map<String, dynamic>> messages = [];
      
      if (cachedData != null) {
        messages = cachedData['messages'] ?? [];
      }

      // Ajouter le nouveau message
      messages.add(message);

      // Sauvegarder la liste mise à jour
      await saveMessages(relationId, messages);

      if (kDebugMode) {
        print('💾 Nouveau message ajouté au cache pour relation $relationId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur ajout message cache: $e');
    }
  }

  /// Nettoyer le cache expiré
  Future<void> cleanExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_conversationsMetaKey) || key.startsWith(_messagesMetaPrefix)) {
          final metaJson = prefs.getString(key);
          if (metaJson != null) {
            final metadata = jsonDecode(metaJson);
            final timestamp = DateTime.fromMillisecondsSinceEpoch(metadata['timestamp']);
            
            if (DateTime.now().difference(timestamp) > _cacheValidityDuration) {
              // Supprimer les métadonnées expirées
              await prefs.remove(key);
              
              // Supprimer les données correspondantes du stockage sécurisé
              if (key.startsWith(_messagesMetaPrefix)) {
                final relationId = key.replaceFirst(_messagesMetaPrefix, '');
                await _secureStorage.delete(key: '$_messagesPrefix$relationId');
              } else if (key == _conversationsMetaKey) {
                await _secureStorage.delete(key: _conversationsKey);
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

  /// Vérifier si on a des données en cache pour une relation
  Future<bool> hasMessagesCache(String relationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metaJson = prefs.getString('$_messagesMetaPrefix$relationId');
      
      if (metaJson == null) return false;

      final metadata = jsonDecode(metaJson);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(metadata['timestamp']);
      
      return DateTime.now().difference(timestamp) <= _cacheValidityDuration;
    } catch (e) {
      return false;
    }
  }

  /// Vérifier si on a des conversations en cache
  Future<bool> hasConversationsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metaJson = prefs.getString(_conversationsMetaKey);
      
      if (metaJson == null) return false;

      final metadata = jsonDecode(metaJson);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(metadata['timestamp']);
      
      return DateTime.now().difference(timestamp) <= _cacheValidityDuration;
    } catch (e) {
      return false;
    }
  }

  /// Obtenir des données par défaut en cas d'absence de cache et de connexion
  Map<String, dynamic> getDefaultConversationsData() {
    return {
      'conversations': [],
      'count': 0,
      'fromFallback': true,
      'message': 'Aucune conversation disponible hors ligne',
    };
  }

  Map<String, dynamic> getDefaultMessagesData(String relationId) {
    return {
      'messages': [],
      'count': 0,
      'relationId': relationId,
      'fromFallback': true,
      'message': 'Aucun message disponible hors ligne',
    };
  }

  /// Supprimer tout le cache d'une relation spécifique (messages + conversation)
  Future<void> clearRelationCache(String relationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Supprimer les métadonnées des messages de cette relation
      await prefs.remove('$_messagesMetaPrefix$relationId');

      // Supprimer les messages de cette relation du stockage sécurisé
      await _secureStorage.delete(key: '$_messagesPrefix$relationId');

      // Supprimer aussi le cache des conversations pour forcer un refresh
      await prefs.remove(_conversationsMetaKey);
      await _secureStorage.delete(key: _conversationsKey);

      if (kDebugMode) {
        print('🗑️ Cache des messages supprimé pour la relation $relationId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur suppression cache relation: $e');
    }
  }
}
