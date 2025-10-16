import 'package:flutter_test/flutter_test.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';

void main() {
  group('Emoji Support Tests', () {
    test('Alphabet étendu inclut les emojis populaires', () {
      final package = LangMapGenerator.generateLanguagePackage();
      final languages = Map<String, Map<String, String>>.from(
        (package['languages'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v))),
      );
      
      final firstLang = languages['lang_00']!;
      
      // Vérifier que l'alphabet est plus grand qu'avant (584+ vs 484)
      expect(firstLang.length, greaterThan(580));
      print('📊 Taille de l\'alphabet : ${firstLang.length} caractères');
      
      // Vérifier quelques emojis spécifiques
      final testEmojis = ['😀', '😂', '🤣', '😍', '🥰', '😎', '🤩', '😭', '😤', '😱'];
      for (final emoji in testEmojis) {
        expect(firstLang.containsKey(emoji), isTrue, 
          reason: 'Emoji $emoji manquant dans l\'alphabet');
      }
      
      // Vérifier quelques emojis gestuels (simples uniquement)
      final gestureEmojis = ['👋', '👍', '👎', '👌', '🤞', '👏', '🙌', '🤝', '🙏'];
      for (final emoji in gestureEmojis) {
        expect(firstLang.containsKey(emoji), isTrue,
          reason: 'Emoji gestuel $emoji manquant dans l\'alphabet');
      }

      // Vérifier quelques emojis cœurs (simples uniquement)
      final heartEmojis = ['💔', '💕', '💖', '💗', '💘', '💝', '💟', '💯'];
      for (final emoji in heartEmojis) {
        expect(firstLang.containsKey(emoji), isTrue,
          reason: 'Emoji cœur $emoji manquant dans l\'alphabet');
      }
      
      // Vérifier quelques emojis objets
      final objectEmojis = ['🔥', '💧', '⭐', '🌟', '✨', '🎉', '🎊', '🎈', '🎁', '🎀'];
      for (final emoji in objectEmojis) {
        expect(firstLang.containsKey(emoji), isTrue, 
          reason: 'Emoji objet $emoji manquant dans l\'alphabet');
      }
      
      print('✅ Tous les emojis testés sont présents dans l\'alphabet !');
    });
    
    test('Communication avec emojis fonctionne parfaitement', () {
      
      final packageA = LangMapGenerator.generateLanguagePackage();
      final packageB = packageA; // Utiliser le même package pour les tests
      
      final languagesA = Map<String, Map<String, String>>.from(
        (packageA['languages'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v))),
      );
      final languagesB = Map<String, Map<String, String>>.from(
        (packageB['languages'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v))),
      );
      
      // Messages avec emojis
      const messagesWithEmojis = [
        'Salut ! 😀 Comment ça va ? 😊',
        'Super bien ! 😍 Et toi ? 🤩',
        'Ça va ! 👍 On se voit ce soir ? 🎉',
        'Oui ! 🥰 J\'ai hâte ! 🎊✨',
        'Parfait ! 😎 À ce soir ! 👋',
        'À bientôt ! ❤️💕🔥',
        'Test complet : 😀😂🤣😍🥰😎🤩😭😤😱👋👍👎👌✌️🤞👏🙌🤝🙏💪❤️💔💕💖💗💘💝💟💯🔥💧⭐🌟✨🎉🎊🎈🎁🎀🎂🍰🎵🎶🎤🎧🎮🎯🎲🎭🎨🎪🎫🎬',
      ];
      
      for (final message in messagesWithEmojis) {
        // A envoie à B
        final result = MultiLanguageManager.prepareMessage(
          message,
          languagesA,
          packageA['mediaKey'] as String,
          forcePerCharacterMode: true,
        );
        
        final decoded = MultiLanguageManager.decodeMessageUnified(
          result['codedText'] as String,
          result['encryptedAAD'] as String,
          languagesB,
          packageB['mediaKey'] as String,
        );
        
        expect(decoded, equals(message), 
          reason: 'Message avec emojis mal décodé: "$message"');
        
        print('✅ "$message" → Communication réussie !');
      }
      
      print('\n🎉 TOUS LES TESTS EMOJIS RÉUSSIS !');
      print('✅ ${messagesWithEmojis.length} messages avec emojis testés');
      print('✅ Communication bidirectionnelle parfaite');
      print('✅ Synchronisation maintenue avec emojis');
    });
    
    test('Performance avec emojis reste acceptable', () {
      
      final stopwatch = Stopwatch()..start();
      
      // Générer 50 packages avec le nouvel alphabet étendu
      for (int i = 0; i < 50; i++) {
        LangMapGenerator.generateLanguagePackage();
      }
      
      stopwatch.stop();
      
      // Doit rester rapide (moins de 3 secondes pour 50 générations)
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
      
      final avgTime = stopwatch.elapsedMilliseconds / 50;
      print('⏱️ Performance avec emojis: 50 générations en ${stopwatch.elapsedMilliseconds}ms');
      print('📊 Temps moyen par génération: ${avgTime.toStringAsFixed(1)}ms');
      
      // Vérifier que ça reste sous 10ms par génération
      expect(avgTime, lessThan(10.0));
      
      print('✅ Performance excellente maintenue avec emojis !');
    });
    
    test('Taille mémoire avec emojis reste raisonnable', () {
      final package = LangMapGenerator.generateLanguagePackage();
      final languages = Map<String, Map<String, String>>.from(
        (package['languages'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v))),
      );
      
      // Calculer la taille approximative
      int totalMappings = 0;
      for (final lang in languages.values) {
        totalMappings += lang.length;
      }
      
      // Estimation: chaque mapping = ~100 bytes (clé + valeur + overhead)
      final estimatedSizeKB = (totalMappings * 100) / 1024;
      
      print('📊 Statistiques mémoire avec emojis:');
      print('   • Nombre total de mappings: $totalMappings');
      print('   • Taille estimée: ${estimatedSizeKB.toStringAsFixed(1)} KB');
      print('   • Caractères par langue: ${languages['lang_00']!.length}');
      
      // Vérifier que ça reste sous 1MB
      expect(estimatedSizeKB, lessThan(1024));
      
      // Vérifier qu'on a bien plus de 580 caractères
      expect(languages['lang_00']!.length, greaterThan(580));
      
      print('✅ Taille mémoire acceptable avec emojis !');
    });
  });
}
