import 'package:flutter/material.dart';
import 'package:silencia/core/theme/app_theme.dart';
import 'package:silencia/core/theme/theme_manager.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';
import 'message_bubble_widget.dart';
import '../ui/typing_indicator.dart';
import '../media/encrypted_image_widget.dart';
import '../media/encrypted_video_widget.dart';
import '../media/encrypted_voice_widget.dart';
import '../media/video_message_widget.dart';
import '../media/authenticated_image_widget.dart';

/// Widget pour afficher la liste des messages du chat
/// Version simplifiée et modulaire de MessagesList
class MessageListWidget extends StatefulWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> messages;
  final Map<String, String>? langMap;
  final Map<String, Map<String, String>>? multiLanguages;
  final bool canWrite;
  final bool estTraduit;
  final bool isContactTyping;
  final bool isMultiLanguageMode;
  final String? mediaKey;
  final String relationId;
  final String contactName;
  final String Function(String, Map<String, String>) applyReverseMap;
  final Function(String, Map<String, dynamic>) onMessageTap;
  final Function(String, Map<String, dynamic>) onMessageLongPress;

  const MessageListWidget({
    super.key,
    required this.scrollController,
    required this.messages,
    this.langMap,
    this.multiLanguages,
    required this.canWrite,
    required this.estTraduit,
    required this.isContactTyping,
    required this.isMultiLanguageMode,
    this.mediaKey,
    required this.relationId,
    required this.contactName,
    required this.applyReverseMap,
    required this.onMessageTap,
    required this.onMessageLongPress,
  });

  @override
  State<MessageListWidget> createState() => _MessageListWidgetState();
}

class _MessageListWidgetState extends State<MessageListWidget> {
  @override
  Widget build(BuildContext context) {
    final displayedMessages = List<Map<String, dynamic>>.from(widget.messages);
    
    // Ajouter l'indicateur de frappe si nécessaire
    if (widget.isContactTyping) {
      displayedMessages.add({'isTypingIndicator': true});
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: displayedMessages.length,
      itemBuilder: (context, index) {
        final message = displayedMessages[index];
        
        // Indicateur de frappe
        if (message['isTypingIndicator'] == true) {
          return Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: TypingIndicator(contactName: widget.contactName),
          );
        }

        return _buildMessageItem(message, index);
      },
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> message, int index) {
    final messageType = message['messageType'] ?? 'text';
    final fromMe = message['fromMe'] ?? false;
    final time = message['time'];
    final isRead = message['isRead'] ?? false;

    // Messages système
    if (messageType == 'system') {
      return SystemMessageBubble(
        text: message['text'] ?? '',
        icon: Icons.info_outline,
      );
    }

    // Messages temporaires (en cours d'envoi)
    if (message['metadata']?['isTemporary'] == true) {
      return LoadingMessageBubble(fromMe: fromMe);
    }

    switch (messageType) {
      case 'text':
        return _buildTextMessage(message, fromMe, time, isRead);
      case 'image':
        return _buildImageMessage(message, fromMe, time, isRead);
      case 'video':
        return _buildVideoMessage(message, fromMe, time, isRead);
      case 'voice':
      case 'audio':
        return _buildVoiceMessage(message, fromMe, time, isRead);
      default:
        return _buildTextMessage(message, fromMe, time, isRead);
    }
  }

  Widget _buildTextMessage(Map<String, dynamic> message, bool fromMe, String? time, bool isRead) {
    String displayText = message['text'] ?? message['content'] ?? '';
    
    // Appliquer la traduction si activée
    if (widget.estTraduit && widget.canWrite) {
      displayText = _getTranslatedText(message);
    }

    return MessageBubble(
      text: displayText,
      fromMe: fromMe,
      time: time,
      isRead: isRead,
      onTap: () => widget.onMessageTap(message['id'], message),
      onLongPress: () => widget.onMessageLongPress(message['id'], message),
    );
  }

  Widget _buildImageMessage(Map<String, dynamic> message, bool fromMe, String? time, bool isRead) {
    final imageUrl = message['content'] ?? '';
    final caption = message['metadata']?['caption'];
    final isEncrypted = message['encrypted'] == true || message['encrypted'] == 'true';

    Widget imageWidget;
    if (isEncrypted && widget.relationId.isNotEmpty) {
      imageWidget = EncryptedImageWidget(
        imageUrl: imageUrl,
        relationId: widget.relationId,
        width: 200,
      );
    } else {
      imageWidget = AuthenticatedImage(
        imageUrl: imageUrl,
        width: 200,
        relationId: widget.relationId,
      );
    }

    return MediaMessageBubble(
      mediaWidget: imageWidget,
      caption: caption,
      fromMe: fromMe,
      time: time,
      isRead: isRead,
      onTap: () => widget.onMessageTap(message['id'], message),
      onLongPress: () => widget.onMessageLongPress(message['id'], message),
    );
  }

  Widget _buildVideoMessage(Map<String, dynamic> message, bool fromMe, String? time, bool isRead) {
    final videoUrl = message['content'] ?? '';
    final caption = message['metadata']?['caption'];
    final isEncrypted = message['encrypted'] == true || message['encrypted'] == 'true';

    Widget videoWidget;
    if (isEncrypted && widget.relationId.isNotEmpty) {
      videoWidget = EncryptedVideoWidget(
        videoUrl: videoUrl,
        relationId: widget.relationId,
        width: 200,
        height: 150,
      );
    } else {
      videoWidget = VideoMessageWidget(
        videoUrl: videoUrl,
        width: 200,
        isFromMe: fromMe,
        time: time ?? '',
        isRead: isRead,
      );
    }

    return MediaMessageBubble(
      mediaWidget: videoWidget,
      caption: caption,
      fromMe: fromMe,
      time: time,
      isRead: isRead,
      onTap: () => widget.onMessageTap(message['id'], message),
      onLongPress: () => widget.onMessageLongPress(message['id'], message),
    );
  }

  Widget _buildVoiceMessage(Map<String, dynamic> message, bool fromMe, String? time, bool isRead) {
    final audioUrl = message['content'] ?? '';
    final metadata = message['metadata'];
    final duration = metadata is Map ? (metadata['duration'] ?? 0) : 0;
    final isEncrypted = message['encrypted'] == true || message['encrypted'] == 'true';

    // Vérification de sécurité
    if (audioUrl.isEmpty) {
      return MediaMessageBubble(
        mediaWidget: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error, color: fromMe ? Colors.white : Colors.red),
              const SizedBox(width: 8),
              Text(
                'Erreur: fichier manquant',
                style: TextStyle(
                  color: fromMe ? Colors.white : Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        fromMe: fromMe,
        time: time,
        isRead: isRead,
        onTap: () => widget.onMessageTap(message['id'], message),
        onLongPress: () => widget.onMessageLongPress(message['id'], message),
      );
    }

    Widget voiceWidget;
    if (isEncrypted && widget.relationId.isNotEmpty) {
      voiceWidget = EncryptedVoiceWidget(
        voiceUrl: audioUrl,
        relationId: widget.relationId,
        duration: duration is int ? duration : int.tryParse(duration.toString()) ?? 0,
        isFromMe: fromMe,
      );
    } else {
      // Widget simple pour audio non chiffré
      voiceWidget = Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, color: fromMe ? Colors.white : Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              '${duration}s',
              style: TextStyle(
                color: fromMe ? Colors.white : Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return MediaMessageBubble(
      mediaWidget: voiceWidget,
      fromMe: fromMe,
      time: time,
      isRead: isRead,
      onTap: () => widget.onMessageTap(message['id'], message),
      onLongPress: () => widget.onMessageLongPress(message['id'], message),
    );
  }

  String _getTranslatedText(Map<String, dynamic> message) {
    final content = message['content'] ?? message['text'] ?? '';
    final encryptedAAD = message['encryptedAAD'];
    final messageType = message['messageType'] ?? 'text';

    // ⚠️ IMPORTANT: Ne PAS traduire les messages média (voice, image, video, audio)
    // car 'content' contient le chemin du fichier, pas du texte
    if (messageType == 'voice' || messageType == 'audio' || messageType == 'image' || messageType == 'video') {
      return content;
    }

    if (!widget.canWrite) {
      return content;
    }

    try {
      if (widget.mediaKey == null) {
        return '[Clé de déchiffrement manquante]';
      }

      if (encryptedAAD != null && widget.isMultiLanguageMode && widget.multiLanguages != null) {
        // Mode multi-langues avec AAD chiffré
        try {
          final decodedText = MultiLanguageManager.decodeMessage(
            content,
            encryptedAAD,
            widget.multiLanguages!,
            widget.mediaKey!,
            autoRepairLanguages: true,
          );
          return decodedText;
        } catch (e) {
          return '[Erreur de décodage: $e]';
        }
      } else if (encryptedAAD == null && widget.langMap != null) {
        // Mode ancien (1 langue) - SEULEMENT pour messages sans AAD
        return widget.applyReverseMap(content, widget.langMap!);
      }

      return content;
    } catch (e) {
      return '[Erreur de traduction]';
    }
  }
}

/// Widget simple pour afficher un message de chargement
class LoadingMessagesWidget extends StatelessWidget {
  const LoadingMessagesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = globalThemeManager;
    final isDark = themeManager.currentTheme == AppThemeMode.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? Colors.white : Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement des messages...',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget pour afficher un message d'erreur
class ErrorMessagesWidget extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const ErrorMessagesWidget({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final themeManager = globalThemeManager;
    final isDark = themeManager.currentTheme == AppThemeMode.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: isDark ? Colors.red[400] : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ],
      ),
    );
  }
}
