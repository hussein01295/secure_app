import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:silencia/core/service/logging_service.dart';

/// Service d'authentification biométrique pour Silencia
class BiometricService {
  static const _storage = FlutterSecureStorage();
  static final _localAuth = LocalAuthentication();
  static final _instance = BiometricService._internal();
  
  factory BiometricService() => _instance;
  BiometricService._internal();

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricSetupKey = 'biometric_setup_complete';

  /// Vérifie si l'appareil supporte la biométrie
  Future<bool> isDeviceSupported() async {
    try {
      final isAvailable = await _localAuth.isDeviceSupported();
      logger.debug('Biométrie supportée par l\'appareil: $isAvailable');
      return isAvailable;
    } catch (e) {
      logger.error('Erreur vérification support biométrique', e);
      return false;
    }
  }

  /// Vérifie si des données biométriques sont enregistrées
  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      logger.debug('Peut vérifier biométrie: $canCheck');
      return canCheck;
    } catch (e) {
      logger.error('Erreur vérification capacité biométrique', e);
      return false;
    }
  }

  /// Obtient la liste des biométries disponibles
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      logger.debug('Biométries disponibles: $availableBiometrics');
      return availableBiometrics;
    } catch (e) {
      logger.error('Erreur récupération biométries disponibles', e);
      return [];
    }
  }

  /// Vérifie si la biométrie est activée dans l'app
  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _storage.read(key: _biometricEnabledKey);
      return enabled == 'true';
    } catch (e) {
      logger.error('Erreur lecture statut biométrique', e);
      return false;
    }
  }

  /// Active ou désactive la biométrie
  Future<bool> setBiometricEnabled(bool enabled) async {
    try {
      if (enabled) {
        // Vérifier que l'appareil supporte la biométrie
        final isSupported = await isDeviceSupported();
        final canCheck = await canCheckBiometrics();
        
        if (!isSupported || !canCheck) {
          logger.warning('Impossible d\'activer la biométrie: appareil non supporté');
          return false;
        }

        // Tester l'authentification avant d'activer
        final authResult = await authenticate(
          reason: 'Activez l\'authentification biométrique pour sécuriser votre compte',
        );
        
        if (!authResult) {
          logger.warning('Échec activation biométrie: authentification échouée');
          return false;
        }
      }

      await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
      await _storage.write(key: _biometricSetupKey, value: enabled.toString());
      
      logger.security('Biométrie ${enabled ? 'activée' : 'désactivée'}', {
        'enabled': enabled,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      logger.error('Erreur modification statut biométrique', e);
      return false;
    }
  }

  /// Authentifie l'utilisateur avec la biométrie
  Future<bool> authenticate({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      // Vérifier que la biométrie est disponible
      final isSupported = await isDeviceSupported();
      final canCheck = await canCheckBiometrics();

      if (!isSupported || !canCheck) {
        logger.warning('Authentification biométrique impossible: non supportée');
        return false;
      }

      logger.debug('Début authentification biométrique');

      // Petit délai pour s'assurer que l'UI est prête
      await Future.delayed(const Duration(milliseconds: 500));

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: false, // Permet le fallback sur PIN/motif
        ),
      );

      if (authenticated) {
        logger.security('Authentification biométrique réussie', {
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        logger.warning('Authentification biométrique échouée');
      }

      return authenticated;
    } on PlatformException catch (e) {
      logger.error('Erreur plateforme lors de l\'authentification biométrique', e);
      
      // Gérer les erreurs spécifiques
      switch (e.code) {
        case 'NotAvailable':
          logger.warning('Biométrie non disponible sur cet appareil');
          break;
        case 'NotEnrolled':
          logger.warning('Aucune biométrie enregistrée sur l\'appareil');
          break;
        case 'LockedOut':
          logger.warning('Biométrie temporairement verrouillée');
          break;
        case 'PermanentlyLockedOut':
          logger.error('Biométrie définitivement verrouillée');
          break;
        case 'no_fragment_activity':
          logger.error('Erreur d\'activité Flutter - redémarrez l\'application');
          break;
        case 'UserCancel':
          logger.debug('Authentification annulée par l\'utilisateur');
          break;
        default:
          logger.error('Erreur biométrique inconnue: ${e.code}');
      }
      
      return false;
    } catch (e) {
      logger.error('Erreur inattendue lors de l\'authentification biométrique', e);
      return false;
    }
  }

  /// Authentifie pour accéder à l'application
  Future<bool> authenticateForAppAccess() async {
    final isEnabled = await isBiometricEnabled();
    
    if (!isEnabled) {
      logger.debug('Biométrie désactivée, accès autorisé');
      return true;
    }

    return await authenticate(
      reason: 'Authentifiez-vous pour accéder à Silencia',
      useErrorDialogs: true,
      stickyAuth: true,
    );
  }

  /// Authentifie pour une action sensible
  Future<bool> authenticateForSensitiveAction(String action) async {
    final isEnabled = await isBiometricEnabled();
    
    if (!isEnabled) {
      logger.debug('Biométrie désactivée pour action sensible: $action');
      return true;
    }

    logger.security('Demande authentification pour action sensible', {
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
    });

    return await authenticate(
      reason: 'Authentifiez-vous pour $action',
      useErrorDialogs: true,
      stickyAuth: false, // Pas de sticky pour les actions sensibles
    );
  }

  /// Obtient un résumé des capacités biométriques
  Future<BiometricCapabilities> getCapabilities() async {
    try {
      final isSupported = await isDeviceSupported();
      final canCheck = await canCheckBiometrics();
      final availableBiometrics = await getAvailableBiometrics();
      final isEnabled = await isBiometricEnabled();

      return BiometricCapabilities(
        isSupported: isSupported,
        canCheck: canCheck,
        availableBiometrics: availableBiometrics,
        isEnabled: isEnabled,
      );
    } catch (e) {
      logger.error('Erreur récupération capacités biométriques', e);
      return BiometricCapabilities(
        isSupported: false,
        canCheck: false,
        availableBiometrics: [],
        isEnabled: false,
      );
    }
  }

  /// Teste la disponibilité de l'authentification biométrique
  Future<BiometricTestResult> testBiometricAvailability() async {
    try {
      final isSupported = await isDeviceSupported();
      final canCheck = await canCheckBiometrics();
      final availableBiometrics = await getAvailableBiometrics();

      if (!isSupported) {
        return BiometricTestResult(
          success: false,
          message: 'Appareil non supporté',
          errorCode: 'NOT_SUPPORTED',
        );
      }

      if (!canCheck) {
        return BiometricTestResult(
          success: false,
          message: 'Aucune biométrie configurée',
          errorCode: 'NOT_ENROLLED',
        );
      }

      if (availableBiometrics.isEmpty) {
        return BiometricTestResult(
          success: false,
          message: 'Aucune méthode biométrique disponible',
          errorCode: 'NO_METHODS',
        );
      }

      // Test simple d'authentification
      try {
        await Future.delayed(const Duration(milliseconds: 100));
        final testAuth = await _localAuth.authenticate(
          localizedReason: 'Test de disponibilité biométrique',
          options: const AuthenticationOptions(
            useErrorDialogs: false,
            stickyAuth: false,
            biometricOnly: true,
          ),
        );

        return BiometricTestResult(
          success: true,
          message: 'Biométrie fonctionnelle',
          errorCode: null,
          authenticationWorked: testAuth,
        );
      } catch (e) {
        return BiometricTestResult(
          success: false,
          message: 'Erreur lors du test: ${e.toString()}',
          errorCode: e is PlatformException ? e.code : 'UNKNOWN',
        );
      }
    } catch (e) {
      return BiometricTestResult(
        success: false,
        message: 'Erreur générale: ${e.toString()}',
        errorCode: 'GENERAL_ERROR',
      );
    }
  }

  /// Réinitialise la configuration biométrique
  Future<void> resetBiometricSettings() async {
    try {
      await _storage.delete(key: _biometricEnabledKey);
      await _storage.delete(key: _biometricSetupKey);

      logger.security('Configuration biométrique réinitialisée', {
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      logger.error('Erreur réinitialisation biométrique', e);
    }
  }
}

/// Classe représentant les capacités biométriques de l'appareil
class BiometricCapabilities {
  final bool isSupported;
  final bool canCheck;
  final List<BiometricType> availableBiometrics;
  final bool isEnabled;

  BiometricCapabilities({
    required this.isSupported,
    required this.canCheck,
    required this.availableBiometrics,
    required this.isEnabled,
  });

  bool get hasFingerprint => availableBiometrics.contains(BiometricType.fingerprint);
  bool get hasFace => availableBiometrics.contains(BiometricType.face);
  bool get hasIris => availableBiometrics.contains(BiometricType.iris);
  bool get hasStrong => availableBiometrics.contains(BiometricType.strong);
  bool get hasWeak => availableBiometrics.contains(BiometricType.weak);

  bool get isFullyAvailable => isSupported && canCheck && availableBiometrics.isNotEmpty;

  String get primaryBiometricName {
    if (hasFingerprint) return 'Empreinte digitale';
    if (hasFace) return 'Reconnaissance faciale';
    if (hasIris) return 'Reconnaissance iris';
    if (hasStrong) return 'Biométrie forte';
    if (hasWeak) return 'Biométrie faible';
    return 'Aucune';
  }

  @override
  String toString() {
    return 'BiometricCapabilities(supported: $isSupported, canCheck: $canCheck, '
           'available: $availableBiometrics, enabled: $isEnabled)';
  }
}

/// Résultat d'un test de disponibilité biométrique
class BiometricTestResult {
  final bool success;
  final String message;
  final String? errorCode;
  final bool? authenticationWorked;

  BiometricTestResult({
    required this.success,
    required this.message,
    this.errorCode,
    this.authenticationWorked,
  });

  @override
  String toString() {
    return 'BiometricTestResult(success: $success, message: $message, '
           'errorCode: $errorCode, authWorked: $authenticationWorked)';
  }
}
