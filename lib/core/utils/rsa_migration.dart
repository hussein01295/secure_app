import 'package:flutter/foundation.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'rsa_serrvice.dart';

/// Service de migration pour corriger la vulnérabilité RSA critique
/// 
/// Cette migration régénère toutes les clés RSA avec un seed cryptographiquement sûr
/// pour corriger la vulnérabilité du seed prévisible (DateTime-based).
class RSAMigration {
  static const String _migrationKey = 'rsa_migration_v2_done';
  static const String _migrationDateKey = 'rsa_migration_v2_date';
  
  /// Vérifie si la migration est nécessaire et l'exécute
  /// 
  /// Retourne `true` si la migration a réussi ou était déjà faite
  /// Retourne `false` en cas d'erreur
  static Future<bool> checkAndMigrate() async {
    try {
      // Vérifier si la migration a déjà été faite
      final migrationDone = await RSAKeyService.storage.read(key: _migrationKey);
      
      if (migrationDone == 'true') {
        if (kDebugMode) {
          final migrationDate = await RSAKeyService.storage.read(key: _migrationDateKey);
          debugPrint('✅ Migration RSA v2 déjà effectuée le $migrationDate');
        }
        return true;
      }
      
      debugPrint('🔄 Migration RSA v2 nécessaire - Régénération des clés...');
      debugPrint('⚠️  Raison: Correction de la vulnérabilité du seed prévisible');
      
      // Récupérer le token d'accès
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('❌ Token non disponible pour la migration RSA');
        debugPrint('ℹ️  La migration sera effectuée au prochain login');
        return false;
      }
      
      // Sauvegarder les anciennes clés pour audit (optionnel)
      if (kDebugMode) {
        final oldPublicKey = await RSAKeyService.storage.read(key: 'rsa_public_key');
        if (oldPublicKey != null) {
          await RSAKeyService.storage.write(
            key: 'rsa_public_key_old_v1',
            value: oldPublicKey,
          );
          debugPrint('📦 Ancienne clé publique sauvegardée pour audit');
        }
      }
      
      // Régénérer les clés avec le nouveau code sécurisé
      await RSAKeyService.generateAndStoreKeyPair(token);
      
      // Marquer la migration comme terminée avec timestamp
      final now = DateTime.now().toIso8601String();
      await RSAKeyService.storage.write(key: _migrationKey, value: 'true');
      await RSAKeyService.storage.write(key: _migrationDateKey, value: now);
      
      debugPrint('✅ Migration RSA v2 terminée avec succès');
      debugPrint('🔐 Nouvelles clés générées avec seed cryptographiquement sûr');
      
      return true;
      
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur lors de la migration RSA: $e');
      if (kDebugMode) {
        debugPrint('Stack trace: $stackTrace');
      }
      return false;
    }
  }
  
  /// Force la régénération des clés (pour tests ou maintenance)
  /// 
  /// ⚠️ ATTENTION : Cette méthode supprime les clés existantes
  static Future<bool> forceRegenerate() async {
    try {
      debugPrint('🔄 Régénération forcée des clés RSA...');
      
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('❌ Token non disponible');
        return false;
      }
      
      // Supprimer les anciennes clés
      await RSAKeyService.storage.delete(key: 'rsa_private_key');
      await RSAKeyService.storage.delete(key: 'rsa_public_key');
      
      // Régénérer
      await RSAKeyService.generateAndStoreKeyPair(token);
      
      // Mettre à jour le timestamp de migration
      final now = DateTime.now().toIso8601String();
      await RSAKeyService.storage.write(key: _migrationKey, value: 'true');
      await RSAKeyService.storage.write(key: _migrationDateKey, value: now);
      
      debugPrint('✅ Régénération forcée terminée');
      return true;
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la régénération forcée: $e');
      return false;
    }
  }
  
  /// Vérifie le statut de la migration
  /// 
  /// Retourne un Map avec les informations de migration
  static Future<Map<String, dynamic>> getMigrationStatus() async {
    try {
      final migrationDone = await RSAKeyService.storage.read(key: _migrationKey);
      final migrationDate = await RSAKeyService.storage.read(key: _migrationDateKey);
      final hasPublicKey = await RSAKeyService.storage.read(key: 'rsa_public_key') != null;
      final hasPrivateKey = await RSAKeyService.storage.read(key: 'rsa_private_key') != null;
      
      return {
        'migrated': migrationDone == 'true',
        'migrationDate': migrationDate,
        'hasPublicKey': hasPublicKey,
        'hasPrivateKey': hasPrivateKey,
        'keysValid': hasPublicKey && hasPrivateKey,
      };
    } catch (e) {
      debugPrint('❌ Erreur lors de la vérification du statut: $e');
      return {
        'migrated': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Nettoie les anciennes clés sauvegardées pour audit
  static Future<void> cleanupOldKeys() async {
    try {
      await RSAKeyService.storage.delete(key: 'rsa_public_key_old_v1');
      await RSAKeyService.storage.delete(key: 'rsa_private_key_old_v1');
      debugPrint('🗑️  Anciennes clés d\'audit supprimées');
    } catch (e) {
      debugPrint('⚠️  Erreur lors du nettoyage: $e');
    }
  }
  
  /// Affiche un rapport détaillé de la migration (debug uniquement)
  static Future<void> printMigrationReport() async {
    if (!kDebugMode) return;
    
    final status = await getMigrationStatus();
    
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('📊 RAPPORT DE MIGRATION RSA v2');
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('Migration effectuée: ${status['migrated'] ? '✅ Oui' : '❌ Non'}');
    
    if (status['migrationDate'] != null) {
      debugPrint('Date de migration: ${status['migrationDate']}');
    }
    
    debugPrint('Clé publique présente: ${status['hasPublicKey'] ? '✅' : '❌'}');
    debugPrint('Clé privée présente: ${status['hasPrivateKey'] ? '✅' : '❌'}');
    debugPrint('Clés valides: ${status['keysValid'] ? '✅' : '❌'}');
    
    if (status['error'] != null) {
      debugPrint('Erreur: ${status['error']}');
    }
    
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('');
  }
}

