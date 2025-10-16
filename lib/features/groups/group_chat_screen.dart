import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/api_config.dart';
import '../../core/service/auth_service.dart';
import '../../core/service/socket_service.dart';
import '../../core/service/groups_cache_service.dart';
import 'add_members_screen.dart';
import 'widgets/group_chat_widgets.dart';

// ✅ AJOUTS
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:silencia/core/utils/rsa_serrvice.dart';
import 'package:silencia/features/chat/chat_service.dart';
import 'package:silencia/features/chat/chat_utils.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> messages = [];
  bool isLoading = true;
  bool isSending = false;
  bool _isOfflineMode = false;
  late SocketService _socketService;
  final GroupsCacheService _cacheService = GroupsCacheService();

  // ✅ Langue de groupe
  Map<String, String>? groupLangMap;
  bool _langTriedFetch = false;

  // ✅ Affichage “comme chat_screen”
  bool estTraduit = false;

  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initUser();
    _initializeSocket();
    _loadMessages();
    _loadGroupLangLocal().then((_) => _bootstrapGroupLang());
  }

  Future<void> _initUser() async {
    _currentUserId = await AuthService.getUserId();
  }

  void _initializeSocket() async {
    _socketService = SocketService();

    final token = await AuthService.getToken();
    if (token != null) {
      _socketService.initSocket(token);

      // ✅ rejoindre la room du groupe avec l'userId
      _socketService.socket.emit('joinGroup', {
        'groupId': widget.groupId,
        'userId': _currentUserId,
      });

      // Nouveaux messages => append et scroll en BAS
      _socketService.socket.on('newGroupMessage', (data) {
        if (!mounted) return;
        if (data == null) return;
        if (data['group'] != widget.groupId) {
          // certains back renvoient l’objet complet ; au cas où:
          final groupField = (data['group'] is Map) ? data['group']['_id'] : data['group'];
          if (groupField != widget.groupId) return;
        }
        setState(() => messages.add(data));

        // Sauvegarder le nouveau message en cache
        _cacheService.addMessageToGroupCache(widget.groupId, Map<String, dynamic>.from(data));

        _scrollToBottom();
      });

      _socketService.socket.on('memberAdded', (_) {
        if (!mounted) return;
        _loadMessages();
      });

      _socketService.socket.on('memberLeft', (_) {
        if (!mounted) return;
        _loadMessages();
      });

      _socketService.socket.on('reactionAdded', (data) {
        if (!mounted) return;
        debugPrint('🔄 Réaction de groupe ajoutée reçue via WebSocket: ${data?['emoji']}');
        // Déclencher un rafraîchissement de l'interface
        setState(() {});
      });

      _socketService.socket.on('reactionRemoved', (data) {
        if (!mounted) return;
        debugPrint('🔄 Réaction de groupe supprimée reçue via WebSocket: ${data?['emoji']}');
        // Déclencher un rafraîchissement de l'interface
        setState(() {});
      });

      // ✅ reçoit notif qu'une payload de langue est dispo pour moi
      _socketService.socket.on('groupLangPayloadAvailable', (data) async {
        if (data == null) return;
        if (data['groupId'] != widget.groupId) return;
        if (data['to'] != _currentUserId) return;
        await _fetchAndStoreGroupLangFromBackend(showToast: true);
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      // 1. Charger d'abord depuis le cache
      final cachedData = await _cacheService.getGroupMessages(widget.groupId);
      if (cachedData != null) {
        if (!mounted) return;
        setState(() {
          messages = List<dynamic>.from(cachedData['messages'] ?? []);
          isLoading = false;
          _isOfflineMode = false;
        });
        _scrollToBottom();

        if (kDebugMode) {
          print('💾 Messages du groupe ${widget.groupId} chargés depuis le cache: ${messages.length} messages');
        }

        // Si on a des données du cache, on peut s'arrêter là
        // La synchronisation se fera en arrière-plan
        if (!cachedData.containsKey('fromFallback')) {
          _syncMessagesInBackground();
          return;
        }
      }

      // 2. Si pas de cache ou fallback, essayer le serveur
      await _loadMessagesFromServer();
    } catch (e) {
      if (kDebugMode) print('❌ Erreur _loadMessages: $e');

      // En cas d'erreur, utiliser les données par défaut
      final defaultData = _cacheService.getDefaultGroupMessagesData(widget.groupId);
      if (!mounted) return;
      setState(() {
        messages = List<dynamic>.from(defaultData['messages'] ?? []);
        isLoading = false;
        _isOfflineMode = true;
      });
      _scrollToBottom();
    }
  }

  Future<void> _loadMessagesFromServer() async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/groups/${widget.groupId}/messages'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverMessages = (data['messages'] ?? []) as List<dynamic>;

        if (!mounted) return;
        setState(() {
          messages = serverMessages;
          isLoading = false;
          _isOfflineMode = false;
        });

        // Sauvegarder en cache pour la prochaine fois
        await _cacheService.saveGroupMessages(
          widget.groupId,
          List<Map<String, dynamic>>.from(serverMessages)
        );

        if (kDebugMode) {
          print('🌐 Messages du groupe ${widget.groupId} chargés depuis le serveur: ${messages.length} messages');
        }

        _scrollToBottom();
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur serveur _loadMessagesFromServer: $e');

      // En cas d'erreur serveur, essayer le cache ou fallback
      final cachedData = await _cacheService.getGroupMessages(widget.groupId);
      if (cachedData != null) {
        if (!mounted) return;
        setState(() {
          messages = List<dynamic>.from(cachedData['messages'] ?? []);
          isLoading = false;
          _isOfflineMode = true;
        });
      } else {
        final defaultData = _cacheService.getDefaultGroupMessagesData(widget.groupId);
        if (!mounted) return;
        setState(() {
          messages = List<dynamic>.from(defaultData['messages'] ?? []);
          isLoading = false;
          _isOfflineMode = true;
        });
      }
      _scrollToBottom();
    }
  }

  Future<void> _syncMessagesInBackground() async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/groups/${widget.groupId}/messages'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverMessages = (data['messages'] ?? []) as List<dynamic>;

        // Sauvegarder en cache
        await _cacheService.saveGroupMessages(
          widget.groupId,
          List<Map<String, dynamic>>.from(serverMessages)
        );

        // Mettre à jour l'interface si les données ont changé
        if (mounted && serverMessages.length != messages.length) {
          setState(() {
            messages = serverMessages;
            _isOfflineMode = false;
          });
          _scrollToBottom();
        }

        if (kDebugMode) {
          print('🔄 Messages du groupe ${widget.groupId} synchronisés en arrière-plan');
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur sync messages groupe: $e');
    }
  }

  // ---------- Langue de groupe ----------
  Future<void> _loadGroupLangLocal() async {
    final map = await ChatService.getLangMap('groupLangMap-${widget.groupId}');
    if (!mounted) return;
    setState(() => groupLangMap = map);
  }

  Future<void> _bootstrapGroupLang() async {
    if (groupLangMap != null) return; // déjà ok
    if (_langTriedFetch) return;
    _langTriedFetch = true;
    await _fetchAndStoreGroupLangFromBackend(showToast: false);
  }

  Future<void> _generateGroupLangLocally() async {
    final newMap = LangMapGenerator.generateLangMap();
    await ChatService.saveLangMap('groupLangMap-${widget.groupId}', newMap);
    if (!mounted) return;
    setState(() => groupLangMap = newMap);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Langue du groupe générée.')),
    );
  }

  Future<bool> _fetchAndStoreGroupLangFromBackend({required bool showToast}) async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return false;

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/groups/${widget.groupId}/lang/fetch'),
        headers: headers,
      );

      if (res.statusCode != 200) return false;

      final data = jsonDecode(res.body);

      final storage = const FlutterSecureStorage();
      final privateKey = await storage.read(key: 'rsa_private_key');
      if (privateKey == null) throw Exception("Clé privée non trouvée sur l'appareil");

      final decrypted = RSAKeyService.hybridDecrypt(data, privateKey);
      final Map<String, String> langMap = Map<String, String>.from(jsonDecode(decrypted));

      await ChatService.saveLangMap('groupLangMap-${widget.groupId}', langMap);

      // supprimer l’enveloppe pour moi
      await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/groups/${widget.groupId}/lang/fetch'),
        headers: headers,
      );

      if (!mounted) return true;
      setState(() => groupLangMap = langMap);

      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Langue du groupe récupérée.')),
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _sendMessage() async {
    var content = _messageController.text.trim();
    if (content.isEmpty || isSending) return;

    setState(() => isSending = true);

    try {
      // ✅ applique la langue si dispo (obfuscation type DM)
      if (groupLangMap != null) {
        content = ChatUtils.applyLanguageMap(content.toLowerCase(), groupLangMap!);
      }

      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/groups/${widget.groupId}/messages'),
        headers: headers,
        body: jsonEncode({
          'content': content,
          'messageType': 'text',
        }),
      );

      if (response.statusCode == 201) {
        _messageController.clear();
        // On n’attend pas le reload complet : on laisse le socket pousser,
        // mais on force un léger scroll au cas où.
        _scrollToBottom();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de l\'envoi')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur réseau')));
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _addMembers() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
        ),
      ),
    );

    if (result == true) {
      _loadMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLang = groupLangMap != null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.groupName),
                  Text(
                    '${messages.length} message${messages.length > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                  ),
                ],
              ),
            ),
            if (_isOfflineMode) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: _showGroupInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Barre “Traduire” comme chat_screen
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF19232b)
                  : const Color(0xFFF5F7F9),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.translate),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Traduire les messages (afficher en clair)',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                Switch(
                  value: estTraduit,
                  onChanged: (v) => setState(() => estTraduit = v),
                ),
              ],
            ),
          ),

          // ✅ Hint si pas de langue locale
          if (!hasLang)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Ce groupe n'est pas encore sécurisé sur cet appareil.\nRécupérez la langue pour encoder vos envois et pouvoir traduire.",
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await _fetchAndStoreGroupLangFromBackend(showToast: true);
                      if (!ok && mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Aucune langue disponible — demandez à l’admin.')),
                        );
                      }
                    },
                    child: const Text("Récupérer"),
                  )
                ],
              ),
            ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? _buildEmptyState()
                    : GroupMessagesList(
                        messages: messages,
                        groupId: widget.groupId,
                        scrollController: _scrollController,
                        // ✅ Passe la map et l’état de traduction
                        langMap: groupLangMap,
                        estTraduit: estTraduit,
                      ),
          ),
          GroupInputBar(
            controller: _messageController,
            onSend: _sendMessage,
            isSending: isSending,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Aucun message',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Soyez le premier à envoyer un message\ndans ce groupe !',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Informations du groupe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Ajouter des membres'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _addMembers();
              },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Générer une langue locale (créateur/admin)'),
              onTap: () async {
                Navigator.pop(context);
                await _generateGroupLangLocally();
              },
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Récupérer la langue du groupe'),
              onTap: () async {
                Navigator.pop(context);
                await _fetchAndStoreGroupLangFromBackend(showToast: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _socketService.socket.off('newGroupMessage');
    _socketService.socket.off('memberAdded');
    _socketService.socket.off('memberLeft');
    _socketService.socket.off('reactionAdded');
    _socketService.socket.off('reactionRemoved');
    _socketService.socket.off('groupLangPayloadAvailable');

    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
