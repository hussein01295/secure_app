import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/services/key_backup_service.dart';

import 'models/recovery_flow_data.dart';

class RecoveryPhraseVerifyScreen extends StatefulWidget {
  const RecoveryPhraseVerifyScreen({super.key, required this.data});

  final RecoveryFlowData data;

  @override
  State<RecoveryPhraseVerifyScreen> createState() =>
      _RecoveryPhraseVerifyScreenState();
}

class _RecoveryPhraseVerifyScreenState
    extends State<RecoveryPhraseVerifyScreen> {
  late final List<int> _indexesToVerify;
  final Map<int, TextEditingController> _controllers =
      <int, TextEditingController>{};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final Random random = Random.secure();
    final int wordCount = widget.data.words.length;
    final Set<int> picks = <int>{};
    while (picks.length < 3 && picks.length < wordCount) {
      picks.add(random.nextInt(wordCount));
    }
    _indexesToVerify = picks.toList()..sort();
    for (final int index in _indexesToVerify) {
      _controllers[index] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification de la phrase'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Entrez les mots demandés pour confirmer que vous avez bien noté la phrase.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              ..._indexesToVerify.map(
                (int index) => _VerificationField(
                  index: index + 1,
                  controller: _controllers[index]!,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isSubmitting ? null : _handleVerify,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Vérifier et sauvegarder'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleVerify() async {
    for (final int index in _indexesToVerify) {
      final String expected = widget.data.words[index];
      final String value = _controllers[index]!.text.trim().toLowerCase();
      if (value != expected.toLowerCase()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Le mot #${index + 1} est incorrect.')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final String? token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Session expirée. Veuillez vous reconnecter.');
      }

      await KeyBackupService.createBackup(
        token: token,
        mode: widget.data.mode,
        masterPassword: widget.data.masterPassword,
        recoveryPhrase: widget.data.phrase,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      context.go('/backup/success');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }
}

class _VerificationField extends StatelessWidget {
  const _VerificationField({required this.index, required this.controller});

  final int index;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: 'Mot #$index',
          hintText: 'Entrez le mot $index',
        ),
      ),
    );
  }
}
