import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';

class MediaEncryptionService {
  /// Chiffre un fichier avec une clé AES-256
  static Future<File> encryptFile(File inputFile, String mediaKey) async {
    try {
      // Décoder la clé base64
      final keyBytes = base64Decode(mediaKey);
      final key = encrypt.Key(keyBytes);

      // Générer un IV aléatoire
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // Lire le fichier
      final fileBytes = await inputFile.readAsBytes();
      
      // Chiffrer les données
      final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);
      
      // Créer le fichier de sortie avec extension .enc
      final outputPath = '${inputFile.path}.enc';
      final outputFile = File(outputPath);
      
      // Combiner IV + données chiffrées
      final combinedData = Uint8List.fromList([
        ...iv.bytes,
        ...encrypted.bytes,
      ]);
      
      await outputFile.writeAsBytes(combinedData);
      
      debugPrint('🔐 Fichier chiffré: ${inputFile.path} → $outputPath');
      debugPrint('🔑 Clé utilisée: ${mediaKey.substring(0, 8)}...');
      debugPrint('📏 Taille originale: ${fileBytes.length} bytes');
      debugPrint('📏 Taille chiffrée: ${combinedData.length} bytes');
      
      return outputFile;
    } catch (e) {
      debugPrint('❌ Erreur chiffrement fichier: $e');
      rethrow;
    }
  }

  /// Déchiffre un fichier avec une clé AES-256
  static Future<Uint8List> decryptFile(File encryptedFile, String mediaKey) async {
    try {
      // Décoder la clé base64
      final keyBytes = base64Decode(mediaKey);
      final key = encrypt.Key(keyBytes);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // Lire le fichier chiffré
      final encryptedData = await encryptedFile.readAsBytes();

      // Extraire IV (16 premiers bytes) et données chiffrées
      final iv = encrypt.IV(encryptedData.sublist(0, 16));
      final encryptedBytes = encryptedData.sublist(16);
      
      // Déchiffrer
      final encrypted = encrypt.Encrypted(encryptedBytes);
      final decryptedBytes = encrypter.decryptBytes(encrypted, iv: iv);
      
      debugPrint('🔓 Fichier déchiffré: ${encryptedFile.path}');
      debugPrint('🔑 Clé utilisée: ${mediaKey.substring(0, 8)}...');
      debugPrint('📏 Taille chiffrée: ${encryptedData.length} bytes');
      debugPrint('📏 Taille déchiffrée: ${decryptedBytes.length} bytes');
      
      return Uint8List.fromList(decryptedBytes);
    } catch (e) {
      debugPrint('❌ Erreur déchiffrement fichier: $e');
      rethrow;
    }
  }

  /// Chiffre des données en mémoire
  static Uint8List encryptBytes(Uint8List data, String mediaKey) {
    try {
      final keyBytes = base64Decode(mediaKey);
      final key = encrypt.Key(keyBytes);
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      final encrypted = encrypter.encryptBytes(data, iv: iv);
      
      // Combiner IV + données chiffrées
      return Uint8List.fromList([
        ...iv.bytes,
        ...encrypted.bytes,
      ]);
    } catch (e) {
      debugPrint('❌ Erreur chiffrement bytes: $e');
      rethrow;
    }
  }

  /// Déchiffre des données en mémoire
  static Uint8List decryptBytes(Uint8List encryptedData, String mediaKey) {
    try {
      final keyBytes = base64Decode(mediaKey);
      final key = encrypt.Key(keyBytes);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // Extraire IV et données chiffrées
      final iv = encrypt.IV(encryptedData.sublist(0, 16));
      final encryptedBytes = encryptedData.sublist(16);
      
      final encrypted = encrypt.Encrypted(encryptedBytes);
      return Uint8List.fromList(encrypter.decryptBytes(encrypted, iv: iv));
    } catch (e) {
      debugPrint('❌ Erreur déchiffrement bytes: $e');
      rethrow;
    }
  }

  /// Génère un hash du fichier pour vérification d'intégrité
  static String generateFileHash(Uint8List data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }

  /// Vérifie l'intégrité d'un fichier déchiffré
  static bool verifyFileIntegrity(Uint8List data, String expectedHash) {
    final actualHash = generateFileHash(data);
    return actualHash == expectedHash;
  }

  /// Chiffre un fichier et retourne les métadonnées
  static Future<Map<String, dynamic>> encryptFileWithMetadata(
    File inputFile, 
    String mediaKey
  ) async {
    try {
      // Lire le fichier original
      final originalBytes = await inputFile.readAsBytes();
      final originalHash = generateFileHash(originalBytes);
      
      // Chiffrer le fichier
      final encryptedFile = await encryptFile(inputFile, mediaKey);
      
      return {
        'encryptedFile': encryptedFile,
        'originalSize': originalBytes.length,
        'encryptedSize': (await encryptedFile.readAsBytes()).length,
        'originalHash': originalHash,
        'mediaKey': '${mediaKey.substring(0, 8)}...', // Pour debug seulement
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Erreur chiffrement avec métadonnées: $e');
      rethrow;
    }
  }

  /// Déchiffre un fichier et vérifie l'intégrité
  static Future<Map<String, dynamic>> decryptFileWithVerification(
    File encryptedFile, 
    String mediaKey,
    {String? expectedHash}
  ) async {
    try {
      final decryptedBytes = await decryptFile(encryptedFile, mediaKey);
      
      bool integrityOk = true;
      if (expectedHash != null) {
        integrityOk = verifyFileIntegrity(decryptedBytes, expectedHash);
      }
      
      return {
        'data': decryptedBytes,
        'size': decryptedBytes.length,
        'integrityOk': integrityOk,
        'hash': generateFileHash(decryptedBytes),
      };
    } catch (e) {
      debugPrint('❌ Erreur déchiffrement avec vérification: $e');
      rethrow;
    }
  }

  /// Teste si une clé peut déchiffrer un fichier
  static Future<bool> testMediaKey(File encryptedFile, String mediaKey) async {
    try {
      await decryptFile(encryptedFile, mediaKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Nettoie les fichiers temporaires chiffrés
  static Future<void> cleanupEncryptedFile(File encryptedFile) async {
    try {
      if (await encryptedFile.exists()) {
        await encryptedFile.delete();
        debugPrint('🗑️ Fichier chiffré supprimé: ${encryptedFile.path}');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur suppression fichier chiffré: $e');
    }
  }
}
