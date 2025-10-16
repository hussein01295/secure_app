import 'package:flutter/material.dart';
import 'package:silencia/core/services/local_language_backup_service.dart';

class LocalBackupSuccessScreen extends StatelessWidget {
  const LocalBackupSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup local'), centerTitle: true),
      body: SafeArea(
        child: FutureBuilder<bool>(
          future: LocalLanguageBackupService.backupExists(),
          builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
            final bool exists = snapshot.data ?? false;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 24),
                  const Icon(Icons.check_circle, size: 64, color: Colors.green),
                  const SizedBox(height: 24),
                  Text(
                    'Sauvegarde locale créée !',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    exists
                        ? 'Le fichier chiffré a été enregistré dans le stockage sécurisé de l’application.'
                        : 'Le fichier chiffré sera généré lors de la prochaine sauvegarde.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
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
}
