import 'dart:io';

import 'package:flutter/material.dart';
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/services/media_encryption_service.dart';
import 'package:silencia/features/chat/chat_service.dart';
import 'package:silencia/features/chat/controller/chat_vars.dart';
import 'package:silencia/features/chat/widgets/media/media_picker_widget.dart';
import 'package:http/http.dart' as http;

mixin ChatMediaMixin<T extends StatefulWidget> on ChatVars<T> {
  Future<void> pickAndSendFile(BuildContext context) async {
    showMediaPicker(
      context,
      onMediaSelected: (file, type, caption) {
        sendMediaMessage(file, type, caption);
      },
    );
  }

  Future<void> sendFileMessage(File file) async {
    final headers = await AuthService.getAuthorizedHeaders(context: context);
    if (headers == null) return;

    final uri = Uri.parse("${ApiConfig.baseUrl}/messages/upload");
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields['receiver'] = contactId
      ..fields['relationId'] = relationId
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();

    if (response.statusCode != 201) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l\'envoi du fichier')),
      );
    }
  }

  Future<void> sendVoiceMessage(File audioFile, int durationSeconds) async {
    final headers = await AuthService.getAuthorizedHeaders(context: context);
    if (headers == null) return;

    final mKey = await ChatService.getMediaKey(relationId);
    File fileToUpload = audioFile;
    bool isEncrypted = false;

    if (mKey != null) {
      try {
        fileToUpload = await MediaEncryptionService.encryptFile(audioFile, mKey);
        isEncrypted = true;
      } catch (e) {
        fileToUpload = audioFile;
        isEncrypted = false;
      }
    }

    final uri = Uri.parse("${ApiConfig.baseUrl}/media/upload");
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields['receiver'] = contactId
      ..fields['relationId'] = relationId
      ..fields['messageType'] = 'voice'
      ..fields['duration'] = durationSeconds.toString()
      ..fields['encrypted'] = isEncrypted.toString();

    request.files.add(await http.MultipartFile.fromPath('file', fileToUpload.path));

    try {
      final response = await request.send();

      if (response.statusCode != 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi du message vocal')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau: $e')),
      );
    } finally {
      // Nettoyer le fichier chiffré si différent de l'original
      if (fileToUpload != audioFile && await fileToUpload.exists()) {
        await MediaEncryptionService.cleanupEncryptedFile(fileToUpload);
      }

      // Nettoyer le fichier audio original (enregistrement temporaire)
      if (await audioFile.exists()) {
        try {
          await audioFile.delete();
        } catch (e) {
          // Ignorer les erreurs de suppression
        }
      }
    }
  }

  Future<void> sendMediaMessage(File file, String type, String? caption) async {
    final headers = await AuthService.getAuthorizedHeaders(context: context);
    if (headers == null) return;

    final mKey = await ChatService.getMediaKey(relationId);
    File fileToUpload = file;

    if (mKey != null) {
      try {
        fileToUpload = await MediaEncryptionService.encryptFile(file, mKey);
      } catch (e) {
        debugPrint('❌ Erreur chiffrement fichier: $e');
        fileToUpload = file;
      }
    }

    final uri = Uri.parse("${ApiConfig.baseUrl}/media/upload");
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields['receiver'] = contactId
      ..fields['relationId'] = relationId;

    if (caption != null && caption.isNotEmpty) {
      request.fields['caption'] = caption;
    }

    if (mKey != null && fileToUpload != file) {
      request.fields['encrypted'] = 'true';
    }

    request.files.add(await http.MultipartFile.fromPath('file', fileToUpload.path));

    try {
      final response = await request.send();
      if (response.statusCode != 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'envoi du ${_getFileTypeLabel(type)}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau: $e')),
      );
    } finally {
      if (fileToUpload != file && await fileToUpload.exists()) {
        await MediaEncryptionService.cleanupEncryptedFile(fileToUpload);
      }
    }
  }

  String _getFileTypeLabel(String type) {
    switch (type) {
      case 'image': return 'image';
      case 'video': return 'vidéo';
      case 'audio': return 'fichier audio';
      case 'document': return 'document';
      default: return 'fichier';
    }
  }
}
