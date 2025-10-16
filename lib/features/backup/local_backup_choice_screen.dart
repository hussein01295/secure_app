import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:silencia/core/services/local_language_backup_service.dart';

class LocalBackupChoiceScreen extends StatefulWidget {
  const LocalBackupChoiceScreen({super.key});

  @override
  State<LocalBackupChoiceScreen> createState() =>
      _LocalBackupChoiceScreenState();
}

class _LocalBackupChoiceScreenState extends State<LocalBackupChoiceScreen> {
  bool _isProcessing = false;
  bool _backupExists = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final bool exists = await LocalLanguageBackupService.backupExists();
    if (!mounted) return;
    setState(() {
      _backupExists = exists;
    });
  }

  Future<void> _createBackup() async {
    final String? password = await _askPassword(confirm: true);
    if (password == null || password.isEmpty) return;
    await _executeWithLoading(() async {
      await LocalLanguageBackupService.createLocalBackup(password);
      if (!mounted) return;
      await context.push('/local-backup-success');
    });
  }

  Future<void> _updateBackup() async {
    if (!_backupExists) {
      _showSnackBar('Aucun backup local trouvé.');
      return;
    }
    final String? password = await _askPassword(confirm: false);
    if (password == null || password.isEmpty) return;
    await _executeWithLoading(() async {
      await LocalLanguageBackupService.updateLocalBackupWithPassword(password);
      _showSnackBar('Backup local mis à jour.');
    });
  }

  Future<void> _exportBackup() async {
    final File? file = await LocalLanguageBackupService.getBackupFileIfExists();
    if (file == null) {
      _showSnackBar('Aucun backup local à exporter.');
      return;
    }
    await Share.shareXFiles(<XFile>[
      XFile(file.path),
    ], text: 'Sauvegarde locale des langues Silencia');
  }

  Future<void> _importBackup() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Sélectionner un fichier de backup',
        type: FileType.custom,
        allowedExtensions: <String>['enc'],
      );
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('FilePicker custom filter failed: $e');
      }
      result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Sélectionner un fichier de backup',
        type: FileType.any,
      );
    }

    if (result == null || result.files.isEmpty) return;
    final String? path = result.files.single.path;
    if (path == null) return;
    if (!path.toLowerCase().endsWith('.enc')) {
      _showSnackBar('Veuillez sélectionner un fichier .enc');
      return;
    }

    final String? password = await _askPassword(confirm: false);
    if (password == null || password.isEmpty) return;

    await _executeWithLoading(() async {
      await LocalLanguageBackupService.restoreFromFile(File(path), password);
      _showSnackBar('Backup local importé avec succès.');
    });
  }

  Future<void> _executeWithLoading(Future<void> Function() action) async {
    setState(() {
      _isProcessing = true;
      _lastError = null;
    });
    try {
      await action();
      await _refreshStatus();
    } catch (e) {
      setState(() {
        _lastError = e.toString();
      });
      _showSnackBar('Erreur : $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<String?> _askPassword({required bool confirm}) async {
    final TextEditingController passwordCtrl = TextEditingController();
    final TextEditingController confirmCtrl = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final String? result = await showDialog<String?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(confirm ? 'Définir un mot de passe' : 'Mot de passe'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Mot de passe requis';
                    }
                    if (value.length < 8) {
                      return 'Minimum 8 caractères';
                    }
                    return null;
                  },
                ),
                if (confirm)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextFormField(
                      controller: confirmCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Confirmer'),
                      validator: (String? value) {
                        if (value != passwordCtrl.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, passwordCtrl.text);
                }
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
    return result;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde locale'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: colorScheme.surfaceContainerHighest,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Sauvegarde locale des langues',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _backupExists
                          ? 'Un fichier de sauvegarde est présent sur ce dispositif.'
                          : 'Aucun fichier de sauvegarde local n’a été détecté.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (_lastError != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        _lastError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _ActionButton(
                icon: Icons.save,
                label: 'Créer un backup local',
                onPressed: _isProcessing ? null : _createBackup,
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.update,
                label: 'Mettre à jour le backup',
                onPressed: _isProcessing ? null : _updateBackup,
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.ios_share,
                label: 'Exporter le fichier',
                onPressed: _isProcessing ? null : _exportBackup,
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.folder_open,
                label: 'Importer un fichier de backup',
                onPressed: _isProcessing ? null : _importBackup,
              ),
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(label),
      ),
      style: ElevatedButton.styleFrom(alignment: Alignment.centerLeft),
    );
  }
}
