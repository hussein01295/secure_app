import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silencia/core/theme/theme_manager.dart';
import 'package:silencia/core/theme/app_theme.dart';
import 'package:silencia/features/chat/controller/chat_ephemeral_mixin.dart';
import 'package:silencia/features/chat/controller/chat_language_mixin.dart';
import 'package:silencia/features/chat/controller/chat_media_mixin.dart';
import 'package:silencia/features/chat/controller/chat_messages_mixin.dart';
import 'package:silencia/features/chat/widgets/chat_widgets.dart';
import 'package:silencia/features/chat/search_db/message_repo.dart';
import 'package:silencia/core/widgets/cached_profile_avatar.dart';
import 'package:silencia/features/call/models/call_state.dart';

import 'package:silencia/core/utils/encryption_helper.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';

import 'chat_socket_handler.dart';
import 'chat_utils.dart';
import 'controller/chat_screen_data.dart';
import 'controller/chat_vars.dart';
import 'controller/chat_init.dart';
import 'controller/chat_sockets_mixin.dart';

class _SearchQueryPlan {
  final String query;
  final bool translatedMode;
  const _SearchQueryPlan(this.query, this.translatedMode);
}

class ChatScreen extends StatefulWidget implements ChatScreenData {
  final String contactName;
  final String contactId;
  final String token;
  final String userId;
  final String relationId;

  const ChatScreen({
    super.key,
    required this.contactName,
    required this.contactId,
    required this.token,
    required this.userId,
    required this.relationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with
        ChatVars,
        ChatInit,
        ChatSocketsMixin,
        ChatMessagesMixin,
        ChatLanguagesMixin,
        ChatMediaMixin,
        ChatEphemeralMixin
    implements ChatSocketHandler {
  _ChatScreenState() : super();

  // 🎨 Variables pour le fond d'écran
  String? _currentWallpaper;
  final GlobalKey<MessagesListState> _messagesListKey =
      GlobalKey<MessagesListState>();
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  List<_SearchEntry> _searchIndex = [];
  List<_SearchEntry> _searchResults = [];
  String _lastSearchQuery = '';
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadWallpaper();
    // Build initial search index after a short delay to ensure messages are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && messages.isNotEmpty) {
        _rebuildSearchIndex(triggerSearch: false);
      }
    });
  }

  Future<void> _loadWallpaper() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wallpaper = prefs.getString('chat_wallpaper_${widget.relationId}');
      setState(() {
        _currentWallpaper = wallpaper ?? 'default';
      });
    } catch (e) {
      setState(() {
        _currentWallpaper = 'default';
      });
    }
  }

  BoxDecoration? _getWallpaperDecoration() {
    switch (_currentWallpaper) {
      case 'gradient_blue':
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[400]!, Colors.blue[800]!],
          ),
        );
      case 'gradient_purple':
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple[400]!, Colors.purple[800]!],
          ),
        );
      case 'gradient_green':
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green[400]!, Colors.green[800]!],
          ),
        );
      case 'gradient_pink':
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.pink[400]!, Colors.pink[800]!],
          ),
        );
      case 'solid_dark':
        return BoxDecoration(color: Colors.grey[900]);
      case 'solid_light':
        return BoxDecoration(color: Colors.grey[100]);
      case 'default':
      default:
        return null; // Fond par défaut
    }
  }

  @override
  void handleMessagesUpdated() {
    super.handleMessagesUpdated();
    // Always rebuild search index when messages are updated, regardless of search state
    _rebuildSearchIndex(
      triggerSearch: _searchOpen && _lastSearchQuery.isNotEmpty,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeManager = globalThemeManager;

    // ✅ Peut écrire dès qu'on a une langue (ancien ou nouveau format)
    final canWrite =
        (isMultiLanguageMode && multiLanguages != null) ||
        (!isMultiLanguageMode && langMap != null);

    final appBarBg = themeManager.getSurfaceColor();
    final titleColor = theme.colorScheme.onSurface;
    final backgroundColor = themeManager.getChatBackgroundColor();

    return Container(
      decoration: _currentWallpaper != 'default'
          ? _getWallpaperDecoration()
          : null,
      child: Scaffold(
        backgroundColor: _currentWallpaper == 'default'
            ? backgroundColor
            : Colors.transparent,
        appBar: AppBar(
          backgroundColor: appBarBg,
          elevation: 0,
          flexibleSpace: themeManager.currentTheme == AppThemeMode.neon
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.neonPurple.withValues(alpha: 0.3),
                        AppTheme.neonPink.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                )
              : null,
          title: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  // 🔍 DEBUG
                  debugPrint('🔍 DEBUG: Navigation vers conversation-info');
                  debugPrint(
                    '🔍 DEBUG: widget.relationId = ${widget.relationId}',
                  );
                  debugPrint(
                    '🔍 DEBUG: widget.relationId.runtimeType = ${widget.relationId.runtimeType}',
                  );

                  final result = await context.push(
                    '/conversation-info',
                    extra: {
                      'contactName': widget.contactName,
                      'username': "contactUsername", // à remplacer
                      'isOnline': isOnline,
                      'lastSeen': "il y a 8 semaines",
                      'secureStatus': canWrite
                          ? "Les messages sont chiffrés de bout en bout"
                          : "Non sécurisé",
                      'exchangedMessages': messages.length,
                      'lastMessage': messages.isNotEmpty
                          ? messages.last['text'] ?? ''
                          : '',
                      'lastMessageDate': messages.isNotEmpty
                          ? "12 mars 2024"
                          : '',
                      'sharedPhotos': const [],
                      'relationId': widget.relationId,
                    },
                  );

                  if (result != null && result is Map) {
                    if (result['action'] == 'wallpaperChanged') {
                      await _loadWallpaper();
                    }
                  }
                },
                child: Container(
                  decoration: themeManager.currentTheme == AppThemeMode.neon
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppTheme.neonPurple, AppTheme.neonPink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.neonPurple.withValues(alpha: 0.5),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        )
                      : null,
                  child: CachedProfileAvatar(
                    username: widget.contactName,
                    radius: 20,
                    enableHeroAnimation: true,
                    heroTag: 'avatar_${widget.contactId}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.contactName,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      if (isOfflineMode) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange, width: 1),
                          ),
                          child: const Text(
                            'Hors ligne',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline
                              ? AppTheme.success
                              : theme.colorScheme.outline,
                          boxShadow:
                              isOnline &&
                                  themeManager.currentTheme == AppThemeMode.neon
                              ? [
                                  BoxShadow(
                                    color: AppTheme.success.withValues(
                                      alpha: 0.8,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOnline ? "En ligne" : "Hors ligne",
                        style: TextStyle(
                          color: isOnline
                              ? AppTheme.success
                              : theme.colorScheme.outline,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          shadows:
                              isOnline &&
                                  themeManager.currentTheme == AppThemeMode.neon
                              ? [
                                  Shadow(
                                    color: AppTheme.success.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.call, color: titleColor, size: 20),
              onPressed: () => _makeCall(CallType.audio),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: Icon(Icons.videocam, color: titleColor, size: 20),
              onPressed: () => _makeCall(CallType.video),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: Icon(
                _searchOpen ? Icons.close : Icons.search,
                color: titleColor,
                size: 20,
              ),
              onPressed: _toggleSearch,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),

            // 🔒 Icône de sécurité
            IconButton(
              icon: Icon(
                canWrite ? Icons.lock : Icons.lock_open,
                color: canWrite ? AppTheme.success : AppTheme.error,
                size: 20,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      canWrite
                          ? "Canal sécurisé - Messages chiffrés"
                          : "Canal non sécurisé",
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: canWrite
                        ? AppTheme.success
                        : AppTheme.error,
                  ),
                );
              },
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        body: Column(
          children: [
            buildTopBar(
              onToggleTranslation: toggleTranslation,
              estTraduit: estTraduit,
              myLangStatus: myLangStatus,
              otherLangStatus: otherLangStatus,
              onShowDebugInfo:
                  ((isMultiLanguageMode && multiLanguages != null) ||
                      (!isMultiLanguageMode && langMap != null))
                  ? () {
                      showLanguageDebugInfo(
                        context,
                        langMap,
                        myLangStatus,
                        otherLangStatus,
                        mediaKey,
                        this,
                      );
                    }
                  : null,
              langMap: langMap,
            ),
            if (_searchOpen) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: estTraduit
                        ? 'Rechercher (texte traduit)'
                        : 'Rechercher (texte code)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _lastSearchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    _searchDebounce?.cancel();
                    setState(() {
                      _lastSearchQuery = value.trim();
                    });
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 300),
                      () {
                        if (!mounted) return;
                        _runSearch(value);
                      },
                    );
                  },
                ),
              ),
              if (_searchResults.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (_, index) {
                      final entry = _searchResults[index];
                      final displayLine = estTraduit
                          ? entry.decoded
                          : entry.coded;
                      return ListTile(
                        dense: true,
                        title: Text(
                          displayLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: _buildSearchSubtitle(context, entry),
                        onTap: () => _onSearchResultTap(entry),
                      );
                    },
                  ),
                ),
              if (_searchResults.isEmpty && _lastSearchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Text(
                    'Aucun résultat',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
            if (ephemeralSettings != null && ephemeralEnabled)
              EphemeralBanner(
                settings: ephemeralSettings!,
                onTap: () {
                  context.push(
                    '/conversation-info',
                    extra: {
                      'contactName': widget.contactName,
                      'username': "contactUsername",
                      'isOnline': isOnline,
                      'lastSeen': "il y a 8 semaines",
                      'secureStatus': canWrite
                          ? "Les messages sont chiffrés de bout en bout"
                          : "Non sécurisé",
                      'exchangedMessages': messages.length,
                      'lastMessage': messages.isNotEmpty
                          ? messages.last['text'] ?? ''
                          : '',
                      'lastMessageDate': messages.isNotEmpty
                          ? "12 mars 2024"
                          : '',
                      'sharedPhotos': const [],
                      'relationId': widget.relationId,
                    },
                  );
                },
              ),
            if (!canWrite)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Active la langue codée pour sécuriser ce chat.",
                        style: TextStyle(color: Colors.orange, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => ensureLanguageFlow(context),
                      child: const Text("Résoudre"),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: MessagesList(
                key: _messagesListKey,
                scrollController: scrollController,
                messages: messages,
                langMap: langMap,
                canWrite: canWrite,
                estTraduit: estTraduit,
                applyReverseMap:
                    ChatUtils.applyReverseMap, // ✅ utilise ChatUtils
                onMessageVisible: (msgId) {
                  final idx = messages.indexWhere((m) => m['id'] == msgId);
                  if (idx != -1 &&
                      messages[idx]['fromMe'] == false &&
                      messages[idx]['isRead'] == false) {
                    markMessageAsRead(msgId);
                    setState(() {
                      messages[idx]['isRead'] = true;
                    });
                    // Update search index when message read status changes
                    handleMessagesUpdated();
                  }
                },
                isContactTyping: isContactTyping,
                contactName: widget.contactName,
                relationId: widget.relationId, // pour les réactions
                // ✅ NOUVEAU: Support du mode multi-langues
                isMultiLanguageMode: isMultiLanguageMode,
                multiLanguages: multiLanguages,
                mediaKey: mediaKey,
              ),
            ),
            buildInputBar(
              context,
              sendMessage,
              controller,
              enabled: canWrite,
              chatController: this,
              onSendVoice: (audioFile, durationSeconds) =>
                  _sendVoiceMessage(audioFile, durationSeconds),
              onSendText: (text) => _sendTextMessage(text),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSearch() {
    final shouldOpen = !_searchOpen;
    if (!shouldOpen) {
      FocusScope.of(context).unfocus();
    }
    setState(() {
      _searchOpen = shouldOpen;
      if (shouldOpen) {
        _searchCtrl.text = _lastSearchQuery;
      } else {
        _searchResults = [];
        _searchCtrl.clear();
      }
    });
    if (shouldOpen) {
      if (_searchIndex.isEmpty && messages.isNotEmpty) {
        _rebuildSearchIndex(triggerSearch: false);
      }
      if (_lastSearchQuery.isNotEmpty) {
        _runSearch(_lastSearchQuery);
      }
    } else {
      _searchDebounce?.cancel();
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchCtrl.clear();
      _searchResults = [];
      _lastSearchQuery = '';
    });
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    _lastSearchQuery = trimmed;
    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() => _searchResults = []);
      return;
    }
    final token = ++_searchGeneration;
    await _applySearch(trimmed, token);
  }

  Future<void> _applySearch(String needle, int token) async {
    String? _encodeNeedle(String value) {
      if (langMap == null || langMap!.isEmpty) return null;
      try {
        return ChatUtils.applyLanguageMap(value.toLowerCase(), langMap!);
      } catch (_) {
        return null;
      }
    }

    final Set<String> scheduled = {};
    final List<_SearchQueryPlan> queryPlan = [];

    void schedule(String query, bool translatedMode) {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return;
      final key = '${translatedMode ? 'T' : 'C'}|${trimmed.toLowerCase()}';
      if (scheduled.add(key)) {
        queryPlan.add(_SearchQueryPlan(trimmed, translatedMode));
      }
    }

    if (estTraduit) {
      schedule(needle, true);

      final encodedNeedle = !isMultiLanguageMode ? _encodeNeedle(needle) : null;
      if (encodedNeedle != null) {
        schedule(encodedNeedle, false);
      }

      schedule(needle, false);
    } else {
      String? encodedNeedle;
      if (!isMultiLanguageMode) {
        encodedNeedle = _encodeNeedle(needle);
        if (encodedNeedle != null) {
          schedule(encodedNeedle, false);
        }
      }
      schedule(needle, false);
      schedule(needle, true);
    }

    final Set<String> seenIds = {};
    final List<_SearchEntry> aggregated = [];

    Future<void> collect(String query, bool translatedMode) async {
      try {
        final entities = await MessageRepo.search(
          relationId: widget.relationId,
          query: query,
          translatedMode: translatedMode,
          limit: 100,
        );
        if (token != _searchGeneration) return;
        for (final entity in entities) {
          final id = entity.id;
          if (id.isEmpty || seenIds.contains(id)) continue;
          seenIds.add(id);
          aggregated.add(
            _SearchEntry(
              id: id,
              coded: entity.coded ?? '',
              decoded: entity.decoded ?? entity.coded ?? '',
              ts: entity.ts,
              type: entity.type,
              timeLabel: entity.timeLabel,
            ),
          );
        }
      } catch (e, st) {
        debugPrint('Search error: $e\n$st');
      }
    }

    for (final plan in queryPlan) {
      if (token != _searchGeneration) return;
      await collect(plan.query, plan.translatedMode);
    }

    if (aggregated.isEmpty) {
      final fallback = _fallbackSearch(needle);
      if (!mounted || token != _searchGeneration) return;
      setState(() {
        _searchResults = fallback.take(50).toList();
      });
      return;
    }

    aggregated.sort((a, b) => (b.ts ?? 0).compareTo(a.ts ?? 0));

    if (!mounted || token != _searchGeneration) return;

    setState(() {
      _searchResults = aggregated.take(50).toList();
    });
  }

  void _rebuildSearchIndex({bool triggerSearch = false}) {
    if (!mounted) return;
    final List<_SearchEntry> built = [];

    for (final message in messages) {
      final rawId = message['id'] ?? message['_id'];
      if (rawId == null) continue;
      final id = rawId.toString();
      if (id.isEmpty) continue;

      final type = (message['messageType'] ?? 'text').toString();
      final ts = _extractTimestamp(message);
      final timeLabel = message['time']?.toString();

      if (type != 'text') {
        final label = '[]';
        built.add(
          _SearchEntry(
            id: id,
            coded: label,
            decoded: label,
            ts: ts,
            type: type,
            timeLabel: timeLabel,
          ),
        );
        continue;
      }

      final coded = (message['coded'] ?? message['text'] ?? '').toString();
      final decoded = (message['decoded'] ?? message['text'] ?? '').toString();

      built.add(
        _SearchEntry(
          id: id,
          coded: coded,
          decoded: decoded,
          ts: ts,
          type: type,
          timeLabel: timeLabel,
        ),
      );
    }

    setState(() {
      _searchIndex = built;
    });

    if (triggerSearch && _lastSearchQuery.isNotEmpty) {
      _runSearch(_lastSearchQuery);
    }
  }

  List<_SearchEntry> _fallbackSearch(String needle) {
    if (_searchIndex.isEmpty) return [];
    final trimmed = needle.trim();
    if (trimmed.isEmpty) return [];

    final matches = _searchIndex
        .where(
          (entry) =>
              ChatUtils.fuzzyContains(entry.decoded, trimmed) ||
              ChatUtils.fuzzyContains(entry.coded, trimmed),
        )
        .toList();

    matches.sort((a, b) => (b.ts ?? 0).compareTo(a.ts ?? 0));
    return matches;
  }

  int? _extractTimestamp(Map<String, dynamic> message) {
    final candidates = [
      message['timestamp'],
      message['createdAt'],
      message['sentAt'],
    ];
    for (final candidate in candidates) {
      if (candidate is int) return candidate;
      if (candidate is String) {
        final parsedInt = int.tryParse(candidate);
        if (parsedInt != null) return parsedInt;
        final parsedDate = DateTime.tryParse(candidate);
        if (parsedDate != null) return parsedDate.millisecondsSinceEpoch;
      }
    }
    return null;
  }

  Widget _buildSearchSubtitle(BuildContext context, _SearchEntry entry) {
    final theme = Theme.of(context);
    final List<Widget> parts = [];
    if (entry.timeLabel != null && entry.timeLabel!.isNotEmpty) {
      parts.add(Text(entry.timeLabel!, style: theme.textTheme.bodySmall));
    }
    if (entry.type != 'text') {
      if (parts.isNotEmpty) {
        parts.add(const SizedBox(width: 8));
      }
      parts.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            entry.type,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontSize: 11,
            ),
          ),
        ),
      );
    }
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(mainAxisSize: MainAxisSize.min, children: parts);
  }

  void _onSearchResultTap(_SearchEntry entry) {
    debugPrint('🎯 Clic sur résultat de recherche : ${entry.id}');

    // Fermer le clavier et l'interface de recherche
    FocusScope.of(context).unfocus();
    setState(() {
      _searchOpen = false;
      _searchResults = [];
      _searchCtrl.clear();
    });
    _searchDebounce?.cancel();

    // Clear search query to hide search UI
    _lastSearchQuery = '';

    // Navigation vers le message avec délai pour s'assurer que l'UI est mise à jour
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        debugPrint('🚀 Début de la navigation vers le message ${entry.id}');
        _messagesListKey.currentState?.scrollToMessage(
          entry.id,
          duration: const Duration(milliseconds: 600),
        );
      }
    });
  }

  @override
  void toggleTranslation() {
    super.toggleTranslation();
    if (_searchOpen && _lastSearchQuery.isNotEmpty) {
      _runSearch(_lastSearchQuery);
    }
  }

  // 🎤 Messages vocaux
  Future<void> _sendVoiceMessage(File audioFile, int durationSeconds) async {
    await sendVoiceMessage(audioFile, durationSeconds);
  }

  // ✏️ Messages texte
  Future<void> _sendTextMessage(String text) async {
    // Utiliser la méthode existante sendMessage après avoir mis le texte dans le controller
    controller.text = text;
    await sendMessage();
  }

  // 📞 Appel
  void _makeCall(CallType callType) {
    context.push(
      '/call',
      extra: {
        'contactName': widget.contactName,
        'contactId': widget.contactId,
        'callType': callType,
        'isIncoming': false,
      },
    );
  }
}

class _SearchEntry {
  final String id;
  final String coded;
  final String decoded;
  final int? ts;
  final String type;
  final String? timeLabel;

  const _SearchEntry({
    required this.id,
    required this.coded,
    required this.decoded,
    required this.ts,
    required this.type,
    this.timeLabel,
  });
}
