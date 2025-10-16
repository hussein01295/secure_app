import 'package:flutter/material.dart';

/// Widget pour afficher le logo Silencia
class SilenciaLogo extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? letterColor;
  final bool showShadow;

  const SilenciaLogo({
    super.key,
    this.size = 100,
    this.backgroundColor,
    this.letterColor,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final bgColor = backgroundColor ?? (isDark ? const Color(0xFF2c2c2c) : const Color(0xFFf5f5f5));
    final textColor = letterColor ?? const Color(0xFF2c5f5f);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * 0.18), // 18% de rayon pour un look moderne
        boxShadow: showShadow ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: size * 0.05,
            offset: Offset(0, size * 0.02),
          ),
        ] : null,
        border: Border.all(
          color: isDark ? Colors.grey.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          'S',
          style: TextStyle(
            fontSize: size * 0.6, // 60% de la taille du container
            fontWeight: FontWeight.bold,
            color: textColor,
            fontFamily: 'SF Pro Display', // Police moderne
          ),
        ),
      ),
    );
  }
}

/// Widget pour le logo Silencia avec texte
class SilenciaLogoWithText extends StatelessWidget {
  final double logoSize;
  final double textSize;
  final Color? logoColor;
  final Color? textColor;
  final MainAxisAlignment alignment;
  final bool vertical;

  const SilenciaLogoWithText({
    super.key,
    this.logoSize = 60,
    this.textSize = 24,
    this.logoColor,
    this.textColor,
    this.alignment = MainAxisAlignment.center,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = textColor ?? theme.textTheme.titleLarge?.color ?? Colors.black;

    final logo = SilenciaLogo(
      size: logoSize,
      letterColor: logoColor,
    );

    final text = Text(
      'Silencia',
      style: TextStyle(
        fontSize: textSize,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.5,
      ),
    );

    if (vertical) {
      return Column(
        mainAxisAlignment: alignment,
        children: [
          logo,
          SizedBox(height: logoSize * 0.2),
          text,
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: alignment,
        children: [
          logo,
          SizedBox(width: logoSize * 0.3),
          text,
        ],
      );
    }
  }
}

/// Widget pour un petit logo Silencia (pour les app bars, etc.)
class SilenciaLogoSmall extends StatelessWidget {
  final double size;
  final Color? color;

  const SilenciaLogoSmall({
    super.key,
    this.size = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SilenciaLogo(
      size: size,
      letterColor: color,
      showShadow: false,
    );
  }
}

/// Widget pour le splash screen avec animation
class SilenciaLogoAnimated extends StatefulWidget {
  final double size;
  final Duration duration;
  final VoidCallback? onAnimationComplete;

  const SilenciaLogoAnimated({
    super.key,
    this.size = 120,
    this.duration = const Duration(milliseconds: 1500),
    this.onAnimationComplete,
  });

  @override
  State<SilenciaLogoAnimated> createState() => _SilenciaLogoAnimatedState();
}

class _SilenciaLogoAnimatedState extends State<SilenciaLogoAnimated>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    _controller.forward().then((_) {
      if (widget.onAnimationComplete != null) {
        widget.onAnimationComplete!();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: SilenciaLogo(
              size: widget.size,
            ),
          ),
        );
      },
    );
  }
}
