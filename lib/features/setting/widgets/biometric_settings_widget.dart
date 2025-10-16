import 'package:flutter/material.dart';

import 'package:silencia/core/service/biometric_service.dart';
import 'package:silencia/core/service/logging_service.dart';

/// Widget pour configurer l'authentification biométrique
class BiometricSettingsWidget extends StatefulWidget {
  const BiometricSettingsWidget({super.key});

  @override
  State<BiometricSettingsWidget> createState() => _BiometricSettingsWidgetState();
}

class _BiometricSettingsWidgetState extends State<BiometricSettingsWidget> {
  final BiometricService _biometricService = BiometricService();
  
  BiometricCapabilities? _capabilities;
  bool _isLoading = true;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _loadCapabilities();
  }

  Future<void> _loadCapabilities() async {
    try {
      setState(() => _isLoading = true);
      
      final capabilities = await _biometricService.getCapabilities();
      
      if (mounted) {
        setState(() {
          _capabilities = capabilities;
          _isLoading = false;
        });
      }
    } catch (e) {
      logger.error('Erreur chargement capacités biométriques', e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (_isToggling) return;
    
    setState(() => _isToggling = true);
    
    try {
      final success = await _biometricService.setBiometricEnabled(enabled);
      
      if (success) {
        await _loadCapabilities(); // Recharger les capacités
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                enabled 
                  ? 'Authentification biométrique activée ✅'
                  : 'Authentification biométrique désactivée',
              ),
              backgroundColor: enabled ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                enabled 
                  ? 'Impossible d\'activer l\'authentification biométrique'
                  : 'Erreur lors de la désactivation',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      logger.error('Erreur toggle biométrique', e);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la modification des paramètres'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  Future<void> _testBiometric() async {
    try {
      // Test de disponibilité d'abord
      final testResult = await _biometricService.testBiometricAvailability();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              testResult.success
                ? 'Test réussi ! 🎉 ${testResult.message}'
                : 'Test échoué: ${testResult.message}',
            ),
            backgroundColor: testResult.success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Si le test de base réussit, essayer l'authentification complète
      if (testResult.success) {
        await Future.delayed(const Duration(seconds: 1));

        final authSuccess = await _biometricService.authenticate(
          reason: 'Test complet de l\'authentification biométrique',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                authSuccess
                  ? 'Authentification complète réussie ! ✅'
                  : 'Authentification échouée ❌',
              ),
              backgroundColor: authSuccess ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      logger.error('Erreur test biométrique', e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  IconData _getBiometricIcon() {
    if (_capabilities == null) return Icons.fingerprint;
    
    if (_capabilities!.hasFace) return Icons.face;
    if (_capabilities!.hasFingerprint) return Icons.fingerprint;
    if (_capabilities!.hasIris) return Icons.visibility;
    return Icons.security;
  }

  String _getBiometricDescription() {
    if (_capabilities == null || !_capabilities!.isFullyAvailable) {
      return 'Authentification biométrique non disponible';
    }
    
    final types = <String>[];
    if (_capabilities!.hasFingerprint) types.add('empreinte');
    if (_capabilities!.hasFace) types.add('visage');
    if (_capabilities!.hasIris) types.add('iris');
    
    if (types.isEmpty) return 'Biométrie disponible';
    
    return 'Disponible: ${types.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Vérification des capacités biométriques...'),
            ],
          ),
        ),
      );
    }

    if (_capabilities == null || !_capabilities!.isSupported) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                Icons.warning,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Authentification biométrique non supportée sur cet appareil',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                Icon(
                  _getBiometricIcon(),
                  color: _capabilities!.isEnabled 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Authentification biométrique',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getBiometricDescription(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isToggling)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: _capabilities!.isEnabled,
                    onChanged: _capabilities!.isFullyAvailable ? _toggleBiometric : null,
                  ),
              ],
            ),
            
            if (_capabilities!.isFullyAvailable) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Description détaillée
              Text(
                'Sécurisez l\'accès à votre application avec votre ${_capabilities!.primaryBiometricName.toLowerCase()}. '
                'Vous pourrez toujours utiliser votre mot de passe en cas de problème.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Bouton de test
              if (_capabilities!.isEnabled)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _testBiometric,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Tester l\'authentification'),
                  ),
                ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Veuillez configurer l\'authentification biométrique dans les paramètres de votre appareil',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
