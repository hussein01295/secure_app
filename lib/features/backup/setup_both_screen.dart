import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:silencia/core/services/key_backup_service.dart';

import 'models/master_password_args.dart';

class SetupBothScreen extends StatelessWidget {
  const SetupBothScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Double protection'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Vous allez configurer :\n'
                '1. Un mot de passe maître\n'
                '2. Une phrase de récupération (12 mots)',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              _AdvantageItem(
                icon: Icons.shield,
                title: 'Sécurité maximale',
                description:
                    'Le mot de passe protège votre backup sur le serveur.',
              ),
              const SizedBox(height: 12),
              _AdvantageItem(
                icon: Icons.key,
                title: 'Récupération garantie',
                description:
                    'La phrase permet de restaurer vos clés même si le mot de passe est perdu.',
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.push(
                  '/backup/setup-master-password',
                  extra: const MasterPasswordScreenArgs(
                    mode: KeyBackupService.backupModeBoth,
                    includeRecoveryPhrase: true,
                  ),
                ),
                child: const Text('Commencer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvantageItem extends StatelessWidget {
  const _AdvantageItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceVariant,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 14),
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
                Text(description, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
