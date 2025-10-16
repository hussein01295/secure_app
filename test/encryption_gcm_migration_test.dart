// test/encryption_gcm_migration_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:silencia/core/utils/encryption_gcm_helper.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';

void main() {
  group('Migration AES-CBC vers AES-GCM Tests', () {
    late Map<String, Map<String, String>> languages;
    late String mediaKey;

    setUpAll(() {
      // Générer un package de langues pour les tests
      final package = LangMapGenerator.generateLanguagePackage();
      languages = Map<String, Map<String, String>>.from(
        (package['languages'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v))),
      );
      mediaKey = package['mediaKey'] as String;
    });

    group('EncryptionGCMHelper Tests', () {
      test('Chiffrement et déchiffrement GCM basique', () {
        const plainText = 'Hello World!';
        
        // Chiffrer
        final encrypted = EncryptionGCMHelper.encryptTextGCM(plainText, mediaKey);
        expect(encrypted, isNotEmpty);
        
        // Déchiffrer
        final decrypted = EncryptionGCMHelper.decryptTextGCM(encrypted, mediaKey);
        expect(decrypted, equals(plainText));
      });

      test('Chiffrement GCM avec AAD authentifié', () {
        const plainText = 'Message secret';
        const aadData = '{"version":"2.3","mode":"test"}';
        
        // Chiffrer avec AAD
        final encrypted = EncryptionGCMHelper.encryptTextGCM(
          plainText, 
          mediaKey, 
          aadData: aadData,
        );
        
        // Déchiffrer avec AAD
        final decrypted = EncryptionGCMHelper.decryptTextGCM(
          encrypted, 
          mediaKey, 
          aadData: aadData,
        );
        
        expect(decrypted, equals(plainText));
      });

      test('Échec authentification avec AAD modifié', () {
        const plainText = 'Message secret';
        const aadData = '{"version":"2.3","mode":"test"}';
        const wrongAAD = '{"version":"2.3","mode":"hack"}';
        
        // Chiffrer avec AAD correct
        final encrypted = EncryptionGCMHelper.encryptTextGCM(
          plainText, 
          mediaKey, 
          aadData: aadData,
        );
        
        // Tenter de déchiffrer avec AAD incorrect
        expect(
          () => EncryptionGCMHelper.decryptTextGCM(encrypted, mediaKey, aadData: wrongAAD),
          throwsA(isA<AuthenticationException>()),
        );
      });

      test('Détection format GCM vs CBC', () {
        const plainText = 'Test message';
        
        // Format GCM
        final gcmEncrypted = EncryptionGCMHelper.encryptTextGCM(plainText, mediaKey);
        expect(EncryptionGCMHelper.isGCMFormat(gcmEncrypted), isTrue);
        
        // Format CBC (simulé avec un payload court)
        const cbcLike = 'dGVzdA=='; // base64 court
        expect(EncryptionGCMHelper.isGCMFormat(cbcLike), isFalse);
      });

      test('Chiffrement AAD séparé', () {
        final aadJson = {
          'v': '2.3',
          'mode': 'perchar-seq',
          'seq': ['lang_00', 'lang_01', 'lang_02'],
        };
        
        // Chiffrer AAD
        final encryptedAAD = EncryptionGCMHelper.encryptAADGCM(aadJson, mediaKey);
        expect(encryptedAAD, isNotEmpty);
        
        // Déchiffrer AAD
        final decryptedAAD = EncryptionGCMHelper.decryptAADGCM(encryptedAAD, mediaKey);
        expect(decryptedAAD, equals(aadJson));
      });

      test('Validation AAD GCM', () {
        // AAD valide
        final validAAD = {
          'v': '2.3',
          'enc': 'gcm',
          'mode': 'perchar-seq',
        };
        expect(EncryptionGCMHelper.validateAAD(validAAD), isTrue);
        
        // AAD invalide (version manquante)
        final invalidAAD = {
          'enc': 'gcm',
          'mode': 'perchar-seq',
        };
        expect(EncryptionGCMHelper.validateAAD(invalidAAD), isFalse);
        
        // AAD invalide (mauvaise version)
        final wrongVersionAAD = {
          'v': '1.0',
          'enc': 'gcm',
          'mode': 'perchar-seq',
        };
        expect(EncryptionGCMHelper.validateAAD(wrongVersionAAD), isFalse);
      });
    });

    group('MultiLanguageManager GCM Integration Tests', () {
      test('Préparation message per-character avec GCM', () {
        const message = 'salut';
        
        final result = MultiLanguageManager.prepareMessageWithPerCharacterModeGCM(
          message,
          languages,
          mediaKey,
          useAuthenticatedAAD: true,
        );
        
        expect(result['codedText'], isNotEmpty);
        expect(result['encryptedContent'], isNotEmpty);
        expect(result['encryptedAAD'], isNotEmpty);
        expect(result['sequence'], hasLength(message.length));
        expect(result['encryptionMode'], equals('gcm'));
        expect(result['version'], equals('2.3'));
      });

      test('Décodage message per-character avec GCM', () {
        const message = 'hello world';
        
        // Préparer le message
        final prepared = MultiLanguageManager.prepareMessageWithPerCharacterModeGCM(
          message,
          languages,
          mediaKey,
          useAuthenticatedAAD: true,
        );
        
        // Décoder le message
        final decoded = MultiLanguageManager.decodeMessageWithPerCharacterModeGCM(
          prepared['encryptedContent'],
          prepared['encryptedAAD'],
          languages,
          mediaKey,
          isAuthenticatedAAD: true,
        );
        
        expect(decoded, equals(message));
      });

      test('Round-trip complet GCM avec AAD chiffré', () {
        const message = 'test complet';
        
        // Préparer avec AAD chiffré
        final prepared = MultiLanguageManager.prepareMessageWithPerCharacterModeGCM(
          message,
          languages,
          mediaKey,
          useAuthenticatedAAD: false, // AAD chiffré
        );
        
        // Décoder
        final decoded = MultiLanguageManager.decodeMessageWithPerCharacterModeGCM(
          prepared['encryptedContent'],
          prepared['encryptedAAD'],
          languages,
          mediaKey,
          isAuthenticatedAAD: false, // AAD chiffré
        );
        
        expect(decoded, equals(message));
      });

      test('Méthode unifiée avec détection automatique GCM', () {
        const message = 'test unifié';
        
        // Préparer avec GCM
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

      test('Rétrocompatibilité CBC depuis méthode unifiée', () {
        const message = 'test rétro';
        
        // Préparer avec CBC (ancien mode)
        final prepared = MultiLanguageManager.prepareMessage(
          message,
          languages,
          mediaKey,
          useGCMEncryption: false, // Force CBC
        );
        
        // Décoder avec méthode unifiée (doit détecter CBC)
        final decoded = MultiLanguageManager.decodeMessageUnified(
          prepared['codedText'], // CBC utilise codedText, pas encryptedContent
          prepared['encryptedAAD'],
          languages,
          mediaKey,
        );
        
        expect(decoded, equals(message));
      });

      test('Gestion erreur authentification GCM', () {
        const message = 'message tampered';
        
        // Préparer le message
        final prepared = MultiLanguageManager.prepareMessageWithPerCharacterModeGCM(
          message,
          languages,
          mediaKey,
          useAuthenticatedAAD: true,
        );
        
        // Modifier le contenu chiffré (simuler tampering)
        String tamperedContent = prepared['encryptedContent'];
        final bytes = tamperedContent.codeUnits;
        if (bytes.isNotEmpty) {
          // Modifier le dernier caractère
          tamperedContent = tamperedContent.substring(0, tamperedContent.length - 1) + 'X';
        }
        
        // Tenter de décoder le contenu modifié
        expect(
          () => MultiLanguageManager.decodeMessageWithPerCharacterModeGCM(
            tamperedContent,
            prepared['encryptedAAD'],
            languages,
            mediaKey,
            isAuthenticatedAAD: true,
          ),
          throwsException,
        );
      });

      test('Performance GCM vs CBC', () {
        const message = 'performance test message';
        
        // Test CBC
        final stopwatchCBC = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          final prepared = MultiLanguageManager.prepareMessage(
            message,
            languages,
            mediaKey,
            useGCMEncryption: false,
          );
          MultiLanguageManager.decodeMessage(
            prepared['codedText'],
            prepared['encryptedAAD'],
            languages,
            mediaKey,
          );
        }
        stopwatchCBC.stop();
        
        // Test GCM
        final stopwatchGCM = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          final prepared = MultiLanguageManager.prepareMessage(
            message,
            languages,
            mediaKey,
            useGCMEncryption: true,
          );
          MultiLanguageManager.decodeMessageUnified(
            prepared['encryptedContent'],
            prepared['encryptedAAD'],
            languages,
            mediaKey,
          );
        }
        stopwatchGCM.stop();
        
        print('Performance CBC: ${stopwatchCBC.elapsedMilliseconds}ms');
        print('Performance GCM: ${stopwatchGCM.elapsedMilliseconds}ms');
        
        // GCM peut être légèrement plus lent mais doit rester raisonnable
        expect(stopwatchGCM.elapsedMilliseconds, lessThan(stopwatchCBC.elapsedMilliseconds * 3));
      });
    });

    group('Migration et Compatibilité Tests', () {
      test('Messages mixtes CBC et GCM dans même conversation', () {
        const message1 = 'message cbc';
        const message2 = 'message gcm';
        
        // Message 1 en CBC
        final preparedCBC = MultiLanguageManager.prepareMessage(
          message1,
          languages,
          mediaKey,
          useGCMEncryption: false,
        );
        
        // Message 2 en GCM
        final preparedGCM = MultiLanguageManager.prepareMessage(
          message2,
          languages,
          mediaKey,
          useGCMEncryption: true,
        );
        
        // Décoder les deux avec la méthode unifiée
        final decoded1 = MultiLanguageManager.decodeMessageUnified(
          preparedCBC['codedText'],
          preparedCBC['encryptedAAD'],
          languages,
          mediaKey,
        );
        
        final decoded2 = MultiLanguageManager.decodeMessageUnified(
          preparedGCM['encryptedContent'],
          preparedGCM['encryptedAAD'],
          languages,
          mediaKey,
        );
        
        expect(decoded1, equals(message1));
        expect(decoded2, equals(message2));
      });
    });
  });
}
