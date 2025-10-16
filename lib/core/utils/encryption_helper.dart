import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionHelper {
  /// Chiffre un texte avec la clé média (AES-256)
  static String encryptText(String plainText, String mediaKey) {
    // Décoder la clé Base64
    final keyBytes = base64Decode(mediaKey);
    if (keyBytes.length != 32) {
      throw Exception("La clé média doit faire 32 octets (AES-256)");
    }
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    final iv = encrypt.IV.fromSecureRandom(16);

    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    return '${base64Encode(iv.bytes)}:${encrypted.base64}';
  }

  /// Déchiffre un texte avec la clé média (AES-256)
  static String decryptText(String encryptedTextWithIv, String mediaKey) {
    final parts = encryptedTextWithIv.split(':');
    if (parts.length != 2) throw Exception("Format chiffré invalide");

    final iv = encrypt.IV(base64Decode(parts[0]));
    final encryptedBase64 = parts[1];

    final keyBytes = base64Decode(mediaKey);
    if (keyBytes.length != 32) {
      throw Exception("La clé média doit faire 32 octets (AES-256)");
    }
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    return encrypter.decrypt64(encryptedBase64, iv: iv);
  }
}
