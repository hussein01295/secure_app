import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:silencia/core/database/isar_db.dart';

import 'message_entity.dart';
import 'text_norm.dart';

class MessageRepo {
  static Future<void> upsertBatch(
    String relationId,
    Iterable<Map<String, dynamic>> messages,
  ) async {
    if (relationId.isEmpty) return;
    final isar = await IsarDb.instance();
    final entities = <MessageEntity>[];

    for (final msg in messages) {
      final id = _asString(msg['id'] ?? msg['_id']);
      if (id == null || id.isEmpty) {
        continue;
      }

      final type = _asString(msg['messageType']) ?? 'text';
      final ts = _extractTs(msg);
      final coded = _asString(msg['coded'] ?? msg['textCoded'] ?? msg['text']);
      final decoded = _asString(msg['decoded'] ?? msg['text']);
      final encryptedAAD = _asString(msg['encryptedAAD']);
      final timeLabel = _asString(msg['time']);
      final metadataJson = _encodeJson(msg['metadata']);

      final entity = MessageEntity()
        ..id = id
        ..relationId = relationId
        ..ts = ts
        ..fromMe = msg['fromMe'] == true
        ..type = type
        ..coded = coded
        ..decoded = decoded
        ..encryptedAAD = encryptedAAD
        ..timeLabel = timeLabel
        ..isRead = msg['isRead'] == true
        ..metadataJson = metadataJson;

      final normalizedDecoded = TextNorm.normalize(
        decoded ?? coded ?? (type != 'text' ? '[$type]' : ''),
      );
      entity.searchNorm = normalizedDecoded.isEmpty ? '_' : normalizedDecoded;

      final normalizedCoded = TextNorm.normalize(coded ?? '');
      entity.searchNormCoded = normalizedCoded.isEmpty ? null : normalizedCoded;

      entities.add(entity);
    }

    if (entities.isEmpty) return;

    await isar.writeTxn(() async {
      await isar.messageEntitys.putAll(entities);
    });
  }

  static Future<List<MessageEntity>> search({
    required String relationId,
    required String query,
    bool translatedMode = true,
    int limit = 50,
  }) async {
    if (relationId.isEmpty) return [];
    final normalizedNeedle = TextNorm.normalize(query);
    if (normalizedNeedle.isEmpty) return [];

    final isar = await IsarDb.instance();
    final col = isar.messageEntitys;

    if (translatedMode) {
      return await col
          .filter()
          .relationIdEqualTo(relationId)
          .and()
          .searchNormContains(normalizedNeedle)
          .sortByTsDesc()
          .limit(limit)
          .findAll();
    }

    return await col
        .filter()
        .relationIdEqualTo(relationId)
        .and()
        .group(
          (q) => q
              .searchNormContains(normalizedNeedle)
              .or()
              .searchNormCodedContains(normalizedNeedle),
        )
        .sortByTsDesc()
        .limit(limit)
        .findAll();
  }

  static Future<void> deleteForRelation(String relationId) async {
    if (relationId.isEmpty) return;
    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.messageEntitys
          .filter()
          .relationIdEqualTo(relationId)
          .deleteAll();
    });
  }

  static int _extractTs(Map<String, dynamic> message) {
    final candidates = [
      message['timestamp'],
      message['createdAt'],
      message['sentAt'],
    ];

    for (final candidate in candidates) {
      if (candidate is int) return candidate;
      if (candidate is String) {
        final parsedInt = int.tryParse(candidate);
        if (parsedInt != null) return parsedInt;
        final parsedDate = DateTime.tryParse(candidate);
        if (parsedDate != null) {
          return parsedDate.millisecondsSinceEpoch;
        }
      }
    }

    return DateTime.now().millisecondsSinceEpoch;
  }

  static String? _encodeJson(dynamic value) {
    if (value == null) return null;
    try {
      return jsonEncode(value);
    } catch (_) {
      return null;
    }
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }
}
