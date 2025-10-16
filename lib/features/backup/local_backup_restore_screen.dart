import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:silencia/core/services/local_language_backup_service.dart';

class LocalBackupRestoreScreen extends StatefulWidget {
  const LocalBackupRestoreScreen({super.key});

  @override
  State<LocalBackupRestoreScreen> createState() =>
      _LocalBackupRestoreScreenState();
}

class _LocalBackupRestoreScreenState extends State<LocalBackupRestoreScreen> {
  final TextEditingController _passwordController = TextEditingController();
  File? _selectedFile;
  bool _isProcessing = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choisir un fichier de backup',
      type: FileType.custom,
      allowedExtensions: <String>['enc'],
    );
    if (result == null || result.files.isEmpty) return;
    final String? path = result.files.single.path;
    if (path == null) return;
    setState(() {
      _selectedFile = File(path);
    });
  }

  Future<void> _restore() async {
    if (_selectedFile == null) {
      _showSnackBar('Sélectionnez un fichier de backup.');
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showSnackBar('Saisissez le mot de passe.');
      return;
    }
    setState(() => _isProcessing = true);
    try {
      await LocalLanguageBackupService.restoreFromFile(
        _selectedFile!,
        _passwordController.text,
      );
      if (!mounted) return;
      _showSnackBar('Langues restaurées avec succès.');
      Navigator.of(context).pop();
    } catch (e) {
      _showSnackBar('Erreur : $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importer un backup'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Sélectionnez le fichier .enc puis saisissez le mot de passe utilisé lors de la création du backup.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: Text(
                  _selectedFile == null
                      ? 'Sélectionner un fichier'
                      : _selectedFile!.path.split(Platform.pathSeparator).last,
                ),
                onPressed: _isProcessing ? null : _pickFile,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _isProcessing ? null : _restore,
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Restaurer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
