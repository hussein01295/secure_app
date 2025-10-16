// Exemple d'utilisation du mode per-character
// Ce fichier démontre comment utiliser le nouveau mode "1 langue par caractère"

import 'dart:convert';
import 'package:silencia/core/utils/multi_language_manager.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';

void main() {
  print('🚀 Démonstration du mode per-character (v2.2)');
  print('═══════════════════════════════════════════════');
  
  // 1. Générer un package de langues avec 10 langues
  print('\n📦 Génération du package de langues...');
  final package = LangMapGenerator.generateLanguagePackage();
  final languages = Map<String, Map<String, String>>.from(
    (package['languages'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v))),
  );
  final mediaKey = package['mediaKey'] as String;
  
  print('✅ Package généré avec ${languages.length} langues');
  print('🔑 Clé média: ${mediaKey.substring(0, 12)}...');
  
  // 2. Exemple de message à encoder
  const originalMessage = 'salut comment ça va ?';
  print('\n📝 Message original: "$originalMessage"');
  
  // 3. Encodage en mode per-character
  print('\n🔄 Encodage en mode per-character...');
  final encoded = MultiLanguageManager.prepareMessage(
    originalMessage,
    languages,
    mediaKey,
    forcePerCharacterMode: true,
  );
  
  final codedText = encoded['codedText'] as String;
  final encryptedAAD = encoded['encryptedAAD'] as String;
  final sequence = encoded['sequence'] as List<String>?;
  
  print('✅ Encodage terminé');
  print('🔤 Texte codé: "$codedText"');
  print('🔐 AAD chiffré: ${encryptedAAD.substring(0, 30)}...');
  
  if (sequence != null) {
    print('🎯 Séquence de langues (${sequence.length} caractères):');
    for (int i = 0; i < originalMessage.length && i < 10; i++) {
      print('   [$i] "${originalMessage[i]}" → "${codedText[i]}" (${sequence[i]})');
    }
    if (originalMessage.length > 10) {
      print('   ... et ${originalMessage.length - 10} autres caractères');
    }
  }
  
  // 4. Décodage automatique
  print('\n🔍 Décodage automatique...');
  final decoded = MultiLanguageManager.decodeMessage(
    codedText,
    encryptedAAD,
    languages,
    mediaKey,
  );
  
  print('✅ Décodage terminé');
  print('📝 Message décodé: "$decoded"');
  print('🎯 Correspondance: ${decoded == originalMessage ? "✅ PARFAITE" : "❌ ERREUR"}');
  
  // 5. Détection du mode
  print('\n🔍 Détection du mode de message...');
  final modeInfo = MultiLanguageManager.detectMessageMode(encryptedAAD, mediaKey);
  print('📊 Version: ${modeInfo['version']}');
  print('📊 Mode: ${modeInfo['mode']}');
  print('📊 Per-character: ${modeInfo['isPerCharacter']}');
  
  // 6. Comparaison avec le mode legacy
  print('\n🔄 Comparaison avec le mode legacy (v2.0)...');
  final legacyEncoded = MultiLanguageManager.prepareMessageWithRandomLanguage(
    originalMessage,
    languages,
    mediaKey,
  );
  
  final legacyDecoded = MultiLanguageManager.decodeMessage(
    legacyEncoded['codedText'],
    legacyEncoded['encryptedAAD'],
    languages,
    mediaKey,
  );
  
  print('📝 Legacy - Texte codé: "${legacyEncoded['codedText']}"');
  print('📝 Legacy - Langue utilisée: ${legacyEncoded['selectedAAD']}');
  print('📝 Legacy - Décodé: "$legacyDecoded"');
  print('🎯 Legacy - Correspondance: ${legacyDecoded == originalMessage ? "✅ PARFAITE" : "❌ ERREUR"}');
  
  // 7. Test de performance
  print('\n⚡ Test de performance...');
  final stopwatch = Stopwatch()..start();
  
  // Encoder 100 messages
  for (int i = 0; i < 100; i++) {
    MultiLanguageManager.prepareMessage(
      'Message de test numéro $i avec du contenu variable',
      languages,
      mediaKey,
      forcePerCharacterMode: true,
    );
  }
  
  stopwatch.stop();
  print('✅ 100 encodages en ${stopwatch.elapsedMilliseconds}ms');
  print('📊 Moyenne: ${(stopwatch.elapsedMilliseconds / 100).toStringAsFixed(2)}ms par message');
  
  // 8. Statistiques du cache
  print('\n📊 Statistiques du cache...');
  final cacheStats = MultiLanguageManager.getCacheStats();
  print('🔧 Reverse-maps en cache: ${cacheStats['reverseMapsCount']}');
  print('💾 Estimation mémoire: ${cacheStats['memoryEstimate']} bytes');
  print('🗝️ Clés en cache: ${(cacheStats['cacheKeys'] as List).take(5).join(', ')}${(cacheStats['cacheKeys'] as List).length > 5 ? '...' : ''}');
  
  // 9. Test de robustesse
  print('\n🛡️ Tests de robustesse...');
  
  // Message vide
  final emptyResult = MultiLanguageManager.prepareMessage('', languages, mediaKey);
  final emptyDecoded = MultiLanguageManager.decodeMessage(
    emptyResult['codedText'],
    emptyResult['encryptedAAD'],
    languages,
    mediaKey,
  );
  print('📝 Message vide: "${emptyDecoded}" (${emptyDecoded.isEmpty ? "✅" : "❌"})');
  
  // Caractères spéciaux
  const specialMessage = 'éàù@#\$%^&*()';
  final specialResult = MultiLanguageManager.prepareMessage(specialMessage, languages, mediaKey);
  final specialDecoded = MultiLanguageManager.decodeMessage(
    specialResult['codedText'],
    specialResult['encryptedAAD'],
    languages,
    mediaKey,
  );
  print('📝 Caractères spéciaux: "$specialDecoded" (${specialDecoded == specialMessage ? "✅" : "❌"})');
  
  print('\n🎉 Démonstration terminée avec succès !');
  print('═══════════════════════════════════════════════');
}

/// Fonction utilitaire pour afficher un exemple de debug détaillé
void showDetailedExample() {
  print('\n🔍 Exemple détaillé du format AAD v2.2');
  print('─────────────────────────────────────────');
  
  // Simuler un AAD déchiffré
  final aadExample = {
    'v': '2.2',
    'mode': 'perchar-seq',
    'seq': ['lang_01', 'lang_05', 'lang_09', 'lang_01', 'lang_04'],
  };
  
  print('📋 Format AAD JSON:');
  print(jsonEncode(aadExample));
  
  print('\n🎯 Explication:');
  print('• v: Version du protocole (2.2 pour per-character)');
  print('• mode: "perchar-seq" indique le mode caractère par caractère');
  print('• seq: Séquence des langues utilisées, une par caractère');
  
  print('\n💡 Pour un message "salut":');
  print('• s → transformé avec lang_01');
  print('• a → transformé avec lang_05');
  print('• l → transformé avec lang_09');
  print('• u → transformé avec lang_01');
  print('• t → transformé avec lang_04');
}
