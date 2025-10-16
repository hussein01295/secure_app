import 'dart:async';
import 'package:flutter/material.dart';
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/features/chat/widgets/chat_widgets.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'group_message_reactions_widget.dart';

// ✅ Utilitaire pour (dé)coder le texte via la langue du groupe
import 'package:silencia/features/chat/chat_utils.dart';

/// Widget pour afficher les messages d'un groupe avec toutes les fonctionnalités
class GroupMessagesList extends StatefulWidget {
  final List<dynamic> messages;
  final String groupId;
  final ScrollController? scrollController;
  final Function(String content, String? replyToId)? onSendMessage;

  // ✅ Ajouts pour la langue de groupe
  final Map<String, String>? langMap;
  final bool estTraduit;

  const GroupMessagesList({
    super.key,
    required this.messages,
    required this.groupId,
    this.scrollController,
    this.onSendMessage,
    this.langMap,
    this.estTraduit = false,
  });

  @override
  State<GroupMessagesList> createState() => _GroupMessagesListState();
}

class _GroupMessagesListState extends State<GroupMessagesList> with TickerProviderStateMixin {
  final Map<int, bool> translatedBubbles = {};
  OverlayEntry? _menuOverlay;
  AnimationController? _bubbleAnimController;
  Map<String, dynamic>? replyingTo;

  @override
  void initState() {
    super.initState();
    _bubbleAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _closeMenu();
    _bubbleAnimController?.dispose();
    super.dispose();
  }

  void _toggleBubbleTranslation(int index) {
    setState(() => translatedBubbles[index] = !(translatedBubbles[index] ?? false));
  }

  // ✅ Méthode pour ajouter une réaction depuis le menu contextuel
  Future<void> _addReactionFromMenu(String messageId, String emoji) async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      // Construction du payload pour les groupes
      final body = <String, dynamic>{
        'messageId': messageId,
        'emoji': emoji,
        'groupId': widget.groupId, // 👈 important pour les groupes
      };

      // Utiliser directement l'endpoint spécifique aux groupes
      debugPrint('🔍 Ajout réaction groupe - messageId: $messageId, emoji: $emoji, groupId: ${widget.groupId}');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/groups/${widget.groupId}/reactions'),
        headers: headers,
        body: jsonEncode({
          'messageId': messageId,
          'emoji': emoji,
        }),
      );

      debugPrint('🔍 Réponse réaction groupe - Status: ${response.statusCode}');
      debugPrint('🔍 Réponse réaction groupe - Body: ${response.body}');

      if (response.statusCode == 200) {
        _closeMenu();
        setState(() {}); // Rafraîchir l'affichage
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Réaction $emoji ajoutée !'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        // Debug: afficher plus d'infos sur l'erreur
        debugPrint('❌ Erreur réaction groupe - Status: ${response.statusCode}');
        debugPrint('❌ Erreur réaction groupe - Body: ${response.body}');
        debugPrint('❌ Payload envoyé: ${jsonEncode(body)}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Échec de la réaction (${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'ajout de la réaction')),
        );
      }
    }
  }

  void _replyToMessage(int index) {
    final msg = widget.messages[index];
    final raw = msg['content'] ?? '';
    final decoded = (widget.langMap != null && raw is String && raw.isNotEmpty)
        ? ChatUtils.applyReverseMap(raw, widget.langMap!)
        : raw;
    final shown = (widget.estTraduit) ? decoded : raw;

    setState(() {
      replyingTo = {
        'id': msg['_id'],
        'content': shown,
        'sender': msg['sender']?['displayName'] ?? msg['sender']?['username'] ?? 'Quelqu\'un',
        'fromMe': msg['fromMe'] == true,
      };
    });

    _closeMenu();

    if (widget.scrollController?.hasClients == true) {
      widget.scrollController?.animateTo(
        widget.scrollController!.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _deleteMessage(int index) async {
    final msg = widget.messages[index];
    final messageId = msg['_id'];
    if (messageId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de supprimer ce message')),
        );
      }
      return;
    }

    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/groups/${widget.groupId}/messages/$messageId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        setState(() {
          widget.messages.removeWhere((m) => m['_id'] == messageId);
        });
        _closeMenu();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message supprimé')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de la suppression')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur réseau')),
        );
      }
    }
  }

  void _cancelReply() => setState(() => replyingTo = null);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                left: BorderSide(
                  color: replyingTo!['fromMe'] ? Colors.blue : Colors.green,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.reply, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Réponse à ${replyingTo!['sender']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: replyingTo!['fromMe'] ? Colors.blue : Colors.green,
                        ),
                      ),
                      Text(
                        replyingTo!['content'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _cancelReply,
                  icon: Icon(Icons.close, size: 20, color: Colors.grey[600]),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),

        // ✅ Nouveaux en BAS (ordre chronologique)
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: widget.messages.length,
            itemBuilder: (context, index) {
              final msg = widget.messages[index];
              return _buildGroupMessageBubble(msg, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupMessageBubble(Map<String, dynamic> message, int index) {
    final sender = message['sender'];
    final raw = message['content'] ?? '';
    final decoded = (widget.langMap != null && raw is String && raw.isNotEmpty)
        ? ChatUtils.applyReverseMap(raw, widget.langMap!)
        : raw;

    final isBubbleTranslated = translatedBubbles[index] ?? false;
    final showTranslated = widget.estTraduit || isBubbleTranslated;
    final content = showTranslated ? decoded : raw;

    final senderName = sender?['displayName'] ?? sender?['username'] ?? 'Inconnu';
    final timestamp = DateTime.tryParse(message['createdAt'] ?? '');
    final isFromMe = message['fromMe'] == true;

    return GestureDetector(
      onLongPress: () => _showBubbleMenu(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isFromMe)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isFromMe ? Colors.blue[500] : Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                content,
                style: TextStyle(
                  color: isFromMe ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),

            // ✅ Widget de réactions spécifique aux groupes
            GroupMessageReactionsWidget(
              messageId: message['_id'] ?? '',
              groupId: widget.groupId,
              onReactionChanged: () {
                // Optionnel : rafraîchir les données si nécessaire
              },
            ),

            if (timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                child: Text(
                  _formatTime(timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showBubbleMenu(int index) {
    final msg = widget.messages[index];
    final raw = msg['content'] ?? '';
    final decoded = (widget.langMap != null && raw is String && raw.isNotEmpty)
        ? ChatUtils.applyReverseMap(raw, widget.langMap!)
        : raw;

    final currentlyShown = widget.estTraduit ? decoded : raw;
    final isBubbleTranslated = translatedBubbles[index] ?? false;
    final menuText = isBubbleTranslated ? decoded : currentlyShown;



    _menuOverlay = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: GestureDetector(
          onTap: _closeMenu,
          child: Container(
            color: Colors.black26,
            child: Center(
              child: BubbleContextMenu(
                fromMe: msg['fromMe'] == true,
                text: menuText,
                isTranslated: isBubbleTranslated,
                messageId: msg['_id'],
                relationId: widget.groupId, // pas utilisé par le backend du menu, mais laissé pour compat
                onTranslate: () {
                  _toggleBubbleTranslation(index);
                  _closeMenu();
                },
                onClose: _closeMenu,
                onReaction: (emoji) => _addReactionFromMenu(msg['_id'], emoji), // ✅ Réactions via menu
                onReply: () => _replyToMessage(index),
                onDelete: () => _deleteMessage(index),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_menuOverlay!);
  }

  void _closeMenu() {
    _menuOverlay?.remove();
    _menuOverlay = null;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'maintenant';
    }
  }
}

/// Barre de saisie
class GroupInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final Map<String, dynamic>? replyingTo;
  final VoidCallback? onCancelReply;

  const GroupInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.isSending = false,
    this.replyingTo,
    this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () {
              showMediaPicker(
                context,
                onMediaSelected: (file, type, caption) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Upload de médias en cours de développement')),
                  );
                },
              );
            },
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Tapez votre message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: null,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: isSending ? null : onSend,
          ),
        ],
      ),
    );
  }
}
