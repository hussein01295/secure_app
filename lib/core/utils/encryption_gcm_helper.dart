// lib/core/utils/encryption_gcm_helper.dart

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';

/// Helper pour chiffrement AES-256-GCM avec authentification
class EncryptionGCMHelper {
  
  /// Version du protocole GCM
  static const String GCM_VERSION = '2.3';
  
  /// Taille du nonce GCM (12 bytes = 96 bits)
  static const int NONCE_SIZE = 12;
  
  /// Taille du tag d'authentification (16 bytes = 128 bits)
  static const int TAG_SIZE = 16;
  
  /// Chiffre un texte avec AES-256-GCM
  /// 
  /// [plainText] : Texte en clair à chiffrer
  /// [mediaKey] : Clé AES-256 en base64
  /// [aadData] : Données additionnelles à authentifier (optionnel)
  /// 
  /// Retourne : base64(nonce || ciphertext || tag)
  static String encryptTextGCM(
    String plainText,
    String mediaKey, {
    String? aadData,
  }) {
    try {
      debugPrint('🔐 GCM_ENCRYPT: Début chiffrement GCM');
      debugPrint('🔐 GCM_ENCRYPT: Texte longueur: ${plainText.length}');
      debugPrint('🔐 GCM_ENCRYPT: AAD présent: ${aadData != null}');
      
      // 1. Préparer la clé
      final keyBytes = base64Decode(mediaKey);
      final key = encrypt.Key(keyBytes);
      
      // 2. Générer nonce aléatoire (12 bytes)
      final nonce = _generateSecureNonce();
      final iv = encrypt.IV(nonce);
      
      debugPrint('🔐 GCM_ENCRYPT: Nonce généré: ${base64Encode(nonce)}');
      
      // 3. Préparer l'encrypteur GCM
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
      
      // 4. Chiffrer avec AAD si fourni
      final encrypted = aadData != null
          ? encrypter.encrypt(plainText, iv: iv, associatedData: utf8.encode(aadData))
          : encrypter.encrypt(plainText, iv: iv);
      
      // 5. Construire le payload : nonce || ciphertext || tag
      final payload = Uint8List.fromList([
        ...nonce,
        ...encrypted.bytes,
      ]);
      
      final result = base64Encode(payload);
      debugPrint('✅ GCM_ENCRYPT: Chiffrement réussi, taille: ${result.length}');
      
      return result;
      
    } catch (e) {
      debugPrint('❌ GCM_ENCRYPT: Erreur chiffrement: $e');
      throw Exception('Erreur chiffrement GCM: $e');
    }
  }
  
  /// Déchiffre un texte avec AES-256-GCM
  /// 
  /// [encryptedPayload] : Payload chiffré en base64(nonce || ciphertext || tag)
  /// [mediaKey] : Clé AES-256 en base64
  /// [aadData] : Données additionnelles à vérifier (optionnel)
  /// 
  /// Retourne : Texte déchiffré
  /// Lève une exception si l'authentification échoue
  static String decryptTextGCM(
    String encryptedPayload,
    String mediaKey, {
    String? aadData,
  }) {
    try {
      debugPrint('🔓 GCM_DECRYPT: Début déchiffrement GCM');
      debugPrint('🔓 GCM_DECRYPT: Payload longueur: ${encryptedPayload.length}');
      debugPrint('🔓 GCM_DECRYPT: AAD présent: ${aadData != null}');
      
      // 1. Décoder le payload
      final payloadBytes = base64Decode(encryptedPayload);
      
      // 2. Vérifier la taille minimale
      if (payloadBytes.length < NONCE_SIZE + TAG_SIZE) {
        throw Exception('Payload GCM trop court: ${payloadBytes.length} bytes');
      }
      
      // 3. Extraire nonce, ciphertext
      final nonce = payloadBytes.sublist(0, NONCE_SIZE);
      final ciphertext = payloadBytes.sublist(NONCE_SIZE);
      
      debugPrint('🔓 GCM_DECRYPT: Nonce: ${base64Encode(nonce)}');
      debugPrint('🔓 GCM_DECRYPT: Ciphertext longueur: ${ciphertext.length}');
      
      // 4. Préparer la clé et IV
      final keyBytes = base64Decode(mediaKey);
      final key = encrypt.Key(keyBytes);
      final iv = encrypt.IV(nonce);
      
      // 5. Préparer l'encrypteur GCM
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
      
      // 6. Déchiffrer avec vérification AAD
      final encrypted = encrypt.Encrypted(ciphertext);
      final decrypted = aadData != null
          ? encrypter.decrypt(encrypted, iv: iv, associatedData: utf8.encode(aadData))
          : encrypter.decrypt(encrypted, iv: iv);
      
      debugPrint('✅ GCM_DECRYPT: Déchiffrement réussi, longueur: ${decrypted.length}');
      
      return decrypted;
      
    } catch (e) {
      debugPrint('❌ GCM_DECRYPT: Erreur déchiffrement: $e');
      
      // Distinguer les erreurs d'authentification
      if (e.toString().contains('authentication') ||
          e.toString().contains('tag') ||
          e.toString().contains('verification') ||
          e.toString().contains('InvalidCipherTextException')) {
        throw AuthenticationException('Échec authentification GCM: $e');
      }
      
      throw Exception('Erreur déchiffrement GCM: $e');
    }
  }
  
  /// Chiffre les métadonnées AAD avec GCM
  /// 
  /// [aadJson] : Métadonnées AAD en JSON
  /// [mediaKey] : Clé de chiffrement
  /// 
  /// Retourne : AAD chiffré en base64
  static String encryptAADGCM(Map<String, dynamic> aadJson, String mediaKey) {
    final aadString = jsonEncode(aadJson);
    return encryptTextGCM(aadString, mediaKey);
  }
  
  /// Déchiffre les métadonnées AAD avec GCM
  /// 
  /// [encryptedAAD] : AAD chiffré en base64
  /// [mediaKey] : Clé de déchiffrement
  /// 
  /// Retourne : Métadonnées AAD déchiffrées
  static Map<String, dynamic> decryptAADGCM(String encryptedAAD, String mediaKey) {
    final aadString = decryptTextGCM(encryptedAAD, mediaKey);
    return jsonDecode(aadString) as Map<String, dynamic>;
  }
  
  /// Détecte si un payload utilise le format GCM
  /// 
  /// [payload] : Payload à analyser
  /// 
  /// Retourne : true si format GCM détecté
  static bool isGCMFormat(String payload) {
    try {
      final payloadBytes = base64Decode(payload);
      
      // Format GCM : au moins nonce (12) + tag (16) = 28 bytes minimum
      if (payloadBytes.length < NONCE_SIZE + TAG_SIZE) {
        return false;
      }
      
      // Heuristique : les payloads GCM sont généralement plus longs
      // et ont une structure différente des payloads CBC
      return payloadBytes.length >= 28;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Génère un nonce sécurisé de 12 bytes
  static Uint8List _generateSecureNonce() {
    final random = Random.secure();
    final nonce = Uint8List(NONCE_SIZE);
    
    for (int i = 0; i < NONCE_SIZE; i++) {
      nonce[i] = random.nextInt(256);
    }
    
    return nonce;
  }
  
  /// Crée les métadonnées AAD pour GCM
  /// 
  /// [mode] : Mode de transformation (ex: "perchar-seq")
  /// [sequence] : Séquence de langues (optionnel)
  /// [messageLength] : Longueur du message original
  /// 
  /// Retourne : Métadonnées AAD structurées
  static Map<String, dynamic> createGCMAAD({
    required String mode,
    List<String>? sequence,
    int? messageLength,
    String? seed,
  }) {
    final aad = <String, dynamic>{
      'v': GCM_VERSION,
      'enc': 'gcm',
      'mode': mode,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    if (sequence != null) {
      aad['seq'] = sequence;
    }
    
    if (messageLength != null) {
      aad['msgLen'] = messageLength;
    }
    
    if (seed != null) {
      aad['seed'] = seed;
    }
    
    return aad;
  }
  
  /// Valide l'intégrité des métadonnées AAD
  /// 
  /// [aad] : Métadonnées à valider
  /// 
  /// Retourne : true si AAD valide
  static bool validateAAD(Map<String, dynamic> aad) {
    // Vérifications de base
    if (!aad.containsKey('v') || !aad.containsKey('enc') || !aad.containsKey('mode')) {
      return false;
    }
    
    // Vérifier la version
    if (aad['v'] != GCM_VERSION) {
      debugPrint('⚠️ GCM_AAD: Version non supportée: ${aad['v']}');
      return false;
    }
    
    // Vérifier l'encodage
    if (aad['enc'] != 'gcm') {
      debugPrint('⚠️ GCM_AAD: Encodage non supporté: ${aad['enc']}');
      return false;
    }
    
    return true;
  }
}

/// Exception spécifique pour les échecs d'authentification GCM
class AuthenticationException implements Exception {
  final String message;
  
  const AuthenticationException(this.message);
  
  @override
  String toString() => 'AuthenticationException: $message';
}
