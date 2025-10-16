import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/services/auto_backup_service.dart';
import 'package:silencia/core/services/key_backup_service.dart';

class RestoreBackupScreen extends StatefulWidget {
  const RestoreBackupScreen({super.key});

  @override
  State<RestoreBackupScreen> createState() => _RestoreBackupScreenState();
}

class _RestoreBackupScreenState extends State<RestoreBackupScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phraseController = TextEditingController();

  bool _hasBackup = false;
  bool _loadingStatus = true;
  bool _restoringPassword = false;
  bool _restoringPhrase = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final String? token = await AuthService.getToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _loadingStatus = false;
        });
      }
      return;
    }
    final bool has = await KeyBackupService.hasBackup(token);
    if (mounted) {
      setState(() {
        _hasBackup = has;
        _loadingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurer un backup'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_loadingStatus)
                const LinearProgressIndicator()
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: _hasBackup
                        ? colorScheme.primaryContainer
                        : Colors.orange.withOpacity(0.15),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        _hasBackup ? Icons.check_circle : Icons.info,
                        color: _hasBackup
                            ? colorScheme.onPrimaryContainer
                            : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _hasBackup
                              ? 'Un backup est disponible. Entrez votre secret pour restaurer.'
                              : 'Aucun backup trouvé pour votre compte.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _hasBackup
                                ? colorScheme.onPrimaryContainer
                                : Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              _RestoreCard(
                title: 'Mot de passe maître',
                description:
                    'Renseignez votre mot de passe maître pour restaurer toutes les clés.',
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe maître',
                  ),
                ),
                action: FilledButton(
                  onPressed: !_hasBackup || _restoringPassword
                      ? null
                      : _restoreWithPassword,
                  child: _restoringPassword
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Restaurer'),
                ),
              ),
              const SizedBox(height: 24),
              _RestoreCard(
                title: 'Phrase de récupération',
                description:
                    'Saisissez les 12 mots de votre phrase, séparés par un espace.',
                child: TextField(
                  controller: _phraseController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Phrase de récupération',
                    hintText: 'mot1 mot2 ... mot12',
                  ),
                ),
                action: FilledButton(
                  onPressed: !_hasBackup || _restoringPhrase
                      ? null
                      : _restoreWithPhrase,
                  child: _restoringPhrase
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Restaurer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restoreWithPassword() async {
    final String password = _passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez votre mot de passe maître.')),
      );
      return;
    }
    setState(() => _restoringPassword = true);
    try {
      final String? token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Session expirée. Veuillez vous reconnecter.');
      }
      await KeyBackupService.restoreFromMasterPassword(
        token: token,
        masterPassword: password,
      );
      await AutoBackupService.scheduleFullSync(origin: 'restore');
      if (!mounted) return;
      setState(() => _restoringPassword = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restauré avec succès.')),
      );
      context.go('/settings');
    } catch (e) {
      if (!mounted) return;
      setState(() => _restoringPassword = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> _restoreWithPhrase() async {
    final String phrase = _phraseController.text.trim();
    if (phrase.split(RegExp(r'\s+')).length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La phrase doit contenir 12 mots.')),
      );
      return;
    }
    setState(() => _restoringPhrase = true);
    try {
      final String? token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Session expirée. Veuillez vous reconnecter.');
      }
      await KeyBackupService.restoreFromRecoveryPhrase(
        token: token,
        recoveryPhrase: phrase,
      );
      await AutoBackupService.scheduleFullSync(origin: 'restore');
      if (!mounted) return;
      setState(() => _restoringPhrase = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restauré avec succès.')),
      );
      context.go('/settings');
    } catch (e) {
      if (!mounted) return;
      setState(() => _restoringPhrase = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }
}

class _RestoreCard extends StatelessWidget {
  const _RestoreCard({
    required this.title,
    required this.description,
    required this.child,
    required this.action,
  });

  final String title;
  final String description;
  final Widget child;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surfaceVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          child,
          const SizedBox(height: 16),
          action,
        ],
      ),
    );
  }
}
