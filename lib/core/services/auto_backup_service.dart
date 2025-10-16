import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:silencia/core/service/auth_service.dart';

import 'key_backup_service.dart';

/// Manages the language auto-backup preference and a persistent retry queue.
class AutoBackupService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _autoBackupEnabledKey = 'autoBackupEnabled';
  static const String _pendingQueueKey = 'autoBackupPendingQueue';
  static const String _pendingErrorFlagKey = 'autoBackupHasError';
  static const int _maxAttempts = 5;

  static bool _isProcessingQueue = false;

  static Future<bool> isAutoBackupEnabled() async {
    final String? value = await _storage.read(key: _autoBackupEnabledKey);
    if (value == null) return false;
    return value.toLowerCase() == 'true';
  }

  static Future<void> setAutoBackupEnabled(bool enabled) async {
    await _storage.write(key: _autoBackupEnabledKey, value: enabled.toString());
    if (enabled) {
      await flushPendingBackups();
    }
  }

  static Future<bool> hasPendingFailures() async {
    final String? value = await _storage.read(key: _pendingErrorFlagKey);
    return value != null && value.toLowerCase() == 'true';
  }

  static Future<void> clearFailureFlag() async {
    await _storage.delete(key: _pendingErrorFlagKey);
  }

  static Future<void> handleLanguageGenerated({
    required String relationId,
    required String userId,
    required String packageJson,
  }) async {
    if (!await isAutoBackupEnabled()) return;
    await _enqueueLanguageTask(
      relationId: relationId,
      userId: userId,
      packageJson: packageJson,
      origin: 'generated',
    );
    await _processQueue();
  }

  static Future<void> handleLanguageImported({
    required String relationId,
    required String userId,
    required String packageJson,
  }) async {
    if (!await isAutoBackupEnabled()) return;
    await _enqueueLanguageTask(
      relationId: relationId,
      userId: userId,
      packageJson: packageJson,
      origin: 'imported',
    );
    await _processQueue();
  }

  static Future<void> scheduleFullSync({String origin = 'sync'}) async {
    if (!await isAutoBackupEnabled()) return;
    final List<_PendingAutoBackupTask> queue = await _readQueue();
    queue.add(
      _PendingAutoBackupTask.fullSync(
        attempts: 0,
        origin: origin,
      ),
    );
    await _writeQueue(queue);
    await _processQueue();
  }

  static Future<void> flushPendingBackups() async {
    await _processQueue();
  }

  static Future<void> _enqueueLanguageTask({
    required String relationId,
    required String userId,
    required String packageJson,
    required String origin,
  }) async {
    final List<_PendingAutoBackupTask> queue = await _readQueue();
    queue.add(
      _PendingAutoBackupTask.language(
        relationId: relationId,
        userId: userId,
        packageJson: packageJson,
        origin: origin,
      ),
    );
    await _writeQueue(queue);
  }

  static Future<List<_PendingAutoBackupTask>> _readQueue() async {
    final String? raw = await _storage.read(key: _pendingQueueKey);
    if (raw == null || raw.isEmpty) return <_PendingAutoBackupTask>[];
    try {
      final List<dynamic> data = jsonDecode(raw) as List<dynamic>;
      return data
          .map(
            (dynamic item) => _PendingAutoBackupTask.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AutoBackupService: unable to decode queue: $e');
      }
      return <_PendingAutoBackupTask>[];
    }
  }

  static Future<void> _writeQueue(List<_PendingAutoBackupTask> tasks) async {
    if (tasks.isEmpty) {
      await _storage.delete(key: _pendingQueueKey);
      return;
    }
    final String encoded = jsonEncode(
      tasks.map((task) => task.toJson()).toList(),
    );
    await _storage.write(key: _pendingQueueKey, value: encoded);
  }

  static Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    if (!await isAutoBackupEnabled()) return;

    _isProcessingQueue = true;
    try {
      final List<_PendingAutoBackupTask> queue = await _readQueue();
      if (queue.isEmpty) {
        await _storage.delete(key: _pendingErrorFlagKey);
        return;
      }

      final DateTime now = DateTime.now();
      final List<_PendingAutoBackupTask> remaining = <_PendingAutoBackupTask>[];
      bool hasFailures = false;

      final bool refreshed = await AuthService.refreshTokenIfNeeded();
      if (!refreshed) {
        await _writeQueue(queue);
        await _storage.write(key: _pendingErrorFlagKey, value: 'true');
        return;
      }

      final String? token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        await _writeQueue(queue);
        await _storage.write(key: _pendingErrorFlagKey, value: 'true');
        return;
      }

      for (final _PendingAutoBackupTask task in queue) {
        if (!task.isReady(now)) {
          remaining.add(task);
          continue;
        }

        try {
          switch (task.type) {
            case _AutoBackupTaskType.language:
              if (task.relationId != null &&
                  task.userId != null &&
                  task.packageJson != null) {
                await KeyBackupService.addLanguageKeyToBackup(
                  relationId: task.relationId!,
                  userId: task.userId!,
                  key: task.packageJson!,
                  token: token,
                );
              }
              break;
            case _AutoBackupTaskType.fullSync:
              await KeyBackupService.syncCurrentBackup(
                token: token,
                reason: task.origin,
              );
              break;
          }
        } catch (e) {
          hasFailures = true;
          if (kDebugMode) {
            debugPrint(
              'AutoBackupService: task ${task.type.name} failed (attempt ${task.attempts + 1}): $e',
            );
          }
          if (task.attempts + 1 < _maxAttempts) {
            remaining.add(task.markFailure());
          }
        }
      }

      await _writeQueue(remaining);
      if (hasFailures && remaining.isNotEmpty) {
        await _storage.write(key: _pendingErrorFlagKey, value: 'true');
      } else if (remaining.isEmpty) {
        await _storage.delete(key: _pendingErrorFlagKey);
      }
    } finally {
      _isProcessingQueue = false;
    }
  }
}

enum _AutoBackupTaskType { language, fullSync }

class _PendingAutoBackupTask {
  const _PendingAutoBackupTask({
    required this.type,
    this.relationId,
    this.userId,
    this.packageJson,
    this.attempts = 0,
    this.readyAt,
    this.origin,
  });

  factory _PendingAutoBackupTask.language({
    required String relationId,
    required String userId,
    required String packageJson,
    String? origin,
  }) {
    return _PendingAutoBackupTask(
      type: _AutoBackupTaskType.language,
      relationId: relationId,
      userId: userId,
      packageJson: packageJson,
      origin: origin,
    );
  }

  factory _PendingAutoBackupTask.fullSync({
    required int attempts,
    String? origin,
  }) {
    return _PendingAutoBackupTask(
      type: _AutoBackupTaskType.fullSync,
      attempts: attempts,
      origin: origin,
    );
  }

  factory _PendingAutoBackupTask.fromJson(Map<String, dynamic> json) {
    final String typeString = json['type'] as String? ?? 'language';
    final _AutoBackupTaskType type = typeString == 'fullSync'
        ? _AutoBackupTaskType.fullSync
        : _AutoBackupTaskType.language;
    final String? readyAtIso = json['readyAt'] as String?;
    return _PendingAutoBackupTask(
      type: type,
      relationId: json['relationId'] as String?,
      userId: json['userId'] as String?,
      packageJson: json['packageJson'] as String?,
      attempts: json['attempts'] as int? ?? 0,
      readyAt: readyAtIso != null ? DateTime.tryParse(readyAtIso) : null,
      origin: json['origin'] as String?,
    );
  }

  final _AutoBackupTaskType type;
  final String? relationId;
  final String? userId;
  final String? packageJson;
  final int attempts;
  final DateTime? readyAt;
  final String? origin;

  bool isReady(DateTime reference) {
    if (readyAt == null) return true;
    return !readyAt!.isAfter(reference);
  }

  _PendingAutoBackupTask markFailure() {
    final int nextAttempts = attempts + 1;
    final int minutes = nextAttempts.clamp(1, 5);
    return _PendingAutoBackupTask(
      type: type,
      relationId: relationId,
      userId: userId,
      packageJson: packageJson,
      attempts: nextAttempts,
      readyAt: DateTime.now().add(Duration(minutes: minutes)),
      origin: origin,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.name,
      'relationId': relationId,
      'userId': userId,
      'packageJson': packageJson,
      'attempts': attempts,
      'readyAt': readyAt?.toIso8601String(),
      'origin': origin,
    };
  }
}
