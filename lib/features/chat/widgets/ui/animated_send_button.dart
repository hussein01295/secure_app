import 'package:flutter/material.dart';
import 'package:silencia/core/service/animation_service.dart';

/// Widget animé pour le bouton d'envoi de message
class AnimatedSendButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isSending;
  final bool hasText;

  const AnimatedSendButton({
    super.key,
    required this.onPressed,
    this.isSending = false,
    this.hasText = false,
  });

  @override
  State<AnimatedSendButton> createState() => _AnimatedSendButtonState();
}

class _AnimatedSendButtonState extends State<AnimatedSendButton>
    with TickerProviderStateMixin {
  final AnimationService _animationService = AnimationService();
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _colorController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animation de scale pour l'effet de pression
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    // Animation de rotation pour l'effet d'envoi
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // Animation de couleur
    _colorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.elasticOut,
    ));
    
    _colorAnimation = ColorTween(
      begin: Colors.blue,
      end: Colors.green,
    ).animate(CurvedAnimation(
      parent: _colorController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnimatedSendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Animer la couleur selon si il y a du texte
    if (widget.hasText != oldWidget.hasText) {
      if (widget.hasText) {
        _colorController.forward();
      } else {
        _colorController.reverse();
      }
    }
  }

  void _handlePress() {
    if (widget.isSending) return;
    
    // Animation de pression
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    
    // Animation de rotation pour l'envoi
    _rotationController.forward().then((_) {
      _rotationController.reset();
    });
    
    // Appeler la fonction d'envoi
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _scaleController,
        _rotationController,
        _colorController,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 2 * 3.14159, // 360 degrés
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _colorAnimation.value ?? Colors.blue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_colorAnimation.value ?? Colors.blue).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _handlePress,
                  child: Center(
                    child: widget.isSending
                        ? _animationService.messageSendAnimation(
                            size: 20,
                          )
                        : Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Widget pour animer l'apparition d'un message avec effet de frappe
class TypingMessageAnimation extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;

  const TypingMessageAnimation({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 50),
  });

  @override
  State<TypingMessageAnimation> createState() => _TypingMessageAnimationState();
}

class _TypingMessageAnimationState extends State<TypingMessageAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _characterCount;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: widget.duration * widget.text.length,
      vsync: this,
    );
    
    _characterCount = IntTween(
      begin: 0,
      end: widget.text.length,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _characterCount,
      builder: (context, child) {
        String displayText = widget.text.substring(0, _characterCount.value);
        
        return Text(
          displayText,
          style: widget.style,
        );
      },
    );
  }
}

/// Widget pour l'effet de pulsation lors de l'envoi
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final bool isActive;

  const PulseAnimation({
    super.key,
    required this.child,
    this.isActive = false,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}
