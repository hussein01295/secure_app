import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:silencia/core/service/logging_service.dart';

/// Service centralisé pour la gestion des animations Lottie
class AnimationService {
  static final AnimationService _instance = AnimationService._internal();
  factory AnimationService() => _instance;
  AnimationService._internal();

  // Cache des animations pour éviter les rechargements
  final Map<String, LottieComposition> _animationCache = {};
  
  // Contrôleurs d'animation actifs
  final Map<String, AnimationController> _activeControllers = {};

  /// Chemins des animations disponibles
  static const Map<String, String> _animationPaths = {
    // Animations de sécurité
    'security_lock': 'assets/animations/security_lock.json',
    'biometric_scan': 'assets/animations/security_lock.json', // Réutilise pour l'instant
    
    // Animations de messagerie
    'message_send': 'assets/animations/message_send.json',
    'message_received': 'assets/animations/message_send.json', // Variante
    'typing_indicator': 'assets/animations/typing_indicator.json',
    'message_encrypted': 'assets/animations/security_lock.json',
    
    // Animations de connexion
    'connection_pulse': 'assets/animations/connection_pulse.json',
    'sync': 'assets/animations/connection_pulse.json',
    
    // Animations d'état
    'loading': 'assets/animations/connection_pulse.json',
    'success': 'assets/animations/message_send.json',
    'error': 'assets/animations/security_lock.json',
  };

  /// Précharge les animations essentielles
  Future<void> preloadEssentialAnimations() async {
    try {
      logger.info('🎨 Préchargement des animations essentielles...');
      
      final essentialAnimations = [
        'security_lock',
        'message_send',
        'typing_indicator',
        'connection_pulse',
      ];

      for (final animationKey in essentialAnimations) {
        await _loadAnimation(animationKey);
      }
      
      logger.info('✅ Animations essentielles préchargées');
    } catch (e) {
      logger.error('❌ Erreur lors du préchargement des animations', e);
    }
  }

  /// Charge une animation spécifique
  Future<LottieComposition?> _loadAnimation(String animationKey) async {
    try {
      if (_animationCache.containsKey(animationKey)) {
        return _animationCache[animationKey];
      }

      final path = _animationPaths[animationKey];
      if (path == null) {
        logger.warning('Animation non trouvée: $animationKey');
        return null;
      }

      final composition = await AssetLottie(path).load();
      _animationCache[animationKey] = composition;
      
      logger.debug('Animation chargée: $animationKey');
      return composition;
    } catch (e) {
      logger.error('Erreur chargement animation $animationKey', e);
      return null;
    }
  }

  /// Crée un widget Lottie pour une animation donnée
  Widget createAnimationWidget({
    required String animationKey,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    bool repeat = true,
    bool reverse = false,
    bool autoPlay = true,
    AnimationController? controller,
    VoidCallback? onLoaded,
    Color? color,
  }) {
    final path = _animationPaths[animationKey];
    if (path == null) {
      logger.warning('Animation non trouvée: $animationKey');
      return _createFallbackWidget(width, height);
    }

    return Lottie.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      repeat: repeat,
      reverse: reverse,
      animate: autoPlay,
      controller: controller,
      onLoaded: (composition) {
        logger.debug('Animation chargée: $animationKey (${composition.duration})');
        onLoaded?.call();
      },
      errorBuilder: (context, error, stackTrace) {
        logger.error('Erreur affichage animation $animationKey', error);
        return _createFallbackWidget(width, height);
      },
      frameBuilder: color != null 
        ? (context, child, composition) {
            return ColorFiltered(
              colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
              child: child,
            );
          }
        : null,
    );
  }

  /// Crée un contrôleur d'animation avec gestion automatique
  AnimationController createController({
    required TickerProvider vsync,
    required String animationKey,
    Duration? duration,
  }) {
    // Nettoyer l'ancien contrôleur s'il existe
    _activeControllers[animationKey]?.dispose();
    
    final controller = AnimationController(
      vsync: vsync,
      duration: duration ?? const Duration(seconds: 2),
    );
    
    _activeControllers[animationKey] = controller;
    
    logger.debug('Contrôleur créé pour: $animationKey');
    return controller;
  }

  /// Widget de sécurité avec animation de cadenas
  Widget securityLockAnimation({
    double size = 50,
    bool autoPlay = true,
    Color? color,
  }) {
    return createAnimationWidget(
      animationKey: 'security_lock',
      width: size,
      height: size,
      autoPlay: autoPlay,
      color: color,
    );
  }

  /// Widget d'envoi de message avec animation
  Widget messageSendAnimation({
    double size = 30,
    bool autoPlay = true,
    VoidCallback? onComplete,
  }) {
    return createAnimationWidget(
      animationKey: 'message_send',
      width: size,
      height: size,
      autoPlay: autoPlay,
      repeat: false,
      onLoaded: onComplete,
    );
  }

  /// Widget d'indicateur de frappe
  Widget typingIndicatorAnimation({
    double width = 60,
    double height = 20,
  }) {
    return createAnimationWidget(
      animationKey: 'typing_indicator',
      width: width,
      height: height,
      repeat: true,
    );
  }

  /// Widget de pulsation de connexion
  Widget connectionPulseAnimation({
    double size = 40,
    Color? color,
  }) {
    return createAnimationWidget(
      animationKey: 'connection_pulse',
      width: size,
      height: size,
      repeat: true,
      color: color,
    );
  }

  /// Widget de chargement avec animation
  Widget loadingAnimation({
    double size = 50,
    Color? color,
  }) {
    return createAnimationWidget(
      animationKey: 'loading',
      width: size,
      height: size,
      repeat: true,
      color: color,
    );
  }

  /// Widget de succès avec animation
  Widget successAnimation({
    double size = 40,
    VoidCallback? onComplete,
  }) {
    return createAnimationWidget(
      animationKey: 'success',
      width: size,
      height: size,
      repeat: false,
      onLoaded: onComplete,
    );
  }

  /// Crée un widget de fallback en cas d'erreur
  Widget _createFallbackWidget(double? width, double? height) {
    return Container(
      width: width ?? 50,
      height: height ?? 50,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.animation,
        color: Colors.grey,
      ),
    );
  }

  /// Nettoie les ressources
  void dispose() {
    for (final controller in _activeControllers.values) {
      controller.dispose();
    }
    _activeControllers.clear();
    _animationCache.clear();
    
    logger.debug('AnimationService disposé');
  }

  /// Obtient les statistiques du cache
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_animations': _animationCache.length,
      'active_controllers': _activeControllers.length,
      'available_animations': _animationPaths.length,
      'cache_keys': _animationCache.keys.toList(),
    };
  }

  /// Vide le cache des animations
  void clearCache() {
    _animationCache.clear();
    logger.debug('Cache d\'animations vidé');
  }
}
