import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as encrypt;
// ⬇️ Imports corrects
import 'package:pointycastle/export.dart';
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/services/auto_backup_service.dart'; // ← regroupe tous les bons types (RSA, Fortuna, etc.)

class RSAKeyService {
 
  static final storage = FlutterSecureStorage();

  /// Génère une paire de clés et les stocke localement, envoie la clé publique au backend
  static Future<void> generateAndStoreKeyPair(String accessToken) async {
    // 1. Générer une paire de clés RSA
    final keyParams = RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64);
    final secureRandom = FortunaRandom();

    // ✅ CORRECTION CRITIQUE : Utiliser Random.secure() pour une vraie entropie cryptographique
    // Chaque octet du seed doit être indépendant et vraiment aléatoire
    final random = Random.secure();
    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    secureRandom.seed(KeyParameter(seed));

    final generator = RSAKeyGenerator()
      ..init(ParametersWithRandom(keyParams, secureRandom));

    final pair = generator.generateKeyPair();

    final privateKey = pair.privateKey as RSAPrivateKey;
    final publicKey = pair.publicKey as RSAPublicKey;

    // 2. Convertir les clés en PEM
    final publicPem = CryptoUtils.encodeRSAPublicKeyToPem(publicKey);
    final privatePem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);

    // 3. Stocker localement (clé privée sécurisée)
    await storage.write(key: 'rsa_private_key', value: privatePem);
    await storage.write(key: 'rsa_public_key', value: publicPem);

    // 4. Envoyer la clé publique au backend
    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/users/public-key"),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'publicKey': publicPem}),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de l’envoi de la clé publique');
    }
    await AutoBackupService.scheduleFullSync(origin: 'rsaRotation');
  }

    // Chiffre un texte avec la clé publique PEM
  static String encryptWithPublicKey(String text, String publicKeyPem) {
    final RSAPublicKey publicKey = CryptoUtils.rsaPublicKeyFromPem(publicKeyPem);
    return CryptoUtils.rsaEncrypt(text, publicKey);
  }

  // Déchiffre avec la clé privée PEM
  static String decryptWithPrivateKey(String encrypted, String privateKeyPem) {
    final RSAPrivateKey privateKey = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);
    return CryptoUtils.rsaDecrypt(encrypted, privateKey);
  }


  // Ajoute une méthode pour récupérer la clé publique d'un user (API)
  static Future<String?> fetchPublicKey(String userId, String accessToken) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/users/$userId/public-key'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['publicKey'];
    }
    return null;
  }

  static Map<String, String> hybridEncrypt(String plaintext, String publicKeyPem) {
    // 1. Génère une clé AES 256 bits random avec Random.secure()
    final rnd = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    final aesKey = encrypt.Key(Uint8List.fromList(keyBytes));
    final iv = encrypt.IV.fromSecureRandom(16);

    // 2. Chiffre le JSON avec AES
    final encrypter = encrypt.Encrypter(encrypt.AES(aesKey));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    // 3. Chiffre la clé AES avec RSA
    final RSAPublicKey publicKey = CryptoUtils.rsaPublicKeyFromPem(publicKeyPem);
    final encryptedKey = CryptoUtils.rsaEncrypt(base64Encode(keyBytes), publicKey);

    return {
      "encrypted": encrypted.base64,
      "iv": base64Encode(iv.bytes),
      "encryptedKey": encryptedKey
    };
  }

  // Déchiffre un texte hybride (clé privée locale)
  static String hybridDecrypt(Map<String, dynamic> payload, String privateKeyPem) {
    // 1. Déchiffre la clé AES avec la clé privée RSA
    final encryptedKey = payload["encryptedKey"];
    final ivBase64 = payload["iv"];
    final encryptedBase64 = payload["encrypted"];

    final RSAPrivateKey privateKey = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);
    final aesKeyBase64 = CryptoUtils.rsaDecrypt(encryptedKey, privateKey);

    final keyBytes = base64Decode(aesKeyBase64);
    final aesKey = encrypt.Key(Uint8List.fromList(keyBytes));
    final iv = encrypt.IV(base64Decode(ivBase64));

    final encrypter = encrypt.Encrypter(encrypt.AES(aesKey));
    final decrypted = encrypter.decrypt64(encryptedBase64, iv: iv);

    return decrypted;
  }

}
