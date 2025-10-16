import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/service/socket_service.dart';

/// Widget pour afficher et gérer les réactions aux messages
class MessageReactionsWidget extends StatefulWidget {
  final String messageId;

  /// ⚠️ Pour les DM (relation) → laissez `relationId`.
  /// ⚠️ Pour les groupes → passez `groupId` **et** vous pouvez ignorer relationId.
  final String? relationId; // reste compatible avec l’existant
  final String? groupId;     // 👈 nouveau : support groupes

  final Map<String, dynamic>? initialReactions;
  final VoidCallback? onReactionChanged;

  const MessageReactionsWidget({
    super.key,
    required this.messageId,
    this.relationId,
    this.groupId,
    this.initialReactions,
    this.onReactionChanged,
  });

  @override
  State<MessageReactionsWidget> createState() => _MessageReactionsWidgetState();
}

class _MessageReactionsWidgetState extends State<MessageReactionsWidget> {
  Map<String, ReactionData> reactions = {};
  bool isLoading = false;
  SocketService? _socketService;

  // Emojis disponibles pour les réactions
  static const List<String> availableEmojis = [
    '👍', '❤️', '😂', '😮', '😢', '😡', '🔥', '👏', '🎉', '💯'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialReactions != null) {
      _parseReactions(widget.initialReactions!);
    } else {
      _loadReactions();
    }
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    try {
      _socketService = SocketService();

      // Écouter les réactions ajoutées
      _socketService?.socket.on('reactionAdded', (data) {
        if (data != null && data['messageId'] == widget.messageId) {
          // Vérifier si c'est pour la bonne relation/groupe
          bool isForThisWidget = false;
          if (widget.relationId != null && data['relationId'] == widget.relationId) {
            isForThisWidget = true;
          } else if (widget.groupId != null && data['groupId'] == widget.groupId) {
            isForThisWidget = true;
          }

          if (isForThisWidget) {
            debugPrint('🔄 Réaction ajoutée reçue pour ce message: ${data['emoji']}');
            _loadReactions();
          }
        }
      });

      // Écouter les réactions supprimées
      _socketService?.socket.on('reactionRemoved', (data) {
        if (data != null && data['messageId'] == widget.messageId) {
          // Vérifier si c'est pour la bonne relation/groupe
          bool isForThisWidget = false;
          if (widget.relationId != null && data['relationId'] == widget.relationId) {
            isForThisWidget = true;
          } else if (widget.groupId != null && data['groupId'] == widget.groupId) {
            isForThisWidget = true;
          }

          if (isForThisWidget) {
            debugPrint('🔄 Réaction supprimée reçue pour ce message: ${data['emoji']}');
            _loadReactions();
          }
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

  void _parseReactions(Map<String, dynamic> reactionsData) {
    final List<dynamic> reactionsList = reactionsData['reactions'] ?? [];
    reactions.clear();

    for (final reaction in reactionsList) {
      final emoji = reaction['emoji'] as String;
      reactions[emoji] = ReactionData(
        emoji: emoji,
        count: reaction['count'] ?? 0,
        hasUserReacted: reaction['hasUserReacted'] ?? false,
        users: List<String>.from(
          reaction['users']?.map((u) => u['displayName'] ?? u['username']) ?? [],
        ),
      );
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadReactions() async {
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/reactions/${widget.messageId}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _parseReactions(data);
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des réactions: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _addReaction(String emoji) async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      // Construction du payload en fonction du contexte
      final body = <String, dynamic>{
        'messageId': widget.messageId,
        'emoji': emoji,
        if (widget.groupId != null) 'groupId': widget.groupId,        // 👈 groupe
        if (widget.groupId == null && widget.relationId != null)
          'relationId': widget.relationId,                             // 👈 DM
      };

      // Optimistic update
      setState(() {
        if (reactions.containsKey(emoji)) {
          if (reactions[emoji]!.hasUserReacted) {
            reactions[emoji] = reactions[emoji]!.copyWith(
              count: reactions[emoji]!.count - 1,
              hasUserReacted: false,
            );
            if (reactions[emoji]!.count <= 0) {
              reactions.remove(emoji);
            }
          } else {
            reactions[emoji] = reactions[emoji]!.copyWith(
              count: reactions[emoji]!.count + 1,
              hasUserReacted: true,
            );
          }
        } else {
          reactions[emoji] = ReactionData(
            emoji: emoji,
            count: 1,
            hasUserReacted: true,
            users: const ['Vous'],
          );
        }
      });

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/reactions'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        // Rollback en cas d'erreur
        await _loadReactions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Échec de la réaction')),
          );
        }
      } else {
        widget.onReactionChanged?.call();
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'ajout de réaction: $e');
      await _loadReactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec de la réaction')),
        );
      }
    }
  }



  void _showReactionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choisir une réaction',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 15,
              runSpacing: 15,
              children: availableEmojis.map((emoji) {
                final hasReacted = reactions[emoji]?.hasUserReacted ?? false;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _addReaction(emoji);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: hasReacted ? Colors.blue.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(25),
                      border: hasReacted ? Border.all(color: Colors.blue, width: 2) : null,
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty && !isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          // Afficher les réactions existantes
          ...reactions.values.map((reaction) => _buildReactionChip(reaction)),

          // Bouton pour ajouter une réaction
          GestureDetector(
            onTap: _showReactionPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.add,
                size: 16,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionChip(ReactionData reaction) {
    return GestureDetector(
      onTap: () => _addReaction(reaction.emoji),
      onLongPress: () => _showReactionDetails(reaction),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: reaction.hasUserReacted
              ? Colors.blue.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: reaction.hasUserReacted ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              reaction.emoji,
              style: const TextStyle(fontSize: 14),
            ),
            if (reaction.count > 1) ...[
              const SizedBox(width: 4),
              Text(
                '${reaction.count}',
                style: TextStyle(
                  fontSize: 12,
                  color: reaction.hasUserReacted ? Colors.blue : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReactionDetails(ReactionData reaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(reaction.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text('${reaction.count} réaction${reaction.count > 1 ? 's' : ''}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: reaction.users
              .map((user) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(user),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

/// Classe pour représenter les données d'une réaction
class ReactionData {
  final String emoji;
  final int count;
  final bool hasUserReacted;
  final List<String> users;

  const ReactionData({
    required this.emoji,
    required this.count,
    required this.hasUserReacted,
    required this.users,
  });

  ReactionData copyWith({
    String? emoji,
    int? count,
    bool? hasUserReacted,
    List<String>? users,
  }) {
    return ReactionData(
      emoji: emoji ?? this.emoji,
      count: count ?? this.count,
      hasUserReacted: hasUserReacted ?? this.hasUserReacted,
      users: users ?? this.users,
    );
  }
}
