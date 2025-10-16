import 'package:flutter/foundation.dart';

import 'package:silencia/core/utils/encryption_helper.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';
import 'package:silencia/features/chat/chat_utils.dart';

import 'message_repo.dart';

class MessageIndexHelper {
  static Future<void> indexMessages({
    required String relationId,
    required Iterable<Map<String, dynamic>> messages,
    required bool isMultiLanguageMode,
    required Map<String, String>? langMap,
    required Map<String, Map<String, String>>? multiLanguages,
    required String? mediaKey,
    bool logErrors = false,
  }) async {
    if (relationId.isEmpty) return;
    final batch = preparePayload(
      messages: messages,
      isMultiLanguageMode: isMultiLanguageMode,
      langMap: langMap,
      multiLanguages: multiLanguages,
      mediaKey: mediaKey,
    );

    if (batch.isEmpty) return;

    try {
      await MessageRepo.upsertBatch(relationId, batch);
    } catch (e, st) {
      if (logErrors) {
        debugPrint('[MessageIndexHelper] Failed to index messages: $e\n$st');
      }
    }
  }

  static List<Map<String, dynamic>> preparePayload({
    required Iterable<Map<String, dynamic>> messages,
    required bool isMultiLanguageMode,
    required Map<String, String>? langMap,
    required Map<String, Map<String, String>>? multiLanguages,
    required String? mediaKey,
  }) {
    final list = messages
        .where((m) => m.isNotEmpty)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    if (list.isEmpty) return const [];

    final bool hasLangMap = langMap != null && langMap.isNotEmpty;
    final bool hasMultiLanguages =
        multiLanguages != null && multiLanguages.isNotEmpty;

    final result = <Map<String, dynamic>>[];

    for (final map in list) {
      final rawId = map['id'] ?? map['_id'];
      if (rawId == null) continue;
      final id = rawId.toString();
      if (id.isEmpty) continue;

      map['id'] = id;

      final type = (map['messageType'] ?? 'text').toString();
      map['messageType'] = type;
      map['time'] = map['time']?.toString();
      map['timestamp'] ??= DateTime.now().toIso8601String();

      if (type != 'text') {
        final label = '[${type.toUpperCase()}]';
        final codedLabel = (map['coded'] ?? '').toString();
        final decodedLabel = (map['decoded'] ?? '').toString();
        map['coded'] = codedLabel.isNotEmpty ? codedLabel : label;
        map['decoded'] = decodedLabel.isNotEmpty ? decodedLabel : label;
        result.add(map);
        continue;
      }

      String coded = '';
      final codedCandidate = map['coded'] ?? map['text'];
      if (codedCandidate != null) {
        coded = codedCandidate.toString();
      }

      final encryptedAAD = map['encryptedAAD'] as String?;
      final rawContent = (map['content'] ?? '').toString();
      final bool isEncrypted = map['encrypted'] == true;

      String decoded = (map['decoded'] ?? '').toString();
      String decrypted = '';

      if (decoded.isEmpty) {
        if (mediaKey != null &&
            rawContent.isNotEmpty &&
            (isEncrypted || rawContent != coded)) {
          try {
            decrypted = EncryptionHelper.decryptText(rawContent, mediaKey);
          } catch (_) {
            decrypted = rawContent;
          }
        }
        if (decrypted.isEmpty && coded.isNotEmpty) {
          decrypted = coded;
        }
      }

      if (decoded.isEmpty) {
        decoded = decrypted.isNotEmpty ? decrypted : coded;
      }

      try {
        if (isMultiLanguageMode &&
            encryptedAAD != null &&
            hasMultiLanguages &&
            mediaKey != null) {
          final textToProcess = decrypted.isNotEmpty ? decrypted : coded;
          if (textToProcess.isNotEmpty) {
            decoded = MultiLanguageManager.decodeMessage(
              textToProcess,
              encryptedAAD,
              multiLanguages!,
              mediaKey,
              autoRepairLanguages: true,
            );
          }
        } else if (!isMultiLanguageMode && hasLangMap) {
          final textToProcess = decoded.isNotEmpty ? decoded : coded;
          if (textToProcess.isNotEmpty) {
            decoded = ChatUtils.applyReverseMap(textToProcess, langMap!);
          }
        }
      } catch (_) {
        // Ignore decoding issues for indexing to keep UI responsive.
      }

      map['coded'] = coded;
      map['decoded'] = decoded;
      result.add(map);
    }

    return result;
  }
}
