// test/aad_format_detection_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';
import 'package:silencia/core/utils/encryption_gcm_helper.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';
import 'dart:convert';

void main() {
  group('Tests de Détection Format AAD', () {
    late Map<String, Map<String, String>> languages;
    late String mediaKey;

    setUpAll(() {
      final package = LangMapGenerator.generateLanguagePackage();
      languages = Map<String, Map<String, String>>.from(
        (package['languages'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v))),
      );
      mediaKey = package['mediaKey'] as String;
    });

    test('Détection AAD authentifié (base64 JSON)', () {
      // Créer un AAD authentifié
      final aadJson = {
        'v': '2.3',
        'enc': 'gcm',
        'mode': 'perchar-seq',
        'seq': ['lang_00', 'lang_01'],
      };
      final aadString = jsonEncode(aadJson);
      final aadBase64 = base64Encode(utf8.encode(aadString));
      
      // Tester le déchiffrement
      final result = MultiLanguageManager.decryptAAD(aadBase64, mediaKey);
      expect(result, equals(aadString));
    });

    test('Détection AAD chiffré GCM', () {
      // Créer un AAD chiffré avec GCM
      final aadJson = {
        'v': '2.3',
        'enc': 'gcm',
        'mode': 'perchar-seq',
        'seq': ['lang_00', 'lang_01'],
      };
      final encryptedAAD = EncryptionGCMHelper.encryptAADGCM(aadJson, mediaKey);
      
      // Tester le déchiffrement
      final result = MultiLanguageManager.decryptAAD(encryptedAAD, mediaKey);
      final resultJson = jsonDecode(result);
      expect(resultJson, equals(aadJson));
    });

    test('Détection AAD CBC classique', () {
      // Créer un AAD CBC classique
      const aadString = 'lang_05';
      final encryptedAAD = MultiLanguageManager.encryptAAD(aadString, mediaKey);
      
      // Tester le déchiffrement
      final result = MultiLanguageManager.decryptAAD(encryptedAAD, mediaKey);
      expect(result, equals(aadString));
    });

    test('Message GCM complet avec AAD authentifié', () {
      const message = 'test aad auth';
      
      // Préparer avec AAD authentifié
      final prepared = MultiLanguageManager.prepareMessage(
        message,
        languages,
        mediaKey,
        useGCMEncryption: true,
        useAuthenticatedAAD: true,
      );
      
      // Décoder avec méthode unifiée
      final decoded = MultiLanguageManager.decodeMessageUnified(
        prepared['encryptedContent'],
        prepared['encryptedAAD'],
        languages,
        mediaKey,
      );
      
      expect(decoded, equals(message));
    });

    test('Message GCM complet avec AAD chiffré', () {
      const message = 'test aad chiffré';
      
      // Préparer avec AAD chiffré
      final prepared = MultiLanguageManager.prepareMessage(
        message,
        languages,
        mediaKey,
        useGCMEncryption: true,
        useAuthenticatedAAD: false, // AAD chiffré
      );
      
      // Décoder avec méthode unifiée
      final decoded = MultiLanguageManager.decodeMessageUnified(
        prepared['encryptedContent'],
        prepared['encryptedAAD'],
        languages,
        mediaKey,
      );
      
      expect(decoded, equals(message));
    });

    test('Message CBC legacy avec méthode unifiée', () {
      const message = 'test cbc legacy';
      
      // Préparer avec CBC
      final prepared = MultiLanguageManager.prepareMessage(
        message,
        languages,
        mediaKey,
        useGCMEncryption: false, // Force CBC
      );
      
      // Décoder avec méthode unifiée
      final decoded = MultiLanguageManager.decodeMessageUnified(
        prepared['codedText'], // CBC utilise codedText
        prepared['encryptedAAD'],
        languages,
        mediaKey,
      );
      
      expect(decoded, equals(message));
    });

    test('Gestion erreur format AAD invalide', () {
      const invalidAAD = 'format_invalide_sans_deux_points';
      
      expect(
        () => MultiLanguageManager.decryptAAD(invalidAAD, mediaKey),
        throwsException,
      );
    });

    test('Détection mode message avec AAD authentifié', () {
      // Créer un AAD authentifié pour mode per-character
      final aadJson = {
        'v': '2.3',
        'enc': 'gcm',
        'mode': 'perchar-seq',
        'seq': ['lang_00', 'lang_01', 'lang_02'],
      };
      final aadString = jsonEncode(aadJson);
      final aadBase64 = base64Encode(utf8.encode(aadString));
      
      // Tester la détection de mode
      final modeInfo = MultiLanguageManager.detectMessageMode(aadBase64, mediaKey);
      
      expect(modeInfo['version'], equals('2.3'));
      expect(modeInfo['isPerCharacter'], isTrue);
      expect(modeInfo['sequence'], equals(['lang_00', 'lang_01', 'lang_02']));
    });

    test('Fallback gracieux pour AAD corrompu', () {
      const message = 'test fallback';
      
      // Préparer un message normal
      final prepared = MultiLanguageManager.prepareMessage(
        message,
        languages,
        mediaKey,
        useGCMEncryption: false,
      );
      
      // Corrompre l'AAD
      const corruptedAAD = 'aad_corrompu_base64_invalide';
      
      // Le décodage devrait échouer gracieusement
      final result = MultiLanguageManager.decodeMessageUnified(
        prepared['codedText'],
        corruptedAAD,
        languages,
        mediaKey,
      );
      
      // Devrait retourner un message d'erreur plutôt que de crasher
      expect(result, contains('[ERREUR DÉCODAGE]'));
    });
  });
}
