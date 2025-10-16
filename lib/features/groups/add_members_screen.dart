import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/api_config.dart';
import '../../core/service/auth_service.dart';
import '../../core/service/socket_service.dart';

// ✅ AJOUTS
import 'package:silencia/features/chat/chat_service.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';
import 'package:silencia/core/utils/rsa_serrvice.dart';

class AddMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const AddMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  List<dynamic> friends = [];
  List<String> selectedFriends = [];
  bool isLoading = true;
  bool isAdding = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _removeSocketListeners();
    super.dispose();
  }

  /// Configure les listeners socket pour les événements d'amis
  void _setupSocketListeners() {
    final socketService = SocketService();
    if (socketService.isReady) {
      socketService.addFriendRemovedObserver(_onFriendRemoved);
    }
  }

  /// Supprime les listeners socket
  void _removeSocketListeners() {
    final socketService = SocketService();
    if (socketService.isReady) {
      socketService.removeFriendRemovedObserver(_onFriendRemoved);
    }
  }

  /// Callback pour ami supprimé - rafraîchir la liste
  void _onFriendRemoved(Map<String, dynamic> data) {
    if (mounted) {
      _loadFriends(); // Recharger la liste des amis
    }
  }

  Future<void> _loadFriends() async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/relations/friends'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final friendsList = jsonDecode(response.body) as List;
        setState(() {
          friends = friendsList;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _sendGroupLangTo(String userId) async {
    // Récupérer/Créer la map locale du groupe
    Map<String, String>? map = await ChatService.getLangMap('groupLangMap-${widget.groupId}');
    if (map == null) {
      map = LangMapGenerator.generateLangMap();
      await ChatService.saveLangMap('groupLangMap-${widget.groupId}', map);
    }

    final token = await AuthService.getToken();
    final currentUserId = await AuthService.getUserId();
    if (token == null || currentUserId == null) return;

    // Clé publique du destinataire
    final publicKey = await RSAKeyService.fetchPublicKey(userId, token);
    if (publicKey == null) return;

    // Chiffrement hybride de la map
    final langJson = jsonEncode(map);
    final hybrid = RSAKeyService.hybridEncrypt(langJson, publicKey);

    final headers = await AuthService.getAuthorizedHeaders();
    if (headers == null) return;

    // Envoi au serveur (stockage temporaire chiffré)
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/groups/${widget.groupId}/lang/send'),
      headers: headers,
      body: jsonEncode({
        'encrypted': hybrid['encrypted'],
        'iv': hybrid['iv'],
        'encryptedKey': hybrid['encryptedKey'],
        'from': currentUserId,
        'to': userId,
      }),
    );
  }

  Future<void> _addSelectedMembers() async {
    if (selectedFriends.isEmpty || isAdding) return;

    setState(() {
      isAdding = true;
    });

    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      // Ajouter chaque ami sélectionné + lui pousser la langue
      for (String friendId in selectedFriends) {
        final res = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/groups/${widget.groupId}/add-member'),
          headers: headers,
          body: jsonEncode({'userId': friendId}),
        );

        if (res.statusCode == 200) {
          // ✅ Partager la langue à ce nouvel utilisateur
          await _sendGroupLangTo(friendId);
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedFriends.length} membre(s) ajouté(s) au groupe'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l\'ajout des membres')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isAdding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ajouter des membres'),
            Text(
              widget.groupName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          if (selectedFriends.isNotEmpty)
            TextButton(
              onPressed: isAdding ? null : _addSelectedMembers,
              child: isAdding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Ajouter (${selectedFriends.length})',
                      style: const TextStyle(color: Colors.white),
                    ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : friends.isEmpty
              ? _buildEmptyState()
              : _buildFriendsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun ami disponible',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez des amis pour pouvoir\nles inviter dans vos groupes',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    return Column(
      children: [
        if (selectedFriends.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${selectedFriends.length} ami(s) sélectionné(s)',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return _buildFriendTile(friend);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> friend) {
    final friendId = friend['_id'];
    final friendName = friend['displayName'] ?? friend['username'] ?? 'Ami';
    final isSelected = selectedFriends.contains(friendId);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
        child: Text(
          friendName.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        friendName,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text('@${friend['username'] ?? ''}'),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              selectedFriends.add(friendId);
            } else {
              selectedFriends.remove(friendId);
            }
          });
        },
        activeColor: Colors.blue,
      ),
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedFriends.remove(friendId);
          } else {
            selectedFriends.add(friendId);
          }
        });
      },
    );
  }
}
