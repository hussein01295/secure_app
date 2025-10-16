import 'package:flutter/material.dart';
import 'package:silencia/core/theme/theme_manager.dart';
import 'package:silencia/core/theme/app_theme.dart';
import 'package:silencia/core/service/animation_service.dart';

// -------- TYPING INDICATOR (LOTTIE ENHANCED) --------
class TypingIndicator extends StatefulWidget {
  final String contactName;
  final bool useLottieAnimation;

  const TypingIndicator({
    super.key,
    required this.contactName,
    this.useLottieAnimation = true,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  final AnimationService _animationService = AnimationService();
  late AnimationController _controller;
  late Animation<double> _dot1, _dot2, _dot3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _dot1 = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );
    _dot2 = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.6, curve: Curves.easeIn)),
    );
    _dot3 = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeIn)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = globalThemeManager;
    final bubbleColor = themeManager.getMessageBubbleColor(false); // Message du contact

    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(14),
          // 🌈 Effets spéciaux pour le thème néon
          border: themeManager.currentTheme == AppThemeMode.neon
            ? Border.all(
                color: AppTheme.neonPurple.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
          boxShadow: themeManager.currentTheme == AppThemeMode.neon
            ? [
                BoxShadow(
                  color: AppTheme.neonPurple.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${widget.contactName} ",
              style: TextStyle(
                color: themeManager.accentColor,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                // 🌈 Ombre pour le thème néon
                shadows: themeManager.currentTheme == AppThemeMode.neon
                  ? [
                      Shadow(
                        color: themeManager.accentColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
              ),
            ),
            // Animation Lottie ou dots classiques
            widget.useLottieAnimation
                ? _animationService.typingIndicatorAnimation(
                    width: 50,
                    height: 20,
                  )
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDot(_dot1.value),
                          const SizedBox(width: 3),
                          _buildDot(_dot2.value),
                          const SizedBox(width: 3),
                          _buildDot(_dot3.value),
                        ],
                      );
                    },
                  ),
            const SizedBox(width: 6),
            Text(
              "est en train d'écrire...",
              style: TextStyle(
                color: themeManager.accentColor,
                fontStyle: FontStyle.italic,
                fontSize: 14,
                // 🌈 Ombre pour le thème néon
                shadows: themeManager.currentTheme == AppThemeMode.neon
                  ? [
                      Shadow(
                        color: themeManager.accentColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(double opacity) {
    final themeManager = globalThemeManager;

    return Opacity(
      opacity: opacity,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: themeManager.accentColor,
          shape: BoxShape.circle,
          // 🌈 Ombre pour le thème néon
          boxShadow: themeManager.currentTheme == AppThemeMode.neon
            ? [
                BoxShadow(
                  color: themeManager.accentColor.withValues(alpha: 0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
        ),
      ),
    );
  }
}
