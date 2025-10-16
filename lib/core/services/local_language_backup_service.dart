import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'aes_gcm_service.dart';
import 'key_collector_service.dart';
import 'key_derivation_service.dart';

class LocalLanguageBackupService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _fileName = 'silencia_languages_backup.enc';
  static const String _derivedKeyStorageKey = 'local_backup_derived_key';
  static const String _needsRegenerationKey = 'local_backup_requires_regeneration';
  static const String _autoBackupEnabledKey = 'localAutoBackupEnabled';

  static Future<File> _getBackupFile() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  static Future<File?> getBackupFileIfExists() async {
    final File file = await _getBackupFile();
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  static Future<bool> backupExists() async {
    final File file = await _getBackupFile();
    return file.exists();
  }

  static Future<bool> hasStoredDerivedKey() async {
    final String? encoded = await _storage.read(key: _derivedKeyStorageKey);
    return encoded != null && encoded.isNotEmpty;
  }

  static Future<void> clearStoredDerivedKey() async {
    await _storage.delete(key: _derivedKeyStorageKey);
    await _storage.write(key: _needsRegenerationKey, value: 'true');
  }

  static Future<void> createLocalBackup(String password) async {
    final KeyCollection collection = await KeyCollectorService.collectAllKeys();
    final KeyCollection payload = collection.copyWith(
      metadata: Map<String, dynamic>.from(collection.metadata)
        ..addAll(<String, dynamic>{
          'backupType': 'local',
          'generatedAt': DateTime.now().toUtc().toIso8601String(),
        }),
    );

    final String plaintext = jsonEncode(payload.toJson());
    final Uint8List salt = KeyDerivationService.generateSalt(length: 32);
    final Uint8List derivedKey = KeyDerivationService.deriveKey(
      secret: password,
      salt: salt,
    );

    final Map<String, String> encrypted = await AesGcmService.encryptString(
      plaintext: plaintext,
      key: derivedKey,
    );

    final Map<String, dynamic> envelope = <String, dynamic>{
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'iterations': KeyDerivationService.defaultIterations,
      'salt': base64Encode(salt),
      'ciphertext': encrypted['ciphertext'],
      'iv': encrypted['iv'],
      'tag': encrypted['tag'],
    };

    final File file = await _getBackupFile();
    await file.writeAsString(jsonEncode(envelope));
    await _storage.write(
      key: _derivedKeyStorageKey,
      value: base64Encode(derivedKey),
    );
    await _storage.write(key: _needsRegenerationKey, value: 'false');
  }

  static Future<void> updateLocalBackupWithPassword(String password) async {
    final File file = await _getBackupFile();
    if (!await file.exists()) {
      throw StateError('Aucun fichier de backup local trouvé.');
    }

    final Map<String, dynamic> envelope = await _readEnvelope(file);
    final String? saltBase64 = envelope['salt'] as String?;
    if (saltBase64 == null) {
      throw StateError('Backup local invalide : salt manquant.');
    }
    final Uint8List derivedKey = KeyDerivationService.deriveKey(
      secret: password,
      salt: base64Decode(saltBase64),
    );
    await _rewriteBackup(envelope: envelope, derivedKey: derivedKey);
    await _storage.write(
      key: _derivedKeyStorageKey,
      value: base64Encode(derivedKey),
    );
    await _storage.write(key: _needsRegenerationKey, value: 'false');
  }

  static Future<void> updateBackupFromSecureStorageIfEnabled() async {
    if (!await isAutoUpdateEnabled()) return;
    final Uint8List? key = await _loadDerivedKey();
    if (key == null) return;
    final File file = await _getBackupFile();
    if (!await file.exists()) return;
    final Map<String, dynamic> envelope = await _readEnvelope(file);
    await _rewriteBackup(envelope: envelope, derivedKey: key);
  }

  static Future<void> restoreFromFile(File sourceFile, String password) async {
    final Map<String, dynamic> envelope =
        jsonDecode(await sourceFile.readAsString()) as Map<String, dynamic>;

    final String? saltBase64 = envelope['salt'] as String?;
    if (saltBase64 == null) {
      throw StateError('Backup local invalide : salt manquant.');
    }

    final Uint8List derivedKey = KeyDerivationService.deriveKey(
      secret: password,
      salt: base64Decode(saltBase64),
    );

    final String plaintext = await _decryptEnvelope(
      envelope: envelope,
      derivedKey: derivedKey,
    );
    final Map<String, dynamic> parsed =
        jsonDecode(plaintext) as Map<String, dynamic>;
    final KeyCollection collection = KeyCollection.fromJson(parsed);
    await KeyCollectorService.saveCollectedKeys(collection);

    final File destination = await _getBackupFile();
    if (sourceFile.path != destination.path) {
      await destination.writeAsString(jsonEncode(envelope));
    }
    await _storage.write(
      key: _derivedKeyStorageKey,
      value: base64Encode(derivedKey),
    );
    await _storage.write(key: _needsRegenerationKey, value: 'false');
  }

  static Future<bool> isAutoUpdateEnabled() async {
    final String? value = await _storage.read(key: _autoBackupEnabledKey);
    if (value == null) return false;
    return value.toLowerCase() == 'true';
  }

  static Future<void> setAutoUpdateEnabled(bool enabled) async {
    await _storage.write(key: _autoBackupEnabledKey, value: enabled.toString());
    if (!enabled) {
      await clearStoredDerivedKey();
    } else {
      final bool hasKey = await hasStoredDerivedKey();
      await _storage.write(
        key: _needsRegenerationKey,
        value: hasKey ? 'false' : 'true',
      );
    }
  }

  static Future<bool> needsRegeneration() async {
    final String? value = await _storage.read(key: _needsRegenerationKey);
    if (value == null) return false;
    return value.toLowerCase() == 'true';
  }

  static Future<void> _rewriteBackup({
    required Map<String, dynamic> envelope,
    required Uint8List derivedKey,
  }) async {
    final KeyCollection collection = await KeyCollectorService.collectAllKeys();
    final KeyCollection payload = collection.copyWith(
      metadata: Map<String, dynamic>.from(collection.metadata)
        ..addAll(<String, dynamic>{
          'backupType': 'local',
          'generatedAt': DateTime.now().toUtc().toIso8601String(),
        }),
    );

    final String plaintext = jsonEncode(payload.toJson());
    final Map<String, String> encrypted = await AesGcmService.encryptString(
      plaintext: plaintext,
      key: derivedKey,
    );

    final Map<String, dynamic> updatedEnvelope = <String, dynamic>{
      'version': envelope['version'] ?? 1,
      'createdAt': envelope['createdAt'] ?? envelope['updatedAt'],
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'iterations':
          envelope['iterations'] ?? KeyDerivationService.defaultIterations,
      'salt': envelope['salt'],
      'ciphertext': encrypted['ciphertext'],
      'iv': encrypted['iv'],
      'tag': encrypted['tag'],
    };

    final File file = await _getBackupFile();
    await file.writeAsString(jsonEncode(updatedEnvelope));
    await _storage.write(key: _needsRegenerationKey, value: 'false');
  }

  static Future<Map<String, dynamic>> _readEnvelope(File file) async {
    final String content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  static Future<Uint8List?> _loadDerivedKey() async {
    final String? encoded = await _storage.read(key: _derivedKeyStorageKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  static Future<String> _decryptEnvelope({
    required Map<String, dynamic> envelope,
    required Uint8List derivedKey,
  }) {
    final Map<String, dynamic> payload = <String, dynamic>{
      'ciphertext': envelope['ciphertext'],
      'iv': envelope['iv'],
      'tag': envelope['tag'],
    };
    return AesGcmService.decryptString(payload: payload, key: derivedKey);
  }
}
