import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/service/socket_service.dart'; // <-- AJOUT ICI
import 'package:silencia/core/service/messages_cache_service.dart';
import 'package:silencia/core/service/profile_cache_service.dart';
import 'package:silencia/core/service/image_cache_service.dart';
import 'package:flutter/foundation.dart';

class FriendRequestsPage extends StatefulWidget {
  final String token;
  final String userId;

  const FriendRequestsPage({
    super.key,
    required this.token,
    required this.userId,
  });

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  List<dynamic> requests = [];
  bool isLoading = true;
  final SocketService _socketService = SocketService();
  final MessagesCacheService _messagesCacheService = MessagesCacheService();
  final ProfileCacheService _profileCacheService = ProfileCacheService();
  final ImageCacheService _imageCacheService = ImageCacheService();

  @override
  void initState() {
    super.initState();
    fetchRequests();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _removeSocketListeners();
    super.dispose();
  }

  /// Configure les listeners socket pour la synchronisation temps réel
  void _setupSocketListeners() {
    if (_socketService.isReady) {
      _socketService.addFriendRequestObserver(_onFriendRequestReceived);
    }
  }

  /// Supprime les listeners socket
  void _removeSocketListeners() {
    if (_socketService.isReady) {
      _socketService.removeFriendRequestObserver(_onFriendRequestReceived);
    }
  }

  /// Callback appelé quand une nouvelle demande d'ami est reçue
  void _onFriendRequestReceived(Map<String, dynamic> data) {
    debugPrint('📱 Nouvelle demande d\'ami reçue en temps réel: $data');
    // Rafraîchir la liste des demandes
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    setState(() => isLoading = true);

    final headers = await AuthService.getAuthorizedHeaders(context: context);
    if (headers == null) return;
    final url = Uri.parse('${ApiConfig.baseUrl}/relations');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      setState(() {
        requests = data.where((rel) =>
            rel['status'] == 'pending' &&
            rel['user2']['_id'] == widget.userId
        ).toList();
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur chargement demandes")),
        );
      }
    }
  }

  Future<void> acceptRequest(String relationId) async {
    final headers = await AuthService.getAuthorizedHeaders(context: context);
    if (headers == null) return;
    final url = Uri.parse('${ApiConfig.baseUrl}/relations/$relationId/accept');
    final res = await http.patch(url, headers: headers);
    if (res.statusCode == 200) {
      fetchRequests(); // refresh la liste
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Demande acceptée !")),
      );
    }
  }

  Future<void> refuseRequest(String relationId) async {
    final headers = await AuthService.getAuthorizedHeaders(context: context);
    if (headers == null) return;
    final url = Uri.parse('${ApiConfig.baseUrl}/relations/$relationId/refuse');
    final res = await http.delete(url, headers: headers);
    if (res.statusCode == 200) {
      // Trouver l'utilisateur refusé pour supprimer son cache
      final refusedRequest = requests.firstWhere(
        (req) => req['_id'] == relationId,
        orElse: () => null,
      );

      if (refusedRequest != null) {
        final userId = refusedRequest['user1']['_id'];
        await _clearUserCache(relationId, userId);
      }

      fetchRequests(); // refresh la liste
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Demande refusée !")),
      );
    }
  }

  /// Supprimer le cache d'un utilisateur refusé
  Future<void> _clearUserCache(String relationId, String userId) async {
    try {
      // Supprimer le cache des messages de cette relation
      await _messagesCacheService.clearRelationCache(relationId);

      // Supprimer le cache du profil de cet utilisateur
      await _profileCacheService.clearUserCache(userId);

      // Supprimer les images en cache de cet utilisateur
      await _imageCacheService.clearUserImages(userId);

      if (kDebugMode) {
        print('🗑️ Cache supprimé pour l\'utilisateur refusé $userId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur suppression cache utilisateur refusé: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? colorScheme.surface,
        title: Text(
          "Demandes d'amis",
          style: theme.appBarTheme.titleTextStyle ?? TextStyle(color: colorScheme.primary),
        ),
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : requests.isEmpty
              ? Center(
                  child: Text(
                    "Aucune demande",
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                )
              : ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, idx) {
                    final rel = requests[idx];
                    final user = rel['user1'];
                    return Card(
                      color: theme.cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primary,
                          child: Icon(Icons.person, color: colorScheme.onPrimary),
                        ),
                        title: Text(
                          user['displayName']?.isNotEmpty == true
                              ? user['displayName']
                              : user['username'],
                          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '@${user['username']}',
                          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.redAccent),
                              onPressed: () => refuseRequest(rel['_id']),
                              tooltip: 'Refuser',
                            ),
                            IconButton(
                              icon: Icon(Icons.check, color: Colors.green),
                              onPressed: () => acceptRequest(rel['_id']),
                              tooltip: 'Accepter',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
