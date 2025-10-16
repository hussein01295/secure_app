import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service de cache intelligent pour optimiser les performances
class CacheService {
  static const _storage = FlutterSecureStorage();
  static final _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _cachePrefix = 'cache_';
  static const String _cacheMetaPrefix = 'cache_meta_';
  
  // Cache en mémoire pour les données fréquemment utilisées
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _memoryCacheExpiry = {};

  /// Met en cache une donnée avec expiration
  Future<void> put(
    String key, 
    dynamic data, {
    Duration? expiry,
    bool useMemoryCache = true,
  }) async {
    try {
      final cacheKey = '$_cachePrefix$key';
      final metaKey = '$_cacheMetaPrefix$key';
      
      final expiryTime = expiry != null 
        ? DateTime.now().add(expiry)
        : DateTime.now().add(const Duration(hours: 24)); // Défaut 24h

      // Sérialiser les données
      final serializedData = jsonEncode({
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'expiry': expiryTime.toIso8601String(),
      });

      // Stocker dans le stockage sécurisé
      await _storage.write(key: cacheKey, value: serializedData);
      
      // Stocker les métadonnées
      await _storage.write(key: metaKey, value: expiryTime.toIso8601String());

      // Cache mémoire si demandé
      if (useMemoryCache) {
        _memoryCache[key] = data;
        _memoryCacheExpiry[key] = expiryTime;
      }

      if (kDebugMode) {
        print('💾 Cache mis à jour: $key (expire: ${expiryTime.toString().substring(11, 16)})');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur mise en cache: $e');
    }
  }

  /// Récupère une donnée du cache
  Future<T?> get<T>(String key) async {
    try {
      // Vérifier d'abord le cache mémoire
      if (_memoryCache.containsKey(key)) {
        final expiry = _memoryCacheExpiry[key];
        if (expiry != null && DateTime.now().isBefore(expiry)) {
          if (kDebugMode) print('🚀 Cache mémoire hit: $key');
          return _memoryCache[key] as T?;
        } else {
          // Nettoyer le cache mémoire expiré
          _memoryCache.remove(key);
          _memoryCacheExpiry.remove(key);
        }
      }

      // Vérifier le stockage sécurisé
      final cacheKey = '$_cachePrefix$key';
      final cachedData = await _storage.read(key: cacheKey);
      
      if (cachedData == null) return null;

      final parsed = jsonDecode(cachedData);
      final expiry = DateTime.parse(parsed['expiry']);
      
      // Vérifier l'expiration
      if (DateTime.now().isAfter(expiry)) {
        await remove(key); // Nettoyer automatiquement
        return null;
      }

      final data = parsed['data'] as T;
      
      // Remettre en cache mémoire
      _memoryCache[key] = data;
      _memoryCacheExpiry[key] = expiry;

      if (kDebugMode) print('💾 Cache storage hit: $key');
      return data;
    } catch (e) {
      if (kDebugMode) print('❌ Erreur lecture cache: $e');
      return null;
    }
  }

  /// Supprime une entrée du cache
  Future<void> remove(String key) async {
    try {
      final cacheKey = '$_cachePrefix$key';
      final metaKey = '$_cacheMetaPrefix$key';
      
      await _storage.delete(key: cacheKey);
      await _storage.delete(key: metaKey);
      
      _memoryCache.remove(key);
      _memoryCacheExpiry.remove(key);
      
      if (kDebugMode) print('🗑️ Cache supprimé: $key');
    } catch (e) {
      if (kDebugMode) print('❌ Erreur suppression cache: $e');
    }
  }

  /// Vérifie si une clé existe et n'est pas expirée
  Future<bool> exists(String key) async {
    final data = await get(key);
    return data != null;
  }

  /// Nettoie tout le cache expiré
  Future<void> cleanExpired() async {
    try {
      final allKeys = await _storage.readAll();
      int cleanedCount = 0;
      
      for (final entry in allKeys.entries) {
        if (entry.key.startsWith(_cachePrefix)) {
          try {
            final parsed = jsonDecode(entry.value);
            final expiry = DateTime.parse(parsed['expiry']);
            
            if (DateTime.now().isAfter(expiry)) {
              final originalKey = entry.key.substring(_cachePrefix.length);
              await remove(originalKey);
              cleanedCount++;
            }
          } catch (e) {
            // Supprimer les entrées corrompues
            await _storage.delete(key: entry.key);
            cleanedCount++;
          }
        }
      }
      
      if (kDebugMode && cleanedCount > 0) {
        debugPrint('🧹 Cache nettoyé: $cleanedCount entrées supprimées');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur nettoyage cache: $e');
    }
  }

  /// Vide complètement le cache
  Future<void> clear() async {
    try {
      final allKeys = await _storage.readAll();
      int deletedCount = 0;
      
      for (final key in allKeys.keys) {
        if (key.startsWith(_cachePrefix) || key.startsWith(_cacheMetaPrefix)) {
          await _storage.delete(key: key);
          deletedCount++;
        }
      }
      
      _memoryCache.clear();
      _memoryCacheExpiry.clear();
      
      if (kDebugMode) {
        print('🗑️ Cache vidé complètement: $deletedCount entrées supprimées');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur vidage cache: $e');
    }
  }

  /// Obtient les statistiques du cache
  Future<CacheStats> getStats() async {
    try {
      final allKeys = await _storage.readAll();
      int totalEntries = 0;
      int expiredEntries = 0;
      int memoryEntries = _memoryCache.length;
      
      for (final entry in allKeys.entries) {
        if (entry.key.startsWith(_cachePrefix)) {
          totalEntries++;
          try {
            final parsed = jsonDecode(entry.value);
            final expiry = DateTime.parse(parsed['expiry']);
            if (DateTime.now().isAfter(expiry)) {
              expiredEntries++;
            }
          } catch (e) {
            expiredEntries++; // Compter les entrées corrompues comme expirées
          }
        }
      }
      
      return CacheStats(
        totalEntries: totalEntries,
        expiredEntries: expiredEntries,
        memoryEntries: memoryEntries,
        validEntries: totalEntries - expiredEntries,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Erreur stats cache: $e');
      return CacheStats(totalEntries: 0, expiredEntries: 0, memoryEntries: 0, validEntries: 0);
    }
  }
}

/// Classe pour les statistiques du cache
class CacheStats {
  final int totalEntries;
  final int expiredEntries;
  final int memoryEntries;
  final int validEntries;

  CacheStats({
    required this.totalEntries,
    required this.expiredEntries,
    required this.memoryEntries,
    required this.validEntries,
  });

  double get hitRatio => totalEntries > 0 ? validEntries / totalEntries : 0.0;
  
  @override
  String toString() {
    return 'CacheStats(total: $totalEntries, valid: $validEntries, expired: $expiredEntries, memory: $memoryEntries, hit ratio: ${(hitRatio * 100).toStringAsFixed(1)}%)';
  }
}
