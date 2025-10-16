import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../core/config/api_config.dart';
import '../../core/service/auth_service.dart';
import '../../core/service/groups_cache_service.dart';

// ✅ AJOUTS
import 'package:silencia/core/utils/lang_map_generator.dart';
import 'package:silencia/features/chat/chat_service.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<dynamic> groups = [];
  bool isLoading = true;
  bool _isOfflineMode = false;
  String searchQuery = '';
  final GroupsCacheService _cacheService = GroupsCacheService();

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      // 1. Charger d'abord depuis le cache
      final cachedData = await _cacheService.getGroups();
      if (cachedData != null) {
        if (!mounted) return;
        setState(() {
          groups = List<dynamic>.from(cachedData['groups'] ?? []);
          isLoading = false;
          _isOfflineMode = false;
        });

        if (kDebugMode) {
          print('💾 Groupes chargés depuis le cache: ${groups.length} groupes');
        }

        // Si on a des données du cache, on peut s'arrêter là
        // La synchronisation se fera en arrière-plan
        if (!cachedData.containsKey('fromFallback')) {
          _syncGroupsInBackground();
          return;
        }
      }

      // 2. Si pas de cache ou fallback, essayer le serveur
      await _loadGroupsFromServer();
    } catch (e) {
      if (kDebugMode) print('❌ Erreur _loadGroups: $e');

      // En cas d'erreur, utiliser les données par défaut
      final defaultData = _cacheService.getDefaultGroupsData();
      if (!mounted) return;
      setState(() {
        groups = List<dynamic>.from(defaultData['groups'] ?? []);
        isLoading = false;
        _isOfflineMode = true;
      });
    }
  }

  Future<void> _loadGroupsFromServer() async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/groups/my-groups'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverGroups = data['groups'] ?? [];

        if (!mounted) return;
        setState(() {
          groups = serverGroups;
          isLoading = false;
          _isOfflineMode = false;
        });

        // Sauvegarder en cache pour la prochaine fois
        await _cacheService.saveGroups(List<Map<String, dynamic>>.from(serverGroups));

        if (kDebugMode) {
          print('🌐 Groupes chargés depuis le serveur: ${groups.length} groupes');
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur serveur _loadGroupsFromServer: $e');

      // En cas d'erreur serveur, essayer le cache ou fallback
      final cachedData = await _cacheService.getGroups();
      if (cachedData != null) {
        if (!mounted) return;
        setState(() {
          groups = List<dynamic>.from(cachedData['groups'] ?? []);
          isLoading = false;
          _isOfflineMode = true;
        });
      } else {
        final defaultData = _cacheService.getDefaultGroupsData();
        if (!mounted) return;
        setState(() {
          groups = List<dynamic>.from(defaultData['groups'] ?? []);
          isLoading = false;
          _isOfflineMode = true;
        });
      }
    }
  }

  Future<void> _syncGroupsInBackground() async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/groups/my-groups'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverGroups = data['groups'] ?? [];

        // Sauvegarder en cache
        await _cacheService.saveGroups(List<Map<String, dynamic>>.from(serverGroups));

        // Mettre à jour l'interface si les données ont changé
        if (mounted && serverGroups.length != groups.length) {
          setState(() {
            groups = serverGroups;
            _isOfflineMode = false;
          });
        }

        if (kDebugMode) {
          print('🔄 Groupes synchronisés en arrière-plan');
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur sync groupes: $e');
    }
  }

  Future<void> _createGroup() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateGroupDialog(),
    );

    if (result != null) {
      try {
        final headers = await AuthService.getAuthorizedHeaders();
        if (headers == null) return;

        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/groups/create'),
          headers: headers,
          body: jsonEncode(result),
        );

        if (response.statusCode == 201) {
          // ✅ Générer et stocker la langue côté créateur immédiatement
          try {
            final body = jsonDecode(response.body);
            final group = body['group'];
            final groupId = group?['_id'] as String?;
            if (groupId != null) {
              final map = LangMapGenerator.generateLangMap();
              await ChatService.saveLangMap('groupLangMap-$groupId', map);
              // Optionnel: snack d’info
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Langue du groupe générée sur cet appareil.')),
                );
              }
            }
          } catch (_) {}

          _loadGroups(); // Recharger la liste
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Groupe créé avec succès')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erreur lors de la création')),
            );
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la création')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Groupes'),
            if (_isOfflineMode) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: const Text(
                  'Hors ligne',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implémenter la recherche
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Indicateur de mode offline
          if (_isOfflineMode)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8),
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
                      'Mode hors ligne - Groupes en cache',
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

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : groups.isEmpty
                    ? _buildEmptyState()
                    : _buildGroupsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        tooltip: 'Créer un groupe',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun groupe',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Créez votre premier groupe pour\ncommencer à discuter en équipe',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createGroup,
            icon: const Icon(Icons.add),
            label: const Text('Créer un groupe'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsList() {
    return RefreshIndicator(
      onRefresh: _loadGroups,
      child: ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return _buildGroupTile(group);
        },
      ),
    );
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    final memberCount = group['memberCount'] ?? 0;
    final unreadCount = group['unreadCount'] ?? 0;
    final lastMessage = group['lastMessage'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            group['name']?.substring(0, 1).toUpperCase() ?? 'G',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                group['name'] ?? 'Groupe sans nom',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lastMessage != null)
              Text(
                '${lastMessage['sender']?['displayName'] ?? 'Quelqu\'un'}: ${lastMessage['content'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                  fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.people, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '$memberCount membre${memberCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.push('/group-chat', extra: {
            'groupId': group['_id'],
            'groupName': group['name'],
          });
        },
      ),
    );
  }
}

class _CreateGroupDialog extends StatefulWidget {
  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPrivate = false;
  int _maxMembers = 100;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un groupe'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du groupe *',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Groupe privé'),
              subtitle: const Text('Seuls les membres invités peuvent rejoindre'),
              value: _isPrivate,
              onChanged: (value) => setState(() => _isPrivate = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Limite de membres: '),
                Expanded(
                  child: Slider(
                    value: _maxMembers.toDouble(),
                    min: 10,
                    max: 500,
                    divisions: 49,
                    label: _maxMembers.toString(),
                    onChanged: (value) => setState(() => _maxMembers = value.round()),
                  ),
                ),
                Text(_maxMembers.toString()),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () {
                  Navigator.pop(context, {
                    'name': _nameController.text.trim(),
                    'description': _descriptionController.text.trim(),
                    'isPrivate': _isPrivate,
                    'maxMembers': _maxMembers,
                  });
                },
          child: const Text('Créer'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
