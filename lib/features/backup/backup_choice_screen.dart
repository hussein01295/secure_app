import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:silencia/core/services/key_backup_service.dart';

import 'models/master_password_args.dart';

class BackupChoiceScreen extends StatelessWidget {
  const BackupChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sécuriser vos clés'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(theme, colorScheme),
              const SizedBox(height: 24),
              _BackupOptionCard(
                icon: Icons.vpn_key,
                title: 'Mot de passe maître',
                subtitle: 'Protégez vos clés avec un mot de passe.',
                onTap: () => context.push(
                  '/backup/setup-master-password',
                  extra: const MasterPasswordScreenArgs(
                    mode: KeyBackupService.backupModePassword,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _BackupOptionCard(
                icon: Icons.menu_book,
                title: 'Phrase de récupération',
                subtitle: '12 mots uniques à noter en lieu sûr.',
                onTap: () => context.push('/backup/setup-recovery-phrase'),
              ),
              const SizedBox(height: 16),
              _BackupOptionCard(
                icon: Icons.shield,
                title: 'Double protection (recommandé)',
                subtitle: 'Mot de passe + phrase pour une sécurité maximale.',
                accentColor: colorScheme.secondary,
                onTap: () => context.push('/backup/setup-both'),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => _confirmSkip(context),
                child: const Text('Continuer sans backup'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: <Color>[
            colorScheme.primary.withOpacity(0.15),
            colorScheme.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Important',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sauvegardez vos clés pour ne pas les perdre en cas de changement '
            'd’appareil ou de réinstallation.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _confirmSkip(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Continuer sans sauvegarde ?'),
          content: const Text(
            'Sans sauvegarde, il sera impossible de restaurer vos messages '
            'si vous perdez cet appareil.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton.tonal(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).maybePop();
              },
              child: const Text('Je comprends'),
            ),
          ],
        );
      },
    );
  }
}

class _BackupOptionCard extends StatelessWidget {
  const _BackupOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color highlight = accentColor ?? colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.cardColor,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: highlight.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: highlight.withOpacity(0.12),
              child: Icon(icon, color: highlight),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
