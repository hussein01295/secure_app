import 'package:flutter/material.dart';
import 'package:silencia/core/theme/theme_manager.dart';
import 'package:silencia/core/theme/app_theme.dart';
import 'package:silencia/core/service/ephemeral_service.dart';

class EphemeralIndicator extends StatelessWidget {
  final Map<String, dynamic>? ephemeralData;
  final bool isFromMe;
  final bool isCompact;

  const EphemeralIndicator({
    super.key,
    this.ephemeralData,
    required this.isFromMe,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (ephemeralData == null || ephemeralData!['enabled'] != true) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final themeManager = globalThemeManager;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 4 : 6,
        vertical: isCompact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: _getIndicatorColor(themeManager),
        borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
        border: themeManager.currentTheme == AppThemeMode.neon
            ? Border.all(
                color: const Color(0xFFE91E63).withValues(alpha: 0.3),
                width: 0.5,
              )
            : null,
        boxShadow: themeManager.currentTheme == AppThemeMode.neon
            ? [
                BoxShadow(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIndicatorIcon(),
            size: isCompact ? 10 : 12,
            color: _getIconColor(themeManager),
          ),
          if (!isCompact) ...[
            const SizedBox(width: 4),
            Text(
              _getIndicatorText(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: _getTextColor(themeManager),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getIndicatorColor(ThemeManager themeManager) {
    switch (themeManager.currentTheme) {
      case AppThemeMode.neon:
        return const Color(0xFF6A1B9A).withValues(alpha: 0.2);
      case AppThemeMode.dark:
        return Colors.orange.withValues(alpha: 0.2);
      case AppThemeMode.light:
        return Colors.orange.withValues(alpha: 0.1);
    }
  }

  Color _getIconColor(ThemeManager themeManager) {
    switch (themeManager.currentTheme) {
      case AppThemeMode.neon:
        return const Color(0xFFE91E63);
      case AppThemeMode.dark:
        return Colors.orange;
      case AppThemeMode.light:
        return Colors.orange.shade700;
    }
  }

  Color _getTextColor(ThemeManager themeManager) {
    switch (themeManager.currentTheme) {
      case AppThemeMode.neon:
        return const Color(0xFFE91E63);
      case AppThemeMode.dark:
        return Colors.orange.shade300;
      case AppThemeMode.light:
        return Colors.orange.shade800;
    }
  }

  IconData _getIndicatorIcon() {
    final durationType = ephemeralData!['durationType'] ?? 'timer';
    
    switch (durationType) {
      case 'after_read':
        return Icons.visibility_off;
      case 'timer':
      case 'custom':
        return Icons.timer;
      default:
        return Icons.auto_delete;
    }
  }

  String _getIndicatorText() {
    final durationType = ephemeralData!['durationType'] ?? 'timer';
    
    switch (durationType) {
      case 'after_read':
        return 'Vue';
      case 'timer':
        final duration = ephemeralData!['timerDuration'] ?? 86400000;
        return _formatShortDuration(duration);
      case 'custom':
        final duration = ephemeralData!['customDuration'];
        if (duration != null) {
          return _formatShortDuration(duration);
        }
        return 'Custom';
      default:
        return 'Éph';
    }
  }

  String _formatShortDuration(int durationMs) {
    final duration = Duration(milliseconds: durationMs);
    
    if (duration.inDays > 0) {
      return '${duration.inDays}j';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

class EphemeralCountdownIndicator extends StatefulWidget {
  final DateTime? expiresAt;
  final bool isFromMe;
  final VoidCallback? onExpired;

  const EphemeralCountdownIndicator({
    super.key,
    this.expiresAt,
    required this.isFromMe,
    this.onExpired,
  });

  @override
  State<EphemeralCountdownIndicator> createState() => _EphemeralCountdownIndicatorState();
}

class _EphemeralCountdownIndicatorState extends State<EphemeralCountdownIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  String? _timeRemaining;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _updateTimeRemaining();
    _startCountdown();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _animationController.repeat(reverse: true);
    
    // Mettre à jour toutes les secondes
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _updateTimeRemaining();
        if (!_isExpired) {
          _startCountdown();
        }
      }
    });
  }

  void _updateTimeRemaining() {
    if (widget.expiresAt == null) return;
    
    final timeLeft = EphemeralService.getTimeUntilExpiration(widget.expiresAt);
    
    setState(() {
      _timeRemaining = timeLeft;
      _isExpired = timeLeft == 'Expiré';
    });

    if (_isExpired) {
      _animationController.stop();
      widget.onExpired?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.expiresAt == null || _timeRemaining == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final themeManager = globalThemeManager;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _isExpired 
                ? Colors.red.withValues(alpha: 0.2)
                : Colors.orange.withValues(alpha: 0.2 + (_animation.value * 0.1)),
            borderRadius: BorderRadius.circular(8),
            border: themeManager.currentTheme == AppThemeMode.neon
                ? Border.all(
                    color: (_isExpired ? Colors.red : Colors.orange)
                        .withValues(alpha: 0.3 + (_animation.value * 0.2)),
                    width: 0.5,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isExpired ? Icons.warning : Icons.timer,
                size: 10,
                color: _isExpired ? Colors.red : Colors.orange,
              ),
              const SizedBox(width: 3),
              Text(
                _timeRemaining!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  color: _isExpired ? Colors.red : Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class EphemeralBanner extends StatelessWidget {
  final Map<String, dynamic> settings;
  final VoidCallback? onTap;

  const EphemeralBanner({
    super.key,
    required this.settings,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (settings['enabled'] != true) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final themeManager = globalThemeManager;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: themeManager.currentTheme == AppThemeMode.neon
              ? const Color(0xFF6A1B9A).withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: themeManager.currentTheme == AppThemeMode.neon
                ? const Color(0xFFE91E63).withValues(alpha: 0.3)
                : Colors.orange.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.auto_delete,
              color: themeManager.currentTheme == AppThemeMode.neon
                  ? const Color(0xFFE91E63)
                  : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Messages éphémères activés',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: themeManager.currentTheme == AppThemeMode.neon
                          ? const Color(0xFFE91E63)
                          : Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    EphemeralService.getEphemeralDescription(settings),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.settings,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
