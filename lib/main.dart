import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:silencia/core/theme/theme.dart';
import 'package:silencia/core/theme/theme_manager.dart';
import 'package:silencia/core/routes/app_router.dart'; // <- import du router
import 'package:silencia/core/service/notification_service.dart';
import 'package:silencia/core/service/logging_service.dart';
import 'package:silencia/core/service/app_health_service.dart';
import 'package:silencia/core/service/cache_service.dart';
import 'package:silencia/core/service/app_lifecycle_service.dart';
import 'package:silencia/core/service/animation_service.dart';
import 'package:silencia/core/service/image_cache_service.dart';
import 'package:silencia/core/service/profile_cache_service.dart';
import 'package:silencia/core/widgets/biometric_auth_overlay.dart';
import 'package:silencia/core/utils/rsa_migration.dart'; // 🔐 Migration RSA critique
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser le service de logs en premier
  await logger.initialize();

  try {
    logger.info('🔥 Initialisation Firebase...');
    // Initialiser Firebase avec les options de configuration
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logger.info('✅ Firebase initialisé avec succès');

    // Initialiser les services essentiels
    await _initializeServices();

  } catch (e, stackTrace) {
    logger.error('❌ Erreur lors de l\'initialisation Firebase', e, stackTrace);
    // Continuer même en cas d'erreur pour permettre le démarrage de l'app
  }

  // Initialiser le gestionnaire de thème
  logger.info('🎨 Initialisation du gestionnaire de thème...');
  await globalThemeManager.initTheme();
  logger.info('✅ Gestionnaire de thème initialisé');

  logger.info('🚀 Démarrage de l\'application...');
  runApp(MyApp());
}

// Initialisation des services essentiels
Future<void> _initializeServices() async {
  try {
    // 🔐 CRITIQUE: Vérifier et exécuter la migration RSA en premier
    logger.info('🔐 Vérification de la migration RSA...');
    try {
      final migrationSuccess = await RSAMigration.checkAndMigrate();
      if (migrationSuccess) {
        logger.info('✅ Migration RSA vérifiée/complétée');
        // Afficher le rapport en mode debug
        await RSAMigration.printMigrationReport();
      } else {
        logger.warning('⚠️ Migration RSA en attente (sera effectuée au prochain login)');
      }
    } catch (e, stackTrace) {
      logger.error('❌ Erreur lors de la migration RSA', e, stackTrace);
      // Ne pas bloquer le démarrage de l'app
    }

    // Initialiser le service de santé de l'app
    logger.info('💊 Initialisation du service de santé...');
    await AppHealthService().initialize();

    // Initialiser le service de cache
    logger.info('💾 Initialisation du service de cache...');
    await CacheService().cleanExpired(); // Nettoyer le cache expiré au démarrage

    // Initialiser le service de cycle de vie pour l'authentification
    logger.info('🔐 Initialisation du service de cycle de vie...');
    await AppLifecycleService().initialize();

    // Précharger les animations essentielles
    logger.info('🎨 Préchargement des animations...');
    await AnimationService().preloadEssentialAnimations();

    // Initialiser le cache d'images
    logger.info('🖼️ Initialisation du cache d\'images...');
    await ImageCacheService().initialize();

    // Synchroniser le cache de profil si possible
    logger.info('👤 Synchronisation du cache de profil...');
    final profileCache = ProfileCacheService();
    await profileCache.syncWithServerIfOnline();

    // Initialiser les notifications de manière asynchrone
    _initializeNotificationsAsync();

    logger.info('✅ Services essentiels initialisés');
  } catch (e) {
    logger.error('❌ Erreur lors de l\'initialisation des services', e);
  }
}

// Initialisation asynchrone des notifications pour éviter de bloquer le démarrage
void _initializeNotificationsAsync() {
  Future.delayed(const Duration(seconds: 2), () async {
    try {
      logger.info('📱 Initialisation différée du service de notifications...');
      await NotificationService().initialize();
      logger.info('✅ Service de notifications initialisé');
    } catch (e) {
      logger.error('❌ Erreur lors de l\'initialisation des notifications', e);
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLifecycleService _lifecycleService = AppLifecycleService();
  bool _showAuthOverlay = false;
  bool _isInitialAuthChecked = false;

  @override
  void initState() {
    super.initState();
    _setupAuthenticationCallbacks();
    _checkInitialAuthentication();
  }

  void _setupAuthenticationCallbacks() {
    _lifecycleService.setAuthenticationCallbacks(
      onAuthenticationRequired: () {
        if (mounted) {
          setState(() {
            _showAuthOverlay = true;
          });
        }
      },
      onAuthenticationSuccess: () {
        if (mounted) {
          setState(() {
            _showAuthOverlay = false;
          });
        }
      },
      onAuthenticationFailed: () {
        if (mounted) {
          setState(() {
            _showAuthOverlay = false;
          });
          // Optionnel: fermer l'application ou rediriger vers login
        }
      },
    );
  }

  Future<void> _checkInitialAuthentication() async {
    // Vérifier l'authentification au démarrage
    final authRequired = !await _lifecycleService.checkInitialAuthentication();

    if (mounted) {
      setState(() {
        _showAuthOverlay = authRequired;
        _isInitialAuthChecked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalThemeManager,
      builder: (context, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: material3Notifier,
          builder: (context, useMaterial3, __) {
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              title: 'Silencia',
              theme: globalThemeManager.themeData,
              routerConfig: appRouter,
              builder: (context, child) {
                // Afficher l'overlay d'authentification si nécessaire
                if (_showAuthOverlay && _isInitialAuthChecked) {
                  return Stack(
                    children: [
                      child ?? const SizedBox.shrink(),
                      BiometricAuthOverlay(
                        onAuthenticationSuccess: () {
                          setState(() {
                            _showAuthOverlay = false;
                          });
                        },
                        onAuthenticationFailed: () {
                          setState(() {
                            _showAuthOverlay = false;
                          });
                        },
                      ),
                    ],
                  );
                }
                return child ?? const SizedBox.shrink();
              },
            );
          },
        );
      },
    );
  }
}
