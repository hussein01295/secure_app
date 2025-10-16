import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/service/socket_service.dart';
import 'package:silencia/core/utils/encryption_helper.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';
import 'package:silencia/features/chat/chat_service.dart';
import 'package:silencia/features/chat/chat_utils.dart';
import 'package:silencia/features/chat/controller/chat_vars.dart';
import 'package:silencia/features/chat/search_db/message_index_helper.dart';

import 'package:http/http.dart' as http;

mixin ChatMessagesMixin<T extends StatefulWidget> on ChatVars<T> {
  Future<void> fetchMessages() async {
    try {
      final cachedData = await cacheService.getMessages(relationId);
      if (cachedData != null) {
        if (!mounted) return;
        setState(() {
          messages
            ..clear()
            ..addAll(cachedData['messages'] ?? []);
          isOfflineModeInternal = false;
        });
        handleMessagesUpdated();
        scrollToBottom();
        if (!cachedData.containsKey('fromFallback')) {
          _syncMessagesInBackground();
          return;
        }
      }
      await _fetchMessagesFromServer();
    } catch (e) {
      final defaultData = cacheService.getDefaultMessagesData(relationId);
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(defaultData['messages'] ?? []);
        isOfflineModeInternal = true;
      });
      handleMessagesUpdated();
      scrollToBottom();
    }
  }

  Future<void> _fetchMessagesFromServer() async {
    try {
      final result = await ChatService.fetchMessagesListPaginated(
        controller: this,
        limit: messagesPerPage,
      );

      if (!mounted) return;

      final backendMessages = result['messages'] as List<Map<String, dynamic>>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      final mergedMessages = _mergeMessagesIntelligently(
        messages,
        backendMessages,
      );

      setState(() {
        messages
          ..clear()
          ..addAll(mergedMessages);
        isOfflineModeInternal = false;
        hasMoreMessages = pagination['hasMore'] ?? false;
        nextCursor = pagination['nextCursor'];
      });
      handleMessagesUpdated();

      unawaited(
        MessageIndexHelper.indexMessages(
          relationId: relationId,
          messages: backendMessages,
          isMultiLanguageMode: isMultiLanguageMode,
          langMap: langMap,
          multiLanguages: multiLanguages,
          mediaKey: mediaKeyInternal,
        ),
      );

      await cacheService.saveMessages(relationId, backendMessages);
      scrollToBottom();
    } catch (e) {
      final cachedData = await cacheService.getMessages(relationId);
      if (cachedData != null) {
        if (!mounted) return;
        setState(() {
          messages
            ..clear()
            ..addAll(cachedData['messages'] ?? []);
          isOfflineModeInternal = true;
        });
        handleMessagesUpdated();
      } else {
        final defaultData = cacheService.getDefaultMessagesData(relationId);
        if (!mounted) return;
        setState(() {
          messages
            ..clear()
            ..addAll(defaultData['messages'] ?? []);
          isOfflineModeInternal = true;
        });
        handleMessagesUpdated();
      }
      scrollToBottom();
    }
  }

  Future<void> loadMoreMessages() async {
    if (isLoadingMore || !hasMoreMessages || nextCursor == null) return;

    setState(() {
      isLoadingMore = true;
    });

    try {
      final result = await ChatService.fetchMessagesListPaginated(
        controller: this,
        limit: messagesPerPage,
        before: nextCursor,
      );

      if (!mounted) return;

      final newMessages = result['messages'] as List<Map<String, dynamic>>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      setState(() {
        messages.insertAll(0, newMessages);
        hasMoreMessages = pagination['hasMore'] ?? false;
        nextCursor = pagination['nextCursor'];
        isLoadingMore = false;
      });
      handleMessagesUpdated();

      unawaited(
        MessageIndexHelper.indexMessages(
          relationId: relationId,
          messages: newMessages,
          isMultiLanguageMode: isMultiLanguageMode,
          langMap: langMap,
          multiLanguages: multiLanguages,
          mediaKey: mediaKeyInternal,
        ),
      );

      await cacheService.saveMessages(relationId, messages);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  List<Map<String, dynamic>> _mergeMessagesIntelligently(
    List<Map<String, dynamic>> currentMessages,
    List<Map<String, dynamic>> backendMessages,
  ) {
    final localRecentMessages = currentMessages.where((localMsg) {
      if (localMsg['sending'] == true) {
        return true;
      }
      final messageId = localMsg['id'];
      if (messageId == null) return true;
      final existsInBackend = backendMessages.any(
        (backendMsg) =>
            backendMsg['_id'] == messageId || backendMsg['id'] == messageId,
      );
      return !existsInBackend;
    }).toList();

    final mergedMessages = <Map<String, dynamic>>[];
    mergedMessages.addAll(backendMessages);

    for (final localMsg in localRecentMessages) {
      final isDuplicate = mergedMessages.any(
        (msg) =>
            (msg['_id'] == localMsg['id'] || msg['id'] == localMsg['id']) ||
            (msg['content'] == localMsg['content'] &&
                msg['fromMe'] == localMsg['fromMe'] &&
                msg['messageType'] == localMsg['messageType']),
      );
      if (!isDuplicate) {
        mergedMessages.add(localMsg);
      }
    }

    mergedMessages.sort((a, b) {
      final aTime = a['timestamp'] ?? a['time'] ?? '';
      final bTime = b['timestamp'] ?? b['time'] ?? '';
      return aTime.toString().compareTo(bTime.toString());
    });

    return mergedMessages;
  }

  Future<void> _syncMessagesInBackground() async {
    try {
      final result = await ChatService.fetchMessagesListPaginated(
        controller: this,
        limit: messagesPerPage,
      );

      final backendMessages = result['messages'] as List<Map<String, dynamic>>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      await cacheService.saveMessages(relationId, backendMessages);

      if (!mounted) return;

      final mergedMessages = _mergeMessagesIntelligently(
        messages,
        backendMessages,
      );

      setState(() {
        messages
          ..clear()
          ..addAll(mergedMessages);
        isOfflineModeInternal = false;
        hasMoreMessages = pagination['hasMore'] ?? false;
        nextCursor = pagination['nextCursor'];
      });
      // Update search index after background sync
      handleMessagesUpdated();
    } catch (_) {}
  }

  Future<void> sendMessage() async {
    debugPrint('🚀 sendMessage: DÉBUT - Vérification des langues');

    bool hasLanguages = false;
    if (isMultiLanguageMode && multiLanguages != null) {
      hasLanguages = true;
    } else if (!isMultiLanguageMode && langMap != null) {
      hasLanguages = true;
    }

    if (!hasLanguages) {
      await ensureLanguageFlow(context);
      return;
    }

    await _sendMessageSmooth();
  }

  Future<void> markMessageAsRead(String messageId) async {
    final headers = await AuthService.getAuthorizedHeaders(context: context);
    if (headers == null) return;
    final url = Uri.parse("${ApiConfig.baseUrl}/messages/$messageId/read");
    await http.patch(url, headers: headers);
  }

  Future<void> _sendMessageSmooth() async {
    if (controller.text.trim().isEmpty || mediaKeyInternal == null) return;
    if (!isMultiLanguageMode && langMap == null) return;
    if (isMultiLanguageMode && multiLanguages == null) return;

    final content = controller.text.trim();
    String coded;
    String? encryptedAAD;

    if (isMultiLanguageMode && multiLanguages != null) {
      if (mediaKeyInternal == null) {
        mediaKeyInternal = LangMapGenerator.generateMediaKey();
        await ChatService.saveMediaKey(relationId, mediaKeyInternal!);
      }

      // 🆕 NOUVEAU: Utilisation de la méthode unifiée qui choisit automatiquement le mode
      debugPrint('🚀 SEND: Préparation message multi-langues pour: "$content"');
      debugPrint('🚀 SEND: Langues disponibles: ${multiLanguages!.length}');

      final result = MultiLanguageManager.prepareMessage(
        content,
        multiLanguages!,
        mediaKeyInternal!,
        forcePerCharacterMode: true, // Activer le nouveau mode per-character
      );
      coded = result['codedText'];
      encryptedAAD = result['encryptedAAD'];

      // Debug: afficher des infos sur le mode utilisé
      if (result.containsKey('sequence')) {
        debugPrint('✅ SEND: Mode per-character utilisé (v2.2)');
        debugPrint(
          '🎯 SEND: Séquence: ${(result['sequence'] as List<String>).take(10).join(', ')}${(result['sequence'] as List<String>).length > 10 ? '...' : ''}',
        );
      } else {
        debugPrint('⚠️ SEND: Mode single-language utilisé (v2.0)');
        debugPrint('🌐 SEND: Langue: ${result['selectedAAD']}');
      }
    } else {
      // Mode legacy (v1.0) - une seule langue pour tout
      debugPrint('🔄 SEND: Mode legacy (v1.0) - langue unique');
      coded = ChatUtils.applyLanguageMap(content.toLowerCase(), langMap!);
    }

    final encrypted = EncryptionHelper.encryptText(coded, mediaKeyInternal!);
    final tempId = UniqueKey().toString();

    final now = DateTime.now();
    final localMessage = {
      'id': tempId,
      'text': coded,
      'coded': coded,
      'decoded': content,
      'fromMe': true,
      'time': TimeOfDay.now().format(context),
      'timestamp': now.toIso8601String(),
      'isRead': false,
      'sending': true,
      'messageType': 'text',
      'content': coded,
      'encryptedAAD': encryptedAAD,
    };

    setState(() {
      messages.add(localMessage);
      controller.clear();
    });
    handleMessagesUpdated();
    scrollToBottom();
    unawaited(
      MessageIndexHelper.indexMessages(
        relationId: relationId,
        messages: [localMessage],
        isMultiLanguageMode: isMultiLanguageMode,
        langMap: langMap,
        multiLanguages: multiLanguages,
        mediaKey: mediaKeyInternal,
      ),
    );

    final socket = SocketService().socket;
    socket.emit('stopTyping', {'relationId': relationId, 'userId': userId});

    if (!mounted) return;
    final headers = await AuthService.getAuthorizedHeaders(context: context);
    if (headers == null) return;
    final url = Uri.parse("${ApiConfig.baseUrl}/messages");

    final body = {
      'receiver': contactId,
      'content': encrypted,
      'relationId': relationId,
      'encryptedAAD': encryptedAAD,
    };

    await http.post(url, headers: headers, body: jsonEncode(body));
  }

  void onMessageRead(dynamic data) {
    if (data == null) return;
    final String messageId = data['messageId'];
    final String relId = data['relationId'];
    if (relId != relationId) return;
    final idx = messages.lastIndexWhere((m) => m['id'] == messageId);
    if (idx != -1) {
      if (!mounted) return;
      setState(() {
        messages[idx]['isRead'] = true;
      });
      // Update search index when message read status changes
      handleMessagesUpdated();
    }
  }

  @override
  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Contrat avec ChatLanguagesMixin
  Future<void> ensureLanguageFlow(BuildContext context);
}
