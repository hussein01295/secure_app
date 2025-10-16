import 'package:flutter/material.dart';
import 'package:silencia/core/service/biometric_service.dart';
import 'package:silencia/core/service/logging_service.dart';
import 'package:silencia/core/service/animation_service.dart';

/// Overlay d'authentification biométrique qui s'affiche par-dessus l'application
class BiometricAuthOverlay extends StatefulWidget {
  final VoidCallback? onAuthenticationSuccess;
  final VoidCallback? onAuthenticationFailed;
  final String? customMessage;

  const BiometricAuthOverlay({
    super.key,
    this.onAuthenticationSuccess,
    this.onAuthenticationFailed,
    this.customMessage,
  });

  @override
  State<BiometricAuthOverlay> createState() => _BiometricAuthOverlayState();
}

class _BiometricAuthOverlayState extends State<BiometricAuthOverlay>
    with TickerProviderStateMixin {
  final BiometricService _biometricService = BiometricService();
  final AnimationService _animationService = AnimationService();
  
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  
  bool _isAuthenticating = false;
  String _statusMessage = 'Authentification requise';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAuthentication();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _startAuthentication() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _statusMessage = 'Authentification en cours...';
    });

    try {
      // Petit délai pour que l'animation se termine
      await Future.delayed(const Duration(milliseconds: 500));

      final success = await _biometricService.authenticate(
        reason: widget.customMessage ?? 'Authentifiez-vous pour continuer à utiliser Silencia',
        useErrorDialogs: true,
        stickyAuth: true,
      );

      if (mounted) {
        if (success) {
          setState(() {
            _statusMessage = 'Authentification réussie !';
          });
          
          logger.security('Authentification overlay réussie', {
            'timestamp': DateTime.now().toIso8601String(),
          });
          
          // Petit délai pour montrer le succès
          await Future.delayed(const Duration(milliseconds: 500));
          
          widget.onAuthenticationSuccess?.call();
        } else {
          setState(() {
            _statusMessage = 'Authentification échouée';
            _isAuthenticating = false;
          });
          
          logger.warning('Authentification overlay échouée');
          widget.onAuthenticationFailed?.call();
        }
      }
    } catch (e) {
      logger.error('Erreur authentification overlay', e);
      
      if (mounted) {
        setState(() {
          _statusMessage = 'Erreur d\'authentification';
          _isAuthenticating = false;
        });
        
        widget.onAuthenticationFailed?.call();
      }
    }
  }



  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.9),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo Silencia avec animation
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: _animationService.securityLockAnimation(
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Titre
                Text(
                  'Silencia',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Message de statut
                Text(
                  _statusMessage,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Animation biométrique
                if (_isAuthenticating)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: _animationService.securityLockAnimation(
                            size: 64,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  )
                else
                  // Message d'erreur si l'authentification a échoué
                  Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: theme.colorScheme.error,
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'Authentification échouée',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: () {
                          widget.onAuthenticationFailed?.call();
                        },
                        child: const Text('Fermer'),
                      ),
                    ],
                  ),
                
                if (_isAuthenticating) ...[
                  const SizedBox(height: 24),
                  
                  // Indicateur de chargement
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    'Placez votre doigt sur le capteur\nou utilisez votre méthode d\'authentification',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
