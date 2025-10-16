import 'dart:async';
import 'package:flutter/material.dart';

import 'package:silencia/core/service/messages_cache_service.dart';
import 'package:silencia/core/service/socket_service.dart';

import '../chat_socket_handler.dart';
import 'chat_screen_data.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 1 — VARIABLES & PROPRIÉTÉS (ChatVars)
// ═══════════════════════════════════════════════════════════════════════════════
/// Mixins génériques pour éviter le conflit `State<ChatScreen>` vs `State<StatefulWidget>`.
mixin ChatVars<T extends StatefulWidget> on State<T> implements ChatSocketHandler {
  // Helper typé
  ChatScreenData get data => widget as ChatScreenData;

  // 📝 UI
  final controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // 💬 Messages & cache
  final List<Map<String, dynamic>> messages = [];
  final MessagesCacheService _cacheService = MessagesCacheService();
  bool _isOfflineMode = false;
  String? _mediaKey;

  // 🌐 Langues
  Map<String, String>? langMap;
  Map<String, Map<String, String>>? multiLanguages;
  bool isMultiLanguageMode = false;
  bool estTraduit = false;
  bool isLoadingLang = false;
  String myLangStatus = "lost";
  String otherLangStatus = "lost";
  bool _bootstrappedLang = false;

  // 🔌 Sockets
  bool isOnline = false;
  bool isContactTyping = false;
  Timer? onlineStatusTimer;
  Timer? typingDebounce;
  late final void Function(bool, String) _typingListener;

  // ⏰ Éphémères
  Map<String, dynamic>? ephemeralSettings;
  bool ephemeralEnabled = false;

  // 📄 Pagination
  bool isLoadingMore = false;
  bool hasMoreMessages = true;
  String? nextCursor;
  final int messagesPerPage = 30;

  // Getters utiles
  bool get isOfflineMode => _isOfflineMode;
  String get contactId => data.contactId;
  @override
  String get relationId => data.relationId;
  @override
  String get userId => data.userId;
  @override
  String? get mediaKey => _mediaKey;

  String get langMapKey => 'langMap-$relationId';

  // Getters protégés pour les autres mixins
  MessagesCacheService get cacheService => _cacheService;
  String? get mediaKeyInternal => _mediaKey;
  set mediaKeyInternal(String? value) => _mediaKey = value;
  bool get isOfflineModeInternal => _isOfflineMode;
  set isOfflineModeInternal(bool value) => _isOfflineMode = value;
  bool get bootstrappedLang => _bootstrappedLang;
  set bootstrappedLang(bool value) => _bootstrappedLang = value;
  void Function(bool, String) get typingListener => _typingListener;
  set typingListener(void Function(bool, String) value) => _typingListener = value;

  @protected
  void handleMessagesUpdated() {}

  // === Implémentations requises par ChatSocketHandler ===
  @override
  List<Map<String, dynamic>> get chatMessages => messages;

  @override
  ScrollController get chatScrollController => scrollController;

  @override
  dynamic getSocket() => SocketService().socket;

  // Contrats abstraits pour les autres mixins
  Future<void> refreshLangStatus();
}
