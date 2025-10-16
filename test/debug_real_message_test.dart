// test/debug_real_message_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';
import 'package:silencia/core/utils/message_debug_helper.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';

void main() {
  group('Debug Message Réel', () {
    late Map<String, Map<String, String>> languages;
    late String mediaKey;

    setUpAll(() {
      final package = LangMapGenerator.generateLanguagePackage();
      languages = Map<String, Map<String, String>>.from(
        (package['languages'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v))),
      );
      mediaKey = package['mediaKey'] as String;
    });

    test('Diagnostic message zesd avec données réelles', () {
      // REMPLACEZ CES VALEURS PAR VOS VRAIES DONNÉES
      const realCodedText = 'zesd';
      const realEncryptedAAD = 'REMPLACER_PAR_VOTRE_VRAIE_VALEUR_AAD';
      
      print('\n🔍 DIAGNOSTIC MESSAGE RÉEL');
      print('═══════════════════════════════════════');
      print('📝 Message codé: $realCodedText');
      print('🔐 AAD fourni: $realEncryptedAAD');
      
      if (realEncryptedAAD == 'REMPLACER_PAR_VOTRE_VRAIE_VALEUR_AAD') {
        print('\n⚠️ INSTRUCTIONS:');
        print('1. Remplacez realEncryptedAAD par votre vraie valeur AAD');
        print('2. Si vous n\'avez pas l\'AAD, nous allons simuler différents scénarios');
        print('3. Relancez ce test après modification');
        
        // Simuler différents scénarios possibles
        _testDifferentScenarios(realCodedText, languages, mediaKey);
      } else {
        // Diagnostic avec vraies données
        final diagnosis = MessageDebugHelper.diagnoseMessage(
          realCodedText,
          realEncryptedAAD,
          languages,
          mediaKey,
        );
        
        MessageDebugHelper.printDiagnosisReport(diagnosis);
        
        // Test de décodage direct
        print('\n🧪 TEST DÉCODAGE DIRECT:');
        try {
          final decoded = MultiLanguageManager.decodeMessageUnified(
            realCodedText,
            realEncryptedAAD,
            languages,
            mediaKey,
          );
          print('✅ Résultat: "$decoded"');
        } catch (e) {
          print('❌ Erreur: $e');
        }
      }
    });

    test('Analyse caractères du message zesd', () {
      const message = 'zesd';
      print('\n🔬 ANALYSE CARACTÈRES: "$message"');
      print('═══════════════════════════════════════');
      
      for (int i = 0; i < message.length; i++) {
        final char = message[i];
        print('Position $i: "$char" (code: ${char.codeUnitAt(0)})');
        
        // Chercher dans quelles langues ce caractère existe
        final foundInLanguages = <String>[];
        for (final entry in languages.entries) {
          final langKey = entry.key;
          final langMap = entry.value;
          
          // Chercher le caractère dans les valeurs (côté codé)
          if (langMap.values.contains(char)) {
            foundInLanguages.add(langKey);
          }
        }
        
        if (foundInLanguages.isNotEmpty) {
          print('   Trouvé dans: $foundInLanguages');
        } else {
          print('   ❌ Caractère non trouvé dans aucune langue!');
        }
      }
    });

    test('Recherche reverse mapping pour zesd', () {
      const message = 'zesd';
      print('\n🔄 RECHERCHE REVERSE MAPPING: "$message"');
      print('═══════════════════════════════════════');
      
      // Essayer chaque langue individuellement
      for (final entry in languages.entries) {
        final langKey = entry.key;
        final langMap = entry.value;
        
        print('\n🌐 Test avec langue: $langKey');
        
        try {
          String decoded = '';
          bool canDecode = true;
          
          for (int i = 0; i < message.length; i++) {
            final char = message[i];
            
            // Chercher la clé correspondant à cette valeur
            String? originalChar;
            for (final mapEntry in langMap.entries) {
              if (mapEntry.value == char) {
                originalChar = mapEntry.key;
                break;
              }
            }
            
            if (originalChar != null) {
              decoded += originalChar;
              print('   "$char" -> "$originalChar"');
            } else {
              print('   "$char" -> ❌ NON TROUVÉ');
              canDecode = false;
              break;
            }
          }
          
          if (canDecode) {
            print('   ✅ Décodage complet: "$decoded"');
          } else {
            print('   ❌ Décodage impossible');
          }
        } catch (e) {
          print('   ❌ Erreur: $e');
        }
      }
    });

    test('Génération AAD compatible pour zesd', () {
      const message = 'zesd';
      print('\n🔧 GÉNÉRATION AAD COMPATIBLE: "$message"');
      print('═══════════════════════════════════════');
      
      // Essayer de créer un message qui produit "zesd"
      for (int attempt = 0; attempt < 10; attempt++) {
        try {
          // Créer un message aléatoire court
          final testMessage = 'test${attempt}';
          
          // Mode CBC v2.2
          final preparedCBC = MultiLanguageManager.prepareMessage(
            testMessage,
            languages,
            mediaKey,
            useGCMEncryption: false,
          );
          
          // Mode GCM v2.3
          final preparedGCM = MultiLanguageManager.prepareMessage(
            testMessage,
            languages,
            mediaKey,
            useGCMEncryption: true,
            useAuthenticatedAAD: true,
          );
          
          print('Tentative $attempt: "$testMessage"');
          print('   CBC: "${preparedCBC['codedText']}"');
          print('   GCM: "${preparedGCM['codedText'] ?? 'N/A'}"');
          
          // Vérifier si on obtient quelque chose proche
          if (preparedCBC['codedText'].toString().contains('z') ||
              preparedCBC['codedText'].toString().contains('e') ||
              preparedCBC['codedText'].toString().contains('s') ||
              preparedCBC['codedText'].toString().contains('d')) {
            print('   🎯 MATCH PARTIEL CBC!');
            
            // Tester le décodage
            final decoded = MultiLanguageManager.decodeMessageUnified(
              preparedCBC['codedText'],
              preparedCBC['encryptedAAD'],
              languages,
              mediaKey,
            );
            print('   ✅ Décodé: "$decoded"');
          }
          
        } catch (e) {
          print('Tentative $attempt: Erreur = $e');
        }
      }
    });
  });
}

void _testDifferentScenarios(String codedText, Map<String, Map<String, String>> languages, String mediaKey) {
  print('\n🧪 SIMULATION DIFFÉRENTS SCÉNARIOS');
  print('═══════════════════════════════════════');
  
  // Scénario 1: Message v2.0 (single language)
  print('\n📋 Scénario 1: Message v2.0 (single language)');
  for (final langKey in ['lang_00', 'lang_01', 'lang_02', 'lang_05']) {
    try {
      final aad = MultiLanguageManager.encryptAAD(langKey, mediaKey);
      final decoded = MultiLanguageManager.decodeMessageUnified(codedText, aad, languages, mediaKey);
      print('   $langKey: "$decoded"');
      if (!decoded.startsWith('[ERREUR DÉCODAGE]')) {
        print('   ✅ SUCCÈS avec $langKey!');
      }
    } catch (e) {
      print('   $langKey: Erreur = $e');
    }
  }
  
  // Scénario 2: Message v2.2 (per-character CBC)
  print('\n📋 Scénario 2: Message v2.2 (per-character CBC)');
  try {
    // Créer un AAD v2.2 avec séquence correspondant à la longueur
    final aadJson = {
      'v': '2.2',
      'mode': 'perchar-seq',
      'seq': ['lang_00', 'lang_01', 'lang_02', 'lang_03'], // 4 langues pour 4 caractères
    };
    final aadString = jsonEncode(aadJson);
    final encryptedAAD = MultiLanguageManager.encryptAAD(aadString, mediaKey);
    
    final decoded = MultiLanguageManager.decodeMessageUnified(codedText, encryptedAAD, languages, mediaKey);
    print('   Résultat: "$decoded"');
    if (!decoded.startsWith('[ERREUR DÉCODAGE]')) {
      print('   ✅ SUCCÈS avec v2.2!');
    }
  } catch (e) {
    print('   Erreur v2.2: $e');
  }
  
  // Scénario 3: Message v2.3 (per-character GCM) avec AAD authentifié
  print('\n📋 Scénario 3: Message v2.3 (AAD authentifié)');
  try {
    final aadJson = {
      'v': '2.3',
      'enc': 'gcm',
      'mode': 'perchar-seq',
      'seq': ['lang_00', 'lang_01', 'lang_02', 'lang_03'],
    };
    final aadString = jsonEncode(aadJson);
    final aadBase64 = base64Encode(utf8.encode(aadString));
    
    final decoded = MultiLanguageManager.decodeMessageUnified(codedText, aadBase64, languages, mediaKey);
    print('   Résultat: "$decoded"');
    if (!decoded.startsWith('[ERREUR DÉCODAGE]')) {
      print('   ✅ SUCCÈS avec v2.3 authentifié!');
    }
  } catch (e) {
    print('   Erreur v2.3: $e');
  }
}
