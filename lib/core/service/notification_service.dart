import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/service/message_notification_handler.dart';
import 'package:silencia/core/service/messages_cache_service.dart';
import 'package:silencia/core/service/profile_cache_service.dart';
import 'package:silencia/core/service/image_cache_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _fcmToken;

  /// Initialise le service de notifications
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Firebase est déjà initialisé dans main.dart
      debugPrint('🔔 Initialisation du service de notifications...');

      // Demander les permissions
      await _requestPermissions();

      // Configurer les notifications locales
      await _initializeLocalNotifications();

      // Configurer Firebase Messaging
      await _initializeFirebaseMessaging();

      // Obtenir et enregistrer le token FCM
      await _registerFCMToken();

      _initialized = true;
      debugPrint('✅ NotificationService initialisé avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation des notifications: $e');
    }
  }

  /// Demande les permissions pour les notifications
  Future<void> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Permission accordée: ${settings.authorizationStatus}');
  }

  /// Initialise les notifications locales
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Initialise Firebase Messaging
  Future<void> _initializeFirebaseMessaging() async {
    // Gérer les messages en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Gérer les messages quand l'app est au premier plan
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Gérer les messages quand l'app est ouverte depuis une notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Vérifier si l'app a été ouverte depuis une notification
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  /// Obtient et enregistre le token FCM sur le serveur
  Future<void> _registerFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        debugPrint('Token FCM: $_fcmToken');
        await _sendTokenToServer(_fcmToken!);
      }

      // Écouter les changements de token
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _sendTokenToServer(newToken);
      });
    } catch (e) {
      debugPrint('Erreur lors de l\'obtention du token FCM: $e');
    }
  }

  /// Envoie le token FCM au serveur
  Future<void> _sendTokenToServer(String token) async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/users/fcm-token'),
        headers: headers,
        body: jsonEncode({'fcmToken': token}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Token FCM enregistré sur le serveur');
      } else {
        debugPrint('❌ Erreur lors de l\'enregistrement du token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'envoi du token au serveur: $e');
    }
  }

  /// Gère les messages reçus quand l'app est au premier plan
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Message reçu au premier plan: ${message.notification?.title}');
    _showLocalNotification(message);
  }

  /// Gère les messages quand l'app est ouverte depuis une notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('App ouverte depuis notification: ${message.data}');
    _handleNotificationAction(message.data);
  }

  /// Affiche une notification locale avec contenu intelligent
  Future<void> _showLocalNotification(RemoteMessage message) async {
    // Déterminer le canal de notification selon le type
    String channelId = 'default_channel';
    String channelName = 'Notifications générales';
    String channelDescription = 'Notifications générales de l\'application';

    final messageType = message.data['type'];
    if (messageType == 'new_message') {
      channelId = 'messages_channel';
      channelName = 'Messages';
      channelDescription = 'Notifications pour les nouveaux messages';
    } else if (messageType == 'language_request') {
      channelId = 'language_requests';
      channelName = 'Demandes de langue';
      channelDescription = 'Notifications pour les demandes de langue';
    }

    // Préparer le contenu intelligent selon l'état du téléphone
    String notificationBody = await _prepareIntelligentContent(message);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Nouvelle notification',
      notificationBody,
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// Prépare le contenu intelligent selon l'état du téléphone
  Future<String> _prepareIntelligentContent(RemoteMessage message) async {
    final messageType = message.data['type'];

    // Pour les messages normaux, utiliser le contenu par défaut
    if (messageType != 'new_message') {
      return message.notification?.body ?? '';
    }

    // Vérifier si on doit décrypter le contenu
    final shouldDecrypt = await _shouldDecryptContent();

    // Si on ne doit pas décrypter, afficher le contenu crypté
    if (!shouldDecrypt) {
      final encryptedContent = message.data['encryptedContent'];
      if (encryptedContent != null && encryptedContent.isNotEmpty) {
        // Afficher une version tronquée du contenu crypté
        final shortEncrypted = encryptedContent.length > 30
            ? '${encryptedContent.substring(0, 30)}...'
            : encryptedContent;
        return '🔒 $shortEncrypted';
      }
    }

    // 🔄 MIGRATION RSA: Plus de déchiffrement avec sharedKey
    // Le contenu est maintenant chiffré avec mediaKey côté client
    // En mode sécurisé, on affiche le contenu crypté pour la notification
    try {
      final encryptedContent = message.data['encryptedContent'];

      if (encryptedContent != null && encryptedContent.isNotEmpty) {
        // Afficher une version tronquée du contenu pour la notification
        final shortContent = encryptedContent.length > 50
            ? '${encryptedContent.substring(0, 50)}...'
            : encryptedContent;
        return '🔒 $shortContent';
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la préparation du contenu pour notification: $e');
    }

    // Fallback vers le contenu par défaut
    return message.notification?.body ?? 'Nouveau message';
  }

  /// Détecte si l'appareil est déverrouillé
  Future<bool> _isDeviceUnlocked() async {
    try {
      // Méthode 1: Vérifier l'état de l'application
      final appLifecycleState = WidgetsBinding.instance.lifecycleState;
      final isAppActive = appLifecycleState == AppLifecycleState.resumed;

      debugPrint('🔍 État de l\'app: $appLifecycleState');

      if (isAppActive) {
        // Si l'app est active et au premier plan, l'appareil est déverrouillé
        debugPrint('✅ Appareil déverrouillé (app active)');
        return true;
      }

      // Méthode 2: Si l'app est en arrière-plan, on assume verrouillé par sécurité
      debugPrint('🔒 Appareil probablement verrouillé (app en arrière-plan)');
      return false;

    } catch (e) {
      debugPrint('❌ Erreur lors de la détection de l\'état de l\'appareil: $e');
      // En cas d'erreur, on assume que l'appareil est verrouillé (plus sécurisé)
      return false;
    }
  }

  /// Force l'affichage du contenu décrypté (pour les tests)
  static bool _forceDecryption = false;

  /// Active/désactive le forçage du décryptage (pour les tests)
  static void setForceDecryption(bool force) {
    _forceDecryption = force;
    debugPrint('🔧 Forçage du décryptage: ${force ? "ACTIVÉ" : "DÉSACTIVÉ"}');
  }

  /// Vérifie si on doit décrypter le contenu
  Future<bool> _shouldDecryptContent() async {
    // Si le forçage est activé, toujours décrypter
    if (_forceDecryption) {
      debugPrint('🔧 Décryptage forcé activé');
      return true;
    }

    // Sinon, vérifier l'état de l'appareil
    return await _isDeviceUnlocked();
  }

  /// Gère le tap sur une notification
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      _handleNotificationAction(data);
    }
  }

  /// Gère les actions basées sur le type de notification
  void _handleNotificationAction(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'language_request':
        // Naviguer vers la conversation concernée pour la demande de langue
        final relationId = data['relationId'];
        final contactId = data['contactId'];
        final contactName = data['contactName'] ?? 'Contact';
        debugPrint('Ouvrir conversation pour demande de langue: $relationId');
        _navigateToLanguageRequest(relationId, contactId, contactName, data);
        break;
      case 'new_message':
        // Utiliser le handler de notifications de messages
        debugPrint('📱 Traitement notification de message');
        MessageNotificationHandler.instance.handleMessageNotification(data);
        break;
      case 'friend_request':
        // Naviguer vers la page des demandes d'amis
        final senderName = data['senderName'] ?? 'Utilisateur';
        debugPrint('📱 Nouvelle demande d\'ami de: $senderName');
        _navigateToFriendRequests(data);
        break;
      case 'friend_request_accepted':
        // Afficher une notification locale et rafraîchir la liste d'amis
        final accepterName = data['accepterName'] ?? 'Utilisateur';
        debugPrint('📱 Demande d\'ami acceptée par: $accepterName');
        _showFriendNotification(
          'Demande acceptée',
          '$accepterName a accepté votre demande d\'ami',
        );
        break;
      case 'friend_removed':
        // Afficher une notification locale et rafraîchir la liste d'amis
        final removerName = data['removerName'] ?? 'Utilisateur';
        final relationId = data['relationId'];
        final removerId = data['removerId'];

        debugPrint('📱 Supprimé des amis par: $removerName');

        // Supprimer le cache de l'ami qui nous a supprimés
        if (relationId != null && removerId != null) {
          _clearRemovedFriendCache(relationId, removerId);
        }

        _showFriendNotification(
          'Ami supprimé',
          '$removerName vous a retiré de sa liste d\'amis',
        );
        break;
      default:
        debugPrint('Type de notification non géré: $type');
    }
  }

  /// Navigue vers la conversation et affiche la demande de langue
  void _navigateToLanguageRequest(String relationId, String contactId, String contactName, Map<String, dynamic> data) {
    // Cette méthode sera appelée quand l'utilisateur tape sur la notification
    // Elle doit ouvrir l'app et naviguer vers la conversation concernée
    // Pour l'instant, on stocke les données pour les traiter quand l'app s'ouvre
    _pendingLanguageRequest = {
      'relationId': relationId,
      'contactId': contactId,
      'contactName': contactName,
      'requesterId': data['requesterId'],
      'targetId': data['targetId'],
    };
  }

  Map<String, dynamic>? _pendingLanguageRequest;



  /// Récupère et traite une demande de langue en attente
  Map<String, dynamic>? getPendingLanguageRequest() {
    final request = _pendingLanguageRequest;
    _pendingLanguageRequest = null; // Clear après récupération
    return request;
  }

  /// Vérifie et traite les notifications de messages en attente
  Future<void> checkPendingMessageNotifications(BuildContext context) async {
    await MessageNotificationHandler.instance.checkPendingMessageNotifications(context);
  }

  /// Envoie une notification push pour une demande de langue
  static Future<void> sendLanguageRequestNotification({
    required String targetUserId,
    required String relationId,
    required String contactId,
    required String contactName,
    required String requesterId,
  }) async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/notifications/language-request'),
        headers: headers,
        body: jsonEncode({
          'targetUserId': targetUserId,
          'relationId': relationId,
          'contactId': contactId,
          'contactName': contactName,
          'requesterId': requesterId,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Notification de demande de langue envoyée');
      } else {
        debugPrint('❌ Erreur lors de l\'envoi de la notification: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'envoi de la notification: $e');
    }
  }

  /// Getter pour le token FCM
  String? get fcmToken => _fcmToken;

  /// Vérifie si le service est initialisé
  bool get isInitialized => _initialized;
}

/// Handler pour les messages en arrière-plan avec contenu intelligent
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Message reçu en arrière-plan: ${message.notification?.title}');

  // Afficher une notification locale même en arrière-plan
  try {
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

    // Initialisation rapide pour l'arrière-plan
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await localNotifications.initialize(initSettings);

    // Déterminer le canal selon le type de message
    String channelId = 'messages_channel';
    String channelName = 'Messages';

    final messageType = message.data['type'];
    if (messageType == 'language_request') {
      channelId = 'language_requests';
      channelName = 'Demandes de langue';
    }

    // Préparer le contenu intelligent pour l'arrière-plan
    String notificationBody = await _prepareBackgroundIntelligentContent(message);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notifications pour les messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Nouveau message',
      notificationBody,
      details,
    );

    debugPrint('✅ Notification locale intelligente affichée en arrière-plan');
  } catch (e) {
    debugPrint('❌ Erreur lors de l\'affichage de la notification en arrière-plan: $e');
  }
}

/// Prépare le contenu intelligent pour les notifications en arrière-plan
@pragma('vm:entry-point')
Future<String> _prepareBackgroundIntelligentContent(RemoteMessage message) async {
  final messageType = message.data['type'];

  // Pour les messages normaux, utiliser le contenu par défaut
  if (messageType != 'new_message') {
    return message.notification?.body ?? '';
  }

  // En arrière-plan, on assume que l'appareil est verrouillé
  // donc on affiche le contenu crypté par sécurité
  try {
    final encryptedContent = message.data['encryptedContent'];
    if (encryptedContent != null && encryptedContent.isNotEmpty) {
      // Afficher une version tronquée du contenu crypté
      final shortEncrypted = encryptedContent.length > 30
          ? '${encryptedContent.substring(0, 30)}...'
          : encryptedContent;
      return '🔒 $shortEncrypted';
    }
  } catch (e) {
    debugPrint('❌ Erreur lors de la préparation du contenu en arrière-plan: $e');
  }

  // Fallback vers le contenu par défaut
  return message.notification?.body ?? 'Nouveau message';
}

  /// Navigue vers la page des demandes d'amis
  void _navigateToFriendRequests(Map<String, dynamic> data) {
    // Stocker les données pour navigation ultérieure
    _pendingFriendRequest = {
      'relationId': data['relationId'],
      'senderId': data['senderId'],
      'senderName': data['senderName'],
      'senderUsername': data['senderUsername'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    debugPrint('📱 Demande d\'ami stockée pour navigation: ${data['senderName']}');
  }

  /// Affiche une notification locale pour les événements d'amis
  Future<void> _showFriendNotification(String title, String body) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'friends_channel',
        'Amis',
        channelDescription: 'Notifications pour les demandes d\'amis et événements',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await FlutterLocalNotificationsPlugin().show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
      debugPrint('❌ Erreur affichage notification amis: $e');
    }
  }

  Map<String, dynamic>? _pendingFriendRequest;

  /// Récupère la demande d'ami en attente
  Map<String, dynamic>? getPendingFriendRequest() {
    final request = _pendingFriendRequest;
    _pendingFriendRequest = null; // Consommer la demande
    return request;
  }

  /// Supprimer le cache de l'ami qui nous a supprimés
  Future<void> _clearRemovedFriendCache(String relationId, String userId) async {
    try {
      // Créer des instances locales des services de cache
      final messagesCacheService = MessagesCacheService();
      final profileCacheService = ProfileCacheService();
      final imageCacheService = ImageCacheService();

      // Supprimer le cache des messages de cette relation
      await messagesCacheService.clearRelationCache(relationId);

      // Supprimer le cache du profil de cet utilisateur
      await profileCacheService.clearUserCache(userId);

      // Supprimer les images en cache de cet utilisateur
      await imageCacheService.clearUserImages(userId);

      debugPrint('🗑️ Cache supprimé pour l\'ami qui nous a supprimés: $userId');
    } catch (e) {
      debugPrint('❌ Erreur suppression cache ami supprimé: $e');
    }
  }

