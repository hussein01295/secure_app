import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Data holder describing the cryptographic material collected from local secure storage.
class KeyCollection {
  KeyCollection({
    required this.languagePackages,
    required this.mediaKeys,
    required this.metadata,
    this.rsaPrivateKey,
    this.rsaPublicKey,
  });

  final Map<String, String> languagePackages;
  final Map<String, String> mediaKeys;
  final Map<String, dynamic> metadata;
  final String? rsaPrivateKey;
  final String? rsaPublicKey;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rsaPrivateKey': rsaPrivateKey,
      'rsaPublicKey': rsaPublicKey,
      'languagePackages': languagePackages,
      'mediaKeys': mediaKeys,
      'metadata': metadata,
    };
  }

  factory KeyCollection.fromJson(Map<String, dynamic> json) {
    return KeyCollection(
      rsaPrivateKey: json['rsaPrivateKey'] as String?,
      rsaPublicKey: json['rsaPublicKey'] as String?,
      languagePackages: Map<String, String>.from(
        json['languagePackages'] as Map? ?? <String, String>{},
      ),
      mediaKeys: Map<String, String>.from(
        json['mediaKeys'] as Map? ?? <String, String>{},
      ),
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map? ?? <String, dynamic>{},
      ),
    );
  }

  KeyCollection copyWith({
    Map<String, String>? languagePackages,
    Map<String, String>? mediaKeys,
    Map<String, dynamic>? metadata,
    String? rsaPrivateKey,
    String? rsaPublicKey,
  }) {
    return KeyCollection(
      languagePackages: languagePackages ?? this.languagePackages,
      mediaKeys: mediaKeys ?? this.mediaKeys,
      metadata: metadata ?? this.metadata,
      rsaPrivateKey: rsaPrivateKey ?? this.rsaPrivateKey,
      rsaPublicKey: rsaPublicKey ?? this.rsaPublicKey,
    );
  }
}

/// Utility responsible for reading and writing cryptographic material from [FlutterSecureStorage].
class KeyCollectorService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _languagePrefix = 'langMap-';
  static const String _mediaPrefix = 'mediaKey-';
  static const String _rsaPrivateKey = 'rsa_private_key';
  static const String _rsaPublicKey = 'rsa_public_key';

  /// Collects all encryption related secrets stored locally.
  static Future<KeyCollection> collectAllKeys() async {
    final Map<String, String> raw = await _storage.readAll();

    final Map<String, String> languagePackages = <String, String>{};
    final Map<String, String> mediaKeys = <String, String>{};

    for (final MapEntry<String, String> entry in raw.entries) {
      final String key = entry.key;
      final String value = entry.value;
      if (key.startsWith(_languagePrefix)) {
        final String relationId = key.substring(_languagePrefix.length);
        languagePackages[relationId] = value;
      } else if (key.startsWith(_mediaPrefix)) {
        final String relationId = key.substring(_mediaPrefix.length);
        mediaKeys[relationId] = value;
      }
    }

    final String? rsaPrivateKey = raw[_rsaPrivateKey];
    final String? rsaPublicKey = raw[_rsaPublicKey];

    final Map<String, dynamic> metadata = <String, dynamic>{
      'languageCount': languagePackages.length,
      'mediaCount': mediaKeys.length,
      'hasPrivateKey': rsaPrivateKey != null && rsaPrivateKey.isNotEmpty,
      'hasPublicKey': rsaPublicKey != null && rsaPublicKey.isNotEmpty,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'relationIds': languagePackages.keys.toList(),
    };

    return KeyCollection(
      languagePackages: languagePackages,
      mediaKeys: mediaKeys,
      rsaPrivateKey: rsaPrivateKey,
      rsaPublicKey: rsaPublicKey,
      metadata: metadata,
    );
  }

  /// Persists all secrets after a successful restoration.
  static Future<void> saveCollectedKeys(KeyCollection keys) async {
    final Map<String, String> current = await _storage.readAll();

    // Remove stale language packages.
    for (final String storedKey in current.keys.where(
      (String key) => key.startsWith(_languagePrefix),
    )) {
      final String relationId = storedKey.substring(_languagePrefix.length);
      if (!keys.languagePackages.containsKey(relationId)) {
        await _storage.delete(key: storedKey);
      }
    }

    // Remove stale media keys.
    for (final String storedKey in current.keys.where(
      (String key) => key.startsWith(_mediaPrefix),
    )) {
      final String relationId = storedKey.substring(_mediaPrefix.length);
      if (!keys.mediaKeys.containsKey(relationId)) {
        await _storage.delete(key: storedKey);
      }
    }

    // Write updated packages.
    for (final MapEntry<String, String> entry
        in keys.languagePackages.entries) {
      await _storage.write(
        key: '$_languagePrefix${entry.key}',
        value: entry.value,
      );
    }

    for (final MapEntry<String, String> entry in keys.mediaKeys.entries) {
      await _storage.write(
        key: '$_mediaPrefix${entry.key}',
        value: entry.value,
      );
    }

    if (keys.rsaPrivateKey != null && keys.rsaPrivateKey!.isNotEmpty) {
      await _storage.write(key: _rsaPrivateKey, value: keys.rsaPrivateKey);
    }
    if (keys.rsaPublicKey != null && keys.rsaPublicKey!.isNotEmpty) {
      await _storage.write(key: _rsaPublicKey, value: keys.rsaPublicKey);
    }

    // Optionally persist metadata for debug purposes.
    final String metadataJson = jsonEncode(keys.metadata);
    await _storage.write(key: 'backup_metadata', value: metadataJson);

    if (kDebugMode) {
      debugPrint(
        'KeyCollectorService.saveCollectedKeys → '
        '${keys.languagePackages.length} languages, ${keys.mediaKeys.length} media keys, '
        'rsaPrivate=${keys.rsaPrivateKey != null}, rsaPublic=${keys.rsaPublicKey != null}',
      );
    }
  }
}
