// lib/core/utils/lang_map_generator.dart

import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class LangMapGenerator {
  /// Génère une langue avec un seed aléatoire (pour usage local/test)
  static Map<String, String> generateLangMap() {
    return generateLangMapWithSeed(Random.secure().nextInt(0x7FFFFFFF));
  }

  /// Génère une langue avec alphabets séparés (texte→texte, emoji→emoji) et seed déterministe
  static Map<String, String> generateLangMapWithSeed(int seed) {
    // 🔤 ALPHABET TEXTE (sans emojis)
    const String textAlphabet =
        // Lettres latines (minuscules et majuscules)
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
        // Chiffres
        '0123456789'
        // Ponctuation et symboles de base
        ' .?!,;:-_()[]{}@#\$%^&*+=<>/\\|`~"\''
        // Caractères accentués français
        'àáâäæçèéêëìíîïñòóôöùúûüÿ'
        'ÀÁÂÄÆÇÈÉÊËÌÍÎÏÑÒÓÔÖÙÚÛÜŸ'
        // Caractères allemands
        'ßöäüÖÄÜ'
        // Caractères espagnols supplémentaires
        'ñÑ¿¡'
        // Caractères italiens
        'òàèìù'
        // Caractères portugais
        'ãõçÃÕÇ'
        // Caractères nordiques
        'åæøÅÆØ'
        // Caractères slaves (cyrillique de base)
        'абвгдеёжзийклмнопрстуфхцчшщъыьэюя'
        'АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ'
        // Caractères grecs
        'αβγδεζηθικλμνξοπρστυφχψω'
        'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ'
        // Caractères arabes de base
        'ابتثجحخدذرزسشصضطظعغفقكلمنهوي'
        // Caractères chinois/japonais de base (quelques kanji courants)
        '一二三四五六七八九十人大小中上下左右前後'
        // Caractères japonais (hiragana)
        'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん'
        // Caractères japonais (katakana)
        'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン'
        // Symboles mathématiques et spéciaux simples
        '±×÷∞≠≤≥∑∏√∫∂∇∈∉∪∩⊂⊃⊆⊇∧∨¬∀∃'
        // Symboles monétaires
        '€£¥¢₹₽₩₪₫₨₦₡₵₴₸₼₾'
        // Flèches et symboles géométriques
        '←↑→↓↔↕↖↗↘↙⇐⇑⇒⇓⇔⇕'
        // Symboles divers
        '©®™§¶†‡•…‰′″‹›«»°¡¿';

    // 😀 ALPHABET EMOJI (séparé)
    const String emojiAlphabet =
        // Emojis visages et émotions (simples)
        '😀😃😄😁😆😅😂🤣😊😇🙂🙃😉😌😍🥰😘😗😙😚😋😛😝😜🤪🤨🧐🤓😎🤩🥳😏😒😞😔😟😕🙁😣😖😫😩🥺😢😭😤😠😡🤬🤯😳🥵🥶😱😨😰😥😓🤗🤔🤭🤫🤥😶😐😑😬🙄😯😦😧😮😲🥱😴🤤😪😵🤐🥴🤢🤮🤧😷🤒🤕🤑🤠😈👿👹👺🤡💩👻💀👽👾🤖🎃'
        // Emojis gestuels et mains (simples uniquement)
        '👋👍👎👌🤞🤟🤘🤙👈👉👆👇👏🙌👐🤝🙏💪'
        // Emojis cœurs et symboles d'amour (simples)
        '💔💕💖💗💘💝💟💯'
        // Emojis objets et activités populaires (simples)
        '🔥💧⭐🌟✨🎉🎊🎈🎁🎀🎂🍰🎵🎶🎤🎧🎮🎯🎲🎭🎨🎪🎫🎬';

    // Traiter l'alphabet texte
    final textChars = <String>[];
    final textRunes = textAlphabet.runes.toList();
    for (int i = 0; i < textRunes.length; i++) {
      final char = String.fromCharCode(textRunes[i]);
      if (!textChars.contains(char)) {
        textChars.add(char);
      }
    }

    // Traiter l'alphabet emoji
    final emojiChars = <String>[];
    final emojiRunes = emojiAlphabet.runes.toList();
    for (int i = 0; i < emojiRunes.length; i++) {
      final char = String.fromCharCode(emojiRunes[i]);
      if (!emojiChars.contains(char)) {
        emojiChars.add(char);
      }
    }

    // Créer des mélanges DÉTERMINISTES séparés
    final random = Random(seed);

    // Mélanger le texte avec le texte
    List<String> shuffledText = List.from(textChars);
    shuffledText.shuffle(random);

    // Mélanger les emojis avec les emojis (nouveau seed dérivé)
    List<String> shuffledEmoji = List.from(emojiChars);
    shuffledEmoji.shuffle(Random(seed + 1000)); // Seed différent pour les emojis

    // Créer la bijection complète
    Map<String, String> map = {};

    // Mapper texte → texte
    for (int i = 0; i < textChars.length; i++) {
      map[textChars[i]] = shuffledText[i];
    }

    // Mapper emoji → emoji
    for (int i = 0; i < emojiChars.length; i++) {
      map[emojiChars[i]] = shuffledEmoji[i];
    }

    debugPrint('🔤 LANG_MAP: Alphabet texte: ${textChars.length} caractères');
    debugPrint('😀 LANG_MAP: Alphabet emoji: ${emojiChars.length} caractères');
    debugPrint('📊 LANG_MAP: Total: ${map.length} mappings (texte→texte, emoji→emoji)');

    return map;
  }

  /// Génère une clé AES-256 sécurisée pour le chiffrement des médias
  static String generateMediaKey() {
    return generateMediaKeyWithSeed(Random.secure().nextInt(0x7FFFFFFF));
  }

  /// Génère une clé média déterministe avec un seed
  static String generateMediaKeyWithSeed(int seed) {
    final random = Random(seed);
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(keyBytes);
  }

  /// Génère un package complet : 10 langues + clé média (aléatoire)
  static Map<String, dynamic> generateLanguagePackage() {
    return generateLanguagePackageWithSeed(Random.secure().nextInt(0x7FFFFFFF));
  }

  /// Génère un package complet avec un seed déterministe
  static Map<String, dynamic> generateLanguagePackageWithSeed(int baseSeed) {
    final mediaKey = generateMediaKeyWithSeed(baseSeed);

    // Générer 10 langues différentes avec des seeds dérivés
    final languages = <String, Map<String, String>>{};
    for (int i = 0; i < 10; i++) {
      final aad = 'lang_${i.toString().padLeft(2, '0')}'; // lang_00, lang_01, etc.
      // Chaque langue a un seed unique dérivé du seed de base
      final langSeed = baseSeed + i * 1000; // Espacement pour éviter les collisions
      languages[aad] = generateLangMapWithSeed(langSeed);
    }

    return {
      'languages': languages,        // 10 langues avec AAD
      'mediaKey': mediaKey,         // Clé AES-256 pour médias
      'timestamp': DateTime.now().toIso8601String(),
      'version': '2.0',             // Version 2.0 pour le nouveau format
      'baseSeed': baseSeed,         // 🔑 Seed de base utilisé
    };
  }



  /// Génère un package complet (rétrocompatibilité version 1.0)
  static Map<String, dynamic> generateLanguagePackageLegacy() {
    final langMap = generateLangMap();
    final mediaKey = generateMediaKey();

    return {
      'langMap': langMap,
      'mediaKey': mediaKey,
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0'
    };
  }

  /// Transforme la clé média avec la map linguistique pour l'obfusquer
  static String obfuscateMediaKey(String mediaKey, Map<String, String> langMap) {
    return mediaKey.split('').map((c) => langMap[c] ?? c).join('');
  }

  /// Détransforme la clé média obfusquée
  static String deobfuscateMediaKey(String obfuscatedKey, Map<String, String> langMap) {
    final reverseMap = {for (var e in langMap.entries) e.value: e.key};
    return obfuscatedKey.split('').map((c) => reverseMap[c] ?? c).join('');
  }
}
