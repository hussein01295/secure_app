// lib/core/utils/multi_language_manager.dart

import 'dart:math';
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'encryption_gcm_helper.dart';
import '../config/debug_config.dart';

// Helper pour les logs conditionnels
void _debugLog(String message) {
  if (DebugConfig.enableMultiLanguageLogs) {
    debugPrint(message);
  }
}

/// Gestionnaire pour les 10 langues avec AAD chiffré
class MultiLanguageManager {
  
  /// Sélectionne aléatoirement une langue parmi les 10 disponibles
  static String selectRandomLanguageAAD(Map<String, Map<String, String>> languages) {
    final aadList = languages.keys.toList();
    final random = Random.secure();
    return aadList[random.nextInt(aadList.length)];
  }

  /// Chiffre l'AAD avec la clé média pour masquer quelle langue a été utilisée
  static String encryptAAD(String aad, String mediaKey) {
    try {
      final keyBytes = base64Decode(mediaKey);
      final key = encrypt.Key(keyBytes);
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      final encrypted = encrypter.encrypt(aad, iv: iv);

      // Retourner IV:EncryptedAAD en base64
      return '${base64Encode(iv.bytes)}:${encrypted.base64}';
    } catch (e) {
      throw Exception('Erreur chiffrement AAD: $e');
    }
  }

  /// Déchiffre l'AAD pour identifier quelle langue utiliser
  static String decryptAAD(String encryptedAAD, String mediaKey) {
    try {
      // 1. Vérifier si c'est un AAD authentifié (base64 JSON simple)
      try {
        final decoded = utf8.decode(base64Decode(encryptedAAD));
        final json = jsonDecode(decoded);
        if (json is Map && json.containsKey('v')) {
          debugPrint('🔍 DECRYPT_AAD: AAD authentifié détecté, retour direct');
          return decoded;
        }
      } catch (e) {
        // Pas un AAD authentifié, continuer avec déchiffrement CBC
        debugPrint('🔍 DECRYPT_AAD: Pas un AAD authentifié, tentative déchiffrement CBC');
      }

      // 2. Vérifier si c'est un format GCM
      if (EncryptionGCMHelper.isGCMFormat(encryptedAAD)) {
        debugPrint('🔍 DECRYPT_AAD: Format GCM détecté, utilisation helper GCM');
        return EncryptionGCMHelper.decryptTextGCM(encryptedAAD, mediaKey);
      }

      // 3. Format CBC classique (IV:ciphertext)
      debugPrint('🔍 DECRYPT_AAD: Tentative déchiffrement CBC classique');
      final keyBytes = base64Decode(mediaKey);
      final key = encrypt.Key(keyBytes);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      final parts = encryptedAAD.split(':');
      if (parts.length != 2) {
        throw Exception('Format AAD CBC invalide (attendu IV:ciphertext)');
      }

      final iv = encrypt.IV(base64Decode(parts[0]));
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      debugPrint('❌ DECRYPT_AAD: Erreur déchiffrement: $e');
      throw Exception('Erreur déchiffrement AAD: $e');
    }
  }

  /// Applique la langue correspondant à l'AAD
  static String applyLanguageByAAD(
    String text, 
    Map<String, Map<String, String>> languages, 
    String aad
  ) {
    final langMap = languages[aad];
    if (langMap == null) {
      throw Exception('Langue introuvable pour AAD: $aad');
    }
    
    return text.split('').map((c) => langMap[c] ?? c).join('');
  }

  /// Applique la langue inverse correspondant à l'AAD (pour déchiffrement)
  static String applyReverseLanguageByAAD(
    String text, 
    Map<String, Map<String, String>> languages, 
    String aad
  ) {
    final langMap = languages[aad];
    if (langMap == null) {
      throw Exception('Langue introuvable pour AAD: $aad');
    }
    
    final reverseMap = {for (var e in langMap.entries) e.value: e.key};
    return text.split('').map((c) => reverseMap[c] ?? c).join('');
  }

  /// Prépare un message avec langue aléatoire et AAD chiffré (mode legacy v2.0)
  static Map<String, dynamic> prepareMessageWithRandomLanguage(
    String text,
    Map<String, Map<String, String>> languages,
    String mediaKey
  ) {
    // 1. Sélectionner une langue aléatoire
    final selectedAAD = selectRandomLanguageAAD(languages);

    // 2. Appliquer la langue au texte
    final codedText = applyLanguageByAAD(text.toLowerCase(), languages, selectedAAD);

    // 3. Chiffrer l'AAD
    final encryptedAAD = encryptAAD(selectedAAD, mediaKey);

    return {
      'codedText': codedText,
      'encryptedAAD': encryptedAAD,
      'selectedAAD': selectedAAD, // Pour debug uniquement
    };
  }

  /// Méthode unifiée pour préparer un message (choisit automatiquement le mode)
  static Map<String, dynamic> prepareMessage(
    String text,
    Map<String, Map<String, String>> languages,
    String mediaKey, {
    bool forcePerCharacterMode = true, // Par défaut, utiliser le nouveau mode
    bool autoPrecomputeCache = true, // Pré-calculer automatiquement le cache
    bool useGCMEncryption = true, // Utiliser GCM par défaut (v2.3)
    bool useAuthenticatedAAD = true, // AAD authentifié mais non chiffré
  }) {
    debugPrint('🚀 PREPARE_MESSAGE: Début préparation pour: "$text"');
    debugPrint('🚀 PREPARE_MESSAGE: Langues disponibles: ${languages.length}');
    debugPrint('🚀 PREPARE_MESSAGE: Mode per-character forcé: $forcePerCharacterMode');
    debugPrint('🚀 PREPARE_MESSAGE: Chiffrement GCM: $useGCMEncryption');

    // Pré-calculer le cache si demandé et si on a assez de langues
    if (autoPrecomputeCache && languages.length >= 5) {
      // Vérifier si le cache est vide ou incomplet
      if (_reverseMapsCache.length < languages.length) {
        debugPrint('🔧 PREPARE_MESSAGE: Pré-calcul du cache des reverse-maps');
        precomputeReverseMaps(languages);
      }
    }

    // Vérifier si on peut utiliser le mode per-character
    final canUsePerCharacter = languages.length == 10 && forcePerCharacterMode;

    if (canUsePerCharacter) {
      if (useGCMEncryption) {
        debugPrint('✅ PREPARE_MESSAGE: Utilisation du mode per-character GCM (v2.3)');
        return prepareMessageWithPerCharacterModeGCM(
          text,
          languages,
          mediaKey,
          useAuthenticatedAAD: useAuthenticatedAAD,
        );
      } else {
        debugPrint('✅ PREPARE_MESSAGE: Utilisation du mode per-character CBC (v2.2)');
        return prepareMessageWithPerCharacterMode(text, languages, mediaKey);
      }
    } else {
      debugPrint('⚠️ PREPARE_MESSAGE: Fallback vers mode single-language (v2.0)');
      debugPrint('⚠️ PREPARE_MESSAGE: Raison: langues=${languages.length}, force=$forcePerCharacterMode');
      return prepareMessageWithRandomLanguage(text, languages, mediaKey);
    }
  }

  /// Décode un message reçu avec AAD chiffré (mode legacy v2.0)
  static String decodeMessageWithAAD(
    String codedText,
    String encryptedAAD,
    Map<String, Map<String, String>> languages,
    String mediaKey
  ) {
    debugPrint('🔍 DECODE_AAD: Début décodage legacy');
    debugPrint('🔍 DECODE_AAD: codedText = $codedText');
    debugPrint('🔍 DECODE_AAD: encryptedAAD = $encryptedAAD');
    debugPrint('🔍 DECODE_AAD: languages disponibles = ${languages.keys.toList()}');

    try {
      // 1. Déchiffrer l'AAD pour identifier la langue
      debugPrint('🔍 DECODE_AAD: Déchiffrement AAD...');
      final aad = decryptAAD(encryptedAAD, mediaKey);
      debugPrint('✅ DECODE_AAD: AAD déchiffré = $aad');

      // 2. Appliquer la langue inverse pour décoder
      debugPrint('🔍 DECODE_AAD: Application langue inverse...');
      final result = applyReverseLanguageByAAD(codedText, languages, aad);
      debugPrint('✅ DECODE_AAD: Résultat final = $result');

      return result;
    } catch (e) {
      debugPrint('❌ DECODE_AAD: Erreur = $e');
      rethrow;
    }
  }

  /// Méthode unifiée pour décoder un message (détecte automatiquement le mode)
  static String decodeMessage(
    String codedText,
    String encryptedAAD,
    Map<String, Map<String, String>> languages,
    String mediaKey, {
    bool autoPrecomputeCache = true, // Pré-calculer automatiquement le cache
    bool autoRepairLanguages = true, // Réparer automatiquement les langues manquantes
  }) {
    debugPrint('🔍 DECODE_UNIFIED: Début décodage unifié');
    debugPrint('🔍 DECODE_UNIFIED: codedText = "$codedText"');
    debugPrint('🔍 DECODE_UNIFIED: encryptedAAD = ${encryptedAAD.substring(0, 20)}...');

    // Pré-calculer le cache si demandé et si on a assez de langues
    if (autoPrecomputeCache && languages.length >= 5) {
      // Vérifier si le cache est vide ou incomplet
      if (_reverseMapsCache.length < languages.length) {
        debugPrint('🔧 DECODE_UNIFIED: Pré-calcul du cache des reverse-maps');
        precomputeReverseMaps(languages);
      }
    }

    try {
      // 1. Détecter le mode du message
      debugPrint('🔍 DECODE_UNIFIED: Détection du mode...');
      final modeInfo = detectMessageMode(encryptedAAD, mediaKey);
      final isPerCharacter = modeInfo['isPerCharacter'] as bool;
      final version = modeInfo['version'] as String;

      debugPrint('✅ DECODE_UNIFIED: Mode détecté - Version: $version, Per-character: $isPerCharacter');

      // 2. Si mode per-character, vérifier la synchronisation des langues
      Map<String, Map<String, String>> workingLanguages = languages;
      if (isPerCharacter && autoRepairLanguages) {
        final sequence = modeInfo['sequence'] as List<String>?;
        if (sequence != null) {
          final diagnosis = diagnoseLanguageSync(sequence, languages);
          if (diagnosis['hasMissingLanguages'] == true) {
            debugPrint('⚠️ DECODE_UNIFIED: Langues manquantes détectées, tentative de réparation...');
            debugPrint('🔍 DECODE_UNIFIED: Diagnostic: $diagnosis');

            workingLanguages = repairMissingLanguages(
              languages,
              diagnosis['missingLanguages'] as List<String>,
            );

            debugPrint('🔧 DECODE_UNIFIED: Langues réparées, nouvelles langues disponibles: ${workingLanguages.keys.length}');
          }
        }
      }

      // 3. Décoder selon le mode et la version détectés
      if (isPerCharacter) {
        if (version == '2.3') {
          debugPrint('🎯 DECODE_UNIFIED: Décodage per-character GCM (v2.3)');
          // Pour v2.3, vérifier si le contenu est au format GCM ou texte codé
          if (EncryptionGCMHelper.isGCMFormat(codedText)) {
            // C'est du contenu GCM chiffré
            debugPrint('🔐 DECODE_UNIFIED: Contenu GCM détecté');
            // Détecter si AAD est authentifié ou chiffré
            bool isAuthenticatedAAD;
            try {
              final decoded = utf8.decode(base64Decode(encryptedAAD));
              final json = jsonDecode(decoded);
              isAuthenticatedAAD = json is Map && json.containsKey('v');
            } catch (e) {
              isAuthenticatedAAD = false;
            }
            return decodeMessageWithPerCharacterModeGCM(codedText, encryptedAAD, workingLanguages, mediaKey, isAuthenticatedAAD: isAuthenticatedAAD);
          } else {
            // C'est du texte codé, probablement un message v2.2 mal détecté
            debugPrint('⚠️ DECODE_UNIFIED: AAD v2.3 mais contenu non-GCM, fallback vers v2.2');
            return decodeMessageWithPerCharacterMode(codedText, encryptedAAD, workingLanguages, mediaKey);
          }
        } else {
          debugPrint('🎯 DECODE_UNIFIED: Décodage per-character CBC (v2.2)');
          return decodeMessageWithPerCharacterMode(codedText, encryptedAAD, workingLanguages, mediaKey);
        }
      } else {
        debugPrint('🎯 DECODE_UNIFIED: Décodage single-language (v2.0)');
        return decodeMessageWithAAD(codedText, encryptedAAD, workingLanguages, mediaKey);
      }
    } catch (e) {
      debugPrint('❌ DECODE_UNIFIED: Erreur = $e');

      // Fallback intelligent selon le type d'AAD détecté
      debugPrint('🔄 DECODE_UNIFIED: Tentative fallback intelligent...');
      try {
        // Vérifier si c'est un AAD v2.3 qui a échoué
        String? aadContent;
        try {
          aadContent = decryptAAD(encryptedAAD, mediaKey);
          final aadJson = jsonDecode(aadContent) as Map<String, dynamic>;
          final version = aadJson['v'] as String?;

          if (version == '2.3') {
            debugPrint('🔄 DECODE_UNIFIED: AAD v2.3 détecté, pas de fallback legacy possible');
            return '[MESSAGE COMPROMIS] $codedText';
          }
        } catch (aadError) {
          debugPrint('🔄 DECODE_UNIFIED: Impossible de décrypter AAD pour fallback: $aadError');
        }

        // Fallback vers mode legacy seulement pour v2.0/v2.2
        debugPrint('🔄 DECODE_UNIFIED: Tentative fallback vers mode legacy v2.0...');
        return decodeMessageWithAAD(codedText, encryptedAAD, languages, mediaKey);
      } catch (e2) {
        debugPrint('❌ DECODE_UNIFIED: Fallback échoué = $e2');
        // Dernier recours: retourner le texte codé avec un message d'erreur
        return '[ERREUR DÉCODAGE] $codedText';
      }
    }
  }

  /// Vérifie si un package contient le nouveau format (10 langues)
  static bool isMultiLanguagePackage(Map<String, dynamic> package) {
    return package.containsKey('languages') && 
           package['version'] == '2.0' &&
           package['languages'] is Map;
  }

  /// Convertit un ancien package (1 langue) vers le nouveau format (10 langues)
  static Map<String, dynamic> convertLegacyToMultiLanguage(Map<String, dynamic> legacyPackage) {
    if (legacyPackage.containsKey('langMap')) {
      // Créer 10 langues en dupliquant l'ancienne langue avec variations
      final baseLangMap = Map<String, String>.from(legacyPackage['langMap']);
      final languages = <String, Map<String, String>>{};
      
      for (int i = 0; i < 10; i++) {
        final aad = 'lang_${i.toString().padLeft(2, '0')}';
        if (i == 0) {
          // Première langue = langue originale
          languages[aad] = baseLangMap;
        } else {
          // Autres langues = variations de la langue originale
          languages[aad] = _generateVariation(baseLangMap, i);
        }
      }
      
      return {
        'languages': languages,
        'mediaKey': legacyPackage['mediaKey'],
        'timestamp': legacyPackage['timestamp'],
        'version': '2.0',
        'convertedFrom': '1.0'
      };
    }
    
    throw Exception('Package legacy invalide');
  }

  /// Génère une variation d'une langue existante
  static Map<String, String> _generateVariation(Map<String, String> baseLangMap, int seed) {
    final random = Random(seed); // Seed fixe pour reproductibilité
    final chars = baseLangMap.keys.toList();
    final values = baseLangMap.values.toList();
    
    // Mélanger les valeurs avec le seed
    values.shuffle(random);
    
    final variation = <String, String>{};
    for (int i = 0; i < chars.length; i++) {
      variation[chars[i]] = values[i];
    }
    
    return variation;
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // NOUVEAU: MODE PER-CHARACTER (v2.2)
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Cache des reverse-maps pour optimiser les performances
  static final Map<String, Map<String, String>> _reverseMapsCache = {};

  /// Cache des hash de langues pour détecter les changements
  static final Map<String, int> _languageHashCache = {};

  /// Obtient ou calcule la reverse-map pour une langue donnée
  static Map<String, String> _getReverseMap(Map<String, String> langMap, String aad) {
    // Calculer un hash simple de la langue pour détecter les changements
    final langHash = langMap.entries.map((e) => '${e.key}:${e.value}').join('|').hashCode;

    // Vérifier si la langue a changé
    if (_languageHashCache[aad] != langHash) {
      debugPrint('🔄 CACHE: Invalidation cache pour langue $aad (hash changé)');
      _reverseMapsCache.remove(aad);
      _languageHashCache[aad] = langHash;
    }

    // Retourner depuis le cache ou calculer
    if (_reverseMapsCache.containsKey(aad)) {
      return _reverseMapsCache[aad]!;
    }

    debugPrint('🔧 CACHE: Calcul reverse-map pour langue $aad');
    final reverseMap = {for (var e in langMap.entries) e.value: e.key};
    _reverseMapsCache[aad] = reverseMap;
    return reverseMap;
  }

  /// Trouve une langue de fallback pour une langue manquante
  static String? _findFallbackLanguage(String missingLang, Map<String, Map<String, String>> availableLanguages) {
    // 1. Essayer de trouver une langue avec un nom similaire
    final availableKeys = availableLanguages.keys.toList();

    // Extraire le numéro de la langue manquante (ex: lang_04 -> 04)
    final missingMatch = RegExp(r'lang_(\d+)').firstMatch(missingLang);
    if (missingMatch != null) {
      final missingNumber = missingMatch.group(1);

      // Chercher des variantes du même numéro
      for (final key in availableKeys) {
        if (key.contains(missingNumber!)) {
          return key;
        }
      }
    }

    // 2. Fallback vers la première langue disponible
    if (availableKeys.isNotEmpty) {
      debugPrint('🔄 FALLBACK: Utilisation de ${availableKeys.first} comme fallback universel');
      return availableKeys.first;
    }

    return null;
  }

  /// Pré-calcule toutes les reverse-maps pour un ensemble de langues
  static void precomputeReverseMaps(Map<String, Map<String, String>> languages) {
    debugPrint('🚀 CACHE: Pré-calcul des reverse-maps pour ${languages.length} langues');
    final stopwatch = Stopwatch()..start();

    for (final entry in languages.entries) {
      final aad = entry.key;
      final langMap = entry.value;
      _getReverseMap(langMap, aad); // Force le calcul et la mise en cache
    }

    stopwatch.stop();
    debugPrint('✅ CACHE: Pré-calcul terminé en ${stopwatch.elapsedMilliseconds}ms');
    debugPrint('📊 CACHE: ${_reverseMapsCache.length} reverse-maps en cache');
  }

  /// Nettoie le cache des reverse-maps
  static void clearReverseMapsCache() {
    debugPrint('🧹 CACHE: Nettoyage du cache des reverse-maps');
    _reverseMapsCache.clear();
    _languageHashCache.clear();
  }

  /// Obtient des statistiques sur le cache
  static Map<String, dynamic> getCacheStats() {
    return {
      'reverseMapsCount': _reverseMapsCache.length,
      'languageHashCount': _languageHashCache.length,
      'cacheKeys': _reverseMapsCache.keys.toList(),
      'memoryEstimate': _reverseMapsCache.values
          .map((map) => map.length * 50) // Estimation: 50 bytes par entrée
          .fold(0, (a, b) => a + b),
    };
  }

  /// Génère une séquence de langues pour chaque caractère du texte
  static List<String> _generateLanguageSequence(String text, List<String> availableLanguages) {
    final random = Random.secure();
    final sequence = <String>[];

    // Traiter le texte avec support Unicode complet
    final runes = text.runes.toList();
    for (int i = 0; i < runes.length; i++) {
      // Sélection aléatoire d'une langue pour chaque caractère
      final selectedLang = availableLanguages[random.nextInt(availableLanguages.length)];
      sequence.add(selectedLang);
    }

    return sequence;
  }

  /// Prépare un message avec le mode per-character (v2.2)
  static Map<String, dynamic> prepareMessageWithPerCharacterMode(
    String text,
    Map<String, Map<String, String>> languages,
    String mediaKey
  ) {
    debugPrint('🔄 PERCHAR: Début préparation per-character pour: "$text"');

    // 1. Vérifier qu'on a exactement 10 langues
    if (languages.length != 10) {
      throw Exception('Le mode per-character nécessite exactement 10 langues (trouvé: ${languages.length})');
    }

    final availableLanguages = languages.keys.toList();
    debugPrint('🌐 PERCHAR: Langues disponibles: $availableLanguages');

    // 2. Générer la séquence de langues (une par caractère)
    final sequence = _generateLanguageSequence(text, availableLanguages);
    debugPrint('🎯 PERCHAR: Séquence générée: $sequence');

    // 3. Appliquer la transformation caractère par caractère
    final codedChars = <String>[];
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final langKey = sequence[i];
      final langMap = languages[langKey]!;
      final codedChar = langMap[char] ?? char; // Laisser inchangé si pas dans la map
      codedChars.add(codedChar);
    }
    final codedText = codedChars.join('');
    debugPrint('🔤 PERCHAR: Texte codé: "$codedText"');

    // 4. Créer le JSON AAD avec la séquence
    final aadJson = {
      'v': '2.2',
      'mode': 'perchar-seq',
      'seq': sequence,
    };
    final aadJsonString = jsonEncode(aadJson);
    debugPrint('📋 PERCHAR: AAD JSON: $aadJsonString');

    // 5. Chiffrer l'AAD
    final encryptedAAD = encryptAAD(aadJsonString, mediaKey);
    debugPrint('🔐 PERCHAR: AAD chiffré: ${encryptedAAD.substring(0, 20)}...');

    return {
      'codedText': codedText,
      'encryptedAAD': encryptedAAD,
      'sequence': sequence, // Pour debug uniquement
      'aadJson': aadJson, // Pour debug uniquement
    };
  }

  /// Décode un message per-character (v2.2)
  static String decodeMessageWithPerCharacterMode(
    String codedText,
    String encryptedAAD,
    Map<String, Map<String, String>> languages,
    String mediaKey
  ) {
    debugPrint('🔍 PERCHAR_DECODE: Début décodage per-character');
    debugPrint('🔍 PERCHAR_DECODE: codedText = "$codedText"');
    debugPrint('🔍 PERCHAR_DECODE: encryptedAAD = ${encryptedAAD.substring(0, 20)}...');

    try {
      // 1. Déchiffrer l'AAD pour obtenir le JSON
      debugPrint('🔓 PERCHAR_DECODE: Déchiffrement AAD...');
      final aadJsonString = decryptAAD(encryptedAAD, mediaKey);
      debugPrint('📋 PERCHAR_DECODE: AAD JSON déchiffré: $aadJsonString');

      // 2. Parser le JSON AAD
      final aadJson = jsonDecode(aadJsonString) as Map<String, dynamic>;
      final version = aadJson['v'] as String?;
      final mode = aadJson['mode'] as String?;
      final sequence = (aadJson['seq'] as List<dynamic>).cast<String>();

      debugPrint('📊 PERCHAR_DECODE: Version: $version, Mode: $mode');
      debugPrint('🎯 PERCHAR_DECODE: Séquence: $sequence');

      // 3. Vérifier le format (accepter v2.2 et v2.3 en mode fallback)
      if ((version != '2.2' && version != '2.3') || mode != 'perchar-seq') {
        throw Exception('Format AAD invalide: v=$version, mode=$mode');
      }

      // Avertissement pour v2.3 en mode fallback
      if (version == '2.3') {
        debugPrint('⚠️ PERCHAR_DECODE: Mode fallback v2.3 -> v2.2 (contenu non-GCM)');
      }

      // 4. Vérifier la cohérence des longueurs (avec support Unicode)
      final codedRunes = codedText.runes.toList();
      if (sequence.length != codedRunes.length) {
        debugPrint('⚠️ PERCHAR_DECODE: Longueur incohérente - seq:${sequence.length}, text:${codedRunes.length}');
        throw Exception('Longueur de séquence incohérente avec le texte codé');
      }

      // 5. Décoder caractère par caractère avec gestion robuste des langues manquantes
      final decodedChars = <String>[];
      final missingLanguages = <String>[];

      for (int i = 0; i < codedRunes.length; i++) {
        final codedChar = String.fromCharCode(codedRunes[i]);
        final langKey = sequence[i];

        if (!languages.containsKey(langKey)) {
          if (!missingLanguages.contains(langKey)) {
            missingLanguages.add(langKey);
            debugPrint('⚠️ PERCHAR_DECODE: Langue $langKey introuvable à la position $i');
          }

          // Fallback intelligent: essayer de trouver une langue similaire
          final fallbackLang = _findFallbackLanguage(langKey, languages);
          if (fallbackLang != null) {
            debugPrint('🔄 PERCHAR_DECODE: Utilisation de $fallbackLang comme fallback pour $langKey');
            final langMap = languages[fallbackLang]!;
            final reverseMap = _getReverseMap(langMap, fallbackLang);
            final decodedChar = reverseMap[codedChar] ?? codedChar;
            decodedChars.add(decodedChar);
          } else {
            // Dernier recours: garder le caractère tel quel
            decodedChars.add(codedChar);
          }
          continue;
        }

        final langMap = languages[langKey]!;
        final reverseMap = _getReverseMap(langMap, langKey);
        final decodedChar = reverseMap[codedChar] ?? codedChar; // Laisser inchangé si pas trouvé
        decodedChars.add(decodedChar);
      }

      // Afficher un résumé des langues manquantes
      if (missingLanguages.isNotEmpty) {
        debugPrint('⚠️ PERCHAR_DECODE: Langues manquantes: $missingLanguages');
        debugPrint('🔍 PERCHAR_DECODE: Langues disponibles: ${languages.keys.toList()}');
        debugPrint('💡 PERCHAR_DECODE: Cela peut indiquer un problème de synchronisation des langues');
      }

      final decodedText = decodedChars.join('');
      debugPrint('✅ PERCHAR_DECODE: Texte décodé: "$decodedText"');

      return decodedText;
    } catch (e) {
      debugPrint('❌ PERCHAR_DECODE: Erreur = $e');
      rethrow;
    }
  }

  /// Détecte le mode d'un message à partir de son AAD chiffré
  static Map<String, dynamic> detectMessageMode(String encryptedAAD, String mediaKey) {
    try {
      final aadContent = decryptAAD(encryptedAAD, mediaKey);

      // Essayer de parser comme JSON (v2.2)
      try {
        final aadJson = jsonDecode(aadContent) as Map<String, dynamic>;
        final version = aadJson['v'] as String?;
        final mode = aadJson['mode'] as String?;

        if ((version == '2.2' || version == '2.3') && mode == 'perchar-seq') {
          return {
            'version': version,
            'mode': 'perchar-seq',
            'isPerCharacter': true,
            'sequence': (aadJson['seq'] as List<dynamic>).cast<String>(),
          };
        }
      } catch (e) {
        // Pas un JSON valide, continuer avec le mode legacy
      }

      // Mode legacy (v2.0) - AAD contient directement la clé de langue
      return {
        'version': '2.0',
        'mode': 'single-lang',
        'isPerCharacter': false,
        'languageKey': aadContent,
      };
    } catch (e) {
      throw Exception('Impossible de détecter le mode du message: $e');
    }
  }

  /// Statistiques d'utilisation des langues (pour debug)
  static Map<String, int> getLanguageUsageStats(List<String> usedAADs) {
    final stats = <String, int>{};
    for (final aad in usedAADs) {
      stats[aad] = (stats[aad] ?? 0) + 1;
    }
    return stats;
  }

  /// Diagnostique les problèmes de synchronisation des langues
  static Map<String, dynamic> diagnoseLanguageSync(
    List<String> requiredLanguages,
    Map<String, Map<String, String>> availableLanguages,
  ) {
    final missing = <String>[];
    final available = availableLanguages.keys.toList();
    final suggestions = <String, String>{};

    for (final required in requiredLanguages) {
      if (!availableLanguages.containsKey(required)) {
        missing.add(required);

        // Chercher des suggestions de fallback
        final fallback = _findFallbackLanguage(required, availableLanguages);
        if (fallback != null) {
          suggestions[required] = fallback;
        }
      }
    }

    return {
      'hasMissingLanguages': missing.isNotEmpty,
      'missingLanguages': missing,
      'availableLanguages': available,
      'fallbackSuggestions': suggestions,
      'totalRequired': requiredLanguages.length,
      'totalAvailable': available.length,
      'syncStatus': missing.isEmpty ? 'OK' : 'DESYNC',
    };
  }

  /// Tente de réparer automatiquement les langues manquantes
  static Map<String, Map<String, String>> repairMissingLanguages(
    Map<String, Map<String, String>> languages,
    List<String> missingLanguages,
  ) {
    final repairedLanguages = Map<String, Map<String, String>>.from(languages);

    for (final missingLang in missingLanguages) {
      // Essayer de générer une langue de remplacement
      final fallback = _findFallbackLanguage(missingLang, languages);
      if (fallback != null) {
        // Créer une variation de la langue de fallback
        final baseLangMap = languages[fallback]!;
        final variation = _generateVariation(baseLangMap, missingLang.hashCode);
        repairedLanguages[missingLang] = variation;
        debugPrint('🔧 REPAIR: Langue $missingLang générée à partir de $fallback');
      } else {
        // Générer une nouvelle langue aléatoire avec alphabets séparés (texte→texte, emoji→emoji)
        final newLangMap = <String, String>{};

        // 🔤 ALPHABET TEXTE (sans emojis) - IDENTIQUE à lang_map_generator.dart
        const String textAlphabet =
            'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
            '0123456789'
            ' .?!,;:-_()[]{}@#\$%^&*+=<>/\\|`~"\''
            'àáâäæçèéêëìíîïñòóôöùúûüÿ'
            'ÀÁÂÄÆÇÈÉÊËÌÍÎÏÑÒÓÔÖÙÚÛÜŸ'
            'ßöäüÖÄÜ'
            'ñÑ¿¡'
            'òàèìù'
            'ãõçÃÕÇ'
            'åæøÅÆØ'
            'абвгдеёжзийклмнопрстуфхцчшщъыьэюя'
            'АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ'
            'αβγδεζηθικλμνξοπρστυφχψω'
            'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ'
            'ابتثجحخدذرزسشصضطظعغفقكلمنهوي'
            '一二三四五六七八九十人大小中上下左右前後'
            'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん'
            'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン'
            '±×÷∞≠≤≥∑∏√∫∂∇∈∉∪∩⊂⊃⊆⊇∧∨¬∀∃'
            '€£¥¢₹₽₩₪₫₨₦₡₵₴₸₼₾'
            '←↑→↓↔↕↖↗↘↙⇐⇑⇒⇓⇔⇕'
            '©®™§¶†‡•…‰′″‹›«»°¡¿';

        // 😀 ALPHABET EMOJI (séparé) - IDENTIQUE à lang_map_generator.dart
        const String emojiAlphabet =
            '😀😃😄😁😆😅😂🤣😊😇🙂🙃😉😌😍🥰😘😗😙😚😋😛😝😜🤪🤨🧐🤓😎🤩🥳😏😒😞😔😟😕🙁😣😖😫😩🥺😢😭😤😠😡🤬🤯😳🥵🥶😱😨😰😥😓🤗🤔🤭🤫🤥😶😐😑😬🙄😯😦😧😮😲🥱😴🤤😪😵🤐🥴🤢🤮🤧😷🤒🤕🤑🤠😈👿👹👺🤡💩👻💀👽👾🤖🎃'
            '👋👍👎👌🤞🤟🤘🤙👈👉👆👇👏🙌👐🤝🙏💪'
            '💔💕💖💗💘💝💟💯'
            '🔥💧⭐🌟✨🎉🎊🎈🎁🎀🎂🍰🎵🎶🎤🎧🎮🎯🎲🎭🎨🎪🎫🎬';

        // Combiner les deux alphabets pour la réparation
        const String alphabet = textAlphabet + emojiAlphabet;

        final chars = <String>[];
        final runes = alphabet.runes.toList();
        for (int i = 0; i < runes.length; i++) {
          final char = String.fromCharCode(runes[i]);
          if (!chars.contains(char)) {
            chars.add(char);
          }
        }

        final shuffled = List<String>.from(chars);
        shuffled.shuffle(Random(missingLang.hashCode)); // Seed déterministe

        for (int i = 0; i < chars.length; i++) {
          newLangMap[chars[i]] = shuffled[i];
        }

        repairedLanguages[missingLang] = newLangMap;
        debugPrint('🆕 REPAIR: Nouvelle langue $missingLang générée (alphabet étendu: ${chars.length} caractères)');
      }
    }

    return repairedLanguages;
  }

  /// Prépare un message avec mode per-character et chiffrement GCM (v2.3)
  static Map<String, dynamic> prepareMessageWithPerCharacterModeGCM(
    String text,
    Map<String, Map<String, String>> languages,
    String mediaKey, {
    bool useAuthenticatedAAD = true, // AAD authentifié mais non chiffré
  }) {
    debugPrint('🔄 PERCHAR_GCM: Début préparation per-character GCM pour: "$text"');

    if (languages.length != 10) {
      throw Exception('Mode per-character GCM nécessite exactement 10 langues, trouvé: ${languages.length}');
    }

    // 1. Générer la séquence aléatoire
    final availableLanguages = languages.keys.toList();
    final sequence = _generateLanguageSequence(text, availableLanguages);

    debugPrint('🌐 PERCHAR_GCM: Langues disponibles: $availableLanguages');
    debugPrint('🎯 PERCHAR_GCM: Séquence générée: $sequence');

    // 2. Transformer caractère par caractère (avec support Unicode)
    final codedChars = <String>[];
    final runes = text.runes.toList();
    for (int i = 0; i < runes.length; i++) {
      final char = String.fromCharCode(runes[i]);
      final langKey = sequence[i];
      final langMap = languages[langKey]!;
      final codedChar = langMap[char] ?? char; // Fallback si caractère non supporté
      codedChars.add(codedChar);
    }

    final codedText = codedChars.join('');
    debugPrint('🔤 PERCHAR_GCM: Texte codé: "$codedText"');

    // 3. Créer l'AAD pour GCM (utiliser runes.length pour support Unicode)
    final aadData = EncryptionGCMHelper.createGCMAAD(
      mode: 'perchar-seq',
      sequence: sequence,
      messageLength: runes.length, // 🔧 FIX: Utiliser runes.length pour les emojis
    );

    debugPrint('📋 PERCHAR_GCM: AAD créé: $aadData');

    // 4. Chiffrer le contenu avec GCM
    String encryptedContent;
    String? encryptedAAD;

    if (useAuthenticatedAAD) {
      // Option A : AAD authentifié mais non chiffré
      final aadString = jsonEncode(aadData);
      encryptedContent = EncryptionGCMHelper.encryptTextGCM(
        codedText,
        mediaKey,
        aadData: aadString,
      );
      encryptedAAD = base64Encode(utf8.encode(aadString)); // AAD en clair mais encodé
      debugPrint('🔐 PERCHAR_GCM: Mode AAD authentifié (non chiffré)');
    } else {
      // Option B : AAD chiffré séparément
      encryptedContent = EncryptionGCMHelper.encryptTextGCM(codedText, mediaKey);
      encryptedAAD = EncryptionGCMHelper.encryptAADGCM(aadData, mediaKey);
      debugPrint('🔐 PERCHAR_GCM: Mode AAD chiffré séparément');
    }

    debugPrint('🔐 PERCHAR_GCM: Contenu chiffré: ${encryptedContent.substring(0, 20)}...');
    debugPrint('🔐 PERCHAR_GCM: AAD traité: ${encryptedAAD.substring(0, 20)}...');

    return {
      'codedText': codedText,
      'encryptedContent': encryptedContent,
      'encryptedAAD': encryptedAAD,
      'sequence': sequence,
      'aadData': aadData,
      'encryptionMode': 'gcm',
      'version': EncryptionGCMHelper.GCM_VERSION,
    };
  }

  /// Décode un message per-character avec chiffrement GCM (v2.3)
  static String decodeMessageWithPerCharacterModeGCM(
    String encryptedContent,
    String encryptedAAD,
    Map<String, Map<String, String>> languages,
    String mediaKey, {
    bool isAuthenticatedAAD = true,
  }) {
    debugPrint('🔍 PERCHAR_GCM_DECODE: Début décodage per-character GCM');
    debugPrint('🔍 PERCHAR_GCM_DECODE: Contenu chiffré: ${encryptedContent.substring(0, 20)}...');
    debugPrint('🔍 PERCHAR_GCM_DECODE: AAD mode authentifié: $isAuthenticatedAAD');

    try {
      // 1. Récupérer l'AAD
      Map<String, dynamic> aadData;
      String? aadString;

      if (isAuthenticatedAAD) {
        // Option A : AAD authentifié mais non chiffré
        aadString = utf8.decode(base64Decode(encryptedAAD));
        aadData = jsonDecode(aadString) as Map<String, dynamic>;
        debugPrint('📋 PERCHAR_GCM_DECODE: AAD authentifié récupéré: $aadData');
      } else {
        // Option B : AAD chiffré séparément
        aadData = EncryptionGCMHelper.decryptAADGCM(encryptedAAD, mediaKey);
        aadString = jsonEncode(aadData);
        debugPrint('📋 PERCHAR_GCM_DECODE: AAD déchiffré: $aadData');
      }

      // 2. Valider l'AAD
      if (!EncryptionGCMHelper.validateAAD(aadData)) {
        throw Exception('AAD GCM invalide: $aadData');
      }

      // 3. Extraire la séquence
      final sequence = (aadData['seq'] as List<dynamic>).cast<String>();
      debugPrint('🎯 PERCHAR_GCM_DECODE: Séquence: $sequence');

      // 4. Déchiffrer le contenu avec GCM
      final codedText = EncryptionGCMHelper.decryptTextGCM(
        encryptedContent,
        mediaKey,
        aadData: isAuthenticatedAAD ? aadString : null,
      );

      debugPrint('🔓 PERCHAR_GCM_DECODE: Contenu déchiffré: "$codedText"');

      // 5. Vérifier la cohérence des longueurs (avec support Unicode)
      final codedRunes = codedText.runes.toList();
      if (sequence.length != codedRunes.length) {
        throw Exception('Incohérence longueurs: séquence=${sequence.length}, texte=${codedRunes.length}');
      }

      // 6. Décoder caractère par caractère avec gestion des langues manquantes
      final decodedChars = <String>[];
      final missingLanguages = <String>[];

      for (int i = 0; i < codedRunes.length; i++) {
        final codedChar = String.fromCharCode(codedRunes[i]);
        final langKey = sequence[i];

        if (!languages.containsKey(langKey)) {
          if (!missingLanguages.contains(langKey)) {
            missingLanguages.add(langKey);
            debugPrint('⚠️ PERCHAR_GCM_DECODE: Langue $langKey introuvable à la position $i');
          }

          // Fallback intelligent
          final fallbackLang = _findFallbackLanguage(langKey, languages);
          if (fallbackLang != null) {
            debugPrint('🔄 PERCHAR_GCM_DECODE: Utilisation de $fallbackLang comme fallback pour $langKey');
            final langMap = languages[fallbackLang]!;
            final reverseMap = _getReverseMap(langMap, fallbackLang);
            final decodedChar = reverseMap[codedChar] ?? codedChar;
            decodedChars.add(decodedChar);
          } else {
            decodedChars.add(codedChar);
          }
          continue;
        }

        final langMap = languages[langKey]!;
        final reverseMap = _getReverseMap(langMap, langKey);
        final decodedChar = reverseMap[codedChar] ?? codedChar;
        decodedChars.add(decodedChar);
      }

      // Afficher un résumé des langues manquantes
      if (missingLanguages.isNotEmpty) {
        debugPrint('⚠️ PERCHAR_GCM_DECODE: Langues manquantes: $missingLanguages');
        debugPrint('🔍 PERCHAR_GCM_DECODE: Langues disponibles: ${languages.keys.toList()}');
      }

      final result = decodedChars.join('');
      debugPrint('✅ PERCHAR_GCM_DECODE: Texte décodé: "$result"');

      return result;

    } catch (e) {
      if (e is AuthenticationException) {
        debugPrint('❌ PERCHAR_GCM_DECODE: Échec authentification GCM: $e');
        throw Exception('Échec authentification GCM: message compromis ou corrompu');
      }

      debugPrint('❌ PERCHAR_GCM_DECODE: Erreur: $e');
      rethrow;
    }
  }

  /// Génère un rapport de debug sur les langues
  static String generateDebugReport(Map<String, Map<String, String>> languages, String mediaKey) {
    final report = StringBuffer();
    report.writeln('🔍 Rapport Multi-Langues Debug');
    report.writeln('═══════════════════════════════');
    report.writeln('📊 Nombre de langues: ${languages.length}');
    report.writeln('🔑 Clé média: ${mediaKey.substring(0, 12)}...');
    report.writeln('🎯 Mode per-character: ${languages.length == 10 ? "✅ Disponible" : "❌ Indisponible"}');
    report.writeln('🔐 Support GCM: ✅ Disponible');
    report.writeln('');

    languages.forEach((aad, langMap) {
      report.writeln('🌐 $aad: ${langMap.length} caractères');
      // Exemple de mapping pour les 5 premiers caractères
      final examples = langMap.entries.take(5).map((e) => '${e.key}→${e.value}').join(', ');
      report.writeln('   Exemples: $examples');
    });

    return report.toString();
  }

  /// Méthode unifiée pour décoder un message avec support GCM (v2.3)
  ///
  /// [contentOrCoded] : Contenu chiffré (GCM) ou texte codé (CBC)
  /// [encryptedAAD] : AAD chiffré ou authentifié
  static String decodeMessageUnified(
    String contentOrCoded,
    String encryptedAAD,
    Map<String, Map<String, String>> languages,
    String mediaKey, {
    bool autoPrecomputeCache = true,
    bool autoRepairLanguages = true,
  }) {
    debugPrint('🔍 DECODE_UNIFIED_GCM: Début décodage unifié avec support GCM');
    debugPrint('🔍 DECODE_UNIFIED_GCM: contentOrCoded = "${contentOrCoded.length > 20 ? contentOrCoded.substring(0, 20) : contentOrCoded}..."');
    debugPrint('🔍 DECODE_UNIFIED_GCM: encryptedAAD = ${encryptedAAD.length > 20 ? encryptedAAD.substring(0, 20) : encryptedAAD}...');

    // Pré-calculer le cache si demandé
    if (autoPrecomputeCache && _reverseMapsCache.length < languages.length) {
      debugPrint('🔧 DECODE_UNIFIED_GCM: Pré-calcul du cache des reverse-maps');
      precomputeReverseMaps(languages);
    }

    try {
      // 1. Détecter si c'est du GCM ou CBC
      final isGCMContent = EncryptionGCMHelper.isGCMFormat(contentOrCoded);
      debugPrint('🔍 DECODE_UNIFIED_GCM: Format GCM détecté: $isGCMContent');

      if (isGCMContent) {
        // Mode GCM (v2.3)
        debugPrint('🔐 DECODE_UNIFIED_GCM: Décodage GCM');

        // Détecter si AAD est authentifié ou chiffré
        // AAD authentifié = base64 JSON simple, AAD chiffré = format GCM
        bool isAuthenticatedAAD;
        try {
          // Tenter de décoder comme JSON base64
          final decoded = utf8.decode(base64Decode(encryptedAAD));
          final json = jsonDecode(decoded);
          isAuthenticatedAAD = json is Map && json.containsKey('v');
        } catch (e) {
          // Si échec, c'est probablement chiffré
          isAuthenticatedAAD = false;
        }
        debugPrint('🔍 DECODE_UNIFIED_GCM: AAD authentifié (non chiffré): $isAuthenticatedAAD');

        return decodeMessageWithPerCharacterModeGCM(
          contentOrCoded,
          encryptedAAD,
          languages,
          mediaKey,
          isAuthenticatedAAD: isAuthenticatedAAD,
        );
      } else {
        // Mode CBC (v2.0/v2.2) - utiliser la méthode existante
        debugPrint('🔐 DECODE_UNIFIED_GCM: Décodage CBC - délégation vers méthode existante');
        return decodeMessage(
          contentOrCoded,
          encryptedAAD,
          languages,
          mediaKey,
          autoPrecomputeCache: autoPrecomputeCache,
          autoRepairLanguages: autoRepairLanguages,
        );
      }
    } catch (e) {
      debugPrint('❌ DECODE_UNIFIED_GCM: Erreur = $e');

      // Gestion spéciale des erreurs d'authentification GCM
      if (e is AuthenticationException) {
        debugPrint('🚨 DECODE_UNIFIED_GCM: Échec authentification GCM - message compromis');
        return '[MESSAGE COMPROMIS] Échec authentification';
      }

      // Fallback vers la méthode existante
      debugPrint('🔄 DECODE_UNIFIED_GCM: Fallback vers décodage CBC...');
      try {
        return decodeMessage(
          contentOrCoded,
          encryptedAAD,
          languages,
          mediaKey,
          autoPrecomputeCache: autoPrecomputeCache,
          autoRepairLanguages: autoRepairLanguages,
        );
      } catch (e2) {
        debugPrint('❌ DECODE_UNIFIED_GCM: Fallback échoué = $e2');
        return '[ERREUR DÉCODAGE] $contentOrCoded';
      }
    }
  }
}
