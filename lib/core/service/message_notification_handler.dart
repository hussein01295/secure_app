import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Handler pour les notifications de messages
class MessageNotificationHandler {
  static MessageNotificationHandler? _instance;
  static MessageNotificationHandler get instance => _instance ??= MessageNotificationHandler._();
  MessageNotificationHandler._();

  /// Données de notification de message en attente
  Map<String, dynamic>? _pendingMessageNotification;

  /// Traite une notification de message reçue
  void handleMessageNotification(Map<String, dynamic> data) {
    final relationId = data['relationId'];
    final senderId = data['senderId'];
    final senderName = data['senderName'] ?? 'Contact';
    final messageType = data['messageType'] ?? 'text';
    final encryptedContent = data['encryptedContent'];

    debugPrint('📱 Notification de message reçue:');
    debugPrint('   Expéditeur: $senderName');
    debugPrint('   Type: $messageType');
    debugPrint('   Relation: $relationId');

    // Stocker pour traitement ultérieur
    _pendingMessageNotification = {
      'relationId': relationId,
      'senderId': senderId,
      'senderName': senderName,
      'messageType': messageType,
      'encryptedContent': encryptedContent,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    debugPrint('✅ Notification de message stockée pour traitement');
  }

  /// Vérifie et traite les notifications de messages en attente
  Future<void> checkPendingMessageNotifications(BuildContext context) async {
    if (_pendingMessageNotification == null) return;

    final data = _pendingMessageNotification!;
    _pendingMessageNotification = null; // Clear après récupération

    debugPrint('🔔 Traitement de la notification de message en attente');

    // Vérifier si la notification n'est pas trop ancienne (5 minutes max)
    final timestamp = data['timestamp'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ageInMinutes = (now - timestamp) / (1000 * 60);

    if (ageInMinutes > 5) {
      debugPrint('⚠️ Notification trop ancienne (${ageInMinutes.toStringAsFixed(1)} min), ignorée');
      return;
    }

    await _showMessageNotificationDialog(context, data);
  }

  /// Affiche une dialog pour la notification de message
  Future<void> _showMessageNotificationDialog(BuildContext context, Map<String, dynamic> data) async {
    final senderName = data['senderName'] as String;
    final messageType = data['messageType'] as String;
    final relationId = data['relationId'] as String;
    final senderId = data['senderId'] as String;

    // Préparer le contenu selon le type de message
    String messagePreview;
    IconData messageIcon;
    
    switch (messageType) {
      case 'image':
        messagePreview = 'Vous a envoyé une image';
        messageIcon = Icons.image;
        break;
      case 'video':
        messagePreview = 'Vous a envoyé une vidéo';
        messageIcon = Icons.videocam;
        break;
      case 'text':
      default:
        messagePreview = 'Vous a envoyé un message';
        messageIcon = Icons.message;
        break;
    }

    if (!context.mounted) return;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(messageIcon, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nouveau message',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$senderName $messagePreview',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Voulez-vous ouvrir la conversation ?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'dismiss'),
            child: const Text('Plus tard'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'open'),
            icon: const Icon(Icons.chat, size: 18),
            label: const Text('Ouvrir'),
          ),
        ],
      ),
    );

    if (action == 'open') {
      if (!context.mounted) return;
      await _navigateToChat(context, relationId, senderId, senderName);
    }
  }

  /// Navigue vers la conversation
  Future<void> _navigateToChat(BuildContext context, String relationId, String senderId, String senderName) async {
    try {
      debugPrint('🚀 Navigation vers la conversation: $senderName');
      
      // Naviguer vers la conversation
      if (context.mounted) {
        context.go('/chat/$senderId', extra: {
          'contactName': senderName,
          'relationId': relationId,
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la navigation: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ouverture de la conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Affiche une notification toast simple (alternative à la dialog)
  void showMessageToast(BuildContext context, Map<String, dynamic> data) {
    final senderName = data['senderName'] as String;
    final messageType = data['messageType'] as String;

    String messageText;
    switch (messageType) {
      case 'image':
        messageText = '$senderName vous a envoyé une image';
        break;
      case 'video':
        messageText = '$senderName vous a envoyé une vidéo';
        break;
      case 'text':
      default:
        messageText = '$senderName vous a envoyé un message';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.message, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(messageText)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Ouvrir',
          textColor: Colors.white,
          onPressed: () {
            _navigateToChat(
              context,
              data['relationId'],
              data['senderId'],
              data['senderName'],
            );
          },
        ),
      ),
    );
  }

  /// Récupère les données de notification en attente (pour debug)
  Map<String, dynamic>? get pendingNotification => _pendingMessageNotification;

  /// Efface les notifications en attente
  void clearPendingNotifications() {
    _pendingMessageNotification = null;
    debugPrint('🧹 Notifications de messages en attente effacées');
  }
}
