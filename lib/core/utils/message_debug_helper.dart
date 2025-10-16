// lib/core/utils/message_debug_helper.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'multi_language_manager.dart';
import 'encryption_gcm_helper.dart';

/// Helper pour diagnostiquer les problèmes de décodage de messages
class MessageDebugHelper {
  
  /// Diagnostique complet d'un message qui ne se décode pas
  static Map<String, dynamic> diagnoseMessage(
    String codedText,
    String encryptedAAD,
    Map<String, Map<String, String>> languages,
    String mediaKey,
  ) {
    final diagnosis = <String, dynamic>{
      'codedText': codedText,
      'encryptedAAD': encryptedAAD.length > 50 ? '${encryptedAAD.substring(0, 50)}...' : encryptedAAD,
      'languagesCount': languages.length,
      'languageKeys': languages.keys.toList(),
      'steps': <Map<String, dynamic>>[],
      'errors': <String>[],
      'recommendations': <String>[],
    };

    void addStep(String step, String status, String details) {
      diagnosis['steps'].add({
        'step': step,
        'status': status,
        'details': details,
      });
      debugPrint('🔍 DIAGNOSIS: $step - $status: $details');
    }

    void addError(String error) {
      diagnosis['errors'].add(error);
      debugPrint('❌ DIAGNOSIS ERROR: $error');
    }

    void addRecommendation(String recommendation) {
      diagnosis['recommendations'].add(recommendation);
      debugPrint('💡 DIAGNOSIS RECOMMENDATION: $recommendation');
    }

    try {
      // Étape 1: Analyser le format du contenu
      addStep('1. Analyse format contenu', 'INFO', 'Longueur: ${codedText.length} caractères');
      
      final isGCMContent = EncryptionGCMHelper.isGCMFormat(codedText);
      addStep('1.1. Détection format GCM', isGCMContent ? 'SUCCESS' : 'INFO', 
              'Format GCM: $isGCMContent');

      // Étape 2: Analyser l'AAD
      addStep('2. Analyse AAD', 'INFO', 'Longueur: ${encryptedAAD.length} caractères');
      
      // Tenter de détecter le type d'AAD
      String aadType = 'UNKNOWN';
      String aadContent = '';
      
      try {
        // Test AAD authentifié (base64 JSON)
        final decoded = utf8.decode(base64Decode(encryptedAAD));
        final json = jsonDecode(decoded);
        if (json is Map && json.containsKey('v')) {
          aadType = 'AUTHENTICATED_JSON';
          aadContent = decoded;
          addStep('2.1. Type AAD', 'SUCCESS', 'AAD authentifié (JSON)');
        }
      } catch (e) {
        // Test format GCM
        if (EncryptionGCMHelper.isGCMFormat(encryptedAAD)) {
          aadType = 'GCM_ENCRYPTED';
          addStep('2.1. Type AAD', 'INFO', 'AAD chiffré GCM');
        } else if (encryptedAAD.contains(':')) {
          aadType = 'CBC_ENCRYPTED';
          addStep('2.1. Type AAD', 'INFO', 'AAD chiffré CBC (format IV:ciphertext)');
        } else {
          aadType = 'INVALID';
          addStep('2.1. Type AAD', 'ERROR', 'Format AAD non reconnu');
          addError('Format AAD invalide: ni JSON authentifié, ni GCM, ni CBC');
        }
      }

      // Étape 3: Tenter de déchiffrer l'AAD
      String? decryptedAAD;
      try {
        decryptedAAD = MultiLanguageManager.decryptAAD(encryptedAAD, mediaKey);
        addStep('3. Déchiffrement AAD', 'SUCCESS', 'AAD déchiffré avec succès');
        
        // Analyser le contenu de l'AAD
        try {
          final aadJson = jsonDecode(decryptedAAD);
          final version = aadJson['v'] ?? 'UNKNOWN';
          final mode = aadJson['mode'] ?? 'UNKNOWN';
          addStep('3.1. Analyse contenu AAD', 'SUCCESS', 'Version: $version, Mode: $mode');
          
          if (aadJson.containsKey('seq')) {
            final sequence = aadJson['seq'] as List;
            addStep('3.2. Séquence détectée', 'SUCCESS', 'Longueur: ${sequence.length}');
            
            // Vérifier les langues manquantes
            final missingLanguages = <String>[];
            for (final langKey in sequence) {
              if (!languages.containsKey(langKey)) {
                missingLanguages.add(langKey.toString());
              }
            }
            
            if (missingLanguages.isNotEmpty) {
              addStep('3.3. Vérification langues', 'WARNING', 
                      'Langues manquantes: $missingLanguages');
              addRecommendation('Synchroniser les langues manquantes: $missingLanguages');
            } else {
              addStep('3.3. Vérification langues', 'SUCCESS', 'Toutes les langues disponibles');
            }
          }
        } catch (e) {
          addStep('3.1. Analyse contenu AAD', 'ERROR', 'AAD n\'est pas du JSON valide: $e');
          addError('AAD déchiffré mais contenu invalide');
        }
      } catch (e) {
        addStep('3. Déchiffrement AAD', 'ERROR', 'Échec: $e');
        addError('Impossible de déchiffrer l\'AAD');
        addRecommendation('Vérifier la clé mediaKey');
        addRecommendation('Vérifier le format de l\'AAD');
      }

      // Étape 4: Tenter le décodage unifié
      try {
        final decoded = MultiLanguageManager.decodeMessageUnified(
          codedText,
          encryptedAAD,
          languages,
          mediaKey,
        );
        
        if (decoded.startsWith('[ERREUR DÉCODAGE]') || decoded.startsWith('[MESSAGE COMPROMIS]')) {
          addStep('4. Décodage unifié', 'ERROR', 'Échec: $decoded');
          addError('Décodage unifié a échoué');
        } else {
          addStep('4. Décodage unifié', 'SUCCESS', 'Message décodé: "$decoded"');
        }
      } catch (e) {
        addStep('4. Décodage unifié', 'ERROR', 'Exception: $e');
        addError('Exception lors du décodage unifié');
      }

      // Étape 5: Tests de décodage spécifiques
      if (decryptedAAD != null) {
        try {
          final aadJson = jsonDecode(decryptedAAD);
          final version = aadJson['v'];
          
          if (version == '2.3') {
            // Test décodage GCM
            addStep('5.1. Test décodage GCM', 'INFO', 'Tentative...');
            try {
              final isAuthAAD = aadType == 'AUTHENTICATED_JSON';
              final decoded = MultiLanguageManager.decodeMessageWithPerCharacterModeGCM(
                codedText,
                encryptedAAD,
                languages,
                mediaKey,
                isAuthenticatedAAD: isAuthAAD,
              );
              addStep('5.1. Test décodage GCM', 'SUCCESS', 'Réussi: "$decoded"');
            } catch (e) {
              addStep('5.1. Test décodage GCM', 'ERROR', 'Échec: $e');
            }
          } else if (version == '2.2') {
            // Test décodage CBC per-character
            addStep('5.2. Test décodage CBC per-char', 'INFO', 'Tentative...');
            try {
              final decoded = MultiLanguageManager.decodeMessageWithPerCharacterMode(
                codedText,
                encryptedAAD,
                languages,
                mediaKey,
              );
              addStep('5.2. Test décodage CBC per-char', 'SUCCESS', 'Réussi: "$decoded"');
            } catch (e) {
              addStep('5.2. Test décodage CBC per-char', 'ERROR', 'Échec: $e');
            }
          }
        } catch (e) {
          addStep('5. Tests spécifiques', 'ERROR', 'AAD JSON invalide: $e');
        }
      }

      // Générer les recommandations finales
      if (diagnosis['errors'].isEmpty) {
        addRecommendation('Le message semble correct, vérifier l\'implémentation');
      } else {
        if (aadType == 'INVALID') {
          addRecommendation('Vérifier le format de l\'AAD envoyé par l\'expéditeur');
        }
        if (languages.length != 10) {
          addRecommendation('Assurer que 10 langues sont disponibles pour le mode per-character');
        }
        addRecommendation('Vérifier la synchronisation des langues entre expéditeur et destinataire');
        addRecommendation('Tester avec un message simple pour isoler le problème');
      }

    } catch (e) {
      addError('Erreur critique lors du diagnostic: $e');
    }

    return diagnosis;
  }

  /// Affiche un rapport de diagnostic formaté
  static void printDiagnosisReport(Map<String, dynamic> diagnosis) {
    print('\n🔍 RAPPORT DE DIAGNOSTIC MESSAGE');
    print('═══════════════════════════════════════');
    print('📝 Message codé: ${diagnosis['codedText']}');
    print('🔐 AAD: ${diagnosis['encryptedAAD']}');
    print('🌐 Langues: ${diagnosis['languagesCount']} (${diagnosis['languageKeys']})');
    print('');
    
    print('📋 ÉTAPES DE DIAGNOSTIC:');
    for (final step in diagnosis['steps']) {
      final status = step['status'];
      final icon = status == 'SUCCESS' ? '✅' : 
                   status == 'WARNING' ? '⚠️' : 
                   status == 'ERROR' ? '❌' : 'ℹ️';
      print('$icon ${step['step']}: ${step['details']}');
    }
    
    if (diagnosis['errors'].isNotEmpty) {
      print('\n❌ ERREURS DÉTECTÉES:');
      for (final error in diagnosis['errors']) {
        print('   • $error');
      }
    }
    
    if (diagnosis['recommendations'].isNotEmpty) {
      print('\n💡 RECOMMANDATIONS:');
      for (final rec in diagnosis['recommendations']) {
        print('   • $rec');
      }
    }
    
    print('═══════════════════════════════════════\n');
  }

  /// Test rapide pour vérifier si un message peut être décodé
  static bool canDecodeMessage(
    String codedText,
    String encryptedAAD,
    Map<String, Map<String, String>> languages,
    String mediaKey,
  ) {
    try {
      final decoded = MultiLanguageManager.decodeMessageUnified(
        codedText,
        encryptedAAD,
        languages,
        mediaKey,
      );
      return !decoded.startsWith('[ERREUR DÉCODAGE]') && 
             !decoded.startsWith('[MESSAGE COMPROMIS]');
    } catch (e) {
      return false;
    }
  }
}
