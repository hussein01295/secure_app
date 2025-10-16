import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/config/api_config.dart';
import '../../../core/service/auth_service.dart';
import '../../../core/service/socket_service.dart';

/// Widget pour afficher et gérer les réactions des messages de groupe
class GroupMessageReactionsWidget extends StatefulWidget {
  final String messageId;
  final String groupId;
  final VoidCallback? onReactionChanged;

  const GroupMessageReactionsWidget({
    super.key,
    required this.messageId,
    required this.groupId,
    this.onReactionChanged,
  });

  @override
  State<GroupMessageReactionsWidget> createState() => _GroupMessageReactionsWidgetState();
}

class _GroupMessageReactionsWidgetState extends State<GroupMessageReactionsWidget> {
  List<Map<String, dynamic>> reactions = [];
  Map<String, dynamic> reactionSummary = {};
  bool isLoading = true;
  String? currentUserId;
  SocketService? _socketService;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadReactions();
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    // Utiliser le SocketService global s'il existe
    try {
      _socketService = SocketService();

      // Écouter les réactions ajoutées
      _socketService?.socket.on('reactionAdded', (data) {
        if (data != null &&
            data['messageId'] == widget.messageId &&
            data['groupId'] == widget.groupId) {
          debugPrint('🔄 Réaction ajoutée reçue pour ce message: ${data['emoji']}');
          _loadReactions();
        }
      });

      // Écouter les réactions supprimées
      _socketService?.socket.on('reactionRemoved', (data) {
        if (data != null &&
            data['messageId'] == widget.messageId &&
            data['groupId'] == widget.groupId) {
          debugPrint('🔄 Réaction supprimée reçue pour ce message: ${data['emoji']}');
          _loadReactions();
        }
      });
    } catch (e) {
      debugPrint('❌ Erreur initialisation WebSocket réactions: $e');
    }
  }

  @override
  void dispose() {
    // Nettoyer les listeners
    _socketService?.socket.off('reactionAdded');
    _socketService?.socket.off('reactionRemoved');
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    currentUserId = await AuthService.getUserId();
  }

  Future<void> _loadReactions() async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/groups/${widget.groupId}/messages/${widget.messageId}/reactions'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          reactions = List<Map<String, dynamic>>.from(data['reactions'] ?? []);
          
          // Convertir le summary en format utilisable
          final summaryList = List<Map<String, dynamic>>.from(data['summary'] ?? []);
          reactionSummary = {};
          for (var item in summaryList) {
            reactionSummary[item['_id']] = {
              'count': item['count'],
              'users': List<String>.from(item['users'] ?? []),
            };
          }
          
          isLoading = false;
        });
      } else {
        debugPrint('❌ Erreur chargement réactions: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement réactions: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _toggleReaction(String emoji) async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      // Vérifier si l'utilisateur a déjà cette réaction
      final hasReaction = reactions.any((r) => 
        r['emoji'] == emoji && r['userId']['_id'] == currentUserId);

      if (hasReaction) {
        // Supprimer la réaction
        final response = await http.delete(
          Uri.parse('${ApiConfig.baseUrl}/groups/${widget.groupId}/reactions'),
          headers: headers,
          body: jsonEncode({
            'messageId': widget.messageId,
          }),
        );

        if (response.statusCode == 200) {
          await _loadReactions();
          widget.onReactionChanged?.call();
        }
      } else {
        // Ajouter la réaction
        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/groups/${widget.groupId}/reactions'),
          headers: headers,
          body: jsonEncode({
            'messageId': widget.messageId,
            'emoji': emoji,
          }),
        );

        if (response.statusCode == 200) {
          await _loadReactions();
          widget.onReactionChanged?.call();
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur toggle réaction: $e');
    }
  }

  bool _userHasReaction(String emoji) {
    return reactions.any((r) => 
      r['emoji'] == emoji && r['userId']['_id'] == currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (reactionSummary.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(top: 4, bottom: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: reactionSummary.entries.map((entry) {
          final emoji = entry.key;
          final data = entry.value;
          final count = data['count'] as int;
          final hasUserReaction = _userHasReaction(emoji);

          return GestureDetector(
            onTap: () => _toggleReaction(emoji),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hasUserReaction
                    ? Colors.blue.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasUserReaction 
                      ? Colors.blue
                      : Colors.grey.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: TextStyle(fontSize: 14),
                  ),
                  if (count > 1) ...[
                    SizedBox(width: 4),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: hasUserReaction ? Colors.blue : Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Widget pour le picker de réactions rapides dans les groupes
class GroupReactionPicker extends StatelessWidget {
  final Function(String) onReactionSelected;

  const GroupReactionPicker({
    super.key,
    required this.onReactionSelected,
  });

  static const List<String> quickReactions = [
    '👍', '❤️', '😂', '😮', '😢', '😡'
  ];

  static const List<String> allReactions = [
    '👍', '❤️', '😂', '😮', '😢', '😡', '🔥', '👏', '🎉', '💯'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Réactions rapides
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: quickReactions.map((emoji) {
              return GestureDetector(
                onTap: () => onReactionSelected(emoji),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    emoji,
                    style: TextStyle(fontSize: 24),
                  ),
                ),
              );
            }).toList(),
          ),
          
          SizedBox(height: 12),
          
          // Bouton "Plus de réactions"
          GestureDetector(
            onTap: () {
              _showAllReactions(context);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Plus de réactions',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllReactions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choisir une réaction'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 1,
            ),
            itemCount: allReactions.length,
            itemBuilder: (context, index) {
              final emoji = allReactions[index];
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  onReactionSelected(emoji);
                },
                child: Container(
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler'),
          ),
        ],
      ),
    );
  }
}
