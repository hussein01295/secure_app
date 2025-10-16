import 'package:flutter/material.dart';

/// Widget pour afficher la barre de réponse comme Instagram
class ReplyBarWidget extends StatelessWidget {
  final Map<String, dynamic> replyingTo;
  final VoidCallback onCancel;

  const ReplyBarWidget({
    super.key,
    required this.replyingTo,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final senderName = replyingTo['sender'] ?? 'Quelqu\'un';
    final messageText = replyingTo['text'] ?? '';
    final isFromMe = replyingTo['fromMe'] ?? false;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        border: Border(
          left: BorderSide(
            color: isFromMe ? Colors.blue : Colors.green,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          // Icône de réponse
          Icon(
            Icons.reply,
            size: 16,
            color: isDark ? Colors.white70 : Colors.grey[600],
          ),
          SizedBox(width: 8),
          
          // Contenu de la réponse
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nom de l'expéditeur
                Text(
                  'Réponse à $senderName',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isFromMe ? Colors.blue : Colors.green,
                  ),
                ),
                SizedBox(height: 2),
                
                // Aperçu du message
                Text(
                  messageText,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Bouton d'annulation
          IconButton(
            onPressed: onCancel,
            icon: Icon(
              Icons.close,
              size: 20,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
            padding: EdgeInsets.all(4),
            constraints: BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget pour afficher un message avec sa réponse
class MessageWithReplyWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final Map<String, dynamic>? replyTo;
  final bool isFromMe;
  final VoidCallback? onReplyTap;

  const MessageWithReplyWidget({
    super.key,
    required this.message,
    this.replyTo,
    required this.isFromMe,
    this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Afficher la réponse si elle existe
        if (replyTo != null) ...[
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            margin: EdgeInsets.only(
              left: isFromMe ? 50 : 0,
              right: isFromMe ? 0 : 50,
              bottom: 4,
            ),
            child: GestureDetector(
              onTap: onReplyTap,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: replyTo!['fromMe'] == true ? Colors.blue : Colors.green,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      replyTo!['sender'] ?? 'Quelqu\'un',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: replyTo!['fromMe'] == true ? Colors.blue : Colors.green,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      replyTo!['text'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        
        // Message principal
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isFromMe 
                ? (isDark ? Colors.blue[700] : Colors.blue[500])
                : (isDark ? Colors.grey[700] : Colors.grey[200]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            message['text'] ?? message['content'] ?? '',
            style: TextStyle(
              color: isFromMe 
                  ? Colors.white 
                  : (isDark ? Colors.white : Colors.black87),
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

/// Fonction utilitaire pour créer un message de réponse
Map<String, dynamic> createReplyMessage({
  required String content,
  required String senderId,
  required String receiverId,
  required String relationId,
  Map<String, dynamic>? replyTo,
}) {
  return {
    'content': content,
    'sender': senderId,
    'receiver': receiverId,
    'relationId': relationId,
    'messageType': 'text',
    'replyTo': replyTo?['id'],
    'metadata': {
      'replyToContent': replyTo?['text'],
      'replyToSender': replyTo?['sender'],
    },
  };
}
