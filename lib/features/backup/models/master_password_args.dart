import 'package:silencia/core/services/key_backup_service.dart';

class MasterPasswordScreenArgs {
  const MasterPasswordScreenArgs({
    required this.mode,
    this.includeRecoveryPhrase = false,
  }) : assert(
         mode == KeyBackupService.backupModePassword ||
             mode == KeyBackupService.backupModeBoth,
         'Mode incompatible pour la configuration du mot de passe.',
       );

  final String mode;
  final bool includeRecoveryPhrase;
}
