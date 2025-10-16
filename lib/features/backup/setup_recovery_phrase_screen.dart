import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:silencia/core/services/key_backup_service.dart';
import 'package:silencia/core/services/recovery_phrase_service.dart';

import 'models/recovery_flow_data.dart';

class SetupRecoveryPhraseScreen extends StatelessWidget {
  const SetupRecoveryPhraseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phrase de récupération'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Nous allons générer une phrase de 12 mots. '
                'Notez-la soigneusement, elle est indispensable pour restaurer vos clés.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              _TipCard(
                icon: Icons.edit_note,
                title: 'Notez-la',
                subtitle: 'Écrivez ces 12 mots sur un support hors ligne.',
              ),
              const SizedBox(height: 16),
              _TipCard(
                icon: Icons.lock,
                title: 'Gardez-la secrète',
                subtitle: 'Ne partagez jamais cette phrase avec quelqu’un.',
              ),
              const SizedBox(height: 16),
              _TipCard(
                icon: Icons.warning_amber,
                title: 'Ne la perdez pas',
                subtitle:
                    'Sans cette phrase, aucune restauration ne sera possible.',
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _generatePhrase(context),
                child: const Text('Générer ma phrase'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _generatePhrase(BuildContext context) {
    final String phrase = RecoveryPhraseService.generateRecoveryPhrase();
    final List<String> words = phrase.split(' ');
    final RecoveryFlowData data = RecoveryFlowData(
      mode: KeyBackupService.backupModePhrase,
      words: words,
    );
    context.push('/backup/recovery-phrase-display', extra: data);
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
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
                Text(subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
