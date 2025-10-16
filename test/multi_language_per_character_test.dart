import 'package:flutter_test/flutter_test.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';

void main() {
  group('MultiLanguageManager - Mode Per-Character Tests', () {
    late Map<String, Map<String, String>> testLanguages;
    late String testMediaKey;

    setUp(() {
      // Générer un package de test avec 10 langues
      final package = LangMapGenerator.generateLanguagePackage();
      testLanguages = Map<String, Map<String, String>>.from(
        (package['languages'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v))),
      );
      testMediaKey = package['mediaKey'] as String;
    });

    test('Encode et décode un message simple en mode per-character', () {
      const testText = 'salut';
      
      // Encoder
      final result = MultiLanguageManager.prepareMessageWithPerCharacterMode(
        testText,
        testLanguages,
        testMediaKey,
      );
      
      expect(result['codedText'], isNotNull);
      expect(result['encryptedAAD'], isNotNull);
      expect(result['sequence'], isNotNull);
      expect((result['sequence'] as List).length, equals(testText.length));
      
      // Décoder
      final decodedText = MultiLanguageManager.decodeMessageWithPerCharacterMode(
        result['codedText'],
        result['encryptedAAD'],
        testLanguages,
        testMediaKey,
      );
      
      expect(decodedText, equals(testText));
    });

    test('Détection automatique du mode per-character', () {
      const testText = 'hello world';
      
      // Préparer avec la méthode unifiée
      final result = MultiLanguageManager.prepareMessage(
        testText,
        testLanguages,
        testMediaKey,
        forcePerCharacterMode: true,
      );
      
      // Vérifier que le mode per-character a été utilisé
      expect(result.containsKey('sequence'), isTrue);
      
      // Décoder avec la méthode unifiée
      final decodedText = MultiLanguageManager.decodeMessage(
        result['codedText'],
        result['encryptedAAD'],
        testLanguages,
        testMediaKey,
      );
      
      expect(decodedText, equals(testText));
    });

    test('Compatibilité avec le mode legacy (single-language)', () {
      const testText = 'test legacy';
      
      // Préparer en mode legacy
      final legacyResult = MultiLanguageManager.prepareMessageWithRandomLanguage(
        testText,
        testLanguages,
        testMediaKey,
      );
      
      // Vérifier que c'est bien le mode legacy
      expect(legacyResult.containsKey('selectedAAD'), isTrue);
      expect(legacyResult.containsKey('sequence'), isFalse);
      
      // Décoder avec la méthode unifiée (doit détecter le mode legacy)
      final decodedText = MultiLanguageManager.decodeMessage(
        legacyResult['codedText'],
        legacyResult['encryptedAAD'],
        testLanguages,
        testMediaKey,
      );
      
      expect(decodedText, equals(testText));
    });

    test('Gestion des caractères non mappés', () {
      const testText = 'test@#\$%';
      
      final result = MultiLanguageManager.prepareMessageWithPerCharacterMode(
        testText,
        testLanguages,
        testMediaKey,
      );
      
      final decodedText = MultiLanguageManager.decodeMessageWithPerCharacterMode(
        result['codedText'],
        result['encryptedAAD'],
        testLanguages,
        testMediaKey,
      );
      
      // Les caractères non mappés doivent rester inchangés
      expect(decodedText, equals(testText));
    });

    test('Gestion des messages vides', () {
      const testText = '';
      
      final result = MultiLanguageManager.prepareMessageWithPerCharacterMode(
        testText,
        testLanguages,
        testMediaKey,
      );
      
      expect(result['codedText'], equals(''));
      expect((result['sequence'] as List).length, equals(0));
      
      final decodedText = MultiLanguageManager.decodeMessageWithPerCharacterMode(
        result['codedText'],
        result['encryptedAAD'],
        testLanguages,
        testMediaKey,
      );
      
      expect(decodedText, equals(''));
    });

    test('Erreur si moins de 10 langues pour le mode per-character', () {
      final insufficientLanguages = <String, Map<String, String>>{};
      for (int i = 0; i < 5; i++) {
        insufficientLanguages['lang_0$i'] = testLanguages.values.first;
      }
      
      expect(
        () => MultiLanguageManager.prepareMessageWithPerCharacterMode(
          'test',
          insufficientLanguages,
          testMediaKey,
        ),
        throwsException,
      );
    });

    test('Fallback automatique si pas assez de langues', () {
      final insufficientLanguages = <String, Map<String, String>>{};
      for (int i = 0; i < 5; i++) {
        insufficientLanguages['lang_0$i'] = testLanguages.values.first;
      }
      
      const testText = 'fallback test';
      
      // La méthode unifiée doit faire un fallback vers le mode legacy
      final result = MultiLanguageManager.prepareMessage(
        testText,
        insufficientLanguages,
        testMediaKey,
        forcePerCharacterMode: true,
      );
      
      // Doit utiliser le mode legacy
      expect(result.containsKey('selectedAAD'), isTrue);
      expect(result.containsKey('sequence'), isFalse);
    });

    test('Cache des reverse-maps', () {
      // Nettoyer le cache
      MultiLanguageManager.clearReverseMapsCache();
      
      var stats = MultiLanguageManager.getCacheStats();
      expect(stats['reverseMapsCount'], equals(0));
      
      // Pré-calculer le cache
      MultiLanguageManager.precomputeReverseMaps(testLanguages);
      
      stats = MultiLanguageManager.getCacheStats();
      expect(stats['reverseMapsCount'], equals(testLanguages.length));
      expect(stats['cacheKeys'], containsAll(testLanguages.keys));
    });

    test('Détection du mode de message', () {
      const testText = 'mode detection test';
      
      // Message per-character
      final perCharResult = MultiLanguageManager.prepareMessageWithPerCharacterMode(
        testText,
        testLanguages,
        testMediaKey,
      );
      
      final perCharMode = MultiLanguageManager.detectMessageMode(
        perCharResult['encryptedAAD'],
        testMediaKey,
      );
      
      expect(perCharMode['version'], equals('2.2'));
      expect(perCharMode['mode'], equals('perchar-seq'));
      expect(perCharMode['isPerCharacter'], isTrue);
      
      // Message legacy
      final legacyResult = MultiLanguageManager.prepareMessageWithRandomLanguage(
        testText,
        testLanguages,
        testMediaKey,
      );
      
      final legacyMode = MultiLanguageManager.detectMessageMode(
        legacyResult['encryptedAAD'],
        testMediaKey,
      );
      
      expect(legacyMode['version'], equals('2.0'));
      expect(legacyMode['mode'], equals('single-lang'));
      expect(legacyMode['isPerCharacter'], isFalse);
    });

    test('Cohérence des longueurs', () {
      const testText = 'coherence test with special chars: éàù!@#';
      
      final result = MultiLanguageManager.prepareMessageWithPerCharacterMode(
        testText,
        testLanguages,
        testMediaKey,
      );
      
      final sequence = result['sequence'] as List<String>;
      final codedText = result['codedText'] as String;
      
      // La séquence doit avoir la même longueur que le texte original
      expect(sequence.length, equals(testText.length));
      expect(codedText.length, equals(testText.length));
    });

    test('Robustesse avec clé média incorrecte', () {
      const testText = 'robustness test';
      const wrongMediaKey = 'wrong_key_base64_encoded_32_bytes_long_key_here';

      final result = MultiLanguageManager.prepareMessageWithPerCharacterMode(
        testText,
        testLanguages,
        testMediaKey,
      );

      // Essayer de décoder avec une mauvaise clé
      expect(
        () => MultiLanguageManager.decodeMessageWithPerCharacterMode(
          result['codedText'],
          result['encryptedAAD'],
          testLanguages,
          wrongMediaKey,
        ),
        throwsException,
      );
    });

    test('Gestion des langues manquantes avec réparation automatique', () {
      const testText = 'test sync';

      // Encoder avec toutes les langues
      final result = MultiLanguageManager.prepareMessageWithPerCharacterMode(
        testText,
        testLanguages,
        testMediaKey,
      );

      // Simuler des langues manquantes (enlever quelques langues)
      final incompleteLanguages = <String, Map<String, String>>{};
      final allKeys = testLanguages.keys.toList();
      for (int i = 0; i < 5; i++) { // Garder seulement 5 langues sur 10
        incompleteLanguages[allKeys[i]] = testLanguages[allKeys[i]]!;
      }

      // Décoder avec réparation automatique
      final decodedText = MultiLanguageManager.decodeMessage(
        result['codedText'],
        result['encryptedAAD'],
        incompleteLanguages,
        testMediaKey,
        autoRepairLanguages: true,
      );

      // Le décodage doit réussir (peut ne pas être identique à cause de la réparation)
      // mais ne doit pas lever d'exception et doit retourner quelque chose
      expect(decodedText, isNotNull);
      expect(decodedText.length, equals(testText.length));

      // Vérifier qu'il n'y a pas d'erreur dans le résultat
      expect(decodedText, isNot(startsWith('[ERREUR DÉCODAGE]')));
    });

    test('Diagnostic de synchronisation des langues', () {
      final requiredLanguages = ['lang_00', 'lang_01', 'lang_05', 'lang_99'];
      final availableLanguages = <String, Map<String, String>>{
        'lang_00': testLanguages['lang_00']!,
        'lang_01': testLanguages['lang_01']!,
        'lang_02': testLanguages['lang_02']!,
      };

      final diagnosis = MultiLanguageManager.diagnoseLanguageSync(
        requiredLanguages,
        availableLanguages,
      );

      expect(diagnosis['hasMissingLanguages'], isTrue);
      expect(diagnosis['missingLanguages'], contains('lang_05'));
      expect(diagnosis['missingLanguages'], contains('lang_99'));
      expect(diagnosis['syncStatus'], equals('DESYNC'));
      expect(diagnosis['totalRequired'], equals(4));
      expect(diagnosis['totalAvailable'], equals(3));
    });

    test('Réparation automatique des langues manquantes', () {
      final originalLanguages = <String, Map<String, String>>{
        'lang_00': testLanguages['lang_00']!,
        'lang_01': testLanguages['lang_01']!,
      };

      final missingLanguages = ['lang_05', 'lang_07'];

      final repairedLanguages = MultiLanguageManager.repairMissingLanguages(
        originalLanguages,
        missingLanguages,
      );

      expect(repairedLanguages.length, equals(4)); // 2 originales + 2 réparées
      expect(repairedLanguages.containsKey('lang_05'), isTrue);
      expect(repairedLanguages.containsKey('lang_07'), isTrue);

      // Vérifier que les langues réparées sont fonctionnelles
      final lang05 = repairedLanguages['lang_05']!;
      expect(lang05.isNotEmpty, isTrue);
      expect(lang05.containsKey('a'), isTrue); // Doit contenir les caractères de base
    });
  });
}
