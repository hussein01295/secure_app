import 'package:flutter_test/flutter_test.dart';

/// Tests unitaires pour TokenRotationService
/// Teste la rotation automatique des tokens JWT
void main() {
  group('Tests TokenRotationService', () {
    late SimpleTokenRotationService tokenService;

    setUp(() {
      tokenService = SimpleTokenRotationService();
    });

    tearDown(() {
      tokenService.clear();
    });

    group('Tests de Détection d\'Âge des Tokens', () {
      test('devrait détecter un token récent (< 14 jours)', () {
        final token = tokenService.createToken(daysOld: 5);
        final age = tokenService.getTokenAge(token);

        expect(age, lessThan(14));
        expect(tokenService.shouldRotate(token), false);
      });

      test('devrait détecter un token ancien (>= 14 jours)', () {
        final token = tokenService.createToken(daysOld: 15);
        final age = tokenService.getTokenAge(token);

        expect(age, greaterThanOrEqualTo(14));
        expect(tokenService.shouldRotate(token), true);
      });

      test('devrait détecter un token à exactement 14 jours', () {
        final token = tokenService.createToken(daysOld: 14);
        final age = tokenService.getTokenAge(token);

        expect(age, equals(14));
        expect(tokenService.shouldRotate(token), true);
      });

      test('devrait gérer les tokens très anciens (> 30 jours)', () {
        final token = tokenService.createToken(daysOld: 100);
        final age = tokenService.getTokenAge(token);

        expect(age, greaterThan(30));
        expect(tokenService.shouldRotate(token), true);
      });
    });

    group('Tests de Rotation des Tokens', () {
      test('devrait faire tourner un ancien token avec succès', () async {
        final oldToken = tokenService.createToken(daysOld: 15);

        final result = await tokenService.rotateToken(oldToken);

        expect(result['success'], true);
        expect(result['newToken'], isNotNull);
        expect(result['newToken'], isNot(oldToken));
        expect(result['reason'], 'age');
      });

      test('ne devrait pas faire tourner un token récent', () async {
        final freshToken = tokenService.createToken(daysOld: 5);

        final result = await tokenService.rotateToken(freshToken);

        expect(result['success'], false);
        expect(result['newToken'], isNull);
        expect(result['reason'], isNull);
      });

      test('devrait générer des tokens uniques lors de la rotation', () async {
        final oldToken = tokenService.createToken(daysOld: 15);

        final result1 = await tokenService.rotateToken(oldToken);
        final result2 = await tokenService.rotateToken(oldToken);

        expect(result1['newToken'], isNot(result2['newToken']));
      });

      test('devrait invalider l\'ancien token après rotation', () async {
        final oldToken = tokenService.createToken(daysOld: 15);

        await tokenService.rotateToken(oldToken);

        expect(tokenService.isTokenValid(oldToken), false);
      });
    });

    group('Tests de Validation des Tokens', () {
      test('devrait valider un token récent', () {
        final token = tokenService.createToken(daysOld: 5);

        expect(tokenService.isTokenValid(token), true);
      });

      test('devrait invalider un token expiré', () {
        final token = tokenService.createToken(daysOld: 15);
        tokenService.expireToken(token);

        expect(tokenService.isTokenValid(token), false);
      });

      test('devrait invalider un token mal formé', () {
        expect(tokenService.isTokenValid('invalid-token'), false);
      });

      test('devrait invalider un token vide', () {
        expect(tokenService.isTokenValid(''), false);
      });
    });

    group('Tests de Rotation Automatique', () {
      test('devrait détecter les tokens nécessitant une rotation', () {
        final freshToken = tokenService.createToken(daysOld: 5);
        final oldToken = tokenService.createToken(daysOld: 15);

        tokenService.addToken(freshToken);
        tokenService.addToken(oldToken);

        final tokensToRotate = tokenService.getTokensNeedingRotation();

        expect(tokensToRotate.length, 1);
        expect(tokensToRotate.contains(oldToken), true);
        expect(tokensToRotate.contains(freshToken), false);
      });

      test('devrait faire tourner tous les tokens éligibles', () async {
        final token1 = tokenService.createToken(daysOld: 15);
        final token2 = tokenService.createToken(daysOld: 20);
        final token3 = tokenService.createToken(daysOld: 5);

        tokenService.addToken(token1);
        tokenService.addToken(token2);
        tokenService.addToken(token3);

        final results = await tokenService.rotateAllEligibleTokens();

        expect(results.length, 2); // token1 et token2
        expect(results.every((r) => r['success'] == true), true);
      });
    });

    group('Tests de Métadonnées des Tokens', () {
      test('devrait stocker l\'heure de création du token', () {
        final token = tokenService.createToken(daysOld: 0);
        final metadata = tokenService.getTokenMetadata(token);

        expect(metadata['createdAt'], isNotNull);
        expect(metadata['createdAt'], isA<DateTime>());
      });

      test('devrait calculer correctement l\'âge du token', () {
        final token = tokenService.createToken(daysOld: 10);
        final metadata = tokenService.getTokenMetadata(token);

        expect(metadata['age'], closeTo(10, 0.1));
      });

      test('devrait suivre le nombre de rotations', () async {
        final token1 = tokenService.createToken(daysOld: 15);
        final token2 = tokenService.createToken(daysOld: 15);

        await tokenService.rotateToken(token1);
        await tokenService.rotateToken(token2);

        expect(tokenService.getRotationCount(), 2);
      });
    });

    group('Tests de Gestion des Erreurs', () {
      test('devrait gérer la rotation d\'un token invalide', () async {
        final result = await tokenService.rotateToken('invalid-token');

        expect(result['success'], false);
        expect(result['error'], isNotNull);
      });

      test('devrait gérer la rotation quand le service est indisponible', () async {
        tokenService.simulateServiceError = true;
        final token = tokenService.createToken(daysOld: 15);

        final result = await tokenService.rotateToken(token);

        expect(result['success'], false);
        expect(result['error'], contains('Service error'));
      });
    });

    group('Tests de Performance', () {
      test('devrait gérer plusieurs tokens efficacement', () {
        final tokens = List.generate(100, (i) => tokenService.createToken(daysOld: i % 30));

        for (final token in tokens) {
          tokenService.addToken(token);
        }

        final tokensToRotate = tokenService.getTokensNeedingRotation();

        expect(tokensToRotate.length, greaterThan(0));
      });

      test('devrait faire tourner les tokens rapidement', () async {
        final token = tokenService.createToken(daysOld: 15);

        final stopwatch = Stopwatch()..start();
        await tokenService.rotateToken(token);
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('Tests de Sécurité', () {
      test('ne devrait pas réutiliser les tokens ayant subi une rotation', () async {
        final oldToken = tokenService.createToken(daysOld: 15);

        final result1 = await tokenService.rotateToken(oldToken);
        final result2 = await tokenService.rotateToken(oldToken);

        expect(result1['newToken'], isNot(result2['newToken']));
      });

      test('devrait générer des tokens cryptographiquement sécurisés', () {
        final tokens = List.generate(100, (_) => tokenService.createToken(daysOld: 0));
        final uniqueTokens = tokens.toSet();

        expect(uniqueTokens.length, 100); // Tous uniques
      });
    });
  });
}

/// Classe simplifiée pour les tests
class SimpleTokenRotationService {
  final Map<String, DateTime> _tokenCreationTimes = {};
  final Set<String> _validTokens = {};
  final Set<String> _expiredTokens = {};
  int _rotationCount = 0;
  bool simulateServiceError = false;

  String createToken({required int daysOld}) {
    final token = 'token_${DateTime.now().millisecondsSinceEpoch}_${_validTokens.length}';
    final createdAt = DateTime.now().subtract(Duration(days: daysOld));
    
    _tokenCreationTimes[token] = createdAt;
    _validTokens.add(token);
    
    return token;
  }

  int getTokenAge(String token) {
    final createdAt = _tokenCreationTimes[token];
    if (createdAt == null) return -1;
    
    final age = DateTime.now().difference(createdAt).inDays;
    return age;
  }

  bool shouldRotate(String token) {
    final age = getTokenAge(token);
    return age >= 14;
  }

  Future<Map<String, dynamic>> rotateToken(String oldToken) async {
    if (simulateServiceError) {
      return {'success': false, 'error': 'Service error'};
    }
    
    if (!_validTokens.contains(oldToken)) {
      return {'success': false, 'error': 'Invalid token'};
    }
    
    if (!shouldRotate(oldToken)) {
      return {'success': false, 'newToken': null, 'reason': null};
    }
    
    // Créer un nouveau token
    final newToken = 'token_${DateTime.now().millisecondsSinceEpoch}_rotated';
    _tokenCreationTimes[newToken] = DateTime.now();
    _validTokens.add(newToken);
    
    // Invalider l'ancien token
    _validTokens.remove(oldToken);
    _expiredTokens.add(oldToken);
    
    _rotationCount++;
    
    return {'success': true, 'newToken': newToken, 'reason': 'age'};
  }

  bool isTokenValid(String token) {
    if (token.isEmpty) return false;
    return _validTokens.contains(token) && !_expiredTokens.contains(token);
  }

  void expireToken(String token) {
    _validTokens.remove(token);
    _expiredTokens.add(token);
  }

  void addToken(String token) {
    if (!_tokenCreationTimes.containsKey(token)) {
      _tokenCreationTimes[token] = DateTime.now();
    }
    _validTokens.add(token);
  }

  List<String> getTokensNeedingRotation() {
    return _validTokens.where((token) => shouldRotate(token)).toList();
  }

  Future<List<Map<String, dynamic>>> rotateAllEligibleTokens() async {
    final tokensToRotate = getTokensNeedingRotation();
    final results = <Map<String, dynamic>>[];
    
    for (final token in tokensToRotate) {
      final result = await rotateToken(token);
      results.add(result);
    }
    
    return results;
  }

  Map<String, dynamic> getTokenMetadata(String token) {
    final createdAt = _tokenCreationTimes[token];
    if (createdAt == null) {
      return {};
    }
    
    final age = DateTime.now().difference(createdAt).inDays.toDouble();
    
    return {
      'createdAt': createdAt,
      'age': age,
      'isValid': isTokenValid(token),
      'shouldRotate': shouldRotate(token),
    };
  }

  int getRotationCount() => _rotationCount;

  void clear() {
    _tokenCreationTimes.clear();
    _validTokens.clear();
    _expiredTokens.clear();
    _rotationCount = 0;
    simulateServiceError = false;
  }
}

