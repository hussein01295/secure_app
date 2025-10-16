import 'package:flutter_test/flutter_test.dart';

// Classe de test simplifiée pour démonstration du cache
class SimpleCacheService {
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _expirations = {};
  
  // Opérations de base
  Future<void> setString(String key, String value) async {
    _cache[key] = value;
  }
  
  Future<String?> getString(String key, {String? defaultValue}) async {
    if (_cache.containsKey(key)) {
      return _cache[key] as String?;
    }
    return defaultValue;
  }
  
  Future<void> setInt(String key, int value) async {
    _cache[key] = value;
  }
  
  Future<int?> getInt(String key) async {
    if (_cache.containsKey(key)) {
      return _cache[key] as int?;
    }
    return null;
  }
  
  Future<void> setBool(String key, bool value) async {
    _cache[key] = value;
  }
  
  Future<bool> getBool(String key) async {
    if (_cache.containsKey(key)) {
      return _cache[key] as bool? ?? false;
    }
    return false;
  }
  
  // Opérations JSON
  Future<void> setJson(String key, Map<String, dynamic> value) async {
    _cache[key] = value;
  }
  
  Future<Map<String, dynamic>?> getJson(String key) async {
    if (_cache.containsKey(key)) {
      return _cache[key] as Map<String, dynamic>?;
    }
    return null;
  }
  
  // Opérations avec expiration
  Future<void> setStringWithExpiration(String key, String value, DateTime expiration) async {
    _cache[key] = value;
    _expirations[key] = expiration;
  }
  
  Future<String?> getStringWithExpiration(String key) async {
    if (_cache.containsKey(key)) {
      final expiration = _expirations[key];
      if (expiration != null && DateTime.now().isAfter(expiration)) {
        // Expiré, supprimer
        _cache.remove(key);
        _expirations.remove(key);
        return null;
      }
      return _cache[key] as String?;
    }
    return null;
  }
  
  // Gestion du cache
  Future<void> remove(String key) async {
    _cache.remove(key);
    _expirations.remove(key);
  }
  
  Future<void> clear() async {
    _cache.clear();
    _expirations.clear();
  }
  
  Future<bool> containsKey(String key) async {
    return _cache.containsKey(key);
  }
  
  Future<Set<String>> getAllKeys() async {
    return _cache.keys.toSet();
  }
  
  Future<int> getCacheSize() async {
    return _cache.length;
  }
  
  Future<void> cleanExpiredEntries() async {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    _expirations.forEach((key, expiration) {
      if (now.isAfter(expiration)) {
        expiredKeys.add(key);
      }
    });
    
    for (final key in expiredKeys) {
      _cache.remove(key);
      _expirations.remove(key);
    }
  }
}

void main() {
  group('SimpleCacheService Tests', () {
    late SimpleCacheService cacheService;

    setUp(() {
      cacheService = SimpleCacheService();
    });

    group('String Cache Operations', () {
      test('should store and retrieve string value', () async {
        // Arrange
        const key = 'test_string_key';
        const value = 'test_string_value';

        // Act
        await cacheService.setString(key, value);
        final retrievedValue = await cacheService.getString(key);

        // Assert
        expect(retrievedValue, equals(value));
      });

      test('should return null for non-existent string key', () async {
        // Arrange
        const key = 'non_existent_key';

        // Act
        final result = await cacheService.getString(key);

        // Assert
        expect(result, isNull);
      });

      test('should return default value for non-existent string key', () async {
        // Arrange
        const key = 'non_existent_key';
        const defaultValue = 'default';

        // Act
        final result = await cacheService.getString(key, defaultValue: defaultValue);

        // Assert
        expect(result, equals(defaultValue));
      });
    });

    group('Integer Cache Operations', () {
      test('should store and retrieve integer value', () async {
        // Arrange
        const key = 'test_int_key';
        const value = 42;

        // Act
        await cacheService.setInt(key, value);
        final retrievedValue = await cacheService.getInt(key);

        // Assert
        expect(retrievedValue, equals(value));
      });

      test('should return null for non-existent integer key', () async {
        // Arrange
        const key = 'non_existent_int_key';

        // Act
        final result = await cacheService.getInt(key);

        // Assert
        expect(result, isNull);
      });
    });

    group('Boolean Cache Operations', () {
      test('should store and retrieve boolean value', () async {
        // Arrange
        const key = 'test_bool_key';
        const value = true;

        // Act
        await cacheService.setBool(key, value);
        final retrievedValue = await cacheService.getBool(key);

        // Assert
        expect(retrievedValue, equals(value));
      });

      test('should return false as default for non-existent boolean key', () async {
        // Arrange
        const key = 'non_existent_bool_key';

        // Act
        final result = await cacheService.getBool(key);

        // Assert
        expect(result, isFalse);
      });
    });

    group('JSON Cache Operations', () {
      test('should store and retrieve JSON object', () async {
        // Arrange
        const key = 'test_json_key';
        final value = {'name': 'John', 'age': 30, 'active': true};

        // Act
        await cacheService.setJson(key, value);
        final retrievedValue = await cacheService.getJson(key);

        // Assert
        expect(retrievedValue, equals(value));
      });

      test('should return null for non-existent JSON key', () async {
        // Arrange
        const key = 'non_existent_json_key';

        // Act
        final result = await cacheService.getJson(key);

        // Assert
        expect(result, isNull);
      });
    });

    group('Cache with Expiration', () {
      test('should store value with expiration', () async {
        // Arrange
        const key = 'expiring_key';
        const value = 'expiring_value';
        final expirationTime = DateTime.now().add(Duration(hours: 1));

        // Act
        await cacheService.setStringWithExpiration(key, value, expirationTime);
        final result = await cacheService.getStringWithExpiration(key);

        // Assert
        expect(result, equals(value));
      });

      test('should return value if not expired', () async {
        // Arrange
        const key = 'valid_key';
        const value = 'valid_value';
        final futureTime = DateTime.now().add(Duration(hours: 1));

        // Act
        await cacheService.setStringWithExpiration(key, value, futureTime);
        final result = await cacheService.getStringWithExpiration(key);

        // Assert
        expect(result, equals(value));
      });

      test('should return null if expired', () async {
        // Arrange
        const key = 'expired_key';
        const value = 'expired_value';
        final pastTime = DateTime.now().subtract(Duration(hours: 1));

        // Act
        await cacheService.setStringWithExpiration(key, value, pastTime);
        final result = await cacheService.getStringWithExpiration(key);

        // Assert
        expect(result, isNull);
      });
    });

    group('Cache Management', () {
      test('should remove specific key', () async {
        // Arrange
        const key = 'key_to_remove';
        const value = 'value_to_remove';
        await cacheService.setString(key, value);

        // Act
        await cacheService.remove(key);
        final result = await cacheService.getString(key);

        // Assert
        expect(result, isNull);
      });

      test('should clear all cache', () async {
        // Arrange
        await cacheService.setString('key1', 'value1');
        await cacheService.setString('key2', 'value2');

        // Act
        await cacheService.clear();

        // Assert
        final size = await cacheService.getCacheSize();
        expect(size, equals(0));
      });

      test('should check if key exists', () async {
        // Arrange
        const existingKey = 'existing_key';
        const nonExistingKey = 'non_existing_key';
        await cacheService.setString(existingKey, 'value');

        // Act
        final existsResult = await cacheService.containsKey(existingKey);
        final notExistsResult = await cacheService.containsKey(nonExistingKey);

        // Assert
        expect(existsResult, isTrue);
        expect(notExistsResult, isFalse);
      });

      test('should get all keys', () async {
        // Arrange
        await cacheService.setString('key1', 'value1');
        await cacheService.setString('key2', 'value2');
        await cacheService.setString('key3', 'value3');

        // Act
        final result = await cacheService.getAllKeys();

        // Assert
        expect(result.length, equals(3));
        expect(result.contains('key1'), isTrue);
        expect(result.contains('key2'), isTrue);
        expect(result.contains('key3'), isTrue);
      });
    });

    group('Cache Statistics', () {
      test('should return cache size', () async {
        // Arrange
        await cacheService.setString('key1', 'value1');
        await cacheService.setString('key2', 'value2');
        await cacheService.setString('key3', 'value3');

        // Act
        final size = await cacheService.getCacheSize();

        // Assert
        expect(size, equals(3));
      });

      test('should return zero for empty cache', () async {
        // Act
        final size = await cacheService.getCacheSize();

        // Assert
        expect(size, equals(0));
      });
    });

    group('Cache Cleanup', () {
      test('should clean expired entries', () async {
        // Arrange
        const validKey = 'valid_key';
        const expiredKey = 'expired_key';
        final futureTime = DateTime.now().add(Duration(hours: 1));
        final pastTime = DateTime.now().subtract(Duration(hours: 1));

        await cacheService.setStringWithExpiration(validKey, 'valid_value', futureTime);
        await cacheService.setStringWithExpiration(expiredKey, 'expired_value', pastTime);

        // Act
        await cacheService.cleanExpiredEntries();

        // Assert
        final validResult = await cacheService.getStringWithExpiration(validKey);
        final expiredResult = await cacheService.getStringWithExpiration(expiredKey);
        
        expect(validResult, equals('valid_value'));
        expect(expiredResult, isNull);
      });
    });
  });
}
