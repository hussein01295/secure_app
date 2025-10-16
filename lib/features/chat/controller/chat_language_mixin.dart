// ***************************************************************************
//  CHAT — REFACTO MODULAIRE EN MIXINS PAR SECTIONS  (VERSION CORRIGÉE)
//  ---------------------------------------------------------------------------
//  ✅ Mixins génériques (<T extends StatefulWidget>) pour éviter les conflits
//  ✅ Méthodes d'init publiques pour éviter collisions de noms privés
//  ✅ Délégations ChatService via Future.sync pour éviter use_of_void_result
// ***************************************************************************

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/service/socket_service.dart';
import 'package:silencia/core/service/ephemeral_service.dart';
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/utils/lang_map_generator.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';
import 'package:silencia/core/utils/rsa_serrvice.dart'; 
import 'package:silencia/core/services/auto_backup_service.dart';
import 'package:silencia/core/services/local_language_backup_service.dart';
import 'package:silencia/features/chat/chat_service.dart';
import 'package:silencia/features/chat/controller/chat_vars.dart';

mixin ChatLanguagesMixin<T extends StatefulWidget> on ChatVars<T> {
  Future<void> generateAndSendLangMap() async {
    debugPrint('🚀 generateAndSendLangMap: Début génération (MULTI-LANGUES)');

    String? existingMediaKey = await ChatService.getMediaKey(relationId);

    Map<String, dynamic> package;
    String mediaKeyGenerated;

    // 🔑 Génération aléatoire sécurisée des langues
    debugPrint('🔑 generateAndSendLangMap: Génération aléatoire pour $userId');
    package = LangMapGenerator.generateLanguagePackage();

    if (existingMediaKey != null) {
      package['mediaKey'] = existingMediaKey;
      mediaKeyGenerated = existingMediaKey;
    } else {
      mediaKeyGenerated = package['mediaKey'] as String;
    }

    if (package.containsKey('languages') && package['version'] == '2.0') {
      multiLanguages = Map<String, Map<String, String>>.from(
        (package['languages'] as Map).map(
          (k, v) => MapEntry(k.toString(), Map<String, String>.from(v)),
        ),
      );
      isMultiLanguageMode = true;
    }

    await ChatService.saveLanguagePackage(langMapKey, package);
    await ChatService.saveMediaKey(relationId, mediaKeyGenerated);
    mediaKeyInternal = mediaKeyGenerated;

    await loadLanguageMap();

    final token = await AuthService.getToken();
    final publicKey = await RSAKeyService.fetchPublicKey(contactId, token!);
    if (publicKey == null) throw Exception("Clé publique de l'ami introuvable");

    final String packageJson = jsonEncode(package);

    await AutoBackupService.handleLanguageGenerated(
      relationId: relationId,
      userId: userId,
      packageJson: packageJson,
    );
    await LocalLanguageBackupService.updateBackupFromSecureStorageIfEnabled();

    final hybrid = RSAKeyService.hybridEncrypt(packageJson, publicKey);

    if (!mounted) return;
    final headers = await AuthService.getAuthorizedHeaders(context: context);
    final url = Uri.parse('${ApiConfig.baseUrl}/lang/$relationId/send');
    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'encrypted': hybrid['encrypted'],
        'iv': hybrid['iv'],
        'encryptedKey': hybrid['encryptedKey'],
        'from': userId,
        'to': contactId,
      }),
    );
    if (res.statusCode == 200) {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/lang/$relationId/mark-generate'),
        headers: headers,
      );
      await refreshLangStatus();
    } else {
      debugPrint('Erreur d\'envoi : ${res.body}');
    }
  }

  Future<bool> fetchAndStoreLangMapFromBackend() async {
    if (!mounted) return false;
    final headers = await AuthService.getAuthorizedHeaders(context: context);
    final url = Uri.parse('${ApiConfig.baseUrl}/lang/$relationId/fetch');
    final res = await http.get(url, headers: headers);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      final storage = const FlutterSecureStorage();
      final privateKey = await storage.read(key: 'rsa_private_key');
      if (privateKey == null)
        throw Exception("Clé privée non trouvée sur l'appareil");

      final decrypted = RSAKeyService.hybridDecrypt(data, privateKey);
      final packageData = jsonDecode(decrypted);

      Map<String, String>? receivedLangMap;

      if (packageData is Map) {
        if (MultiLanguageManager.isMultiLanguagePackage(
          Map<String, dynamic>.from(packageData),
        )) {
          final package = Map<String, dynamic>.from(packageData);
          final languages = Map<String, Map<String, String>>.from(
            (package['languages'] as Map).map(
              (k, v) => MapEntry(k.toString(), Map<String, String>.from(v)),
            ),
          );
          multiLanguages = languages;
          isMultiLanguageMode = true;
          receivedLangMap = languages.values.first;
          await ChatService.saveLanguagePackage(langMapKey, package);
          await AutoBackupService.handleLanguageImported(
            relationId: relationId,
            userId: userId,
            packageJson: jsonEncode(package),
          );
          if (package.containsKey('mediaKey')) {
            final mediaKey = package['mediaKey'] as String;
            await ChatService.saveMediaKey(relationId, mediaKey);
            mediaKeyInternal = mediaKey;
          }
        } else if (packageData.containsKey('langMap') &&
            packageData.containsKey('mediaKey')) {
          final package = Map<String, dynamic>.from(packageData);
          receivedLangMap = Map<String, String>.from(package['langMap']);
          final receivedMediaKey = package['mediaKey'] as String;

          await ChatService.saveLanguagePackage(langMapKey, package);
          await AutoBackupService.handleLanguageImported(
            relationId: relationId,
            userId: userId,
            packageJson: jsonEncode(package),
          );

          final existingMediaKey = await ChatService.getMediaKey(relationId);
          if (existingMediaKey == null) {
            await ChatService.saveMediaKey(relationId, receivedMediaKey);
            mediaKeyInternal = receivedMediaKey;
          }
        } else {
          receivedLangMap = Map<String, String>.from(packageData);
          final compatiblePackage = {
            'langMap': receivedLangMap,
            'mediaKey': null,
            'timestamp': DateTime.now().toIso8601String(),
            'version': '1.0',
            'warning':
                'Ancien format sans clé média - anciens messages non déchiffrables',
          };
          await ChatService.saveLanguagePackage(langMapKey, compatiblePackage);
          await AutoBackupService.handleLanguageImported(
            relationId: relationId,
            userId: userId,
            packageJson: jsonEncode(compatiblePackage),
          );
        }
      }

      await http.delete(url, headers: headers);

      if (mounted) {
        setState(() {
          langMap = receivedLangMap;
        });
      }

      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/lang/$relationId/mark-generate'),
        headers: headers,
      );
      await refreshLangStatus();
      return true;
    }
    return false;
  }

  Future<void> markLangGenerate({bool forceNew = false}) async {
    final headers = await AuthService.getAuthorizedHeaders(context: context);
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/lang/$relationId/mark-generate',
    );

    try {
      final body = forceNew ? jsonEncode({'forceNew': true}) : null;
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['shouldFetchLanguage'] == true) {
          await _fetchExistingLanguage();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '🤖 Langue récupérée automatiquement - Vous pouvez maintenant écrire !',
                ),
              ),
            );
            setState(() {});
          }
        } else if (data['isFirstGenerator'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  forceNew
                      ? '🔄 Nouvelle langue générée - Vous pouvez maintenant écrire !'
                      : '🤖 Langue générée automatiquement - Vous pouvez maintenant écrire !',
                ),
              ),
            );
            setState(() {});
          }
        }
        await refreshLangStatus();
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du marquage de génération: $e');
    }
  }

  Future<void> markLangSuccess() async {
    try {
      final headers = await AuthService.getAuthorizedHeaders(context: context);
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/lang/$relationId/mark-success',
      );
      final res = await http.post(url, headers: headers);
      if (res.statusCode != 200) {
        await markLangGenerate();
      }
    } catch (_) {
      await markLangGenerate();
    }
  }

  Future<void> _fetchExistingLanguage() async {
    try {
      final headers = await AuthService.getAuthorizedHeaders(context: context);
      final url = Uri.parse('${ApiConfig.baseUrl}/lang/$relationId/fetch');
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['payload'] != null) {
          final success = await _decryptAndSaveLanguage(
            Map<String, dynamic>.from(data['payload']),
          );
          if (success) {
            await markLangSuccess();
            await refreshLangStatus();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération de la langue: $e');
    }
  }

  Future<bool> _decryptAndSaveLanguage(Map<String, dynamic> payload) async {
    try {
      const storage = FlutterSecureStorage();
      final privateKey = await storage.read(key: 'rsa_private_key');
      if (privateKey == null) {
        throw Exception('Clé privée non trouvée');
      }

      final packageJson = RSAKeyService.hybridDecrypt(payload, privateKey);
      final packageData = jsonDecode(packageJson);
      String syncPayload = packageJson;

      Map<String, String> receivedLangMap;
      if (packageData is Map &&
          packageData.containsKey('langMap') &&
          packageData.containsKey('mediaKey')) {
        final package = Map<String, dynamic>.from(packageData);
        receivedLangMap = Map<String, String>.from(package['langMap']);
        final receivedMediaKey = package['mediaKey'] as String;
        await ChatService.saveLanguagePackage(langMapKey, package);
        syncPayload = jsonEncode(package);
        final existingMediaKey = await ChatService.getMediaKey(relationId);
        if (existingMediaKey == null) {
          await ChatService.saveMediaKey(relationId, receivedMediaKey);
          mediaKeyInternal = receivedMediaKey;
        }
      } else {
        receivedLangMap = Map<String, String>.from(packageData);
        final compatiblePackage = {
          'langMap': receivedLangMap,
          'mediaKey': null,
          'timestamp': DateTime.now().toIso8601String(),
          'version': '1.0',
          'warning':
              'Ancien format sans clé média - anciens messages non déchiffrables',
        };
        await ChatService.saveLanguagePackage(langMapKey, compatiblePackage);
        syncPayload = jsonEncode(compatiblePackage);
      }

      await AutoBackupService.handleLanguageImported(
        relationId: relationId,
        userId: userId,
        packageJson: syncPayload,
      );

      if (mounted) {
        setState(() {
          langMap = receivedLangMap;
        });
      }
      return true;
    } catch (e) {
      debugPrint('❌ Erreur lors du déchiffrement: $e');
      return false;
    }
  }

  // ---- Délégations vers ChatService (protégées contre use_of_void_result)
  @override
  Future<void> refreshLangStatus() async {
    ChatService.refreshLangStatus(this);
  }

  Future<void> postLangLost() async {
    ChatService.postLangLost(this);
  }

  Future<void> loadLanguageMap() async {
    ChatService.loadLanguageMap(this);
  }

  Future<void> removeLanguageMap() async {
    ChatService.removeLanguageMap(this);
  }

  Future<void> loadMediaKey() async {
    mediaKeyInternal = await ChatService.getMediaKey(relationId);
  }

  Future<Map<String, dynamic>?> getDebugLocalData() async {
    try {
      final result = <String, dynamic>{};
      final package = await ChatService.getLanguagePackage(langMapKey);
      if (package != null) {
        result['localPackage'] = package;
        result['packageType'] = 'complete';
      } else {
        final legacy = await ChatService.getLangMap(langMapKey);
        if (legacy != null) {
          result['localPackage'] = {'langMap': legacy};
          result['packageType'] = 'legacy';
        }
      }
      final mediaKey = await ChatService.getMediaKey(relationId);
      if (mediaKey != null) {
        result['localMediaKey'] = mediaKey;
      }

      try {
        if (!mounted) return null;
        final headers = await AuthService.getAuthorizedHeaders(
          context: context,
        );
        final url = Uri.parse('${ApiConfig.baseUrl}/lang/$relationId/fetch');
        final res = await http.get(url, headers: headers);
        if (res.statusCode == 200) {
          result['databasePayload'] = jsonDecode(res.body);
        }
      } catch (_) {}

      return result.isNotEmpty ? result : null;
    } catch (e) {
      debugPrint('❌ Erreur récupération données locales debug: $e');
      return null;
    }
  }

  void toggleTranslation() {
    if (!mounted) return;
    setState(() => estTraduit = !estTraduit);
  }

  // ---- Bootstrap auto langue (noms publics)
  Future<void> unattendedLangInit() async {
    try {
      await refreshLangStatus();
      await loadLanguageMap();
      await _bootstrapLangHandshake();
    } catch (e, st) {
      debugPrint('bootstrap error: $e\n$st');
    }
  }

  Future<bool> _tryFetchPendingLang() async {
    try {
      return await fetchAndStoreLangMapFromBackend();
    } catch (_) {
      return false;
    }
  }

  Future<void> _bootstrapLangHandshake() async {
    if (bootstrappedLang || !mounted) return;
    bootstrappedLang = true;

    if (langMap != null) {
      return;
    }

    final fetched = await _tryFetchPendingLang();
    if (fetched) {
      return;
    }

    if (langMap == null && myLangStatus == "lost") {
      await generateAndSendLangMap();
      await markLangGenerate();
    }
  }

  Future<void> ensureLanguageFlow(BuildContext context) async {
    if (langMap != null) return;

    final messenger = ScaffoldMessenger.of(context);

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text("Langue codée indisponible"),
              subtitle: Text("Choisis une option pour sécuriser le canal"),
            ),
            ListTile(
              leading: const Icon(Icons.bolt),
              title: const Text("Générer une nouvelle langue (vous)"),
              onTap: () => Navigator.pop(context, 'generate'),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(
                "Demander à ${data.contactName} de renvoyer la langue",
              ),
              onTap: () => Navigator.pop(context, 'request'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'generate') {
      await generateAndSendLangMap();
      await markLangGenerate(forceNew: true);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Nouvelle langue générée et envoyée')),
      );
    } else if (choice == 'request') {
      final ok = await ChatService.requestLangResend(this);
      if (ok) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Demande envoyée à ${data.contactName}')),
        );
        Future.delayed(const Duration(seconds: 20), () async {
          if (!mounted) return;
          if (langMap == null) {
            await generateAndSendLangMap();
            await markLangGenerate();
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(
                content: Text("Pas de réponse — nouvelle langue générée."),
              ),
            );
          }
        });
      }
    }
  }
}
