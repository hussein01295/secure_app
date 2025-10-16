import 'package:flutter/material.dart';
import 'package:silencia/core/service/image_cache_service.dart';
import 'package:silencia/core/theme/theme_manager.dart';
import 'package:silencia/core/theme/app_theme.dart';

/// Widget d'avatar de profil avec cache intelligent
class CachedProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? username;
  final String? displayName;
  final double radius;
  final bool showOnlineStatus;
  final bool isOnline;
  final VoidCallback? onTap;
  final Map<String, String>? headers;
  final bool enableHeroAnimation;
  final String? heroTag;

  const CachedProfileAvatar({
    super.key,
    this.imageUrl,
    this.username,
    this.displayName,
    this.radius = 20,
    this.showOnlineStatus = false,
    this.isOnline = false,
    this.onTap,
    this.headers,
    this.enableHeroAnimation = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    final theme = Theme.of(context);
    final imageService = ImageCacheService();

    Widget avatarWidget = _buildAvatarContent(context, theme, themeManager, imageService);

    // Ajouter l'indicateur de statut si nécessaire
    if (showOnlineStatus) {
      avatarWidget = Stack(
        children: [
          avatarWidget,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: radius * 0.3,
              height: radius * 0.3,
              decoration: BoxDecoration(
                color: isOnline ? AppTheme.success : theme.colorScheme.outline,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Ajouter Hero animation si activée
    if (enableHeroAnimation && heroTag != null) {
      avatarWidget = Hero(
        tag: heroTag!,
        child: avatarWidget,
      );
    }

    // Ajouter le tap si nécessaire
    if (onTap != null) {
      avatarWidget = GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  Widget _buildAvatarContent(
    BuildContext context,
    ThemeData theme,
    ThemeManager themeManager,
    ImageCacheService imageService,
  ) {
    // Si on a une URL d'image, utiliser le cache
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return imageService.buildProfileImage(
        imageUrl: imageUrl!,
        size: radius * 2,
        headers: headers,
      );
    }

    // Sinon, utiliser l'avatar par défaut avec initiales
    return _buildDefaultAvatar(context, theme, themeManager);
  }

  Widget _buildDefaultAvatar(
    BuildContext context,
    ThemeData theme,
    ThemeManager themeManager,
  ) {
    // Obtenir les initiales
    String initials = _getInitials();

    // Style selon le thème
    if (themeManager.currentTheme == AppThemeMode.neon) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppTheme.neonPurple, AppTheme.neonPink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.neonPurple.withValues(alpha: 0.5),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: initials.isNotEmpty
              ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: radius * 0.8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  Icons.person,
                  size: radius * 1.2,
                  color: Colors.white,
                ),
        ),
      );
    }

    // Avatar standard
    return CircleAvatar(
      radius: radius,
      backgroundColor: themeManager.accentColor,
      child: initials.isNotEmpty
          ? Text(
              initials,
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          : Icon(
              Icons.person,
              size: radius * 1.2,
              color: Colors.white,
            ),
    );
  }

  String _getInitials() {
    String name = displayName?.isNotEmpty == true ? displayName! : username ?? '';
    
    if (name.isEmpty) return '';

    List<String> nameParts = name.trim().split(' ');
    
    if (nameParts.length == 1) {
      return nameParts[0].isNotEmpty ? nameParts[0][0].toUpperCase() : '';
    } else {
      String firstInitial = nameParts[0].isNotEmpty ? nameParts[0][0].toUpperCase() : '';
      String lastInitial = nameParts.last.isNotEmpty ? nameParts.last[0].toUpperCase() : '';
      return firstInitial + lastInitial;
    }
  }
}

/// Widget d'avatar de profil large pour les écrans de profil
class LargeProfileAvatar extends StatefulWidget {
  final String? imageUrl;
  final String? username;
  final String? displayName;
  final double radius;
  final bool showOnlineStatus;
  final bool isOnline;
  final VoidCallback? onTap;
  final Map<String, String>? headers;
  final bool enablePulseAnimation;

  const LargeProfileAvatar({
    super.key,
    this.imageUrl,
    this.username,
    this.displayName,
    this.radius = 60,
    this.showOnlineStatus = true,
    this.isOnline = false,
    this.onTap,
    this.headers,
    this.enablePulseAnimation = true,
  });

  @override
  State<LargeProfileAvatar> createState() => _LargeProfileAvatarState();
}

class _LargeProfileAvatarState extends State<LargeProfileAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
  }

  void _initializeAnimation() {
    if (widget.enablePulseAnimation) {
      _pulseController = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      );

      _pulseAnimation = Tween<double>(
        begin: 1.0,
        end: 1.05,
      ).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ));

      if (widget.isOnline && mounted) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void didUpdateWidget(LargeProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.enablePulseAnimation && widget.isOnline != oldWidget.isOnline) {
      if (widget.isOnline && mounted) {
        _pulseController.repeat(reverse: true);
      } else if (mounted) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    if (widget.enablePulseAnimation) {
      _pulseController.stop();
      _pulseController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget avatarWidget = CachedProfileAvatar(
      imageUrl: widget.imageUrl,
      username: widget.username,
      displayName: widget.displayName,
      radius: widget.radius,
      showOnlineStatus: widget.showOnlineStatus,
      isOnline: widget.isOnline,
      headers: widget.headers,
    );

    // Ajouter l'animation de pulsation si activée
    if (widget.enablePulseAnimation && widget.isOnline && mounted) {
      avatarWidget = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          if (!mounted) return child ?? const SizedBox.shrink();

          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: avatarWidget,
      );
    }

    // Ajouter le tap si nécessaire
    if (widget.onTap != null) {
      avatarWidget = GestureDetector(
        onTap: widget.onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }
}
