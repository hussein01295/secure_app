import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Wrapper autour d'AES-256-GCM pour chiffrer / déchiffrer des charges utiles textuelles.
class AesGcmService {
  static final AesGcm _cipher = AesGcm.with256bits();

  static Future<Map<String, String>> encryptString({
    required String plaintext,
    required Uint8List key,
  }) async {
    final SecretKey secretKey = SecretKey(key);
    final List<int> nonce = _cipher.newNonce();

    final SecretBox box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    if (kDebugMode) {
      debugPrint('AesGcmService.encryptString → size=${plaintext.length}');
    }

    return <String, String>{
      'ciphertext': base64Encode(box.cipherText),
      'iv': base64Encode(box.nonce),
      'tag': base64Encode(box.mac.bytes),
    };
  }

  static Future<String> decryptString({
    required Map<String, dynamic> payload,
    required Uint8List key,
  }) async {
    final String? ciphertext = payload['ciphertext'] as String?;
    final String? iv = payload['iv'] as String?;
    final String? tag = payload['tag'] as String?;

    if (ciphertext == null || iv == null || tag == null) {
      throw ArgumentError('Payload AES-GCM invalide (champs manquants).');
    }

    final SecretBox box = SecretBox(
      base64Decode(ciphertext),
      nonce: base64Decode(iv),
      mac: Mac(base64Decode(tag)),
    );

    final List<int> clearBytes = await _cipher.decrypt(
      box,
      secretKey: SecretKey(key),
    );
    return utf8.decode(clearBytes);
  }
}
