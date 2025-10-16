import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/services/key_backup_service.dart';
import 'package:silencia/core/services/recovery_phrase_service.dart';

import 'models/master_password_args.dart';
import 'models/recovery_flow_data.dart';

class SetupMasterPasswordScreen extends StatefulWidget {
  const SetupMasterPasswordScreen({super.key, required this.args});

  final MasterPasswordScreenArgs args;

  @override
  State<SetupMasterPasswordScreen> createState() =>
      _SetupMasterPasswordScreenState();
}

class _SetupMasterPasswordScreenState extends State<SetupMasterPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mot de passe maître'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Créez un mot de passe maître robuste. Il protègera toutes vos clés de chiffrement.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                _buildPasswordField(theme, colorScheme),
                const SizedBox(height: 16),
                _buildConfirmationField(theme),
                const SizedBox(height: 12),
                _PasswordStrengthIndicator(password: _passwordController.text),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continuer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(ThemeData theme, ColorScheme colorScheme) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Mot de passe maître',
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      onChanged: (_) => setState(() {}),
      validator: (String? value) {
        if (value == null || value.isEmpty) {
          return 'Mot de passe requis.';
        }
        if (value.length < 10) {
          return 'Utilisez au moins 10 caractères.';
        }
        final bool hasUpper = value.contains(RegExp(r'[A-Z]'));
        final bool hasLower = value.contains(RegExp(r'[a-z]'));
        final bool hasDigit = value.contains(RegExp(r'[0-9]'));
        final bool hasSpecial = value.contains(RegExp(r'[^A-Za-z0-9]'));
        final int complexity = <bool>[
          hasUpper,
          hasLower,
          hasDigit,
          hasSpecial,
        ].where((bool v) => v).length;
        if (complexity < 3) {
          return 'Ajoutez majuscules, chiffres et symboles pour renforcer le mot de passe.';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmationField(ThemeData theme) {
    return TextFormField(
      controller: _confirmController,
      obscureText: _obscureConfirmation,
      decoration: InputDecoration(
        labelText: 'Confirmer le mot de passe',
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmation ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () =>
              setState(() => _obscureConfirmation = !_obscureConfirmation),
        ),
      ),
      validator: (String? value) {
        if (value == null || value.isEmpty) {
          return 'Confirmation requise.';
        }
        if (value != _passwordController.text) {
          return 'Les mots de passe ne correspondent pas.';
        }
        return null;
      },
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final String? token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Session expirée. Veuillez vous reconnecter.');
      }
      final String password = _passwordController.text;

      if (widget.args.includeRecoveryPhrase) {
        final String phrase = RecoveryPhraseService.generateRecoveryPhrase();
        final List<String> words = phrase.split(' ');
        final RecoveryFlowData data = RecoveryFlowData(
          mode: KeyBackupService.backupModeBoth,
          words: words,
          masterPassword: password,
        );
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        context.push('/backup/recovery-phrase-display', extra: data);
        return;
      }

      await KeyBackupService.createBackup(
        token: token,
        mode: widget.args.mode,
        masterPassword: password,
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

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final _Strength strength = _evaluate(password);
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Expanded(
          child: LinearProgressIndicator(
            value: strength.progress,
            color: strength.color,
            backgroundColor: theme.colorScheme.surfaceVariant,
            minHeight: 6,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          strength.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: strength.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  _Strength _evaluate(String value) {
    if (value.isEmpty) return _Strength.empty;
    double score = value.length >= 10 ? 0.25 : 0.0;
    if (value.contains(RegExp(r'[a-z]'))) score += 0.15;
    if (value.contains(RegExp(r'[A-Z]'))) score += 0.2;
    if (value.contains(RegExp(r'[0-9]'))) score += 0.2;
    if (value.contains(RegExp(r'[^A-Za-z0-9]'))) score += 0.2;
    if (value.length >= 14) score += 0.2;
    score = score.clamp(0.0, 1.0);

    if (score < 0.3) return _Strength('Faible', Colors.redAccent, score);
    if (score < 0.6) return _Strength('Moyen', Colors.orangeAccent, score);
    if (score < 0.85) return _Strength('Fort', Colors.lightGreen, score);
    return _Strength('Excellent', Colors.green, score);
  }
}

class _Strength {
  const _Strength(this.label, this.color, this.progress);

  final String label;
  final Color color;
  final double progress;

  static const _Strength empty = _Strength(' ', Colors.transparent, 0);
}
