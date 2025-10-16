// test/verify_current_encryption_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';

void main() {
  group('Vérification Chiffrement Actuel', () {
    late Map<String, Map<String, String>> languages;
    late String mediaKey;

    setUpAll(() {
      final package = LangMapGenerator.generateLanguagePackage();
      languages = Map<String, Map<String, String>>.from(
        (package['languages'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v))),
      );
      mediaKey = package['mediaKey'] as String;
    });

    test('Vérifier le mode par défaut de prepareMessage', () {
      const message = 'test encryption mode';
      
      print('\n🔍 VÉRIFICATION MODE PAR DÉFAUT');
      print('═══════════════════════════════════════');
      
      // Appel EXACT comme dans votre app (sans paramètres GCM)
      final result = MultiLanguageManager.prepareMessage(
        message,
        languages,
        mediaKey,
        forcePerCharacterMode: true, // Comme dans votre app
      );
      
      print('📝 Message: "$message"');
      print('🔧 Paramètres utilisés:');
      print('   forcePerCharacterMode: true');
      print('   useGCMEncryption: [valeur par défaut]');
      print('   useAuthenticatedAAD: [valeur par défaut]');
      
      print('\n📊 RÉSULTATS:');
      print('   Version: ${result['version']}');
      print('   Mode chiffrement: ${result['encryptionMode']}');
      print('   Champs présents: ${result.keys.toList()}');
      
      // Analyser le type de contenu
      if (result.containsKey('encryptedContent')) {
        final content = result['encryptedContent'] as String;
        print('   Type contenu: GCM (encryptedContent)');
        print('   Longueur contenu: ${content.length} caractères');
        print('   Échantillon: ${content.substring(0, 20)}...');
      } else if (result.containsKey('codedText')) {
        final content = result['codedText'] as String;
        print('   Type contenu: CBC (codedText)');
        print('   Longueur contenu: ${content.length} caractères');
        print('   Échantillon: "$content"');
      }
      
      // Analyser l'AAD
      final aad = result['encryptedAAD'] as String;
      print('   Longueur AAD: ${aad.length} caractères');
      
      // Tenter de décoder l'AAD pour voir sa structure
      try {
        final aadDecoded = MultiLanguageManager.decryptAAD(aad, mediaKey);
        final aadJson = jsonDecode(aadDecoded);
        print('   Structure AAD: ${aadJson}');
        print('   Version AAD: ${aadJson['v']}');
        print('   Encryption AAD: ${aadJson['enc'] ?? 'N/A'}');
      } catch (e) {
        print('   AAD: Format legacy (non-JSON)');
      }
      
      // Conclusion
      if (result['version'] == '2.3' && result['encryptionMode'] == 'gcm') {
        print('\n✅ CONCLUSION: Votre app utilise GCM v2.3 par défaut !');
      } else if (result['version'] == '2.2') {
        print('\n⚠️ CONCLUSION: Votre app utilise encore CBC v2.2');
      } else {
        print('\n❓ CONCLUSION: Mode non déterminé');
      }
    });

    test('Comparaison explicite GCM vs CBC', () {
      const message = 'test comparaison';
      
      print('\n🆚 COMPARAISON GCM vs CBC');
      print('═══════════════════════════════════════');
      
      // Mode GCM explicite
      final gcmResult = MultiLanguageManager.prepareMessage(
        message,
        languages,
        mediaKey,
        forcePerCharacterMode: true,
        useGCMEncryption: true,
        useAuthenticatedAAD: true,
      );
      
      // Mode CBC explicite
      final cbcResult = MultiLanguageManager.prepareMessage(
        message,
        languages,
        mediaKey,
        forcePerCharacterMode: true,
        useGCMEncryption: false,
      );
      
      print('📊 RÉSULTATS COMPARAISON:');
      print('');
      print('🔐 Mode GCM:');
      print('   Version: ${gcmResult['version']}');
      print('   Encryption: ${gcmResult['encryptionMode']}');
      print('   Champs: ${gcmResult.keys.toList()}');
      print('   Contenu: ${gcmResult.containsKey('encryptedContent') ? 'encryptedContent' : 'codedText'}');
      
      print('');
      print('🔓 Mode CBC:');
      print('   Version: ${cbcResult['version']}');
      print('   Encryption: ${cbcResult['encryptionMode'] ?? 'cbc'}');
      print('   Champs: ${cbcResult.keys.toList()}');
      print('   Contenu: ${cbcResult.containsKey('encryptedContent') ? 'encryptedContent' : 'codedText'}');
      
      // Vérifier que les modes sont différents
      expect(gcmResult['version'], equals('2.3'));
      expect(gcmResult['encryptionMode'], equals('gcm'));
      expect(gcmResult.containsKey('encryptedContent'), isTrue);
      
      expect(cbcResult['version'], equals('2.2'));
      expect(cbcResult.containsKey('codedText'), isTrue);
    });

    test('Test décodage avec mode actuel', () {
      const message = 'test décodage actuel';
      
      print('\n🔓 TEST DÉCODAGE MODE ACTUEL');
      print('═══════════════════════════════════════');
      
      // Préparer avec mode par défaut
      final prepared = MultiLanguageManager.prepareMessage(
        message,
        languages,
        mediaKey,
        forcePerCharacterMode: true,
      );
      
      print('📝 Message original: "$message"');
      print('🔧 Mode utilisé: ${prepared['version']} (${prepared['encryptionMode'] ?? 'cbc'})');
      
      // Décoder avec méthode unifiée
      final contentKey = prepared.containsKey('encryptedContent') ? 'encryptedContent' : 'codedText';
      final decoded = MultiLanguageManager.decodeMessageUnified(
        prepared[contentKey],
        prepared['encryptedAAD'],
        languages,
        mediaKey,
      );
      
      print('✅ Message décodé: "$decoded"');
      print('🎯 Décodage réussi: ${decoded == message ? 'OUI' : 'NON'}');
      
      expect(decoded, equals(message));
    });

    test('Simulation appel exact de votre app', () {
      print('\n📱 SIMULATION APPEL EXACT DE VOTRE APP');
      print('═══════════════════════════════════════');
      
      // Code EXACT de votre Chat_messages_mixin.dart
      const content = 'message de test app';
      
      final result = MultiLanguageManager.prepareMessage(
        content,
        languages,
        mediaKey,
        forcePerCharacterMode: true, // Activer le nouveau mode per-character
      );
      
      print('📝 Contenu: "$content"');
      print('🔧 Appel exact comme dans Chat_messages_mixin.dart');
      print('');
      print('📊 RÉSULTAT:');
      print('   Version: ${result['version']}');
      print('   Mode: ${result['encryptionMode'] ?? 'cbc'}');
      print('   Champs: ${result.keys.toList()}');
      
      // Déterminer le type de chiffrement utilisé
      String encryptionType;
      if (result['version'] == '2.3' && result['encryptionMode'] == 'gcm') {
        encryptionType = 'AES-256-GCM (v2.3)';
      } else if (result['version'] == '2.2') {
        encryptionType = 'AES-256-CBC (v2.2)';
      } else {
        encryptionType = 'AES-256-CBC Legacy (v2.0)';
      }
      
      print('');
      print('🎯 CONCLUSION FINALE:');
      print('   Votre app utilise: $encryptionType');
      
      if (encryptionType.contains('GCM')) {
        print('   ✅ Vous ÊTES passé à GCM !');
        print('   ✅ Migration réussie !');
      } else {
        print('   ⚠️ Vous utilisez encore CBC');
        print('   ⚠️ Migration pas encore active');
      }
    });
  });
}
