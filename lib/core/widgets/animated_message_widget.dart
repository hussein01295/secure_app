import 'package:flutter/material.dart';
import 'package:silencia/core/service/animation_service.dart';

/// Widget d'animation pour les messages avec différents états
class AnimatedMessageWidget extends StatefulWidget {
  final Widget child;
  final MessageAnimationType animationType;
  final Duration delay;
  final VoidCallback? onAnimationComplete;

  const AnimatedMessageWidget({
    super.key,
    required this.child,
    this.animationType = MessageAnimationType.slideIn,
    this.delay = Duration.zero,
    this.onAnimationComplete,
  });

  @override
  State<AnimatedMessageWidget> createState() => _AnimatedMessageWidgetState();
}

class _AnimatedMessageWidgetState extends State<AnimatedMessageWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimation();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
  }

  Future<void> _startAnimation() async {
    if (widget.delay > Duration.zero) {
      await Future.delayed(widget.delay);
    }
    
    if (mounted) {
      await _controller.forward();
      widget.onAnimationComplete?.call();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.animationType) {
      case MessageAnimationType.slideIn:
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: widget.child,
          ),
        );
      
      case MessageAnimationType.scaleIn:
        return ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: widget.child,
          ),
        );
      
      case MessageAnimationType.fadeIn:
        return FadeTransition(
          opacity: _fadeAnimation,
          child: widget.child,
        );
    }
  }
}

/// Widget d'indicateur de frappe animé
class TypingIndicatorWidget extends StatelessWidget {
  final AnimationService _animationService = AnimationService();
  final String userName;
  final Color? backgroundColor;

  TypingIndicatorWidget({
    super.key,
    required this.userName,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$userName est en train d\'écrire',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          _animationService.typingIndicatorAnimation(),
        ],
      ),
    );
  }
}

/// Widget d'animation d'envoi de message
class MessageSendAnimationWidget extends StatefulWidget {
  final VoidCallback? onComplete;
  final Color? color;

  const MessageSendAnimationWidget({
    super.key,
    this.onComplete,
    this.color,
  });

  @override
  State<MessageSendAnimationWidget> createState() => _MessageSendAnimationWidgetState();
}

class _MessageSendAnimationWidgetState extends State<MessageSendAnimationWidget> {
  final AnimationService _animationService = AnimationService();

  @override
  Widget build(BuildContext context) {
    return _animationService.messageSendAnimation(
      size: 24,
      onComplete: widget.onComplete,
    );
  }
}

/// Widget d'animation de chiffrement
class EncryptionAnimationWidget extends StatefulWidget {
  final bool isEncrypting;
  final VoidCallback? onComplete;

  const EncryptionAnimationWidget({
    super.key,
    required this.isEncrypting,
    this.onComplete,
  });

  @override
  State<EncryptionAnimationWidget> createState() => _EncryptionAnimationWidgetState();
}

class _EncryptionAnimationWidgetState extends State<EncryptionAnimationWidget>
    with TickerProviderStateMixin {
  final AnimationService _animationService = AnimationService();
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.isEncrypting) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(EncryptionAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isEncrypting != oldWidget.isEncrypting) {
      if (widget.isEncrypting) {
        _controller.repeat();
      } else {
        _controller.stop();
        widget.onComplete?.call();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value * 2 * 3.14159,
          child: _animationService.securityLockAnimation(
            size: 16,
            color: theme.colorScheme.primary,
          ),
        );
      },
    );
  }
}

/// Widget de statut de message avec animations
class MessageStatusWidget extends StatelessWidget {
  final MessageStatus status;
  final AnimationService _animationService = AnimationService();

  MessageStatusWidget({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    switch (status) {
      case MessageStatus.sending:
        return _animationService.loadingAnimation(
          size: 12,
          color: theme.colorScheme.outline,
        );
      
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: 12,
          color: theme.colorScheme.outline,
        );
      
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 12,
          color: theme.colorScheme.outline,
        );
      
      case MessageStatus.read:
        return Icon(
          Icons.done_all,
          size: 12,
          color: theme.colorScheme.primary,
        );
      
      case MessageStatus.encrypted:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _animationService.securityLockAnimation(
              size: 10,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.done_all,
              size: 12,
              color: theme.colorScheme.primary,
            ),
          ],
        );
      
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          size: 12,
          color: theme.colorScheme.error,
        );
    }
  }
}

/// Types d'animation pour les messages
enum MessageAnimationType {
  slideIn,
  scaleIn,
  fadeIn,
}

/// Statuts de message
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  encrypted,
  failed,
}
