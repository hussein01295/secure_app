// test/debug_kn3k_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';
import 'package:silencia/core/utils/message_debug_helper.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';

void main() {
  group('Debug Message kn3k', () {
    late Map<String, Map<String, String>> languages;
    late String mediaKey;

    setUpAll(() {
      final package = LangMapGenerator.generateLanguagePackage();
      languages = Map<String, Map<String, String>>.from(
        (package['languages'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v))),
      );
      mediaKey = package['mediaKey'] as String;
    });

    test('Diagnostic message kn3k avec AAD exemple', () {
      // Simuler votre problème avec un message qui ressemble à "kn3k"
      const problematicCodedText = 'kn3k';
      
      // Créer différents types d'AAD pour tester
      final testCases = <String, String>{
        'AAD_CBC_VALIDE': '',
        'AAD_GCM_AUTH': '',
        'AAD_GCM_CHIFFRE': '',
        'AAD_INVALIDE': 'aad_invalide_sans_format',
        'AAD_CORROMPU': 'YWFkX2NvcnJvbXB1X2Jhc2U2NA==', // base64 de "aad_corrompu_base64"
      };

      // Générer des AAD valides pour les tests
      // 1. AAD CBC valide
      testCases['AAD_CBC_VALIDE'] = MultiLanguageManager.encryptAAD('lang_05', mediaKey);
      
      // 2. AAD GCM authentifié
      final aadJsonAuth = {
        'v': '2.3',
        'enc': 'gcm',
        'mode': 'perchar-seq',
        'seq': ['lang_00', 'lang_01', 'lang_02', 'lang_03'],
      };
      testCases['AAD_GCM_AUTH'] = base64Encode(utf8.encode(jsonEncode(aadJsonAuth)));
      
      // 3. AAD GCM chiffré
      final prepared = MultiLanguageManager.prepareMessage(
        'test',
        languages,
        mediaKey,
        useGCMEncryption: true,
        useAuthenticatedAAD: false,
      );
      testCases['AAD_GCM_CHIFFRE'] = prepared['encryptedAAD'];

      // Tester chaque cas
      for (final entry in testCases.entries) {
        print('\n🧪 TEST CASE: ${entry.key}');
        print('═══════════════════════════════════════');
        
        final diagnosis = MessageDebugHelper.diagnoseMessage(
          problematicCodedText,
          entry.value,
          languages,
          mediaKey,
        );
        
        MessageDebugHelper.printDiagnosisReport(diagnosis);
        
        // Vérifier si le message peut être décodé
        final canDecode = MessageDebugHelper.canDecodeMessage(
          problematicCodedText,
          entry.value,
          languages,
          mediaKey,
        );
        
        print('🎯 RÉSULTAT: ${canDecode ? "DÉCODAGE POSSIBLE" : "DÉCODAGE IMPOSSIBLE"}');
      }
    });

    test('Créer et tester un vrai message qui produit kn3k', () {
      // Essayer de créer un message qui produit "kn3k" comme texte codé
      print('\n🔬 CRÉATION MESSAGE PRODUISANT kn3k');
      print('═══════════════════════════════════════');
      
      // Tester différents messages courts
      final testMessages = ['test', 'salut', 'hello', 'abc', 'xyz'];
      
      for (final message in testMessages) {
        // Créer avec CBC
        final preparedCBC = MultiLanguageManager.prepareMessage(
          message,
          languages,
          mediaKey,
          useGCMEncryption: false,
        );
        
        // Créer avec GCM
        final preparedGCM = MultiLanguageManager.prepareMessage(
          message,
          languages,
          mediaKey,
          useGCMEncryption: true,
          useAuthenticatedAAD: true,
        );
        
        print('📝 Message: "$message"');
        print('   CBC codé: "${preparedCBC['codedText']}"');
        print('   GCM codé: "${preparedGCM['codedText'] ?? 'N/A'}"');
        
        // Vérifier si on obtient quelque chose proche de "kn3k"
        if (preparedCBC['codedText'].toString().contains('k') || 
            preparedCBC['codedText'].toString().contains('n') ||
            preparedCBC['codedText'].toString().contains('3')) {
          print('   🎯 MATCH POTENTIEL CBC!');
          
          // Tester le décodage
          final decoded = MultiLanguageManager.decodeMessageUnified(
            preparedCBC['codedText'],
            preparedCBC['encryptedAAD'],
            languages,
            mediaKey,
          );
          print('   ✅ Décodé: "$decoded"');
        }
      }
    });

    test('Diagnostic avec vos données réelles', () {
      // Si vous avez les vraies données, remplacez ici
      const realCodedText = 'kn3k';
      const realEncryptedAAD = 'REMPLACER_PAR_VOTRE_AAD_REEL';
      
      if (realEncryptedAAD != 'REMPLACER_PAR_VOTRE_AAD_REEL') {
        print('\n🔍 DIAGNOSTIC DONNÉES RÉELLES');
        print('═══════════════════════════════════════');
        
        final diagnosis = MessageDebugHelper.diagnoseMessage(
          realCodedText,
          realEncryptedAAD,
          languages,
          mediaKey,
        );
        
        MessageDebugHelper.printDiagnosisReport(diagnosis);
      } else {
        print('\n⚠️ Pour diagnostiquer vos données réelles:');
        print('1. Remplacez realEncryptedAAD par votre vraie valeur AAD');
        print('2. Vérifiez que realCodedText correspond à votre message');
        print('3. Relancez ce test');
      }
    });

    test('Test réparation automatique des langues', () {
      print('\n🔧 TEST RÉPARATION LANGUES');
      print('═══════════════════════════════════════');
      
      // Créer un message avec une langue manquante
      final incompleteLanguages = Map<String, Map<String, String>>.from(languages);
      incompleteLanguages.remove('lang_05'); // Supprimer une langue
      
      print('🌐 Langues disponibles: ${incompleteLanguages.keys.length}/10');
      print('🚫 Langue manquante: lang_05');
      
      // Créer un message normal
      final prepared = MultiLanguageManager.prepareMessage(
        'test',
        languages, // Utiliser toutes les langues pour la création
        mediaKey,
        useGCMEncryption: false,
      );
      
      print('📝 Message créé: "${prepared['codedText']}"');
      
      // Essayer de décoder avec langues incomplètes
      final decoded = MultiLanguageManager.decodeMessageUnified(
        prepared['codedText'],
        prepared['encryptedAAD'],
        incompleteLanguages, // Langues incomplètes pour le décodage
        mediaKey,
        autoRepairLanguages: true,
      );
      
      print('🔓 Résultat décodage: "$decoded"');
      
      if (decoded.startsWith('[ERREUR DÉCODAGE]')) {
        print('❌ Échec même avec réparation automatique');
        
        // Diagnostic détaillé
        final diagnosis = MessageDebugHelper.diagnoseMessage(
          prepared['codedText'],
          prepared['encryptedAAD'],
          incompleteLanguages,
          mediaKey,
        );
        
        MessageDebugHelper.printDiagnosisReport(diagnosis);
      } else {
        print('✅ Réparation automatique réussie!');
      }
    });
  });
}
