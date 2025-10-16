import 'package:flutter/material.dart'; 
import '../../core/utils/encryption_helper.dart';

/// Mixin propre et indépendant de `State<T>`
/// Tous les getters sont abstraits et doivent être fournis par le `ChatController`
mixin ChatSocketHandler {
  // --- Contexte & état ---
  BuildContext get context;
  bool get mounted;
  void setState(VoidCallback fn);

  // --- Données nécessaires ---
  String get userId;
  String get relationId;
  String? get mediaKey;
  List<Map<String, dynamic>> get chatMessages;
  ScrollController get chatScrollController;

  // --- Méthodes exposées ---
  void refreshLangStatus();
  dynamic getSocket();

  // --- Gestion d’un nouveau message reçu ---
  void onNewMessage(dynamic data) {
    if (data == null || data['sender'] == userId || data['relationId'] != relationId) return;

    String decrypted = '';
    if (mediaKey != null) {
      try {
        decrypted = EncryptionHelper.decryptText(data['content'], mediaKey!);
      } catch (_) {
        decrypted = '[Erreur de décryptage]';
      }
    } else {
      decrypted = '[Pas de clé média]';
    }

    if (!mounted) return;
    setState(() {
      chatMessages.add({
        'text': decrypted,
        'fromMe': false,
        'time': (data['timestamp'] != null && data['timestamp'].toString().length > 11)
            ? data['timestamp'].toString().substring(11, 16)
            : TimeOfDay.now().format(context),
      });
    });
    scrollToBottom();
  }

  // --- Mise à jour du statut de la langue ---
  void onLangStatusUpdate(dynamic payload) {
    if (payload == null) return;
    if (payload['pairId'] == relationId) {
      refreshLangStatus();
    }
  }

  // --- Scroll automatique vers le bas ---
  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatScrollController.hasClients) {
        chatScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
