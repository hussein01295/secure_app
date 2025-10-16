import 'package:flutter/material.dart';
import 'package:silencia/core/theme/app_theme.dart';
import 'package:silencia/core/theme/theme_manager.dart';

/// Widget pour afficher une bulle de message simple
class MessageBubble extends StatelessWidget {
  final String text;
  final bool fromMe;
  final String? time;
  final bool isRead;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const MessageBubble({
    super.key,
    required this.text,
    required this.fromMe,
    this.time,
    this.isRead = false,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final themeManager = globalThemeManager;
    final bubbleColor = themeManager.getMessageBubbleColor(fromMe);
    final textColor = themeManager.getTextColor(fromMe);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: EdgeInsets.only(
          left: fromMe ? 50 : 0,
          right: fromMe ? 0 : 50,
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment: fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(fromMe ? 20 : 5),
                  bottomRight: Radius.circular(fromMe ? 5 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
            if (time != null || (fromMe && isRead))
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (time != null)
                      Text(
                        time!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    if (fromMe && isRead) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all,
                        size: 16,
                        color: Colors.blue[600],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget pour afficher une bulle de message système
class SystemMessageBubble extends StatelessWidget {
  final String text;
  final IconData? icon;

  const SystemMessageBubble({
    super.key,
    required this.text,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final themeManager = globalThemeManager;
    final isDark = themeManager.currentTheme == AppThemeMode.dark;
    final isNeon = themeManager.currentTheme == AppThemeMode.neon;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 50),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
              ? (isNeon ? Colors.cyan.withOpacity(0.1) : Colors.grey[800])
              : Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
            border: isNeon
              ? Border.all(color: Colors.cyan.withOpacity(0.3))
              : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isDark
                    ? (isNeon ? Colors.cyan : Colors.grey[400])
                    : Colors.grey[600],
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                      ? (isNeon ? Colors.cyan : Colors.grey[300])
                      : Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget pour afficher une bulle de message avec média
class MediaMessageBubble extends StatelessWidget {
  final Widget mediaWidget;
  final String? caption;
  final bool fromMe;
  final String? time;
  final bool isRead;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MediaMessageBubble({
    super.key,
    required this.mediaWidget,
    this.caption,
    required this.fromMe,
    this.time,
    this.isRead = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final themeManager = globalThemeManager;
    final bubbleColor = themeManager.getMessageBubbleColor(fromMe);
    final textColor = themeManager.getTextColor(fromMe);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: EdgeInsets.only(
          left: fromMe ? 50 : 0,
          right: fromMe ? 0 : 50,
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment: fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(fromMe ? 20 : 5),
                  bottomRight: Radius.circular(fromMe ? 5 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: caption != null ? Radius.zero : Radius.circular(fromMe ? 20 : 5),
                      bottomRight: caption != null ? Radius.zero : Radius.circular(fromMe ? 5 : 20),
                    ),
                    child: mediaWidget,
                  ),
                  if (caption != null && caption!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        caption!,
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (time != null || (fromMe && isRead))
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (time != null)
                      Text(
                        time!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    if (fromMe && isRead) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all,
                        size: 16,
                        color: Colors.blue[600],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget pour afficher une bulle de message en cours de chargement
class LoadingMessageBubble extends StatelessWidget {
  final bool fromMe;

  const LoadingMessageBubble({
    super.key,
    required this.fromMe,
  });

  @override
  Widget build(BuildContext context) {
    final themeManager = globalThemeManager;
    final bubbleColor = themeManager.getMessageBubbleColor(fromMe);

    return Container(
      margin: EdgeInsets.only(
        left: fromMe ? 50 : 0,
        right: fromMe ? 0 : 50,
        bottom: 4,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(fromMe ? 20 : 5),
            bottomRight: Radius.circular(fromMe ? 5 : 20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  fromMe ? Colors.white : Colors.grey[600]!,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Envoi en cours...',
              style: TextStyle(
                fontSize: 14,
                color: fromMe ? Colors.white : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
