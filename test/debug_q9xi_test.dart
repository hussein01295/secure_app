// test/debug_q9xi_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';
import 'package:silencia/core/utils/message_debug_helper.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';

void main() {
  group('Debug Message q9xi v2.3', () {
    late Map<String, Map<String, String>> languages;
    late String mediaKey;

    setUpAll(() {
      final package = LangMapGenerator.generateLanguagePackage();
      languages = Map<String, Map<String, String>>.from(
        (package['languages'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v))),
      );
      mediaKey = package['mediaKey'] as String;
    });

    test('Diagnostic message q9xi avec AAD v2.3 réel', () {
      const codedText = 'q9xi';
      
      // Créer l'AAD v2.3 exact de votre erreur
      final aadJson = {
        'v': '2.3',
        'enc': 'gcm',
        'mode': 'perchar-seq',
        'timestamp': 1759972501416,
        'seq': ['lang_00', 'lang_00', 'lang_04', 'lang_04'],
        'msgLen': 4,
      };
      
      // Test avec AAD authentifié (comme dans votre erreur)
      final aadString = jsonEncode(aadJson);
      final aadBase64 = base64Encode(utf8.encode(aadString));
      
      print('\n🔍 TEST AVEC AAD v2.3 RÉEL');
      print('═══════════════════════════════════════');
      print('📝 Message codé: $codedText');
      print('🔐 AAD v2.3: ${aadString.substring(0, 50)}...');
      print('🎯 Séquence: ${aadJson['seq']}');
      
      // Diagnostic complet
      final diagnosis = MessageDebugHelper.diagnoseMessage(
        codedText,
        aadBase64,
        languages,
        mediaKey,
      );
      
      MessageDebugHelper.printDiagnosisReport(diagnosis);
      
      // Test de décodage direct
      print('\n🧪 TEST DÉCODAGE UNIFIÉ:');
      final decoded = MultiLanguageManager.decodeMessageUnified(
        codedText,
        aadBase64,
        languages,
        mediaKey,
      );
      print('✅ Résultat: "$decoded"');
      
      // Vérifier que ce n'est plus une erreur
      expect(decoded, isNot(startsWith('[ERREUR DÉCODAGE]')));
    });

    test('Décodage manuel avec séquence v2.3', () {
      const codedText = 'q9xi';
      const sequence = ['lang_00', 'lang_00', 'lang_04', 'lang_04'];
      
      print('\n🔧 DÉCODAGE MANUEL AVEC SÉQUENCE v2.3');
      print('═══════════════════════════════════════');
      print('📝 Message: $codedText');
      print('🎯 Séquence: $sequence');
      
      // Décodage caractère par caractère
      String decoded = '';
      for (int i = 0; i < codedText.length; i++) {
        final char = codedText[i];
        final langKey = sequence[i];
        final langMap = languages[langKey]!;
        
        // Chercher le caractère original
        String? originalChar;
        for (final entry in langMap.entries) {
          if (entry.value == char) {
            originalChar = entry.key;
            break;
          }
        }
        
        if (originalChar != null) {
          decoded += originalChar;
          print('Position $i: "$char" ($langKey) -> "$originalChar"');
        } else {
          print('Position $i: "$char" ($langKey) -> ❌ NON TROUVÉ');
          decoded += '?';
        }
      }
      
      print('✅ Message décodé: "$decoded"');
      expect(decoded, isNot(contains('?')));
    });

    test('Test fallback v2.3 vers v2.2', () {
      const codedText = 'q9xi';
      
      // Créer AAD v2.3 avec contenu non-GCM (devrait déclencher fallback)
      final aadJson = {
        'v': '2.3',
        'enc': 'gcm',
        'mode': 'perchar-seq',
        'seq': ['lang_00', 'lang_00', 'lang_04', 'lang_04'],
        'msgLen': 4,
      };
      
      final aadString = jsonEncode(aadJson);
      final aadBase64 = base64Encode(utf8.encode(aadString));
      
      print('\n🔄 TEST FALLBACK v2.3 -> v2.2');
      print('═══════════════════════════════════════');
      
      // Le système devrait détecter que "q9xi" n'est pas du contenu GCM
      // et faire un fallback vers la méthode v2.2 (maintenant corrigée)
      final decoded = MultiLanguageManager.decodeMessageUnified(
        codedText,
        aadBase64,
        languages,
        mediaKey,
      );
      
      print('✅ Résultat fallback: "$decoded"');
      expect(decoded, isNot(startsWith('[ERREUR DÉCODAGE]')));
      expect(decoded, isNot(startsWith('[MESSAGE COMPROMIS]')));
    });

    test('Comparaison avec message GCM réel', () {
      print('\n🆚 COMPARAISON GCM RÉEL vs TEXTE CODÉ');
      print('═══════════════════════════════════════');
      
      // Créer un vrai message GCM v2.3
      const testMessage = 'test';
      final prepared = MultiLanguageManager.prepareMessage(
        testMessage,
        languages,
        mediaKey,
        useGCMEncryption: true,
        useAuthenticatedAAD: true,
      );
      
      final gcmContent = prepared['encryptedContent'] as String;
      final gcmAAD = prepared['encryptedAAD'] as String;
      
      print('📝 Message original: "$testMessage"');
      print('🔐 Contenu GCM: ${gcmContent.substring(0, 20)}... (${gcmContent.length} chars)');
      print('📋 AAD GCM: ${gcmAAD.substring(0, 20)}... (${gcmAAD.length} chars)');
      
      // Décoder le vrai message GCM
      final decodedGCM = MultiLanguageManager.decodeMessageUnified(
        gcmContent,
        gcmAAD,
        languages,
        mediaKey,
      );
      print('✅ Décodage GCM: "$decodedGCM"');
      
      // Comparer avec notre message problématique
      print('\n🔍 Comparaison:');
      print('   Message GCM: ${gcmContent.length} caractères, format binaire');
      print('   Message q9xi: 4 caractères, format texte');
      print('   -> q9xi est clairement du texte codé, pas du contenu GCM');
      
      expect(decodedGCM, equals(testMessage));
    });

    test('Vérification réparation automatique', () {
      const codedText = 'q9xi';
      
      // Simuler le scénario exact de votre erreur
      final aadJson = {
        'v': '2.3',
        'enc': 'gcm',
        'mode': 'perchar-seq',
        'timestamp': 1759972501416,
        'seq': ['lang_00', 'lang_00', 'lang_04', 'lang_04'],
        'msgLen': 4,
      };
      
      final aadString = jsonEncode(aadJson);
      final aadBase64 = base64Encode(utf8.encode(aadString));
      
      print('\n🔧 VÉRIFICATION RÉPARATION AUTOMATIQUE');
      print('═══════════════════════════════════════');
      
      // Test avec réparation automatique activée
      final decoded = MultiLanguageManager.decodeMessageUnified(
        codedText,
        aadBase64,
        languages,
        mediaKey,
        autoRepairLanguages: true,
      );
      
      print('✅ Résultat avec réparation: "$decoded"');
      
      // Maintenant ça ne devrait plus retourner d'erreur
      expect(decoded, isNot(startsWith('[ERREUR DÉCODAGE]')));
      expect(decoded, isNot(startsWith('[MESSAGE COMPROMIS]')));
      
      // Vérifier que c'est un message sensé
      expect(decoded.length, equals(4));
      expect(decoded, matches(r'^[a-zA-Z0-9\s\.\!\?\-\+\*\/\=\(\)\[\]\{\}\<\>\@\#\$\%\^\&\|\~\`\;\:\,\_]+$'));
    });
  });
}
