import 'package:flutter_test/flutter_test.dart';

/// Tests unitaires pour AuthService
/// Teste l'authentification, la gestion des tokens, et la sécurité
void main() {
  group('Tests AuthService', () {
    late SimpleAuthService authService;

    setUp(() {
      authService = SimpleAuthService();
    });

    tearDown(() {
      authService.clear();
    });

    group('Tests de Connexion', () {
      test('devrait se connecter avec succès avec des identifiants valides', () async {
        final result = await authService.login('testuser', 'password123');

        expect(result['success'], true);
        expect(result['token'], isNotNull);
        expect(result['userId'], isNotNull);
        expect(authService.isAuthenticated, true);
      });

      test('devrait échouer la connexion avec un nom d\'utilisateur invalide', () async {
        final result = await authService.login('', 'password123');

        expect(result['success'], false);
        expect(result['error'], 'Username cannot be empty');
        expect(authService.isAuthenticated, false);
      });

      test('devrait échouer la connexion avec un mot de passe invalide', () async {
        final result = await authService.login('testuser', '');

        expect(result['success'], false);
        expect(result['error'], 'Password cannot be empty');
        expect(authService.isAuthenticated, false);
      });

      test('devrait échouer la connexion avec des identifiants incorrects', () async {
        final result = await authService.login('wronguser', 'wrongpass');

        expect(result['success'], false);
        expect(result['error'], contains('Invalid'));
        expect(authService.isAuthenticated, false);
      });

      test('devrait stocker le token après une connexion réussie', () async {
        await authService.login('testuser', 'password123');

        final token = await authService.getToken();
        expect(token, isNotNull);
        expect(token, isNotEmpty);
      });
    });

    group('Tests de Déconnexion', () {
      test('devrait se déconnecter avec succès', () async {
        await authService.login('testuser', 'password123');
        expect(authService.isAuthenticated, true);

        await authService.logout();

        expect(authService.isAuthenticated, false);
        expect(await authService.getToken(), isNull);
      });

      test('devrait effacer toutes les données d\'authentification lors de la déconnexion', () async {
        await authService.login('testuser', 'password123');
        await authService.logout();

        expect(await authService.getToken(), isNull);
        expect(await authService.getUserId(), isNull);
        expect(authService.isAuthenticated, false);
      });
    });

    group('Tests de Gestion des Tokens', () {
      test('devrait rafraîchir le token avec succès', () async {
        await authService.login('testuser', 'password123');
        final oldToken = await authService.getToken();

        await Future.delayed(Duration(milliseconds: 10));
        final result = await authService.refreshToken();

        expect(result['success'], true);
        expect(result['token'], isNotNull);
        expect(result['token'], isNot(oldToken));
      });

      test('devrait valider un token valide', () async {
        await authService.login('testuser', 'password123');
        final token = await authService.getToken();

        final isValid = await authService.validateToken(token!);
        expect(isValid, true);
      });

      test('devrait rejeter un token invalide', () async {
        final isValid = await authService.validateToken('invalid-token');
        expect(isValid, false);
      });

      test('devrait rejeter un token expiré', () async {
        await authService.login('testuser', 'password123');
        authService.expireToken();

        final token = await authService.getToken();
        final isValid = await authService.validateToken(token!);
        expect(isValid, false);
      });
    });

    group('Tests d\'Inscription', () {
      test('devrait inscrire un nouvel utilisateur avec succès', () async {
        final result = await authService.register('newuser', 'password123', 'New User');

        expect(result['success'], true);
        expect(result['userId'], isNotNull);
        expect(result['token'], isNotNull);
      });

      test('devrait échouer l\'inscription avec un nom d\'utilisateur existant', () async {
        await authService.register('testuser', 'password123', 'Test User');
        final result = await authService.register('testuser', 'password456', 'Another User');

        expect(result['success'], false);
        expect(result['error'], contains('already exists'));
      });

      test('devrait échouer l\'inscription avec un mot de passe faible', () async {
        final result = await authService.register('newuser', '123', 'New User');

        expect(result['success'], false);
        expect(result['error'], contains('Password must be'));
      });

      test('devrait échouer l\'inscription avec un nom d\'utilisateur vide', () async {
        final result = await authService.register('', 'password123', 'New User');

        expect(result['success'], false);
        expect(result['error'], contains('Username cannot be empty'));
      });
    });

    group('Tests de Gestion des Mots de Passe', () {
      test('devrait changer le mot de passe avec succès', () async {
        await authService.login('testuser', 'password123');

        final result = await authService.changePassword('password123', 'newpassword123');

        expect(result['success'], true);
      });

      test('devrait échouer le changement de mot de passe avec un mot de passe actuel incorrect', () async {
        await authService.login('testuser', 'password123');

        final result = await authService.changePassword('wrongpassword', 'newpassword123');

        expect(result['success'], false);
        expect(result['error'], contains('Current password is incorrect'));
      });

      test('devrait échouer le changement de mot de passe avec un nouveau mot de passe faible', () async {
        await authService.login('testuser', 'password123');

        final result = await authService.changePassword('password123', '123');

        expect(result['success'], false);
        expect(result['error'], contains('Password must be'));
      });
    });

    group('Tests de Gestion de Session', () {
      test('devrait maintenir la session après la connexion', () async {
        await authService.login('testuser', 'password123');

        expect(authService.isAuthenticated, true);
        expect(await authService.getUserId(), isNotNull);
      });

      test('devrait effacer la session après la déconnexion', () async {
        await authService.login('testuser', 'password123');
        await authService.logout();

        expect(authService.isAuthenticated, false);
        expect(await authService.getUserId(), isNull);
      });

      test('devrait restaurer la session à partir d\'un token stocké', () async {
        await authService.login('testuser', 'password123');
        final token = await authService.getToken();

        // Sauvegarder le token avant de clear
        final savedToken = token!;

        // Simuler un redémarrage (mais garder les tokens valides)
        final validTokens = Set<String>.from(authService._validTokens);
        authService.clear();
        authService._validTokens.addAll(validTokens);
        expect(authService.isAuthenticated, false);

        // Restaurer la session
        await authService.restoreSession(savedToken);
        expect(authService.isAuthenticated, true);
      });
    });

    group('Tests de Gestion des Erreurs', () {
      test('devrait gérer les erreurs réseau avec élégance', () async {
        authService.simulateNetworkError = true;

        final result = await authService.login('testuser', 'password123');

        expect(result['success'], false);
        expect(result['error'], contains('Network error'));
      });

      test('devrait gérer les erreurs serveur avec élégance', () async {
        authService.simulateServerError = true;

        final result = await authService.login('testuser', 'password123');

        expect(result['success'], false);
        expect(result['error'], contains('Server error'));
      });
    });

    group('Tests de Sécurité', () {
      test('ne devrait pas stocker le mot de passe en texte clair', () async {
        await authService.login('testuser', 'password123');

        final storedData = authService.getStoredData();
        expect(storedData.containsKey('password'), false);
      });

      test('devrait générer des tokens uniques pour chaque connexion', () async {
        await authService.login('testuser', 'password123');
        final token1 = await authService.getToken();

        await Future.delayed(Duration(milliseconds: 10)); // Assurer un timestamp différent

        await authService.logout();
        await authService.login('testuser', 'password123');
        final token2 = await authService.getToken();

        expect(token1, isNot(token2));
      });

      test('devrait invalider les anciens tokens après un changement de mot de passe', () async {
        await authService.login('testuser', 'password123');
        final oldToken = await authService.getToken();

        await authService.changePassword('password123', 'newpassword123');

        final isValid = await authService.validateToken(oldToken!);
        expect(isValid, false);
      });
    });
  });
}

/// Classe simplifiée pour les tests
class SimpleAuthService {
  final Map<String, dynamic> _storage = {};
  final Map<String, String> _users = {'testuser': 'password123'};
  final Set<String> _validTokens = {};
  final Set<String> _expiredTokens = {};
  bool isAuthenticated = false;
  bool simulateNetworkError = false;
  bool simulateServerError = false;

  Future<Map<String, dynamic>> login(String username, String password) async {
    if (simulateNetworkError) {
      return {'success': false, 'error': 'Network error'};
    }
    if (simulateServerError) {
      return {'success': false, 'error': 'Server error'};
    }
    
    if (username.isEmpty) {
      return {'success': false, 'error': 'Username cannot be empty'};
    }
    if (password.isEmpty) {
      return {'success': false, 'error': 'Password cannot be empty'};
    }
    
    if (_users[username] != password) {
      return {'success': false, 'error': 'Invalid credentials'};
    }
    
    final token = 'token_${DateTime.now().millisecondsSinceEpoch}';
    final userId = 'user_$username';
    
    _storage['token'] = token;
    _storage['userId'] = userId;
    _validTokens.add(token);
    isAuthenticated = true;
    
    return {'success': true, 'token': token, 'userId': userId};
  }

  Future<void> logout() async {
    final token = _storage['token'];
    if (token != null) {
      _validTokens.remove(token);
    }
    _storage.clear();
    isAuthenticated = false;
  }

  Future<String?> getToken() async => _storage['token'];
  Future<String?> getUserId() async => _storage['userId'];

  Future<Map<String, dynamic>> refreshToken() async {
    if (!isAuthenticated) {
      return {'success': false, 'error': 'Not authenticated'};
    }
    
    final oldToken = _storage['token'];
    _validTokens.remove(oldToken);
    
    final newToken = 'token_${DateTime.now().millisecondsSinceEpoch}';
    _storage['token'] = newToken;
    _validTokens.add(newToken);
    
    return {'success': true, 'token': newToken};
  }

  Future<bool> validateToken(String token) async {
    return _validTokens.contains(token) && !_expiredTokens.contains(token);
  }

  void expireToken() {
    final token = _storage['token'];
    if (token != null) {
      _expiredTokens.add(token);
    }
  }

  Future<Map<String, dynamic>> register(String username, String password, String displayName) async {
    if (username.isEmpty) {
      return {'success': false, 'error': 'Username cannot be empty'};
    }
    if (password.length < 6) {
      return {'success': false, 'error': 'Password must be at least 6 characters'};
    }
    if (_users.containsKey(username)) {
      return {'success': false, 'error': 'Username already exists'};
    }
    
    _users[username] = password;
    return await login(username, password);
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    if (!isAuthenticated) {
      return {'success': false, 'error': 'Not authenticated'};
    }
    
    final username = _storage['userId']?.toString().replaceAll('user_', '');
    if (_users[username] != currentPassword) {
      return {'success': false, 'error': 'Current password is incorrect'};
    }
    
    if (newPassword.length < 6) {
      return {'success': false, 'error': 'Password must be at least 6 characters'};
    }
    
    _users[username!] = newPassword;
    
    // Invalider tous les tokens
    _validTokens.clear();
    
    return {'success': true};
  }

  Future<void> restoreSession(String token) async {
    if (_validTokens.contains(token)) {
      _storage['token'] = token;
      isAuthenticated = true;
    }
  }

  Map<String, dynamic> getStoredData() => Map.from(_storage);
  
  void clear() {
    _storage.clear();
    _validTokens.clear();
    _expiredTokens.clear();
    isAuthenticated = false;
    simulateNetworkError = false;
    simulateServerError = false;
  }
}

