import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:silencia/core/service/socket_service.dart';
import 'package:silencia/core/service/auth_service.dart';

/// Service de surveillance de la santé de l'application
class AppHealthService {
  static const _storage = FlutterSecureStorage();
  static final _instance = AppHealthService._internal();
  factory AppHealthService() => _instance;
  AppHealthService._internal();

  // Streams pour surveiller l'état
  final _connectivityController = StreamController<bool>.broadcast();
  final _authStatusController = StreamController<bool>.broadcast();
  final _socketStatusController = StreamController<bool>.broadcast();

  Stream<bool> get connectivityStream => _connectivityController.stream;
  Stream<bool> get authStatusStream => _authStatusController.stream;
  Stream<bool> get socketStatusStream => _socketStatusController.stream;

  Timer? _healthCheckTimer;
  bool _isInitialized = false;

  /// Initialise la surveillance de santé
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isInitialized = true;
    
    // Surveillance de la connectivité
    Connectivity().onConnectivityChanged.listen((result) {
      final isConnected = result != ConnectivityResult.none;
      _connectivityController.add(isConnected);
      
      if (kDebugMode) {
        print('🌐 Connectivité: ${isConnected ? "Connecté" : "Déconnecté"}');
      }
    });

    // Vérification périodique de santé (toutes les 30 secondes)
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performHealthCheck(),
    );

    // Vérification initiale
    await _performHealthCheck();
  }

  /// Effectue une vérification complète de santé
  Future<AppHealthStatus> _performHealthCheck() async {
    final status = AppHealthStatus();

    try {
      // 1. Vérifier la connectivité
      final connectivityResult = await Connectivity().checkConnectivity();
      status.hasConnectivity = connectivityResult != ConnectivityResult.none;
      _connectivityController.add(status.hasConnectivity);

      // 2. Vérifier l'authentification
      final token = await AuthService.getToken();
      status.isAuthenticated = token != null;
      _authStatusController.add(status.isAuthenticated);

      // 3. Vérifier le socket
      status.isSocketConnected = SocketService().isConnected;
      _socketStatusController.add(status.isSocketConnected);

      // 4. Vérifier le stockage sécurisé
      try {
        await _storage.write(key: 'health_check', value: 'ok');
        await _storage.read(key: 'health_check');
        await _storage.delete(key: 'health_check');
        status.isStorageHealthy = true;
      } catch (e) {
        status.isStorageHealthy = false;
        if (kDebugMode) print('❌ Stockage sécurisé défaillant: $e');
      }

      // 5. Calculer le score de santé global
      status.calculateHealthScore();

      if (kDebugMode) {
        print('💊 Santé App: ${status.healthScore}% - ${status.getStatusMessage()}');
      }

    } catch (e) {
      if (kDebugMode) print('❌ Erreur vérification santé: $e');
    }

    return status;
  }

  /// Obtient le statut de santé actuel
  Future<AppHealthStatus> getCurrentHealth() async {
    return await _performHealthCheck();
  }



  /// Nettoie les ressources
  void dispose() {
    _healthCheckTimer?.cancel();
    _connectivityController.close();
    _authStatusController.close();
    _socketStatusController.close();
    _isInitialized = false;
  }
}

/// Classe représentant l'état de santé de l'application
class AppHealthStatus {
  bool hasConnectivity = false;
  bool isAuthenticated = false;
  bool isSocketConnected = false;
  bool isStorageHealthy = false;
  int healthScore = 0;

  void calculateHealthScore() {
    int score = 0;
    if (hasConnectivity) score += 25;
    if (isAuthenticated) score += 25;
    if (isSocketConnected) score += 25;
    if (isStorageHealthy) score += 25;
    healthScore = score;
  }

  String getStatusMessage() {
    if (healthScore >= 100) return 'Excellent';
    if (healthScore >= 75) return 'Bon';
    if (healthScore >= 50) return 'Moyen';
    if (healthScore >= 25) return 'Faible';
    return 'Critique';
  }

  bool get isHealthy => healthScore >= 75;
}
