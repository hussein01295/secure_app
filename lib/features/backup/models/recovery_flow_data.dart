import 'package:collection/collection.dart';
import 'package:silencia/core/services/key_backup_service.dart';

class RecoveryFlowData {
  RecoveryFlowData({
    required this.mode,
    required this.words,
    this.masterPassword,
  }) : assert(
         mode == KeyBackupService.backupModePhrase ||
             mode == KeyBackupService.backupModeBoth,
         'Mode invalide pour RecoveryFlowData',
       );

  final String mode;
  final List<String> words;
  final String? masterPassword;

  String get phrase => words.join(' ');

  List<MapEntry<int, String>> indexedWords() =>
      words.mapIndexed((int i, String word) => MapEntry(i + 1, word)).toList();
}
