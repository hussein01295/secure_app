import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedThemeSwitcher extends StatefulWidget {
  final Widget child;
  final AppThemeMode? currentTheme;

  const AnimatedThemeSwitcher({
    super.key,
    required this.child,
    this.currentTheme,
  });

  @override
  State<AnimatedThemeSwitcher> createState() => _AnimatedThemeSwitcherState();
}

class _AnimatedThemeSwitcherState extends State<AnimatedThemeSwitcher>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  AppThemeMode? _previousTheme;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _controller.forward();
    _previousTheme = widget.currentTheme;
  }

  @override
  void didUpdateWidget(AnimatedThemeSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Redémarrer l'animation si le thème a changé
    if (widget.currentTheme != _previousTheme) {
      _controller.reset();
      _controller.forward();
      _previousTheme = widget.currentTheme;
    }
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
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: widget.child,
          ),
        );
      },
    );
  }
}

// 🌈 Widget avec effet de particules pour le thème néon
class NeonParticleEffect extends StatefulWidget {
  final Widget child;
  final bool showParticles;

  const NeonParticleEffect({
    super.key,
    required this.child,
    this.showParticles = false,
  });

  @override
  State<NeonParticleEffect> createState() => _NeonParticleEffectState();
}

class _NeonParticleEffectState extends State<NeonParticleEffect>
    with TickerProviderStateMixin {
  late AnimationController _particleController;
  late List<Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _particles = List.generate(20, (index) => Particle());
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Afficher les particules seulement si demandé
    if (!widget.showParticles) {
      return widget.child;
    }

    return Stack(
      children: [
        // Particules en arrière-plan
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: ParticlePainter(_particles, _particleController.value),
              );
            },
          ),
        ),
        // Contenu principal
        widget.child,
      ],
    );
  }
}

class Particle {
  late double x;
  late double y;
  late double speed;
  late double size;
  late Color color;
  late double opacity;

  Particle() {
    reset();
  }

  void reset() {
    x = (DateTime.now().millisecondsSinceEpoch % 1000) / 1000.0;
    y = (DateTime.now().microsecondsSinceEpoch % 1000) / 1000.0;
    speed = 0.1 + (DateTime.now().millisecondsSinceEpoch % 100) / 1000.0;
    size = 2.0 + (DateTime.now().microsecondsSinceEpoch % 50) / 10.0;
    opacity = 0.3 + (DateTime.now().millisecondsSinceEpoch % 70) / 100.0;
    
    final colors = [
      AppTheme.neonPurple,
      AppTheme.neonPink,
      AppTheme.neonBlue,
      AppTheme.neonGreen,
    ];
    color = colors[DateTime.now().millisecondsSinceEpoch % colors.length];
  }

  void update(double time) {
    y -= speed * time;
    if (y < -0.1) {
      reset();
      y = 1.1;
    }
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double time;

  ParticlePainter(this.particles, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      particle.update(0.01);
      
      final paint = Paint()
        ..color = particle.color.withValues(alpha: particle.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(
          particle.x * size.width,
          particle.y * size.height,
        ),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 🎨 Widget de transition fluide entre thèmes
class ThemeTransition extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final AppThemeMode currentTheme;

  const ThemeTransition({
    super.key,
    required this.child,
    required this.currentTheme,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<ThemeTransition> createState() => _ThemeTransitionState();
}

class _ThemeTransitionState extends State<ThemeTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  AppThemeMode? _previousTheme;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _previousTheme = widget.currentTheme;
  }

  @override
  void didUpdateWidget(ThemeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Détecter le changement de thème
    if (_previousTheme != null && _previousTheme != widget.currentTheme) {
      _controller.reset();
      _controller.forward();
    }
    _previousTheme = widget.currentTheme;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: _getTransitionGradient(widget.currentTheme, _animation.value),
          ),
          child: widget.child,
        );
      },
    );
  }

  LinearGradient _getTransitionGradient(AppThemeMode theme, double progress) {
    final baseGradient = AppTheme.getPrimaryGradient(theme);

    return LinearGradient(
      colors: baseGradient.colors.map((color) {
        return Color.lerp(
          Colors.transparent,
          color,
          progress,
        ) ?? color;
      }).toList(),
      begin: baseGradient.begin,
      end: baseGradient.end,
    );
  }
}

// 🌟 Widget d'effet de brillance pour le thème néon
class NeonGlow extends StatefulWidget {
  final Widget child;
  final Color? glowColor;
  final double glowRadius;
  final bool showGlow;

  const NeonGlow({
    super.key,
    required this.child,
    this.glowColor,
    this.glowRadius = 10.0,
    this.showGlow = false,
  });

  @override
  State<NeonGlow> createState() => _NeonGlowState();
}

class _NeonGlowState extends State<NeonGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
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
  Widget build(BuildContext context) {
    // Effet de brillance seulement si demandé
    if (!widget.showGlow) {
      return widget.child;
    }

    final glowColor = widget.glowColor ?? AppTheme.neonAccent;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: _animation.value * 0.6),
                blurRadius: widget.glowRadius * _animation.value,
                spreadRadius: 2.0 * _animation.value,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
