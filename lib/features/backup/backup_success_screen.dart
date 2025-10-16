import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:silencia/core/services/key_collector_service.dart';

class BackupSuccessScreen extends StatefulWidget {
  const BackupSuccessScreen({super.key});

  @override
  State<BackupSuccessScreen> createState() => _BackupSuccessScreenState();
}

class _BackupSuccessScreenState extends State<BackupSuccessScreen> {
  late Future<KeyCollection> _future;

  @override
  void initState() {
    super.initState();
    _future = KeyCollectorService.collectAllKeys();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Sauvegarde réussie'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<KeyCollection>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<KeyCollection> snapshot) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 24),
                  Center(
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.celebration,
                        color: colorScheme.onPrimaryContainer,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Vos clés sont sauvegardées.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Conservez votre mot de passe / phrase de récupération en lieu sûr pour pouvoir restaurer vos messages à tout moment.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  if (snapshot.hasData)
                    _buildSummaryCard(theme, colorScheme, snapshot.data!),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () => context.go('/settings'),
                    child: const Text('Terminer'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme,
    ColorScheme colorScheme,
    KeyCollection collection,
  ) {
    final Map<String, dynamic> metadata = collection.metadata;
    final int languageCount =
        metadata['languageCount'] as int? ?? collection.languagePackages.length;
    final int mediaCount =
        metadata['mediaCount'] as int? ?? collection.mediaKeys.length;
    final bool hasPrivateKey =
        metadata['hasPrivateKey'] as bool? ??
        (collection.rsaPrivateKey != null);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.surfaceVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Résumé',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            icon: Icons.language,
            label: 'Clés de langue',
            value: '$languageCount',
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            icon: Icons.videocam,
            label: 'Clés média',
            value: '$mediaCount',
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            icon: Icons.lock,
            label: 'Clé RSA privée',
            value: hasPrivateKey ? 'Sauvegardée' : 'Non détectée',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
