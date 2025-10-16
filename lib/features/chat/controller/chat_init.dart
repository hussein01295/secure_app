import 'dart:async';
import 'package:flutter/material.dart';

import 'package:silencia/core/service/socket_service.dart';

import 'chat_vars.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 2 — INITIALISATION (ChatInit)
// ═══════════════════════════════════════════════════════════════════════════════
mixin ChatInit<T extends StatefulWidget> on ChatVars<T> {
  @mustCallSuper
  @override
  void initState() {
    super.initState();

    // Pagination — scroll listener
    scrollController.addListener(_onScroll);

    // Messages init
    fetchMessages();

    // Langues + mediaKey
    refreshLangStatus();
    loadLanguageMap();
    loadMediaKey();

    // Éphémères
    loadEphemeralSettings();

    // WebSocket & online monitoring
    initializeSocketConnections();
    initializeOnlineStatusMonitoring();

    // Bootstrap auto langue
    unattendedLangInit();
  }

  @override
  void dispose() {
    // Off handlers socket
    final socket = SocketService().socket;
    socket.off('newMessage');
    socket.off('langStatusUpdate');
    socket.off('messageRead');
    socket.off('userOnline');
    socket.off('userOffline');
    socket.off('langResendRequested');
    socket.off('langResendDeclined');
    socket.off('langPayloadAvailable');
    socket.off('reactionAdded');
    socket.off('reactionRemoved');

    SocketService().unregisterTypingObserver(relationId, typingListener);
    controller.dispose();
    scrollController.dispose();
    onlineStatusTimer?.cancel();
    typingDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (scrollController.hasClients) {
      final maxScroll = scrollController.position.maxScrollExtent;
      final currentScroll = scrollController.position.pixels;
      if (currentScroll >= maxScroll - 200) {
        if (!isLoadingMore && hasMoreMessages) {
          loadMoreMessages();
        }
      }
    }
  }

  // Contrats (à fournir par d'autres mixins)
  Future<void> fetchMessages();
  Future<void> loadLanguageMap();
  Future<void> loadMediaKey();
  Future<void> loadEphemeralSettings();

  // ⬇️ Noms publics (plus de conflit de privés)
  void initializeSocketConnections();
  void initializeOnlineStatusMonitoring();
  Future<void> unattendedLangInit();

  Future<void> loadMoreMessages();
}
