import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart'; 
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/service/socket_service.dart';
import 'package:silencia/core/service/messages_cache_service.dart';
import 'package:silencia/core/service/profile_cache_service.dart';
import 'package:silencia/core/service/image_cache_service.dart';
import 'package:silencia/core/widgets/cached_profile_avatar.dart';
import 'package:silencia/features/home/widgets/friend_requests_page.dart';
 

class ChatListView extends StatefulWidget {
  final String token;
  final String userId;

  const ChatListView({
    super.key,
    required this.token,
    required this.userId,
  });

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  List<dynamic> friends = [];
  bool isLoading = true;
  bool _isOfflineMode = false;
  String searchTerm = "";
  int friendRequestsCount = 0;
  final Map<String, bool> typingStatus = {};
  final MessagesCacheService _cacheService = MessagesCacheService();
  final ProfileCacheService _profileCacheService = ProfileCacheService();
  final ImageCacheService _imageCacheService = ImageCacheService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await fetchFriends();
      await fetchFriendRequestsCount();
      _setupFriendSocketListeners();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerTypingObservers();
  }

  @override
  void dispose() {
    _unregisterTypingObservers();
    _removeFriendSocketListeners();
    super.dispose();
  }

  /// Configure les listeners socket pour les événements d'amis
  void _setupFriendSocketListeners() {
    final socketService = SocketService();
    if (socketService.isReady) {
      socketService.addFriendRequestObserver(_onFriendRequestReceived);
      socketService.addFriendAcceptedObserver(_onFriendRequestAccepted);
      socketService.addFriendRemovedObserver(_onFriendRemoved);
    }
  }

  /// Supprime les listeners socket pour les événements d'amis
  void _removeFriendSocketListeners() {
    final socketService = SocketService();
    if (socketService.isReady) {
      socketService.removeFriendRequestObserver(_onFriendRequestReceived);
      socketService.removeFriendAcceptedObserver(_onFriendRequestAccepted);
      socketService.removeFriendRemovedObserver(_onFriendRemoved);
    }
  }

  /// Callback pour nouvelle demande d'ami reçue
  void _onFriendRequestReceived(Map<String, dynamic> data) {
    debugPrint('📱 Nouvelle demande d\'ami reçue: ${data['sender']?['displayName']}');
    // Rafraîchir le compteur de demandes d'amis
    fetchFriendRequestsCount();
  }

  /// Callback pour demande d'ami acceptée
  void _onFriendRequestAccepted(Map<String, dynamic> data) {
    debugPrint('📱 Demande d\'ami acceptée: ${data['accepter']?['displayName']}');
    // Rafraîchir la liste des amis et le compteur
    fetchFriends();
    fetchFriendRequestsCount();
  }

  /// Callback pour ami supprimé
  void _onFriendRemoved(Map<String, dynamic> data) {
    debugPrint('📱 Ami supprimé: ${data['removedBy']?['displayName']}');

    // Supprimer le cache de l'ami qui nous a supprimés
    final relationId = data['relationId'];
    final removerId = data['removedBy']?['_id'];

    if (relationId != null && removerId != null) {
      _clearRemovedFriendCache(relationId, removerId);
    }

    // Rafraîchir la liste des amis
    fetchFriends();
  }

  /// Supprimer le cache de l'ami qui nous a supprimés
  Future<void> _clearRemovedFriendCache(String relationId, String userId) async {
    try {
      // Supprimer le cache des messages de cette relation
      await _cacheService.clearRelationCache(relationId);

      // Supprimer le cache du profil de cet utilisateur
      await _profileCacheService.clearUserCache(userId);

      // Supprimer les images en cache de cet utilisateur
      await _imageCacheService.clearUserImages(userId);

      if (kDebugMode) {
        print('🗑️ Cache supprimé pour l\'ami qui nous a supprimés: $userId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur suppression cache ami supprimé: $e');
    }
  }

  String extractRelationId(Map friend) {
    // 🔍 DEBUG: Logs pour diagnostiquer le problème
    debugPrint('🔍 DEBUG: extractRelationId appelé pour friend: $friend');

    if (friend['relationId'] != null && friend['relationId'].toString().isNotEmpty) {
      final relationId = friend['relationId'].toString();
      debugPrint('🔍 DEBUG: relationId trouvé via friend[relationId]: $relationId');
      return relationId;
    }
    if (friend['relation'] != null && friend['relation'] is Map && friend['relation']['_id'] != null) {
      final relationId = friend['relation']['_id'].toString();
      debugPrint('🔍 DEBUG: relationId trouvé via friend[relation][_id]: $relationId');
      return relationId;
    }
    if (friend['_id'] != null && friend['_id'].toString().length == 24) {
      final relationId = friend['_id'].toString();
      debugPrint('🔍 DEBUG: relationId trouvé via friend[_id]: $relationId');
      return relationId;
    }
    debugPrint('❌ DEBUG: Aucun relationId trouvé pour ce friend');
    return '';
  }

  /// NEW: Permet de rejoindre toutes les rooms de conversation pour recevoir les events typing
  void _joinAllRelations() {
    final socket = SocketService().socket;
    for (final friend in friends) {
      final relId = extractRelationId(friend);
      if (relId.isNotEmpty) {
        socket.emit('joinRelation', relId);
      }
    }
  }

  void _registerTypingObservers() {
    for (final friend in friends) {
      final relId = extractRelationId(friend);
      final friendId = friend['_id'];
      if (relId.isEmpty) continue;
      SocketService().registerTypingObserver(relId, (isTyping, typingUserId) {
        if (!mounted) return;
        if (typingUserId == friendId) {
          setState(() {
            typingStatus[relId] = isTyping;
          });
        }
      });
    }
  }

  void _unregisterTypingObservers() {
    for (final friend in friends) {
      final relId = extractRelationId(friend);
      if (relId.isEmpty) continue;
      SocketService().unregisterTypingObserver(relId);
    }
  }

  Future<void> fetchFriends() async {
    setState(() => isLoading = true);

    try {
      // 1. Charger d'abord depuis le cache
      final cachedData = await _cacheService.getConversations();
      if (cachedData != null) {
        setState(() {
          friends = cachedData['conversations'] ?? [];
          isLoading = false;
          _isOfflineMode = false;
        });

        if (kDebugMode) {
          debugPrint('💾 Conversations chargées depuis le cache: ${friends.length} conversations');
        }

        // Si on a des données du cache, on peut s'arrêter là
        // La synchronisation se fera en arrière-plan
        if (!cachedData.containsKey('fromFallback')) {
          _syncConversationsInBackground();
          _unregisterTypingObservers();
          _registerTypingObservers();
          _joinAllRelations();
          return;
        }
      }

      // 2. Si pas de cache ou fallback, essayer le serveur
      await _fetchFriendsFromServer();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur fetchFriends: $e');

      // En cas d'erreur, utiliser les données par défaut
      final defaultData = _cacheService.getDefaultConversationsData();
      setState(() {
        friends = defaultData['conversations'] ?? [];
        isLoading = false;
        _isOfflineMode = true;
      });
    }
  }

  Future<void> _fetchFriendsFromServer() async {
    try {
      final headers = await AuthService.getAuthorizedHeaders(context: context);
      if (headers == null) return;

      final url = Uri.parse("${ApiConfig.baseUrl}/relations/friends");
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          friends = data;
          isLoading = false;
          _isOfflineMode = false;
        });

        // Sauvegarder en cache pour la prochaine fois
        await _cacheService.saveConversations(data);

        if (kDebugMode) {
          debugPrint('🌐 Conversations chargées depuis le serveur: ${friends.length} conversations');
        }

        _unregisterTypingObservers();
        _registerTypingObservers();
        _joinAllRelations();
      } else {
        throw Exception("Erreur serveur : ${response.statusCode}");
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur serveur fetchFriends: $e');

      // En cas d'erreur serveur, essayer le cache ou fallback
      final cachedData = await _cacheService.getConversations();
      if (cachedData != null) {
        setState(() {
          friends = cachedData['conversations'] ?? [];
          isLoading = false;
          _isOfflineMode = true;
        });
      } else {
        final defaultData = _cacheService.getDefaultConversationsData();
        setState(() {
          friends = defaultData['conversations'] ?? [];
          isLoading = false;
          _isOfflineMode = true;
        });
      }
    }
  }

  Future<void> _syncConversationsInBackground() async {
    try {
      final headers = await AuthService.getAuthorizedHeaders(context: context);
      if (headers == null) return;

      final url = Uri.parse("${ApiConfig.baseUrl}/relations/friends");
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        // Sauvegarder en cache
        await _cacheService.saveConversations(data);

        // Mettre à jour l'interface si les données ont changé
        if (mounted && data.length != friends.length) {
          setState(() {
            friends = data;
            _isOfflineMode = false;
          });

          _unregisterTypingObservers();
          _registerTypingObservers();
          _joinAllRelations();
        }

        if (kDebugMode) {
          debugPrint('🔄 Conversations synchronisées en arrière-plan');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur sync conversations: $e');
    }
  }

    Future<void> fetchFriendRequestsCount() async {
      final headers = await AuthService.getAuthorizedHeaders(context: context);
      if (headers == null) return;
      final url = Uri.parse('${ApiConfig.baseUrl}/relations');
      final res = await http.get(url, headers: headers);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final count = data.where((rel) =>
          rel['status'] == 'pending' &&
          rel['user2']['_id'] == widget.userId
        ).length;
        if (mounted) setState(() => friendRequestsCount = count);
      }
    }


  List<dynamic> getFilteredFriends() {
    if (searchTerm.trim().isEmpty) return friends;
    final search = searchTerm.toLowerCase();
    return friends.where((friend) {
      final username = (friend['username'] ?? '').toLowerCase();
      final displayName = (friend['displayName'] ?? '').toLowerCase();
      return username.contains(search) || displayName.contains(search);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredFriends = getFilteredFriends();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await fetchFriends();
          await fetchFriendRequestsCount();
        },
        color: theme.colorScheme.primary,
        backgroundColor: theme.scaffoldBackgroundColor,
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
            : ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 8, top: 14, bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (value) {
                              setState(() => searchTerm = value);
                            },
                            style: TextStyle(color: theme.textTheme.bodyLarge!.color),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: theme.cardColor,
                              prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                              hintText: "Rechercher un ami",
                              hintStyle: TextStyle(color: theme.colorScheme.primary),
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              IconButton(
                                icon: Icon(Icons.notifications, color: theme.colorScheme.primary),
                                tooltip: "Demandes d'amis",
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FriendRequestsPage(
                                        token: widget.token,
                                        userId: widget.userId,
                                      ),
                                    ),
                                  );
                                  fetchFriendRequestsCount();
                                },
                              ),
                              if (friendRequestsCount > 0)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$friendRequestsCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Indicateur de mode offline
                  if (_isOfflineMode)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mode hors ligne - Conversations en cache',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (filteredFriends.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Text(
                          "Aucun ami trouvé",
                          style: TextStyle(color: theme.textTheme.bodySmall!.color?.withValues(alpha: 0.6)),
                        ),
                      ),
                    )
                  else
                  ...filteredFriends.map((friend) {
                    final name = (friend['displayName'] ?? friend['username'] ?? 'Utilisateur inconnu') as String;
                    final username = (friend['username'] ?? 'inconnu') as String;
                    final id = (friend['_id'] ?? '') as String;
                    final relationId = extractRelationId(friend);
                    final isTyping = typingStatus[relationId] == true;

                    return Card(
                      color: theme.cardColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: () {
                          // 🔍 DEBUG: Logs pour diagnostiquer le problème
                          debugPrint('🔍 DEBUG: Navigation vers chat');
                          debugPrint('🔍 DEBUG: name: $name');
                          debugPrint('🔍 DEBUG: id: $id');
                          debugPrint('🔍 DEBUG: relationId: $relationId');
                          debugPrint('🔍 DEBUG: relationId.isEmpty: ${relationId.isEmpty}');

                          context.push('/chat', extra: {
                            'contactName': name,
                            'contactId': id,
                            'token': widget.token,
                            'userId': widget.userId,
                            'relationId': relationId,
                          });
                        },
                        leading: CachedProfileAvatar(
                          username: name,
                          radius: 20,
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge!.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: isTyping
                          ? Text(
                              "$name est en train d'écrire...",
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : Text(
                              '@$username',
                              style: TextStyle(
                                color: theme.textTheme.bodySmall!.color?.withValues(alpha: 0.7),
                              ),
                            ),
                        trailing: Icon(Icons.chat, color: theme.colorScheme.primary),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}
