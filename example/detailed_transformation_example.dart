// Exemple détaillé : Comment "salut" est transformé caractère par caractère
// Ce fichier montre EXACTEMENT ce qui se passe lors de la transformation

import 'dart:convert';
import 'package:silencia/core/utils/multi_language_manager.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';

void main() {
  print('🔍 TRANSFORMATION DÉTAILLÉE : "salut" → mode per-character');
  print('═══════════════════════════════════════════════════════════');
  
  // 1. Générer un package de langues avec 10 langues
  print('\n📦 ÉTAPE 1 : Génération des langues');
  final package = LangMapGenerator.generateLanguagePackage();
  final languages = Map<String, Map<String, String>>.from(
    (package['languages'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v))),
  );
  final mediaKey = package['mediaKey'] as String;
  
  print('✅ ${languages.length} langues générées : ${languages.keys.toList()}');
  
  // 2. Afficher un échantillon de chaque langue
  print('\n🌐 ÉTAPE 2 : Échantillon des langues (pour les lettres de "salut")');
  const targetChars = ['s', 'a', 'l', 'u', 't'];
  
  languages.forEach((langKey, langMap) {
    final sample = targetChars.map((char) => '$char→${langMap[char] ?? char}').join(', ');
    print('   $langKey: $sample');
  });
  
  // 3. Transformation détaillée de "salut"
  print('\n🔄 ÉTAPE 3 : Transformation de "salut"');
  const message = 'salut';
  
  final result = MultiLanguageManager.prepareMessageWithPerCharacterMode(
    message,
    languages,
    mediaKey,
  );
  
  final sequence = result['sequence'] as List<String>;
  final codedText = result['codedText'] as String;
  final aadJson = result['aadJson'] as Map<String, dynamic>;
  
  print('📝 Message original : "$message"');
  print('🎯 Séquence générée : $sequence');
  print('🔤 Texte codé : "$codedText"');
  
  // 4. Détail caractère par caractère
  print('\n🔍 ÉTAPE 4 : Transformation caractère par caractère');
  print('Position | Caractère | Langue utilisée | Transformation | Résultat');
  print('---------|-----------|-----------------|----------------|----------');
  
  for (int i = 0; i < message.length; i++) {
    final originalChar = message[i];
    final langKey = sequence[i];
    final langMap = languages[langKey]!;
    final transformedChar = langMap[originalChar] ?? originalChar;
    final codedChar = codedText[i];
    
    print('    $i    |     $originalChar     |    $langKey    |   $originalChar → $transformedChar   |    $codedChar');
  }
  
  // 5. Structure de l'AAD
  print('\n📋 ÉTAPE 5 : Structure de l\'AAD (métadonnées)');
  print('AAD JSON : ${jsonEncode(aadJson)}');
  print('Contenu :');
  print('  - Version : ${aadJson['v']} (mode per-character v2.2)');
  print('  - Mode : ${aadJson['mode']} (per-character avec séquence)');
  print('  - Séquence : ${aadJson['seq']} (une langue par caractère)');
  
  // 6. Chiffrement de l'AAD
  print('\n🔐 ÉTAPE 6 : Chiffrement de l\'AAD');
  final encryptedAAD = result['encryptedAAD'] as String;
  print('AAD chiffré : ${encryptedAAD.substring(0, 50)}...');
  print('Format : IV:EncryptedData (en base64)');
  final parts = encryptedAAD.split(':');
  print('  - IV (16 bytes) : ${parts[0]}');
  print('  - Data chiffrée : ${parts[1].substring(0, 30)}...');
  
  // 7. Processus de décodage
  print('\n🔓 ÉTAPE 7 : Processus de décodage');
  
  // 7a. Déchiffrement de l'AAD
  final decryptedAAD = MultiLanguageManager.decryptAAD(encryptedAAD, mediaKey);
  final decodedAADJson = jsonDecode(decryptedAAD) as Map<String, dynamic>;
  final decodedSequence = (decodedAADJson['seq'] as List<dynamic>).cast<String>();
  
  print('🔓 AAD déchiffré : $decryptedAAD');
  print('🎯 Séquence récupérée : $decodedSequence');
  
  // 7b. Décodage caractère par caractère
  print('\n🔄 ÉTAPE 7b : Décodage caractère par caractère');
  print('Position | Caractère codé | Langue utilisée | Reverse map | Caractère original');
  print('---------|----------------|-----------------|-------------|-------------------');
  
  final decodedChars = <String>[];
  for (int i = 0; i < codedText.length; i++) {
    final codedChar = codedText[i];
    final langKey = decodedSequence[i];
    final langMap = languages[langKey]!;
    
    // Créer la reverse map (transformation inverse)
    final reverseMap = {for (var e in langMap.entries) e.value: e.key};
    final originalChar = reverseMap[codedChar] ?? codedChar;
    decodedChars.add(originalChar);
    
    print('    $i    |       $codedChar        |    $langKey    |  $codedChar → $originalChar  |         $originalChar');
  }
  
  final finalDecoded = decodedChars.join('');
  print('\n✅ Résultat final : "$finalDecoded"');
  
  // 8. Vérification
  print('\n🎯 ÉTAPE 8 : Vérification');
  print('Message original : "$message"');
  print('Message décodé   : "$finalDecoded"');
  print('Identique ? ${message == finalDecoded ? "✅ OUI" : "❌ NON"}');
  
  // 9. Sécurité et randomisation
  print('\n🔒 ÉTAPE 9 : Aspects sécuritaires');
  print('🎲 Randomisation : Chaque caractère utilise une langue différente choisie aléatoirement');
  print('🔀 Diversité : ${sequence.toSet().length} langues différentes utilisées sur ${sequence.length} caractères');
  print('🛡️ Résistance : Même message → séquences différentes à chaque envoi');
  
  // 10. Test avec le même message
  print('\n🔄 ÉTAPE 10 : Test de randomisation');
  final result2 = MultiLanguageManager.prepareMessageWithPerCharacterMode(
    message,
    languages,
    mediaKey,
  );
  
  final sequence2 = result2['sequence'] as List<String>;
  final codedText2 = result2['codedText'] as String;
  
  print('Premier envoi  : "$codedText" avec séquence $sequence');
  print('Deuxième envoi : "$codedText2" avec séquence $sequence2');
  print('Identique ? ${codedText == codedText2 ? "❌ NON (problème)" : "✅ OUI (différent = sécurisé)"}');
  
  // 11. Exemple avec un message plus long
  print('\n📝 ÉTAPE 11 : Exemple avec message plus long');
  const longMessage = 'bonjour comment allez-vous ?';
  
  final longResult = MultiLanguageManager.prepareMessageWithPerCharacterMode(
    longMessage,
    languages,
    mediaKey,
  );
  
  final longSequence = longResult['sequence'] as List<String>;
  final longCoded = longResult['codedText'] as String;
  
  print('Message long : "$longMessage"');
  print('Transformé   : "$longCoded"');
  print('Langues utilisées : ${longSequence.toSet().length}/10 langues différentes');
  print('Répartition : ${_getLanguageDistribution(longSequence)}');
  
  print('\n🎉 Transformation complète expliquée !');
}

// Fonction utilitaire pour analyser la répartition des langues
Map<String, int> _getLanguageDistribution(List<String> sequence) {
  final distribution = <String, int>{};
  for (final lang in sequence) {
    distribution[lang] = (distribution[lang] ?? 0) + 1;
  }
  return distribution;
}
