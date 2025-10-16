import 'package:flutter_test/flutter_test.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';

void main() {
  group('Separated Alphabets Tests', () {
    test('Texte reste du texte, emojis restent des emojis', () {
      // Générer un package aléatoire
      final package = LangMapGenerator.generateLanguagePackage();
      final languages = package['languages'] as Map<String, Map<String, String>>;
      final mediaKey = package['mediaKey'] as String;

      // Message mixte avec texte et emojis
      const testMessage = "Salut ! 😀 Comment ça va ? 😊 Super ! 👍";
      
      print('🧪 TEST: Message original: "$testMessage"');

      // Encoder le message
      final result = MultiLanguageManager.prepareMessage(
        testMessage,
        languages,
        mediaKey,
        forcePerCharacterMode: true,
        useGCMEncryption: true,
      );

      final codedText = result['codedText'] as String;
      expect(codedText.isNotEmpty, isTrue, reason: 'Texte codé ne doit pas être vide');
      print('🔤 TEST: Texte codé: "$codedText"');

      // Décoder le message
      final decodedText = MultiLanguageManager.decodeMessageUnified(
        codedText,
        result['encryptedAAD'] as String,
        languages,
        mediaKey,
      );

      expect(decodedText, equals(testMessage), reason: 'Message décodé doit être identique');

      print('✅ TEST: Message décodé: "$decodedText"');

      // Vérifier que le texte codé contient bien des caractères texte ET des emojis
      final codedRunes = codedText.runes.toList();
      bool hasTextChars = false;
      bool hasEmojiChars = false;

      for (final rune in codedRunes) {
        final char = String.fromCharCode(rune);
        
        // Vérifier si c'est un caractère texte (ASCII étendu ou Unicode non-emoji)
        if (char.codeUnitAt(0) < 0x1F600 || char.codeUnitAt(0) > 0x1F64F) {
          // Pas dans la plage emoji principale
          if (char != '😀' && char != '😊' && char != '👍') { // Exclure les emojis du message original
            hasTextChars = true;
          }
        }
        
        // Vérifier si c'est un emoji (plage Unicode emoji)
        if (char.codeUnitAt(0) >= 0x1F600 && char.codeUnitAt(0) <= 0x1F64F) {
          hasEmojiChars = true;
        }
      }

      print('📊 TEST: Texte codé contient du texte: $hasTextChars');
      print('📊 TEST: Texte codé contient des emojis: $hasEmojiChars');
      
      // Le texte codé doit contenir les deux types
      expect(hasTextChars, isTrue, reason: 'Le texte codé doit contenir des caractères texte');
      expect(hasEmojiChars, isTrue, reason: 'Le texte codé doit contenir des emojis');
    });

    test('Vérification des alphabets séparés dans la génération', () {
      // Générer une langue avec seed fixe
      final langMap = LangMapGenerator.generateLangMapWithSeed(12345);
      
      // Vérifier que les caractères texte sont mappés vers du texte
      const textChars = 'abcdefghijklmnopqrstuvwxyz';
      // Utiliser des emojis qui sont dans notre alphabet
      const emojiChars = '😀😃😄😁😆😅😂🤣😊😇';
      
      int textToTextCount = 0;
      int emojiToEmojiCount = 0;
      int textToEmojiCount = 0;
      int emojiToTextCount = 0;

      // Vérifier les mappings texte
      for (int i = 0; i < textChars.length; i++) {
        final char = textChars[i];
        final mapped = langMap[char];
        if (mapped != null) {
          if (_isEmoji(mapped)) {
            textToEmojiCount++;
          } else {
            textToTextCount++;
          }
        }
      }

      // Vérifier les mappings emoji
      final emojiRunes = emojiChars.runes.toList();
      for (final rune in emojiRunes) {
        final char = String.fromCharCode(rune);
        final mapped = langMap[char];
        if (mapped != null) {
          if (_isEmoji(mapped)) {
            emojiToEmojiCount++;
          } else {
            emojiToTextCount++;
          }
        }
      }

      print('📊 MAPPING: Texte → Texte: $textToTextCount');
      print('📊 MAPPING: Texte → Emoji: $textToEmojiCount');
      print('📊 MAPPING: Emoji → Emoji: $emojiToEmojiCount');
      print('📊 MAPPING: Emoji → Texte: $emojiToTextCount');

      // Avec la séparation, on doit avoir :
      // - Texte → Texte uniquement (textToEmojiCount = 0)
      // - Emoji → Emoji uniquement (emojiToTextCount = 0)
      expect(textToEmojiCount, equals(0), reason: 'Texte ne doit pas être mappé vers emoji');
      expect(emojiToTextCount, equals(0), reason: 'Emoji ne doit pas être mappé vers texte');
      expect(textToTextCount, greaterThan(0), reason: 'Texte doit être mappé vers texte');
      expect(emojiToEmojiCount, greaterThan(0), reason: 'Emoji doit être mappé vers emoji');
    });

    test('Test de lisibilité : "Salut 😀" → "xxxxx 😊" (exemple)', () {
      // Générer un package avec seed fixe pour résultat prévisible
      final package = LangMapGenerator.generateLanguagePackageWithSeed(54321);
      final languages = package['languages'] as Map<String, Map<String, String>>;
      final mediaKey = package['mediaKey'] as String;

      const testMessage = "Salut 😀";
      
      print('🧪 LISIBILITÉ: Message original: "$testMessage"');

      // Encoder
      final result = MultiLanguageManager.prepareMessage(
        testMessage,
        languages,
        mediaKey,
        forcePerCharacterMode: true,
        useGCMEncryption: true,
      );

      final codedText = result['codedText'] as String;
      print('🔤 LISIBILITÉ: Texte codé: "$codedText"');

      // Vérifier que le texte codé a la structure attendue :
      // - Les 5 premiers caractères (Salut) sont du texte transformé
      // - L'espace reste un espace ou devient un autre caractère texte
      // - L'emoji 😀 devient un autre emoji
      
      final codedRunes = codedText.runes.toList();
      expect(codedRunes.length, equals(7), reason: 'Longueur doit être préservée (5 + 1 + 1)');

      // Le dernier caractère doit être un emoji (transformation de 😀)
      final lastChar = String.fromCharCode(codedRunes.last);
      expect(_isEmoji(lastChar), isTrue, reason: 'Le dernier caractère doit rester un emoji');

      print('✅ LISIBILITÉ: Structure préservée - texte reste texte, emoji reste emoji');
    });
  });
}

/// Fonction utilitaire pour détecter si un caractère est un emoji
bool _isEmoji(String char) {
  final codeUnit = char.codeUnitAt(0);
  // Plages Unicode principales pour les emojis (étendues)
  return (codeUnit >= 0x1F600 && codeUnit <= 0x1F64F) || // Emoticons
         (codeUnit >= 0x1F300 && codeUnit <= 0x1F5FF) || // Misc Symbols and Pictographs
         (codeUnit >= 0x1F680 && codeUnit <= 0x1F6FF) || // Transport and Map
         (codeUnit >= 0x1F1E0 && codeUnit <= 0x1F1FF) || // Flags
         (codeUnit >= 0x2600 && codeUnit <= 0x26FF) ||   // Misc symbols
         (codeUnit >= 0x2700 && codeUnit <= 0x27BF) ||   // Dingbats
         (codeUnit >= 0x1F900 && codeUnit <= 0x1F9FF) || // Supplemental Symbols and Pictographs
         (codeUnit >= 0x1F780 && codeUnit <= 0x1F7FF) || // Geometric Shapes Extended
         (codeUnit >= 0x1F000 && codeUnit <= 0x1F02F) || // Mahjong Tiles
         (codeUnit >= 0x1F0A0 && codeUnit <= 0x1F0FF);   // Playing Cards
}
