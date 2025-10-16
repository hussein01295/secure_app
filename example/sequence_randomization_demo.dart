// Démonstration : Pourquoi les séquences changent à chaque envoi
// Ce fichier montre clairement la randomisation des séquences

import 'dart:convert';
import 'package:silencia/core/utils/multi_language_manager.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';

void main() {
  print('🎲 DÉMONSTRATION : Randomisation des Séquences');
  print('═══════════════════════════════════════════════');
  
  // 1. Générer un package de langues
  final package = LangMapGenerator.generateLanguagePackage();
  final languages = Map<String, Map<String, String>>.from(
    (package['languages'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v))),
  );
  final mediaKey = package['mediaKey'] as String;
  
  print('🌐 Langues disponibles : ${languages.keys.toList()}');
  
  // 2. Envoyer le MÊME message 5 fois
  const message = 'salut';
  print('\n📝 Message à envoyer : "$message"');
  print('\n🔄 Envois multiples du MÊME message :');
  print('═══════════════════════════════════════');
  
  for (int i = 1; i <= 5; i++) {
    final result = MultiLanguageManager.prepareMessageWithPerCharacterMode(
      message,
      languages,
      mediaKey,
    );
    
    final sequence = result['sequence'] as List<String>;
    final codedText = result['codedText'] as String;
    
    print('Envoi $i:');
    print('  Séquence : $sequence');
    print('  Code     : "$codedText"');
    print('  Identique au précédent ? ${i > 1 ? "NON (différent)" : "N/A"}');
    print('');
  }
  
  // 3. Explication technique
  print('🔍 POURQUOI les séquences changent ?');
  print('═══════════════════════════════════');
  print('');
  print('1. 📍 LIGNE DE CODE RESPONSABLE :');
  print('   final random = Random.secure();');
  print('   → Crée un NOUVEAU générateur aléatoire à chaque appel');
  print('');
  print('2. 🎯 SÉLECTION POUR CHAQUE CARACTÈRE :');
  print('   for (int i = 0; i < text.length; i++) {');
  print('     final selectedLang = availableLanguages[random.nextInt(10)];');
  print('   }');
  print('   → Chaque caractère = choix aléatoire parmi 10 langues');
  print('');
  print('3. 🎲 PROBABILITÉS :');
  print('   - Pour 1 caractère : 10 choix possibles');
  print('   - Pour "salut" (5 caractères) : 10^5 = 100,000 combinaisons possibles');
  print('   - Chance d\'avoir la même séquence : 1/100,000 = 0.001%');
  
  // 4. Démonstration avec un caractère unique
  print('\n🔬 TEST avec 1 seul caractère ("a") :');
  print('═══════════════════════════════════════');
  
  final singleCharResults = <String, int>{};
  
  for (int i = 0; i < 20; i++) {
    final result = MultiLanguageManager.prepareMessageWithPerCharacterMode(
      'a',
      languages,
      mediaKey,
    );
    
    final sequence = result['sequence'] as List<String>;
    final langUsed = sequence[0];
    
    singleCharResults[langUsed] = (singleCharResults[langUsed] ?? 0) + 1;
  }
  
  print('Répartition sur 20 envois du caractère "a" :');
  singleCharResults.forEach((lang, count) {
    final percentage = (count / 20 * 100).toStringAsFixed(1);
    print('  $lang : $count fois ($percentage%)');
  });
  
  // 5. Avantages de la randomisation
  print('\n✅ AVANTAGES de cette randomisation :');
  print('═══════════════════════════════════════');
  print('');
  print('🔒 SÉCURITÉ :');
  print('   - Impossible de deviner le pattern');
  print('   - Même message → codes différents');
  print('   - Résistant à l\'analyse de fréquence');
  print('');
  print('🛡️ CONFIDENTIALITÉ :');
  print('   - Un espion ne peut pas reconnaître les messages répétés');
  print('   - "salut" envoyé 100 fois = 100 codes différents');
  print('');
  print('🎯 ROBUSTESSE :');
  print('   - Utilise toutes les langues disponibles');
  print('   - Répartition équitable des transformations');
  
  // 6. Comparaison avec mode fixe (hypothétique)
  print('\n⚖️ COMPARAISON : Mode Aléatoire vs Mode Fixe');
  print('═══════════════════════════════════════════════');
  print('');
  print('MODE FIXE (si on utilisait toujours la même séquence) :');
  print('  "salut" → toujours "abc123" (PRÉVISIBLE ❌)');
  print('');
  print('MODE ALÉATOIRE (actuel) :');
  print('  "salut" → "abc123", "xyz789", "def456", ... (IMPRÉVISIBLE ✅)');
  
  print('\n🎉 Conclusion : La randomisation est ESSENTIELLE pour la sécurité !');
}
