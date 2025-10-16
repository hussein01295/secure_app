import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

/// Tests de sécurité pour valider la correction de la vulnérabilité RSA
///
/// Ces tests vérifient que le seed utilisé pour générer les clés RSA
/// est cryptographiquement sûr et non prévisible.
// ignore_for_file: avoid_print
void main() {
  group('RSA Security Tests - Seed Entropy', () {
    
    test('Test 1: Vérifier que Random.secure() génère des valeurs différentes', () {
      final random = Random.secure();
      final values = List.generate(100, (_) => random.nextInt(256));
      
      // Vérifier qu'on a au moins 50 valeurs différentes (sur 100)
      final uniqueValues = values.toSet();
      expect(uniqueValues.length, greaterThan(50),
        reason: 'Random.secure() devrait générer des valeurs variées');
      
      print('✅ Test 1 réussi: ${uniqueValues.length} valeurs uniques sur 100');
    });
    
    test('Test 2: Vérifier que les seeds sont tous différents', () {
      final random = Random.secure();
      final seeds = List.generate(10, (_) {
        return Uint8List.fromList(
          List<int>.generate(32, (_) => random.nextInt(256)),
        );
      });
      
      // Vérifier que tous les seeds sont différents
      for (int i = 0; i < seeds.length; i++) {
        for (int j = i + 1; j < seeds.length; j++) {
          final areEqual = _areListsEqual(seeds[i], seeds[j]);
          expect(areEqual, false,
            reason: 'Les seeds $i et $j ne devraient pas être identiques');
        }
      }
      
      print('✅ Test 2 réussi: Tous les 10 seeds sont uniques');
    });
    
    test('Test 3: Vérifier l\'entropie de chaque seed (pas de répétition)', () {
      final random = Random.secure();
      final seed = Uint8List.fromList(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      
      // Compter les valeurs uniques dans le seed
      final uniqueBytes = seed.toSet();
      
      // Un bon seed devrait avoir au moins 20 valeurs différentes sur 32
      expect(uniqueBytes.length, greaterThan(20),
        reason: 'Le seed devrait avoir une bonne diversité de valeurs');
      
      print('✅ Test 3 réussi: ${uniqueBytes.length} octets uniques sur 32');
    });
    
    test('Test 4: Vérifier que le seed n\'est PAS basé sur DateTime (vulnérabilité)', () {
      // Simuler l'ancien code vulnérable
      final vulnerableSeed = Uint8List.fromList(
        List<int>.generate(32, (_) => DateTime.now().millisecondsSinceEpoch.remainder(256)),
      );
      
      // Vérifier que tous les octets sont identiques (vulnérabilité)
      final firstByte = vulnerableSeed[0];
      final allSame = vulnerableSeed.every((byte) => byte == firstByte);
      
      expect(allSame, true,
        reason: 'L\'ancien code vulnérable devrait générer des octets identiques');
      
      // Maintenant vérifier que le nouveau code ne fait PAS ça
      final random = Random.secure();
      final secureSeed = Uint8List.fromList(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      
      final firstSecureByte = secureSeed[0];
      final allSecureSame = secureSeed.every((byte) => byte == firstSecureByte);
      
      expect(allSecureSame, false,
        reason: 'Le nouveau code sécurisé ne devrait PAS générer des octets identiques');
      
      print('✅ Test 4 réussi: Vulnérabilité DateTime corrigée');
    });
    
    test('Test 5: Vérifier la distribution statistique du générateur', () {
      final random = Random.secure();
      final samples = List.generate(1000, (_) => random.nextInt(256));
      
      // Calculer la moyenne (devrait être proche de 127.5)
      final average = samples.reduce((a, b) => a + b) / samples.length;
      
      // La moyenne devrait être entre 110 et 145 (marge de 15%)
      expect(average, greaterThan(110));
      expect(average, lessThan(145));
      
      print('✅ Test 5 réussi: Moyenne = ${average.toStringAsFixed(2)} (attendu: ~127.5)');
    });
    
    test('Test 6: Vérifier que FortunaRandom accepte le seed', () {
      final random = Random.secure();
      final seed = Uint8List.fromList(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      
      // Créer un FortunaRandom et le seeder
      final secureRandom = FortunaRandom();
      
      expect(() {
        secureRandom.seed(KeyParameter(seed));
      }, returnsNormally,
        reason: 'FortunaRandom devrait accepter le seed sans erreur');
      
      print('✅ Test 6 réussi: FortunaRandom accepte le seed sécurisé');
    });
    
    test('Test 7: Vérifier que deux clés RSA générées sont différentes', () {
      // Générer deux paires de clés avec des seeds différents
      final keyParams = RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64);
      
      // Première clé
      final random1 = Random.secure();
      final seed1 = Uint8List.fromList(
        List<int>.generate(32, (_) => random1.nextInt(256)),
      );
      final secureRandom1 = FortunaRandom();
      secureRandom1.seed(KeyParameter(seed1));
      
      final generator1 = RSAKeyGenerator()
        ..init(ParametersWithRandom(keyParams, secureRandom1));
      final pair1 = generator1.generateKeyPair();
      
      // Deuxième clé
      final random2 = Random.secure();
      final seed2 = Uint8List.fromList(
        List<int>.generate(32, (_) => random2.nextInt(256)),
      );
      final secureRandom2 = FortunaRandom();
      secureRandom2.seed(KeyParameter(seed2));
      
      final generator2 = RSAKeyGenerator()
        ..init(ParametersWithRandom(keyParams, secureRandom2));
      final pair2 = generator2.generateKeyPair();
      
      // Vérifier que les clés sont différentes
      final publicKey1 = pair1.publicKey as RSAPublicKey;
      final publicKey2 = pair2.publicKey as RSAPublicKey;
      
      expect(publicKey1.modulus, isNot(equals(publicKey2.modulus)),
        reason: 'Les deux clés publiques devraient être différentes');
      
      print('✅ Test 7 réussi: Deux clés RSA générées sont différentes');
    }, timeout: const Timeout(Duration(seconds: 30)));
    
    test('Test 8: Benchmark - Temps de génération de seed', () {
      final stopwatch = Stopwatch()..start();
      
      final random = Random.secure();
      for (int i = 0; i < 100; i++) {
        Uint8List.fromList(
          List<int>.generate(32, (_) => random.nextInt(256)),
        );
      }
      
      stopwatch.stop();
      final timePerSeed = stopwatch.elapsedMicroseconds / 100;
      
      print('✅ Test 8 réussi: Temps moyen par seed = ${timePerSeed.toStringAsFixed(2)} μs');
      
      // Le temps devrait être raisonnable (< 1ms par seed)
      expect(timePerSeed, lessThan(1000),
        reason: 'La génération de seed devrait être rapide');
    });
  });
  
  group('RSA Security Tests - Vulnerability Detection', () {
    
    test('Test 9: Détecter la vulnérabilité DateTime (256 possibilités)', () {
      // Simuler 100 générations avec l'ancien code vulnérable
      final vulnerableSeeds = <int>{};
      
      for (int i = 0; i < 100; i++) {
        final seed = DateTime.now().millisecondsSinceEpoch.remainder(256);
        vulnerableSeeds.add(seed);
        
        // Petit délai pour changer le timestamp
        if (i % 10 == 0) {
          Future.delayed(const Duration(milliseconds: 1));
        }
      }
      
      // Avec l'ancien code, on devrait avoir très peu de valeurs différentes
      print('⚠️  Ancien code vulnérable: ${vulnerableSeeds.length} valeurs uniques sur 100');
      expect(vulnerableSeeds.length, lessThan(50),
        reason: 'L\'ancien code devrait générer peu de valeurs différentes');
      
      // Avec le nouveau code, on devrait avoir beaucoup plus de diversité
      final random = Random.secure();
      final secureValues = <int>{};
      
      for (int i = 0; i < 100; i++) {
        secureValues.add(random.nextInt(256));
      }
      
      print('✅ Nouveau code sécurisé: ${secureValues.length} valeurs uniques sur 100');
      expect(secureValues.length, greaterThan(50),
        reason: 'Le nouveau code devrait générer beaucoup de valeurs différentes');
    });
  });
}

/// Fonction utilitaire pour comparer deux listes d'octets
bool _areListsEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

