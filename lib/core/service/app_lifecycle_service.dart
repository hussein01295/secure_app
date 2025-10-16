import 'package:flutter/material.dart';
import 'package:silencia/core/service/biometric_service.dart';
import 'package:silencia/core/service/logging_service.dart';

/// Service de gestion du cycle de vie de l'application
/// Gère l'authentification biométrique lors du retour en premier plan
class AppLifecycleService with WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  final BiometricService _biometricService = BiometricService();
  
  bool _isInitialized = false;
  bool _isAuthenticationRequired = false;
  bool _isAuthenticating = false;
  DateTime? _lastPausedTime;
  
  // Délai après lequel l'authentification est requise (en secondes)
  static const int _authTimeoutSeconds = 30;
  
  // Callbacks pour notifier l'UI
  VoidCallback? _onAuthenticationRequired;
  VoidCallback? _onAuthenticationSuccess;
  VoidCallback? _onAuthenticationFailed;

  /// Initialise le service de cycle de vie
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      WidgetsBinding.instance.addObserver(this);
      _isInitialized = true;
      
      logger.info('AppLifecycleService initialisé');
    } catch (e) {
      logger.error('Erreur initialisation AppLifecycleService', e);
    }
  }

  /// Définit les callbacks pour les événements d'authentification
  void setAuthenticationCallbacks({
    VoidCallback? onAuthenticationRequired,
    VoidCallback? onAuthenticationSuccess,
    VoidCallback? onAuthenticationFailed,
  }) {
    _onAuthenticationRequired = onAuthenticationRequired;
    _onAuthenticationSuccess = onAuthenticationSuccess;
    _onAuthenticationFailed = onAuthenticationFailed;
  }

  /// Vérifie si l'authentification biométrique est nécessaire au démarrage
  Future<bool> checkInitialAuthentication() async {
    try {
      final isEnabled = await _biometricService.isBiometricEnabled();
      
      if (!isEnabled) {
        logger.debug('Biométrie désactivée, pas d\'authentification requise');
        return true; // Pas d'authentification requise
      }

      logger.debug('Vérification authentification initiale requise');
      return await _performAuthentication('Authentifiez-vous pour accéder à Silencia');
    } catch (e) {
      logger.error('Erreur vérification authentification initiale', e);
      return true; // En cas d'erreur, on laisse passer
    }
  }

  /// Gère les changements d'état du cycle de vie de l'application
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    logger.debug('Changement état application: $state');
    
    switch (state) {
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.inactive:
        // L'app est inactive mais visible (ex: notification pull-down)
        break;
      case AppLifecycleState.hidden:
        // L'app est cachée
        break;
    }
  }

  /// Gère la mise en pause de l'application
  void _handleAppPaused() {
    _lastPausedTime = DateTime.now();
    _isAuthenticationRequired = false;
    
    logger.debug('Application mise en pause à $_lastPausedTime');
  }

  /// Gère la reprise de l'application
  void _handleAppResumed() async {
    logger.debug('Application reprise');
    
    if (_lastPausedTime == null) {
      // Premier démarrage, pas de vérification nécessaire
      return;
    }

    final pauseDuration = DateTime.now().difference(_lastPausedTime!);
    logger.debug('Durée de pause: ${pauseDuration.inSeconds} secondes');

    // Vérifier si l'authentification est nécessaire
    if (pauseDuration.inSeconds >= _authTimeoutSeconds) {
      await _checkAndRequestAuthentication();
    }
  }

  /// Gère la fermeture de l'application
  void _handleAppDetached() {
    logger.debug('Application fermée');
    _lastPausedTime = DateTime.now();
  }

  /// Vérifie et demande l'authentification si nécessaire
  Future<void> _checkAndRequestAuthentication() async {
    if (_isAuthenticating || _isAuthenticationRequired) {
      return; // Éviter les authentifications multiples
    }

    try {
      final isEnabled = await _biometricService.isBiometricEnabled();
      
      if (!isEnabled) {
        logger.debug('Biométrie désactivée, pas d\'authentification requise');
        return;
      }

      _isAuthenticationRequired = true;
      _onAuthenticationRequired?.call();

      logger.security('Authentification requise après retour en premier plan', {
        'pauseDuration': DateTime.now().difference(_lastPausedTime!).inSeconds,
        'timestamp': DateTime.now().toIso8601String(),
      });

      final success = await _performAuthentication(
        'Authentifiez-vous pour continuer à utiliser Silencia'
      );

      if (success) {
        _isAuthenticationRequired = false;
        _onAuthenticationSuccess?.call();
        logger.security('Authentification réussie après retour', {
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        _onAuthenticationFailed?.call();
        logger.warning('Authentification échouée après retour');
      }
    } catch (e) {
      logger.error('Erreur lors de la vérification d\'authentification', e);
      _isAuthenticationRequired = false;
      _onAuthenticationFailed?.call();
    }
  }

  /// Effectue l'authentification biométrique
  Future<bool> _performAuthentication(String reason) async {
    if (_isAuthenticating) {
      return false;
    }

    try {
      _isAuthenticating = true;
      
      final success = await _biometricService.authenticate(
        reason: reason,
        useErrorDialogs: true,
        stickyAuth: true,
      );

      return success;
    } catch (e) {
      logger.error('Erreur lors de l\'authentification', e);
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  /// Force une nouvelle authentification
  Future<bool> forceAuthentication({String? reason}) async {
    return await _performAuthentication(
      reason ?? 'Authentification requise'
    );
  }

  /// Vérifie si l'authentification est actuellement requise
  bool get isAuthenticationRequired => _isAuthenticationRequired;

  /// Vérifie si une authentification est en cours
  bool get isAuthenticating => _isAuthenticating;

  /// Réinitialise l'état d'authentification (utile après une authentification réussie)
  void resetAuthenticationState() {
    _isAuthenticationRequired = false;
    _isAuthenticating = false;
    _lastPausedTime = DateTime.now();
  }

  /// Configure le délai d'authentification (pour les tests)
  static const int authTimeoutSeconds = _authTimeoutSeconds;

  /// Dispose le service
  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
      logger.debug('AppLifecycleService disposé');
    }
  }
}
