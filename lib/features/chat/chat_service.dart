import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/encryption_helper.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/service/notification_service.dart';

class ChatService {
  static const _secure = FlutterSecureStorage();

  // Sauvegarde la langue localement (clé/value)
  static Future<void> saveLangMap(
    String key,
    Map<String, String> langMap,
  ) async {
    await _secure.write(key: key, value: jsonEncode(langMap));
  }

  // Sauvegarde le package complet (langue + clé média)
  static Future<void> saveLanguagePackage(
    String key,
    Map<String, dynamic> package,
  ) async {
    await _secure.write(key: key, value: jsonEncode(package));
  }

  static Future<Map<String, String>?> getLangMap(String key) async {
    final str = await _secure.read(key: key);
    if (str == null) return null;
    try {
      return Map<String, String>.from(jsonDecode(str));
    } catch (_) {
      return null;
    }
  }

  static Future<void> removeLangMap(String key) async {
    await _secure.delete(key: key);
  }

  // Récupère le package complet (langue + clé média)
  static Future<Map<String, dynamic>?> getLanguagePackage(String key) async {
    final str = await _secure.read(key: key);
    if (str == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(str));
    } catch (_) {
      return null;
    }
  }

  // Sauvegarde seulement la clé média
  static Future<void> saveMediaKey(String relationId, String mediaKey) async {
    await _secure.write(key: 'mediaKey-$relationId', value: mediaKey);
  }

  // Récupère seulement la clé média
  static Future<String?> getMediaKey(String relationId) async {
    return await _secure.read(key: 'mediaKey-$relationId');
  }

  // Supprime la clé média
  static Future<void> removeMediaKey(String relationId) async {
    await _secure.delete(key: 'mediaKey-$relationId');
  }

  // ✅ SUPPRIMÉ: fetchSharedKey - on utilise maintenant mediaKey pour tout

  // 🔥 NOUVELLE MÉTHODE: Récupère les messages avec pagination (cursor-based)
  static Future<Map<String, dynamic>> fetchMessagesListPaginated({
    required dynamic controller,
    int limit = 30,
    String? before, // Cursor (timestamp ISO)
  }) async {
    // Construire l'URL avec les paramètres de pagination
    final queryParams = {
      'limit': limit.toString(),
      if (before != null) 'before': before,
    };

    final url = Uri.parse(
      "${ApiConfig.baseUrl}/messages/${controller.widget.contactId}/paginated",
    ).replace(queryParameters: queryParams);

    final headers = await AuthService.getAuthorizedHeaders(
      context: controller.context,
    );
    if (headers == null) {
      return {
        'messages': <Map<String, dynamic>>[],
        'pagination': {
          'hasMore': false,
          'nextCursor': null,
          'limit': limit,
          'count': 0,
        },
      };
    }

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['success'] == true && controller.mediaKey != null) {
        final List rawMessages = data['messages'] ?? [];
        final pagination = data['pagination'] ?? {};

        // Décrypter les messages
        final decryptedMessages = rawMessages.map<Map<String, dynamic>>((msg) {
          final type = msg['messageType'] ?? 'text';
          String text = '';
          String? content = msg['content'];

          // Décryptage seulement pour les messages texte
          if (type == 'text') {
            try {
              text = EncryptionHelper.decryptText(
                content ?? '',
                controller.mediaKey!,
              );
            } catch (e) {
              text = '[Erreur de décryptage]';
            }
          } else {
            // Pour les autres types (voice, image, etc.), pas de décryptage
            text = content ?? '';
          }

          return {
            'id': msg['_id'],
            'text': text,
            'decoded': text,
            'coded': msg['text'] ?? text,
            'content': content,
            'fromMe': msg['sender'] == controller.widget.userId,
            'time': msg['timestamp'].toString().substring(11, 16),
            'timestamp':
                msg['timestamp'], // ✅ IMPORTANT: Garder le timestamp complet
            'isRead': msg['isRead'] ?? false,
            'messageType': type,
            'metadata': msg['metadata'],
            'sender': msg['sender'],
            'encrypted': msg['encrypted'] ?? false,
            'reactions': msg['reactions'] ?? [],
            'replyTo': msg['replyTo'],
            'ephemeral': msg['ephemeral'],
            'encryptedAAD':
                msg['encryptedAAD'], // ✅ CORRECTION: Inclure l'AAD chiffré pour les messages multi-langues
          };
        }).toList();

        return {'messages': decryptedMessages, 'pagination': pagination};
      }
    }

    // En cas d'erreur, retourner une structure vide
    return {
      'messages': <Map<String, dynamic>>[],
      'pagination': {
        'hasMore': false,
        'nextCursor': null,
        'limit': limit,
        'count': 0,
      },
    };
  }

  // ⚠️ ANCIENNE MÉTHODE (Conservée pour compatibilité, mais déconseillée)
  // Récupère les messages (déchiffrement local avec mediaKey)
  static Future<List<Map<String, dynamic>>> fetchMessagesList(
    dynamic controller,
  ) async {
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/messages/${controller.widget.contactId}",
    );
    final headers = await AuthService.getAuthorizedHeaders(
      context: controller.context,
    );
    if (headers == null) return [];
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200 && controller.mediaKey != null) {
      final List data = jsonDecode(response.body);
      return data.map<Map<String, dynamic>>((msg) {
        final type = msg['messageType'] ?? 'text';
        String text = '';
        String? content = msg['content'];

        // Décryptage seulement pour les messages texte
        if (type == 'text') {
          try {
            text = EncryptionHelper.decryptText(
              content ?? '',
              controller.mediaKey!,
            );
          } catch (e) {
            text = '[Erreur de décryptage]';
          }
        } else {
          // Pour les autres types (voice, image, etc.), pas de décryptage
          text = content ?? '';
        }

        return {
          'id': msg['_id'],
          'text': text,
          'decoded': text,
          'coded': msg['text'] ?? text,
          'content': content,
          'fromMe': msg['sender'] == controller.widget.userId,
          'time': msg['timestamp'].toString().substring(11, 16),
          'isRead': msg['isRead'] ?? false,
          'messageType': type,
          'metadata': msg['metadata'],
          'sender': msg['sender'],
          'encrypted': msg['encrypted'] ?? false, // Ajouter le champ encrypted
          'encryptedAAD':
              msg['encryptedAAD'], // ✅ NOUVEAU: Récupérer l'AAD depuis la BDD
        };
      }).toList();
    }
    return [];
  }

  static Future<void> refreshLangStatus(dynamic controller) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/relations");
    final headers = await AuthService.getAuthorizedHeaders(
      context: controller.context,
    );
    if (headers == null) return;
    final res = await http.get(url, headers: headers);
    if (res.statusCode == 200) {
      final List relations = jsonDecode(res.body);
      final relation = relations.firstWhere(
        (r) => r['_id'] == controller.widget.relationId,
        orElse: () => null,
      );
      if (relation != null) {
        final isUser1 = relation['user1']['_id'] == controller.widget.userId;
        final meStatus = isUser1
            ? relation['langStatus']['user1']
            : relation['langStatus']['user2'];
        final otherStatus = isUser1
            ? relation['langStatus']['user2']
            : relation['langStatus']['user1'];
        if (!controller.mounted) return;
        controller.setState(() {
          controller.myLangStatus = meStatus;
          controller.otherLangStatus = otherStatus;
        });
      }
    }
  }

  static Future<void> postLangLost(dynamic controller) async {
    final headers = await AuthService.getAuthorizedHeaders(
      context: controller.context,
    );
    if (headers == null) return;
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/lang/${controller.widget.relationId}/lost",
    );
    await http.post(url, headers: headers);
    await controller.refreshLangStatus();
  }

  static Future<void> loadLanguageMap(dynamic controller) async {
    debugPrint(
      '🔍 loadLanguageMap: Début chargement pour ${controller.langMapKey}',
    );

    // Essayer d'abord le nouveau format (package complet)
    final package = await getLanguagePackage(controller.langMapKey);
    Map<String, String>? lang;
    Map<String, Map<String, String>>? multiLanguages;
    bool isMultiLanguageMode = false;

    if (package != null) {
      // ✅ NOUVEAU: Vérifier format multi-langues (version 2.0)
      if (package.containsKey('languages') &&
          package.containsKey('version') &&
          package['version'] == '2.0') {
        debugPrint('🌐 loadLanguageMap: Package multi-langues trouvé (v2.0)');

        final languagesData = package['languages'];
        if (languagesData is Map) {
          multiLanguages = <String, Map<String, String>>{};
          languagesData.forEach((key, value) {
            if (value is Map) {
              multiLanguages![key] = Map<String, String>.from(value);
            }
          });
          isMultiLanguageMode = true;
          debugPrint(
            '🎯 loadLanguageMap: ${multiLanguages.length} langues chargées',
          );
          debugPrint(
            '🔍 DEBUG: Langues disponibles: ${multiLanguages.keys.toList()}',
          );

          // Afficher un échantillon de chaque langue pour vérifier
          multiLanguages.forEach((key, value) {
            final sample = value.entries
                .take(3)
                .map((e) => '${e.key}→${e.value}')
                .join(', ');
            debugPrint('🔍 DEBUG: $key échantillon: $sample');
          });

          // ✅ RÉTROCOMPATIBILITÉ: Garder la première langue pour les anciens messages (sans AAD)
          // Les nouveaux messages utiliseront leur AAD spécifique
          if (multiLanguages.isNotEmpty) {
            lang = multiLanguages.values.first;
            debugPrint(
              '🔄 loadLanguageMap: Première langue gardée pour anciens messages (sans AAD)',
            );
          }
        }
      }
      // ✅ RÉTROCOMPATIBILITÉ: Format ancien avec langMap unique
      else if (package.containsKey('langMap')) {
        debugPrint('📦 loadLanguageMap: Package ancien format trouvé (v1.0)');
        lang = Map<String, String>.from(package['langMap']);
      }

      // Sauvegarder la clé média si disponible
      if (package.containsKey('mediaKey') && package['mediaKey'] != null) {
        await saveMediaKey(controller.widget.relationId, package['mediaKey']);
        debugPrint('🔑 loadLanguageMap: Clé média sauvegardée');
      }
    } else {
      // Fallback vers l'ancien format direct
      debugPrint('🔄 loadLanguageMap: Fallback vers ancien format direct');
      lang = await getLangMap(controller.langMapKey);
    }

    debugPrint(
      '🗺️ loadLanguageMap: Mode multi-langues: ${isMultiLanguageMode ? "✅" : "❌"}',
    );
    debugPrint(
      '🗺️ loadLanguageMap: Langue unique chargée: ${lang != null ? "✅" : "❌"}',
    );

    if (!controller.mounted) return;
    controller.setState(() {
      controller.langMap = lang;
      controller.multiLanguages = multiLanguages;
      controller.isMultiLanguageMode = isMultiLanguageMode;
    });
  }

  static Future<void> removeLanguageMap(dynamic controller) async {
    await removeLangMap(controller.langMapKey);
    if (!controller.mounted) return;
    controller.setState(() => controller.langMap = null);
    await controller.postLangLost();
  }

  static Future<void> markLangGenerate(
    String relationId,
    BuildContext ctx,
  ) async {
    final headers = await AuthService.getAuthorizedHeaders(context: ctx);
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/lang/$relationId/mark-generate',
    );
    await http.post(url, headers: headers);
  }

  static Future<void> markLangSuccess(
    String relationId,
    BuildContext ctx,
  ) async {
    final headers = await AuthService.getAuthorizedHeaders(context: ctx);
    final url = Uri.parse('${ApiConfig.baseUrl}/lang/$relationId/mark-success');
    await http.post(url, headers: headers);
  }

  static Future<bool> requestLangResend(dynamic controller) async {
    final headers = await AuthService.getAuthorizedHeaders(
      context: controller.context,
    );
    if (headers == null) return false;

    // Envoyer la demande au serveur (socket)
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/lang/${controller.widget.relationId}/request-resend',
    );
    final res = await http.post(url, headers: headers);

    // Si la demande est envoyée avec succès, envoyer aussi une notification push
    if (res.statusCode == 200) {
      // Envoyer une notification push à l'utilisateur B
      await NotificationService.sendLanguageRequestNotification(
        targetUserId: controller.widget.contactId,
        relationId: controller.widget.relationId,
        contactId: controller.widget.userId,
        contactName: 'Vous', // Ou récupérer le vrai nom de l'utilisateur actuel
        requesterId: controller.widget.userId,
      );
    }

    return res.statusCode == 200;
  }
}
