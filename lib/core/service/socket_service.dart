import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/service/auth_service.dart'; // <-- Ajout ici

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  io.Socket? _socket;
  bool _initialized = false;
  String? _currentToken; // Stocker le token pour la reconnexion
  Timer? _reconnectTimer; // Timer pour la reconnexion automatique
  bool _shouldReconnect = true; // Flag pour contrôler la reconnexion
  int _reconnectAttempts = 0; // Compteur de tentatives de reconnexion
  final List<int> _reconnectDelays = [2, 5, 10, 20, 30]; // Délais progressifs en secondes
  static const int _maxReconnectAttempts = 10; // Limite maximale de tentatives

  // 🔥 Ajoute ces maps d'observateurs (callback qui prennent isTyping)
  final Map<String, List<void Function(bool isTyping, String userId)>> _typingObservers = {};

  // 👥 Observateurs pour les événements d'amis
  final List<void Function(Map<String, dynamic>)> _friendRequestObservers = [];
  final List<void Function(Map<String, dynamic>)> _friendAcceptedObservers = [];
  final List<void Function(Map<String, dynamic>)> _friendRemovedObservers = [];

  SocketService._internal();

  io.Socket get socket {
    if (_socket == null) {
      throw Exception('Socket non initialisé: appeler initSocket(token) AVANT');
    }
    return _socket!;
  }

  bool get isReady => _initialized && _socket != null;

  void initSocket(String token) {
    debugPrint('🔥 [FLUTTER] initSocket appelé avec token: ${token.substring(0, 20)}...');

    if (_initialized && _socket != null && _socket!.connected) {
      debugPrint("🔥 [FLUTTER] Socket déjà initialisé et connecté");
      return;
    }

    // Stocker le token pour la reconnexion
    _currentToken = token;
    _shouldReconnect = true;

    // Utilise l'URL centrale de ta config !
    final socketUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    debugPrint('🔥 [FLUTTER] Tentative de connexion à: $socketUrl');

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableReconnection()
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    debugPrint('🔥 [FLUTTER] Socket créé, tentative de connexion...');
    _socket!.connect();
    _socket!.onConnect((_) {
      debugPrint('🔥 [FLUTTER] Socket connecté avec succès !');
      debugPrint('🔥 [FLUTTER] Socket ID: ${_socket!.id}');
      debugPrint('🔥 [FLUTTER] URL: $socketUrl');
      _reconnectAttempts = 0; // Reset le compteur de tentatives
      _cancelReconnectTimer(); // Annuler le timer si on se reconnecte
    });
    _socket!.onDisconnect((reason) {
      debugPrint('🔥 [FLUTTER] Socket déconnecté - Raison: $reason');
      _scheduleReconnect(); // Programmer la reconnexion automatique
    });
    _socket!.onConnectError((err) {
      debugPrint('🔥 [FLUTTER] Erreur de connexion : $err');
      _scheduleReconnect(); // Programmer la reconnexion en cas d'erreur
    });
    _socket!.onError((err) => debugPrint('🔥 [FLUTTER] Erreur socket : $err'));

    // Setup listeners globaux une seule fois
    _setupGlobalTypingListeners();
    _setupFriendListeners();

    _initialized = true;
  }

  void dispose() {
    _shouldReconnect = false; // Arrêter la reconnexion automatique
    _cancelReconnectTimer(); // Annuler le timer de reconnexion
    _reconnectAttempts = 0; // Reset le compteur

    if (_initialized && _socket != null) {
      debugPrint("🛑 Disconnection et clean socket");
      _socket!.disconnect();
      _socket!.dispose();
      _initialized = false;
      _socket = null;
      _typingObservers.clear();
    } else {
      debugPrint("🟡 Dispose appelé sans socket actif");
    }

    _currentToken = null;
  }

  bool get isConnected => _initialized && _socket != null && _socket!.connected;

  // ---------- 🔥 Ajoute ceci 🔥 ---------------
  void registerTypingObserver(String relationId, void Function(bool isTyping, String userId) cb) {
    _typingObservers.putIfAbsent(relationId, () => []);
    if (!_typingObservers[relationId]!.contains(cb)) {
      _typingObservers[relationId]!.add(cb);
    }
  }

  void unregisterTypingObserver(String relationId, [void Function(bool, String)? cb]) {
    if (cb == null) {
      _typingObservers.remove(relationId);
    } else {
      _typingObservers[relationId]?.remove(cb);
      if (_typingObservers[relationId]?.isEmpty ?? false) {
        _typingObservers.remove(relationId);
      }
    }
  }

  void _setupGlobalTypingListeners() {
    final socket = this.socket;
    socket.off('typing');
    socket.off('stopTyping');

    socket.on('typing', (data) {
      final relId = data['relationId']?.toString();
      final userId = data['userId']?.toString();
      if (relId != null && _typingObservers.containsKey(relId)) {
        for (final cb in _typingObservers[relId]!) {
          cb(true, userId ?? "");
        }
      }
    });

    socket.on('stopTyping', (data) {
      final relId = data['relationId']?.toString();
      final userId = data['userId']?.toString();
      if (relId != null && _typingObservers.containsKey(relId)) {
        for (final cb in _typingObservers[relId]!) {
          cb(false, userId ?? "");
        }
      }
    });
  }

  /// Configure les listeners pour les événements d'amis
  void _setupFriendListeners() {
    if (_socket == null) return;

    // Nouvelle demande d'ami reçue
    _socket!.on('friendRequestReceived', (data) {
      debugPrint('👥 Demande d\'ami reçue: $data');
      for (final observer in _friendRequestObservers) {
        observer(Map<String, dynamic>.from(data));
      }
    });

    // Demande d'ami acceptée
    _socket!.on('friendRequestAccepted', (data) {
      debugPrint('✅ Demande d\'ami acceptée: $data');
      for (final observer in _friendAcceptedObservers) {
        observer(Map<String, dynamic>.from(data));
      }
    });

    // Ami supprimé
    _socket!.on('friendRemoved', (data) {
      debugPrint('💔 Ami supprimé: $data');
      for (final observer in _friendRemovedObservers) {
        observer(Map<String, dynamic>.from(data));
      }
    });
  }

  /// Ajouter un observateur pour les demandes d'amis
  void addFriendRequestObserver(void Function(Map<String, dynamic>) callback) {
    _friendRequestObservers.add(callback);
  }

  /// Supprimer un observateur pour les demandes d'amis
  void removeFriendRequestObserver(void Function(Map<String, dynamic>) callback) {
    _friendRequestObservers.remove(callback);
  }

  /// Ajouter un observateur pour les acceptations d'amis
  void addFriendAcceptedObserver(void Function(Map<String, dynamic>) callback) {
    _friendAcceptedObservers.add(callback);
  }

  /// Supprimer un observateur pour les acceptations d'amis
  void removeFriendAcceptedObserver(void Function(Map<String, dynamic>) callback) {
    _friendAcceptedObservers.remove(callback);
  }

  /// Ajouter un observateur pour les suppressions d'amis
  void addFriendRemovedObserver(void Function(Map<String, dynamic>) callback) {
    _friendRemovedObservers.add(callback);
  }

  /// Supprimer un observateur pour les suppressions d'amis
  void removeFriendRemovedObserver(void Function(Map<String, dynamic>) callback) {
    _friendRemovedObservers.remove(callback);
  }

  /// Programmer la reconnexion automatique avec délai progressif
  void _scheduleReconnect() {
    if (!_shouldReconnect || _currentToken == null) {
      return; // Ne pas reconnecter si dispose() a été appelé ou pas de token
    }

    // Vérifier la limite de tentatives
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ Limite de tentatives de reconnexion atteinte ($_maxReconnectAttempts). Arrêt de la reconnexion automatique.');
      _shouldReconnect = false;
      return;
    }

    // Annuler le timer précédent s'il existe
    _cancelReconnectTimer();

    // Délai progressif : 2s, 5s, 10s, 20s, puis 30s
    final delayIndex = _reconnectAttempts.clamp(0, _reconnectDelays.length - 1);
    final delay = _reconnectDelays[delayIndex];

    debugPrint('🔄 Reconnexion programmée dans ${delay}s (tentative ${_reconnectAttempts + 1}/$_maxReconnectAttempts)');
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _attemptReconnect();
    });
  }

  /// Annuler le timer de reconnexion
  void _cancelReconnectTimer() {
    if (_reconnectTimer != null) {
      _reconnectTimer!.cancel();
      _reconnectTimer = null;
    }
  }

  /// Tenter de se reconnecter
  void _attemptReconnect() async {
    if (!_shouldReconnect || _currentToken == null) {
      return; // Ne pas reconnecter si dispose() a été appelé ou pas de token
    }

    if (_socket != null && _socket!.connected) {
      debugPrint('✅ Socket déjà connecté, annulation de la reconnexion');
      _reconnectAttempts = 0; // Reset si déjà connecté
      return;
    }

    _reconnectAttempts++; // Incrémenter le compteur de tentatives
    debugPrint('🔄 Tentative de reconnexion #$_reconnectAttempts...');

    try {
      // 🔥 NOUVEAU : Rafraîchir le token avant la reconnexion
      debugPrint('🔄 Vérification et rafraîchissement du token...');
      final tokenRefreshed = await AuthService.refreshTokenIfNeeded();

      if (!tokenRefreshed) {
        debugPrint('❌ Impossible de rafraîchir le token - arrêt de la reconnexion');
        _shouldReconnect = false;
        return;
      }

      // Récupérer le token frais
      final freshToken = await AuthService.getToken();
      if (freshToken == null) {
        debugPrint('❌ Aucun token disponible après rafraîchissement');
        _shouldReconnect = false;
        return;
      }

      // Mettre à jour le token stocké
      _currentToken = freshToken;
      debugPrint('✅ Token rafraîchi pour la reconnexion');

      // Nettoyer l'ancienne connexion si elle existe
      if (_socket != null) {
        _socket!.disconnect();
        _socket!.dispose();
      }

      // Recréer la connexion avec le token frais
      final socketUrl = ApiConfig.baseUrl.replaceAll('/api', '');
      _socket = io.io(
        socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableReconnection()
            .disableAutoConnect()
            .setAuth({'token': _currentToken!})
            .build(),
      );

      _socket!.connect();
      _socket!.onConnect((_) {
        debugPrint('✅ Reconnexion réussie !');
        _reconnectAttempts = 0; // Reset le compteur de tentatives
        _cancelReconnectTimer(); // Annuler le timer si on se reconnecte
      });
      _socket!.onDisconnect((_) {
        debugPrint('❌ Socket déconnecté après reconnexion');
        _scheduleReconnect(); // Programmer une nouvelle reconnexion
      });
      _socket!.onConnectError((err) {
        debugPrint('⛔ Erreur de reconnexion : $err');
        // Vérifier si c'est une erreur d'authentification
        if (err.toString().contains('unauthorized') || err.toString().contains('invalid token')) {
          debugPrint('🔑 Erreur d\'authentification détectée - token probablement expiré');
        }
        _scheduleReconnect(); // Programmer une nouvelle reconnexion
      });
      _socket!.onError((err) => debugPrint('⛔ Erreur socket après reconnexion : $err'));

      // Reconfigurer les listeners
      _setupGlobalTypingListeners();
      _setupFriendListeners();

    } catch (e) {
      debugPrint('❌ Erreur lors de la tentative de reconnexion : $e');
      _scheduleReconnect(); // Programmer une nouvelle tentative
    }
  }

  /// Forcer une reconnexion immédiate (méthode publique)
  void forceReconnect() {
    debugPrint('🔄 Reconnexion forcée demandée');
    _cancelReconnectTimer();
    _reconnectAttempts = 0; // Reset le compteur pour une reconnexion forcée
    _shouldReconnect = true; // Réactiver la reconnexion
    _attemptReconnect();
  }

  /// Réinitialiser complètement la connexion (pour les cas extrêmes)
  Future<void> resetConnection() async {
    debugPrint('🔄 Réinitialisation complète de la connexion');

    // Arrêter la reconnexion automatique
    _shouldReconnect = false;
    _cancelReconnectTimer();

    // Nettoyer la connexion actuelle
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    // Récupérer un token frais
    final tokenRefreshed = await AuthService.refreshTokenIfNeeded();
    if (!tokenRefreshed) {
      debugPrint('❌ Impossible de rafraîchir le token pour la réinitialisation');
      return;
    }

    final freshToken = await AuthService.getToken();
    if (freshToken == null) {
      debugPrint('❌ Aucun token disponible pour la réinitialisation');
      return;
    }

    // Réinitialiser les compteurs et redémarrer
    _reconnectAttempts = 0;
    _currentToken = freshToken;
    _shouldReconnect = true;

    // Recréer la connexion
    initSocket(freshToken);

    debugPrint('✅ Connexion réinitialisée avec succès');
  }

  /// Arrêter la reconnexion automatique
  void stopReconnection() {
    _shouldReconnect = false;
    _cancelReconnectTimer();
    debugPrint('🛑 Reconnexion automatique arrêtée');
  }

  /// Redémarrer la reconnexion automatique
  void startReconnection() {
    _shouldReconnect = true;
    if (!isConnected) {
      _scheduleReconnect();
    }
    debugPrint('🔄 Reconnexion automatique redémarrée');
  }

  /// Mettre à jour le token et forcer une reconnexion si nécessaire
  void updateToken(String newToken) {
    debugPrint('🔑 Mise à jour du token pour le socket');
    _currentToken = newToken;

    // Si le socket n'est pas connecté, tenter une reconnexion immédiate
    if (_socket == null || !_socket!.connected) {
      debugPrint('🔄 Socket déconnecté - tentative de reconnexion avec nouveau token');
      forceReconnect();
    }
  }
}
