import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/service/socket_service.dart';
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/utils/rsa_serrvice.dart';
import 'package:silencia/core/utils/encryption_helper.dart';

import '../chat_service.dart';
import 'chat_vars.dart';
import 'package:silencia/features/chat/search_db/message_index_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 5 — GESTION DES SOCKETS (ChatSocketsMixin)
// ═══════════════════════════════════════════════════════════════════════════════
mixin ChatSocketsMixin<T extends StatefulWidget> on ChatVars<T> {
  // nom public (évite collision privée)
  void initializeSocketConnections() {
    final socket = SocketService().socket;
    socket.emit('joinRelation', relationId);

    typingListener = (isTyping, typingUserId) {
      if (!mounted) return;
      if (typingUserId == contactId) {
        setState(() => isContactTyping = isTyping);
      }
    };
    SocketService().registerTypingObserver(relationId, typingListener);

    _setupSocketHandlers();
  }

  void _setupSocketHandlers() {
    void safeOn(String event, void Function(dynamic) handler) {
      final s = SocketService().socket;
      s.on(event, (data) {
        try {
          handler(data);
        } catch (e, st) {
          debugPrint('[SOCKET:$event] $e\n$st');
        }
      });
    }

    // Statut utilisateur
    safeOn('userOnline', (id) {
      if (id == contactId) {
        if (!mounted) return;
        setState(() => isOnline = true);
      }
    });

    safeOn('userOffline', (id) {
      if (id == contactId) {
        if (!mounted) return;
        setState(() => isOnline = false);
      }
    });

    // Messages
    safeOn('newMessage', onNewMessage);
    safeOn('messageRead', onMessageRead);

    // Langues
    safeOn('langStatusUpdate', onLangStatusUpdate);
    safeOn('langResendRequested', _onLangResendRequested);
    safeOn('langResendDeclined', _onLangResendDeclined);
    safeOn('langPayloadAvailable', _onLangPayloadAvailable);

    // Réactions
    safeOn('reactionAdded', _onReactionAdded);
    safeOn('reactionRemoved', _onReactionRemoved);
  }

  // nom public (évite collision privée)
  void initializeOnlineStatusMonitoring() {
    fetchContactOnlineStatus();
    onlineStatusTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      fetchContactOnlineStatus();
    });
  }

  // ---- Handlers/lang resend
  Future<void> _onLangResendRequested(dynamic payload) async {
    if (payload == null) return;
    if (payload['pairId'] != relationId) return;
    if (payload['targetId'] != userId) return;

    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("${data.contactName} demande la langue"),
        content: const Text("Voulez-vous renvoyer votre langue codée ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'decline'),
            child: const Text('Refuser'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'accept'),
            child: const Text('Renvoyer'),
          ),
        ],
      ),
    );

    if (action == 'accept') {
      try {
        debugPrint(
          '🔍 _onLangResendRequested: Recherche package avec clé: $langMapKey',
        );

        final package = await ChatService.getLanguagePackage(langMapKey);
        Map<String, dynamic>? packageToSend;
        Map<String, String>? legacyLangMap;

        if (package != null &&
            package.containsKey('languages') &&
            package['version'] == '2.0') {
          packageToSend = Map<String, dynamic>.from(package);
        } else if (package != null && package.containsKey('langMap')) {
          packageToSend = Map<String, dynamic>.from(package);
          legacyLangMap = Map<String, String>.from(package['langMap']);
          debugPrint('✅ Package v1.0: ${legacyLangMap.length} entrées');
        } else {
          legacyLangMap = await ChatService.getLangMap(langMapKey);
          if (legacyLangMap != null) {
            packageToSend = {'langMap': legacyLangMap};
            final localMediaKey = await ChatService.getMediaKey(relationId);
            if (localMediaKey != null) {
              packageToSend['mediaKey'] = localMediaKey;
              packageToSend['timestamp'] = DateTime.now().toIso8601String();
              packageToSend['version'] = '1.0';
            }
          }
        }

        if (packageToSend == null) {
          throw Exception(
            "Langue locale introuvable - Aucun format disponible",
          );
        }
        final token = await AuthService.getToken();
        final requesterId = payload['requesterId'] as String;
        final publicKeyA = await RSAKeyService.fetchPublicKey(
          requesterId,
          token!,
        );
        if (publicKeyA == null)
          throw Exception("Clé publique du demandeur introuvable");

        final packageJson = jsonEncode(packageToSend);
        final hybrid = RSAKeyService.hybridEncrypt(packageJson, publicKeyA);

        if (!mounted) return;
        final headers = await AuthService.getAuthorizedHeaders(
          context: context,
        );
        final url = Uri.parse('${ApiConfig.baseUrl}/lang/$relationId/send');
        await http.post(
          url,
          headers: headers,
          body: jsonEncode({
            'encrypted': hybrid['encrypted'],
            'iv': hybrid['iv'],
            'encryptedKey': hybrid['encryptedKey'],
            'from': userId,
            'to': requesterId,
          }),
        );

        await markLangGenerate();

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Langue renvoyée.')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } else if (action == 'decline') {
      if (!mounted) return;
      final headers = await AuthService.getAuthorizedHeaders(context: context);
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/lang/$relationId/decline-resend'),
        headers: headers,
      );
    }
  }

  Future<void> _onLangResendDeclined(dynamic payload) async {
    if (payload == null) return;
    if (payload['pairId'] != relationId) return;
    if (payload['targetId'] != userId) return;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Demande refusée — génération d\'une nouvelle langue'),
      ),
    );
    await generateAndSendLangMap();
    await markLangGenerate();
  }

  Future<void> _onLangPayloadAvailable(dynamic payload) async {
    if (payload == null) return;
    if (payload['pairId'] != relationId) return;
    if (payload['to'] != userId) return;

    final ok = await fetchAndStoreLangMapFromBackend();
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Langue récupérée. Canal sécurisé.')),
      );
    }
  }

  void _onReactionAdded(dynamic payload) {
    if (payload == null) return;
    if (payload['relationId'] != relationId) return;
    if (mounted) {
      setState(() {});
    }
  }

  void _onReactionRemoved(dynamic payload) {
    if (payload == null) return;
    if (payload['relationId'] != relationId) return;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> fetchContactOnlineStatus() async {
    try {
      final headers = await AuthService.getAuthorizedHeaders(context: context);
      final url = Uri.parse("${ApiConfig.baseUrl}/users/$contactId/status");
      final res = await http.get(url, headers: headers);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (!mounted) return;
        setState(() {
          isOnline = json['online'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Erreur fetchContactOnlineStatus: $e");
    }
  }

  // Contrats d'autres mixins
  void onMessageRead(dynamic data);
  @override
  void scrollToBottom();
  Future<void> markLangGenerate({bool forceNew = false});
  Future<void> generateAndSendLangMap();
  Future<bool> fetchAndStoreLangMapFromBackend();
  Future<void> loadLanguageMap();

  @override
  void onNewMessage(dynamic data) {
    if (data == null || data['relationId'] != relationId) return;

    if (data['messageType'] == 'image' ||
        data['messageType'] == 'video' ||
        data['messageType'] == 'voice') {
      final senderStr = data['sender'].toString();
      final userIdStr = userId.toString();
      final isFromMe = senderStr == userIdStr;

      final label = '[${data['messageType']}]';
      final newMessage = {
        'id': data['_id'],
        'fromMe': isFromMe,
        'messageType': data['messageType'],
        'content': data['content'],
        'metadata': data['metadata'],
        'sender': data['sender'],
        'encrypted': data['encrypted'] ?? false,
        'decoded': label,
        'coded': label,
        'time':
            (data['timestamp'] != null &&
                data['timestamp'].toString().length > 11)
            ? data['timestamp'].toString().substring(11, 16)
            : TimeOfDay.now().format(context),
        'timestamp': data['timestamp'],
        'isRead': data['isRead'] ?? false,
      };

      setState(() {
        if (isFromMe) {
          messages.removeWhere(
            (m) =>
                m['sending'] == true &&
                m['messageType'] == data['messageType'] &&
                m['fromMe'] == true,
          );
        }
        messages.add(newMessage);
      });
      handleMessagesUpdated();
      unawaited(
        MessageIndexHelper.indexMessages(
          relationId: relationId,
          messages: [newMessage],
          isMultiLanguageMode: isMultiLanguageMode,
          langMap: langMap,
          multiLanguages: multiLanguages,
          mediaKey: mediaKeyInternal,
        ),
      );
      return;
    }

    Map<String, dynamic>? indexedMessage;

    setState(() {
      isContactTyping = false;
      final encryptedAAD = data['encryptedAAD'] as String?;

      if (data['sender'] == userId) {
        final idx = messages.lastIndexWhere(
          (m) =>
              m['fromMe'] == true &&
              m['sending'] == true &&
              m['messageType'] == 'text',
        );

        String decodedText;
        try {
          decodedText = EncryptionHelper.decryptText(
            data['content'],
            mediaKeyInternal!,
          );
        } catch (_) {
          decodedText = data['content'];
        }

        final newMessage = {
          'id': data['_id'],
          'text': decodedText,
          'decoded': decodedText,
          'coded': data['coded'] ?? decodedText,
          'fromMe': true,
          'time':
              (data['timestamp'] != null &&
                  data['timestamp'].toString().length > 11)
              ? data['timestamp'].toString().substring(11, 16)
              : TimeOfDay.now().format(context),
          'isRead': data['isRead'] ?? false,
          'messageType': 'text',
          'content': data['content'],
          'encryptedAAD': encryptedAAD,
          'timestamp': data['timestamp'],
          'encrypted': data['encrypted'] ?? true,
        };
        indexedMessage = newMessage;

        if (idx != -1) {
          messages[idx] = newMessage;
        } else {
          final existingIdx = messages.indexWhere(
            (m) => m['id'] == data['_id'],
          );
          if (existingIdx == -1) {
            messages.add(newMessage);
          } else {
            messages[existingIdx] = newMessage;
          }
        }
      } else {
        String decodedText;
        try {
          decodedText = EncryptionHelper.decryptText(
            data['content'],
            mediaKeyInternal!,
          );
        } catch (_) {
          decodedText = data['content'];
        }

        final newMessage = {
          'id': data['_id'],
          'text': decodedText,
          'decoded': decodedText,
          'coded': data['coded'] ?? decodedText,
          'fromMe': false,
          'time':
              (data['timestamp'] != null &&
                  data['timestamp'].toString().length > 11)
              ? data['timestamp'].toString().substring(11, 16)
              : TimeOfDay.now().format(context),
          'isRead': data['isRead'] ?? false,
          'messageType': 'text',
          'content': data['content'],
          'encryptedAAD': encryptedAAD,
          'timestamp': data['timestamp'],
          'encrypted': data['encrypted'] ?? true,
        };

        messages.add(newMessage);
        cacheService.addMessageToCache(relationId, newMessage);
        indexedMessage = newMessage;
      }
    });
    handleMessagesUpdated();

    if (indexedMessage != null) {
      unawaited(
        MessageIndexHelper.indexMessages(
          relationId: relationId,
          messages: [indexedMessage!],
          isMultiLanguageMode: isMultiLanguageMode,
          langMap: langMap,
          multiLanguages: multiLanguages,
          mediaKey: mediaKeyInternal,
        ),
      );
    }

    scrollToBottom();
  }

  @override
  void onLangStatusUpdate(dynamic payload) {
    if (payload == null) return;
    if (payload['pairId'] == relationId) {
      refreshLangStatus();
      loadLanguageMap();
      if (mounted) setState(() {});
    }
  }
}
