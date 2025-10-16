import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/service/notification_service.dart';
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/utils/rsa_serrvice.dart';
import 'package:silencia/features/chat/chat_service.dart';

class LanguageRequestHandler {
  static final LanguageRequestHandler _instance = LanguageRequestHandler._internal();
  factory LanguageRequestHandler() => _instance;
  LanguageRequestHandler._internal();

  /// Vérifie s'il y a une demande de langue en attente et la traite
  Future<void> checkPendingLanguageRequest(BuildContext context) async {
    final request = NotificationService().getPendingLanguageRequest();
    if (request != null) {
      await _handleLanguageRequest(context, request);
    }
  }

  /// Traite une demande de langue reçue via notification push
  Future<void> _handleLanguageRequest(BuildContext context, Map<String, dynamic> request) async {
    final relationId = request['relationId'] as String;
    final contactName = request['contactName'] as String;
    final requesterId = request['requesterId'] as String;
    final targetId = request['targetId'] as String;

    // Vérifier que cette demande est bien pour l'utilisateur actuel
    final currentUserId = await AuthService.getUserId();
    if (currentUserId != targetId) {
      debugPrint('Demande de langue non destinée à cet utilisateur');
      return;
    }

    // Afficher la dialog de demande de langue
    if (!context.mounted) return;
    
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("$contactName demande la langue"),
        content: const Text("Voulez-vous renvoyer votre langue codée ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'decline'),
            child: const Text('Refuser'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'accept'),
            child: const Text('Renvoyer'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    if (action == 'accept') {
      await _acceptLanguageRequest(context, relationId, requesterId);
    } else if (action == 'decline') {
      await _declineLanguageRequest(relationId);
    }
  }

  /// Accepte la demande de langue et renvoie la langue
  Future<void> _acceptLanguageRequest(BuildContext context, String relationId, String requesterId) async {
    try {
      // Récupérer le package complet local (langue + clé média)
      final langMapKey = 'langMap-$relationId';
      debugPrint('🔍 _acceptLanguageRequest: Recherche package avec clé: $langMapKey');

      // Essayer d'abord le nouveau format (package complet)
      final package = await ChatService.getLanguagePackage(langMapKey);
      debugPrint('📦 _acceptLanguageRequest: Package trouvé: ${package != null}');
      if (package != null) {
        debugPrint('📦 _acceptLanguageRequest: Contenu package: ${package.keys}');
      }

      Map<String, dynamic>? packageToSend;

      // ✅ NOUVEAU: Priorité au format v2.0 (10 langues)
      if (package != null && package.containsKey('languages') && package['version'] == '2.0') {
        // Format v2.0 avec 10 langues + AAD
        packageToSend = Map<String, dynamic>.from(package);
        final languages = package['languages'] as Map<String, dynamic>;
        debugPrint('✅ _acceptLanguageRequest: Package v2.0 trouvé avec ${languages.length} langues');
        debugPrint('🔑 _acceptLanguageRequest: Clé média incluse: ${package.containsKey('mediaKey')}');
        debugPrint('🌐 _acceptLanguageRequest: AADs disponibles: ${languages.keys.toList()}');
      } else if (package != null && package.containsKey('langMap')) {
        // Format v1.0 avec langue unique (rétrocompatibilité)
        packageToSend = Map<String, dynamic>.from(package);
        final langMap = Map<String, String>.from(package['langMap']);
        debugPrint('✅ _acceptLanguageRequest: Package v1.0 trouvé avec ${langMap.length} entrées');
        debugPrint('🔑 _acceptLanguageRequest: Clé média incluse: ${package.containsKey('mediaKey')}');
      } else {
        // Fallback vers l'ancien format stocké séparément
        debugPrint('🔄 _acceptLanguageRequest: Tentative fallback vers ancien format');
        final langMap = await ChatService.getLangMap(langMapKey);
        debugPrint('🔄 _acceptLanguageRequest: Ancien format trouvé: ${langMap != null}');

        if (langMap != null) {
          debugPrint('✅ _acceptLanguageRequest: Ancien format trouvé avec ${langMap.length} entrées');

          // Créer un package v1.0 avec la langue + clé média locale si disponible
          packageToSend = {
            'langMap': langMap,
            'version': '1.0',
            'timestamp': DateTime.now().toIso8601String(),
          };

          // Essayer de récupérer la clé média locale
          final localMediaKey = await ChatService.getMediaKey(relationId);
          if (localMediaKey != null) {
            packageToSend['mediaKey'] = localMediaKey;
            debugPrint('🔑 _acceptLanguageRequest: Clé média locale ajoutée au package v1.0');
          } else {
            debugPrint('⚠️ _acceptLanguageRequest: Aucune clé média locale trouvée');
          }
        }
      }

      if (packageToSend == null) {
        debugPrint('❌ _acceptLanguageRequest: AUCUN package trouvé dans tous les formats');
        debugPrint('❌ _acceptLanguageRequest: Clé recherchée: $langMapKey');
        debugPrint('❌ _acceptLanguageRequest: Package: $package');

        // Debug: essayer quelques variations de clés
        debugPrint('🔍 _acceptLanguageRequest: Test de variations de clés...');
        final testKeys = [
          'langMap-$relationId',
          'langMap_$relationId',
          relationId,
          'language-$relationId',
          'lang-$relationId'
        ];

        for (final testKey in testKeys) {
          final testPackage = await ChatService.getLanguagePackage(testKey);
          final testMap = await ChatService.getLangMap(testKey);
          debugPrint('🔍 Test clé "$testKey": package=${testPackage != null}, map=${testMap != null}');

          // Si on trouve un package v2.0, l'utiliser
          if (testPackage != null && testPackage['version'] == '2.0') {
            packageToSend = testPackage;
            debugPrint('✅ _acceptLanguageRequest: Package v2.0 trouvé avec clé alternative: $testKey');
            break;
          }
        }

        throw Exception("Langue locale introuvable - Aucun format disponible pour relationId: $relationId");
      }

      // ✅ NOUVEAU: Vérifier le type de package avant envoi
      final packageVersion = packageToSend['version'] ?? 'unknown';
      if (packageVersion == '2.0') {
        final languages = packageToSend['languages'] as Map<String, dynamic>;
        debugPrint('📦 _acceptLanguageRequest: Envoi package v2.0 avec ${languages.length} langues');
        debugPrint('🌐 _acceptLanguageRequest: AADs: ${languages.keys.toList()}');
      } else if (packageVersion == '1.0') {
        debugPrint('📦 _acceptLanguageRequest: Envoi package v1.0 (rétrocompatibilité)');
      } else {
        debugPrint('⚠️ _acceptLanguageRequest: Version de package inconnue: $packageVersion');
      }

      // Récupérer la clé publique du demandeur
      final token = await AuthService.getToken();
      final publicKeyA = await RSAKeyService.fetchPublicKey(requesterId, token!);
      if (publicKeyA == null) {
        throw Exception("Clé publique du demandeur introuvable");
      }

      // Chiffrer et envoyer le package complet (langue + clé média)
      final packageJson = jsonEncode(packageToSend);
      final hybrid = RSAKeyService.hybridEncrypt(packageJson, publicKeyA);

      debugPrint('📦 _acceptLanguageRequest: Envoi du package complet');
      debugPrint('📦 _acceptLanguageRequest: Contenu: ${packageToSend.keys}');

      if (!context.mounted) return;
      final headers = await AuthService.getAuthorizedHeaders(context: context);
      final url = Uri.parse('${ApiConfig.baseUrl}/lang/$relationId/send');
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'encrypted': hybrid['encrypted'],
          'iv': hybrid['iv'],
          'encryptedKey': hybrid['encryptedKey'],
          'from': await AuthService.getUserId(),
          'to': requesterId,
        }),
      );

      if (response.statusCode == 200) {
        // Marquer comme généré
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/lang/$relationId/mark-generate'),
          headers: headers,
        );

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Langue renvoyée avec succès')),
        );

        // Naviguer vers la conversation
        context.go('/chat', extra: {
          'relationId': relationId,
          'contactId': requesterId,
          'contactName': 'Contact', // Vous pourriez récupérer le vrai nom
        });
      } else {
        throw Exception('Erreur lors de l\'envoi: ${response.statusCode}');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  /// Refuse la demande de langue
  Future<void> _declineLanguageRequest(String relationId) async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/lang/$relationId/decline-resend'),
        headers: headers,
      );

      debugPrint('Demande de langue refusée');
    } catch (e) {
      debugPrint('Erreur lors du refus de la demande: $e');
    }
  }
}
