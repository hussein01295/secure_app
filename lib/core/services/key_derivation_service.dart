import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/api.dart' as pc;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart' show Pbkdf2Parameters;
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

/// Service utilitaire pour dériver des clés symétriques à partir d'un secret utilisateur.
class KeyDerivationService {
  static const int defaultIterations = 100000;
  static const int defaultKeyLength = 32;
  static const int defaultSaltLength = 16;

  static final Random _secureRandom = Random.secure();

  /// Génère un salt cryptographiquement fort.
  static Uint8List generateSalt({int length = defaultSaltLength}) {
    final Uint8List bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return bytes;
  }

  /// Dérive une clé AES-256 en utilisant PBKDF2-HMAC-SHA256.
  static Uint8List deriveKey({
    required String secret,
    required Uint8List salt,
    int iterations = defaultIterations,
    int length = defaultKeyLength,
  }) {
    if (secret.isEmpty) {
      throw ArgumentError('Le secret de dérivation ne peut pas être vide.');
    }
    final pc.KeyDerivator derivator = PBKDF2KeyDerivator(
      HMac(SHA256Digest(), 64),
    );
    derivator.init(Pbkdf2Parameters(salt, iterations, length));
    final Uint8List input = Uint8List.fromList(secret.codeUnits);
    final Uint8List key = derivator.process(input);
    if (kDebugMode) {
      debugPrint(
        'KeyDerivationService.deriveKey → iterations=$iterations length=$length bytes=${key.length}',
      );
    }
    return key;
  }
}
