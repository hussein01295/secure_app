import 'package:bip39/bip39.dart' as bip39;

/// Service dédié aux phrases de récupération BIP39.
class RecoveryPhraseService {
  static const int _defaultStrength = 128; // 12 mots.

  /// Génère une phrase de récupération BIP39 (12 mots).
  static String generateRecoveryPhrase() {
    return bip39.generateMnemonic(strength: _defaultStrength);
  }

  /// Valide la phrase fournie par l'utilisateur.
  static bool validateRecoveryPhrase(String phrase) {
    final String normalized = phrase
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    return bip39.validateMnemonic(normalized);
  }

  /// Convertit la phrase en seed (utile pour dériver des clés si nécessaire).
  static List<int> mnemonicToSeedBytes(String phrase) {
    final String normalized = phrase
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    return bip39.mnemonicToSeed(normalized);
  }
}
