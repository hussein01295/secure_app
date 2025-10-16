import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/service/auth_service.dart';

import 'aes_gcm_service.dart';
import 'key_collector_service.dart';
import 'key_derivation_service.dart';

class BackupNotFoundException implements Exception {
  BackupNotFoundException([this.message = 'Aucune sauvegarde disponible.']);
  final String message;

  @override
  String toString() => 'BackupNotFoundException: $message';
}

class InvalidBackupSecretException implements Exception {
  InvalidBackupSecretException([
    this.message = 'Secret de restauration invalide.',
  ]);
  final String message;

  @override
  String toString() => 'InvalidBackupSecretException: $message';
}

class KeyBackupService {
  static const String backupModePassword = 'password';
  static const String backupModePhrase = 'phrase';
  static const String backupModeBoth = 'both';

  static const int _backupVersion = 1;

  static const String _passwordDerivedKeyStorageKey =
      'backup_master_key_password';
  static const String _phraseDerivedKeyStorageKey = 'backup_master_key_phrase';
  static const String _passwordSaltStorageKey = 'backup_salt_password';
  static const String _phraseSaltStorageKey = 'backup_salt_phrase';
  static const String _modeStorageKey = 'backup_mode';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<void> createBackup({
    required String token,
    required String mode,
    String? masterPassword,
    String? recoveryPhrase,
  }) async {
    _assertValidMode(mode);
    if (_requiresPassword(mode) &&
        (masterPassword == null || masterPassword.isEmpty)) {
      throw ArgumentError('masterPassword requis pour le mode $mode');
    }
    if (_requiresPhrase(mode) &&
        (recoveryPhrase == null || recoveryPhrase.isEmpty)) {
      throw ArgumentError('recoveryPhrase requis pour le mode $mode');
    }

    final KeyCollection collection = await KeyCollectorService.collectAllKeys();
    if (collection.languagePackages.isEmpty &&
        collection.mediaKeys.isEmpty &&
        collection.rsaPrivateKey == null) {
      throw StateError('Aucune donnée à sauvegarder.');
    }

    final Map<String, dynamic> data = <String, dynamic>{};

    if (_requiresPassword(mode)) {
      final _EncryptedBundle bundle = await _buildEncryptedBundle(
        secret: masterPassword!,
        collection: collection,
      );
      data['passwordPayload'] = bundle.payload;
      await _secureStorage.write(
        key: _passwordDerivedKeyStorageKey,
        value: base64Encode(bundle.key),
      );
      await _secureStorage.write(
        key: _passwordSaltStorageKey,
        value: base64Encode(bundle.salt),
      );
    } else {
      await _secureStorage.delete(key: _passwordDerivedKeyStorageKey);
      await _secureStorage.delete(key: _passwordSaltStorageKey);
    }

    if (_requiresPhrase(mode)) {
      final _EncryptedBundle bundle = await _buildEncryptedBundle(
        secret: recoveryPhrase!,
        collection: collection,
      );
      data['phrasePayload'] = bundle.payload;
      await _secureStorage.write(
        key: _phraseDerivedKeyStorageKey,
        value: base64Encode(bundle.key),
      );
      await _secureStorage.write(
        key: _phraseSaltStorageKey,
        value: base64Encode(bundle.salt),
      );
    } else {
      await _secureStorage.delete(key: _phraseDerivedKeyStorageKey);
      await _secureStorage.delete(key: _phraseSaltStorageKey);
    }

    await _secureStorage.write(key: _modeStorageKey, value: mode);

    final String? userId = await AuthService.getUserId();
    if (userId == null) {
      throw StateError('User not authenticated.');
    }

    await _pushBackupPayload(
      mode: mode,
      data: data,
      token: token,
      userId: userId,
    );
  }

  static Future<void> syncCurrentBackup({
    required String token,
    String? reason,
  }) async {
    final String? currentMode = await _secureStorage.read(key: _modeStorageKey);
    if (currentMode == null) {
      throw StateError('No active backup to synchronise.');
    }

    final KeyCollection rawCollection =
        await KeyCollectorService.collectAllKeys();
    final Map<String, dynamic> metadata =
        Map<String, dynamic>.from(rawCollection.metadata)
          ..['syncedAt'] = DateTime.now().toUtc().toIso8601String();
    if (reason != null) {
      metadata['syncReason'] = reason;
    }
    final KeyCollection collection = rawCollection.copyWith(
      metadata: metadata,
    );

    final Map<String, dynamic> data = <String, dynamic>{};

    if (_supportsPassword(currentMode)) {
      final _StoredDerivedKey? stored =
          await _loadStoredDerivedKey(forPassword: true);
      if (stored == null) {
        throw StateError('Password-based backup cannot be updated (missing key).');
      }
      final _EncryptedBundle bundle =
          await _buildEncryptedBundleWithExistingKey(
        derivedKey: stored.key,
        salt: stored.salt,
        collection: collection,
      );
      data['passwordPayload'] = bundle.payload;
    }

    if (_supportsPhrase(currentMode)) {
      final _StoredDerivedKey? stored =
          await _loadStoredDerivedKey(forPassword: false);
      if (stored == null) {
        throw StateError('Phrase-based backup cannot be updated (missing key).');
      }
      final _EncryptedBundle bundle =
          await _buildEncryptedBundleWithExistingKey(
        derivedKey: stored.key,
        salt: stored.salt,
        collection: collection,
      );
      data['phrasePayload'] = bundle.payload;
    }

    if (data.isEmpty) {
      throw StateError('No derived keys available for backup sync.');
    }

    final String? userId = await AuthService.getUserId();
    if (userId == null) {
      throw StateError('Utilisateur non authentifi\u00e9.');
    }

    await _pushBackupPayload(
      mode: currentMode,
      data: data,
      token: token,
      userId: userId,
      reason: reason,
    );
  }

  static Future<void> restoreFromMasterPassword({
    required String token,
    required String masterPassword,
  }) async {
    final Map<String, dynamic> backup = await _fetchBackup(token);
    final Map<String, dynamic>? payload =
        backup['data']?['passwordPayload'] as Map<String, dynamic>?;
    if (payload == null) {
      throw BackupNotFoundException(
        'Aucune sauvegarde protégée par mot de passe.',
      );
    }
    final _DecryptedBundle bundle = await _decryptPayload(
      payload: payload,
      secret: masterPassword,
    );
    await KeyCollectorService.saveCollectedKeys(bundle.collection);
    await _secureStorage.write(
      key: _modeStorageKey,
      value: backup['mode'] as String? ?? backupModePassword,
    );
    await _secureStorage.write(
      key: _passwordDerivedKeyStorageKey,
      value: base64Encode(bundle.derivedKey),
    );
    await _secureStorage.write(
      key: _passwordSaltStorageKey,
      value: base64Encode(bundle.salt),
    );
    await _markRestored(token);
  }

  static Future<void> restoreFromRecoveryPhrase({
    required String token,
    required String recoveryPhrase,
  }) async {
    final Map<String, dynamic> backup = await _fetchBackup(token);
    final Map<String, dynamic>? payload =
        backup['data']?['phrasePayload'] as Map<String, dynamic>?;
    if (payload == null) {
      throw BackupNotFoundException('Aucune sauvegarde protégée par phrase.');
    }
    final _DecryptedBundle bundle = await _decryptPayload(
      payload: payload,
      secret: recoveryPhrase,
    );
    await KeyCollectorService.saveCollectedKeys(bundle.collection);
    await _secureStorage.write(
      key: _modeStorageKey,
      value: backup['mode'] as String? ?? backupModePhrase,
    );
    await _secureStorage.write(
      key: _phraseDerivedKeyStorageKey,
      value: base64Encode(bundle.derivedKey),
    );
    await _secureStorage.write(
      key: _phraseSaltStorageKey,
      value: base64Encode(bundle.salt),
    );
    await _markRestored(token);
  }

  static Future<bool> hasBackup(String token) async {
    final String? userId = await AuthService.getUserId();
    if (userId == null) return false;
    final Uri url = Uri.parse(
      '${ApiConfig.baseUrl}/backup/status?userId=$userId',
    );
    final http.Response response = await http.get(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      return false;
    }
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    return json['hasBackup'] == true;
  }

  static Future<void> deleteBackup(String token) async {
    final String? userId = await AuthService.getUserId();
    if (userId == null) {
      throw StateError('User not authenticated.');
    }

    final Uri url = Uri.parse(
      '${ApiConfig.baseUrl}/backup/keys?userId=$userId',
    );
    final http.Response response = await http.delete(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Échec de la suppression (${response.statusCode}): ${response.body}',
      );
    }
    await _secureStorage.delete(key: _modeStorageKey);
    await _secureStorage.delete(key: _passwordDerivedKeyStorageKey);
    await _secureStorage.delete(key: _phraseDerivedKeyStorageKey);
    await _secureStorage.delete(key: _passwordSaltStorageKey);
    await _secureStorage.delete(key: _phraseSaltStorageKey);
  }

  static Future<void> addLanguageKeyToBackup({
    required String relationId,
    required String userId,
    required String key,
    required String token,
  }) async {
    final String? currentMode = await _secureStorage.read(key: _modeStorageKey);
    if (currentMode == null) {
      throw StateError('Aucun backup actif pour l’auto-sauvegarde.');
    }

    final Map<String, dynamic> payloads = <String, dynamic>{};

    if (_supportsPassword(currentMode)) {
      final String? derivedKeyBase64 = await _secureStorage.read(
        key: _passwordDerivedKeyStorageKey,
      );
      if (derivedKeyBase64 != null && derivedKeyBase64.isNotEmpty) {
        final Uint8List derivedKey = base64Decode(derivedKeyBase64);
        payloads['password'] = await AesGcmService.encryptString(
          plaintext: key,
          key: derivedKey,
        );
      }
    }

    if (_supportsPhrase(currentMode)) {
      final String? derivedKeyBase64 = await _secureStorage.read(
        key: _phraseDerivedKeyStorageKey,
      );
      if (derivedKeyBase64 != null && derivedKeyBase64.isNotEmpty) {
        final Uint8List derivedKey = base64Decode(derivedKeyBase64);
        payloads['phrase'] = await AesGcmService.encryptString(
          plaintext: key,
          key: derivedKey,
        );
      }
    }

    if (payloads.isEmpty) {
      throw StateError(
        'Aucune clé dérivée disponible pour chiffrer la langue.',
      );
    }

    final String? ownerId = await AuthService.getUserId();
    if (ownerId == null) {
      throw StateError('User not authenticated.');
    }

    final Uri url = Uri.parse('${ApiConfig.baseUrl}/backup/keys/add');
    final http.Response response = await http.put(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{
        'userId': ownerId,
        'relationId': relationId,
        'userTargetId': userId,
        'payloads': payloads,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Échec de l’ajout de langue (${response.statusCode}): ${response.body}',
      );
    }
  }

  static Future<_EncryptedBundle> _buildEncryptedBundle({
    required String secret,
    required KeyCollection collection,
  }) async {
    final Uint8List salt = KeyDerivationService.generateSalt();
    final Uint8List derivedKey = KeyDerivationService.deriveKey(
      secret: secret,
      salt: salt,
    );

    final Map<String, dynamic> languagePackages = <String, dynamic>{};
    for (final MapEntry<String, String> entry
        in collection.languagePackages.entries) {
      languagePackages[entry.key] = await AesGcmService.encryptString(
        plaintext: entry.value,
        key: derivedKey,
      );
    }

    final Map<String, dynamic> mediaKeys = <String, dynamic>{};
    for (final MapEntry<String, String> entry in collection.mediaKeys.entries) {
      mediaKeys[entry.key] = await AesGcmService.encryptString(
        plaintext: entry.value,
        key: derivedKey,
      );
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'salt': base64Encode(salt),
      'iterations': KeyDerivationService.defaultIterations,
      'languagePackages': languagePackages,
      'mediaKeys': mediaKeys,
      'metadata': collection.metadata,
      'version': _backupVersion,
    };

    if (collection.rsaPrivateKey != null &&
        collection.rsaPrivateKey!.isNotEmpty) {
      payload['rsaPrivateKey'] = await AesGcmService.encryptString(
        plaintext: collection.rsaPrivateKey!,
        key: derivedKey,
      );
    }

    if (collection.rsaPublicKey != null &&
        collection.rsaPublicKey!.isNotEmpty) {
      payload['rsaPublicKey'] = await AesGcmService.encryptString(
        plaintext: collection.rsaPublicKey!,
        key: derivedKey,
      );
    }

    return _EncryptedBundle(payload: payload, key: derivedKey, salt: salt);
  }

  static Future<_EncryptedBundle> _buildEncryptedBundleWithExistingKey({
    required Uint8List derivedKey,
    required Uint8List salt,
    required KeyCollection collection,
  }) async {
    final Map<String, dynamic> languagePackages = <String, dynamic>{};
    for (final MapEntry<String, String> entry
        in collection.languagePackages.entries) {
      languagePackages[entry.key] = await AesGcmService.encryptString(
        plaintext: entry.value,
        key: derivedKey,
      );
    }

    final Map<String, dynamic> mediaKeys = <String, dynamic>{};
    for (final MapEntry<String, String> entry in collection.mediaKeys.entries) {
      mediaKeys[entry.key] = await AesGcmService.encryptString(
        plaintext: entry.value,
        key: derivedKey,
      );
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'salt': base64Encode(salt),
      'iterations': KeyDerivationService.defaultIterations,
      'languagePackages': languagePackages,
      'mediaKeys': mediaKeys,
      'metadata': collection.metadata,
      'version': _backupVersion,
    };

    if (collection.rsaPrivateKey != null &&
        collection.rsaPrivateKey!.isNotEmpty) {
      payload['rsaPrivateKey'] = await AesGcmService.encryptString(
        plaintext: collection.rsaPrivateKey!,
        key: derivedKey,
      );
    }

    if (collection.rsaPublicKey != null &&
        collection.rsaPublicKey!.isNotEmpty) {
      payload['rsaPublicKey'] = await AesGcmService.encryptString(
        plaintext: collection.rsaPublicKey!,
        key: derivedKey,
      );
    }

    return _EncryptedBundle(payload: payload, key: derivedKey, salt: salt);
  }

  static Future<_StoredDerivedKey?> _loadStoredDerivedKey({
    required bool forPassword,
  }) async {
    final String keyStorage =
        forPassword ? _passwordDerivedKeyStorageKey : _phraseDerivedKeyStorageKey;
    final String saltStorage =
        forPassword ? _passwordSaltStorageKey : _phraseSaltStorageKey;

    final String? encodedKey = await _secureStorage.read(key: keyStorage);
    final String? encodedSalt = await _secureStorage.read(key: saltStorage);

    if (encodedKey == null ||
        encodedKey.isEmpty ||
        encodedSalt == null ||
        encodedSalt.isEmpty) {
      return null;
    }

    try {
      return _StoredDerivedKey(
        key: base64Decode(encodedKey),
        salt: base64Decode(encodedSalt),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> _fetchBackup(String token) async {
    final String? userId = await AuthService.getUserId();
    if (userId == null) {
      throw StateError('User not authenticated.');
    }
    final Uri url = Uri.parse(
      '${ApiConfig.baseUrl}/backup/keys?userId=$userId',
    );
    final http.Response response = await http.get(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 404) {
      throw BackupNotFoundException();
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Échec de la récupération (${response.statusCode}): ${response.body}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> _markRestored(String token) async {
    final String? userId = await AuthService.getUserId();
    if (userId == null) return;
    final Uri url = Uri.parse('${ApiConfig.baseUrl}/backup/restored');
    await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{'userId': userId}),
    );
  }

  static Future<_DecryptedBundle> _decryptPayload({
    required Map<String, dynamic> payload,
    required String secret,
  }) async {
    final String? saltBase64 = payload['salt'] as String?;
    final int iterations =
        (payload['iterations'] as int?) ??
        KeyDerivationService.defaultIterations;
    if (saltBase64 == null) {
      throw StateError('Salt manquant dans la sauvegarde.');
    }
    final Uint8List saltBytes = base64Decode(saltBase64);
    final Uint8List derivedKey = KeyDerivationService.deriveKey(
      secret: secret,
      salt: saltBytes,
      iterations: iterations,
    );

    try {
      final Map<String, dynamic> languagePayload = Map<String, dynamic>.from(
        payload['languagePackages'] as Map? ?? <String, dynamic>{},
      );
      final Map<String, String> languagePackages = <String, String>{};
      for (final MapEntry<String, dynamic> entry in languagePayload.entries) {
        final Map<String, dynamic> encrypted = Map<String, dynamic>.from(
          entry.value as Map,
        );
        languagePackages[entry.key] = await AesGcmService.decryptString(
          payload: encrypted,
          key: derivedKey,
        );
      }

      final Map<String, dynamic> mediaPayload = Map<String, dynamic>.from(
        payload['mediaKeys'] as Map? ?? <String, dynamic>{},
      );
      final Map<String, String> mediaKeys = <String, String>{};
      for (final MapEntry<String, dynamic> entry in mediaPayload.entries) {
        final Map<String, dynamic> encrypted = Map<String, dynamic>.from(
          entry.value as Map,
        );
        mediaKeys[entry.key] = await AesGcmService.decryptString(
          payload: encrypted,
          key: derivedKey,
        );
      }

      String? rsaPrivateKey;
      if (payload['rsaPrivateKey'] != null) {
        rsaPrivateKey = await AesGcmService.decryptString(
          payload: Map<String, dynamic>.from(payload['rsaPrivateKey'] as Map),
          key: derivedKey,
        );
      }

      String? rsaPublicKey;
      if (payload['rsaPublicKey'] != null) {
        rsaPublicKey = await AesGcmService.decryptString(
          payload: Map<String, dynamic>.from(payload['rsaPublicKey'] as Map),
          key: derivedKey,
        );
      }

      final Map<String, dynamic> metadata = Map<String, dynamic>.from(
        payload['metadata'] as Map? ?? <String, dynamic>{},
      );
      metadata['restoredAt'] = DateTime.now().toUtc().toIso8601String();

      final KeyCollection collection = KeyCollection(
        languagePackages: languagePackages,
        mediaKeys: mediaKeys,
        rsaPrivateKey: rsaPrivateKey,
        rsaPublicKey: rsaPublicKey,
        metadata: metadata,
      );

      return _DecryptedBundle(
        collection: collection,
        derivedKey: derivedKey,
        salt: saltBytes,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('KeyBackupService._decryptPayload error: $e');
      }
      throw InvalidBackupSecretException();
    }
  }

  static bool _requiresPassword(String mode) =>
      mode == backupModePassword || mode == backupModeBoth;

  static bool _requiresPhrase(String mode) =>
      mode == backupModePhrase || mode == backupModeBoth;

  static bool _supportsPassword(String mode) =>
      mode == backupModePassword || mode == backupModeBoth;

  static bool _supportsPhrase(String mode) =>
      mode == backupModePhrase || mode == backupModeBoth;

  static void _assertValidMode(String mode) {
    if (mode != backupModePassword &&
        mode != backupModePhrase &&
        mode != backupModeBoth) {
      throw ArgumentError('Mode de sauvegarde invalide: $mode');
    }
  }

  static Future<void> _pushBackupPayload({
    required String mode,
    required Map<String, dynamic> data,
    required String token,
    required String userId,
    String? reason,
  }) async {
    final Uri url = Uri.parse('${ApiConfig.baseUrl}/backup/keys');
    final http.Response response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{
        'userId': userId,
        'mode': mode,
        'version': _backupVersion,
        'data': data,
        if (reason != null) 'reason': reason,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Backup request failed (${response.statusCode}): ${response.body}',
      );
    }
  }
}

class _StoredDerivedKey {
  const _StoredDerivedKey({
    required this.key,
    required this.salt,
  });

  final Uint8List key;
  final Uint8List salt;
}

class _EncryptedBundle {
  const _EncryptedBundle({
    required this.payload,
    required this.key,
    required this.salt,
  });

  final Map<String, dynamic> payload;
  final Uint8List key;
  final Uint8List salt;
}

class _DecryptedBundle {
  const _DecryptedBundle({
    required this.collection,
    required this.derivedKey,
    required this.salt,
  });

  final KeyCollection collection;
  final Uint8List derivedKey;
  final Uint8List salt;
}
