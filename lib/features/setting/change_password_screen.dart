import 'package:flutter/material.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/theme/theme_manager.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  bool _hideOld = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _loading = false; // NEW

  @override
  void dispose() {
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _loading = true);
    try {
      final ok = await AuthService.changePassword(
        _oldPwdCtrl.text,
        _newPwdCtrl.text,
      );
      setState(() => _loading = false);
      if (ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mot de passe changé avec succès ✅")),
        );
        Navigator.of(context).pop();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors du changement de mot de passe ❌")),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = globalThemeManager;

    return Scaffold(
      backgroundColor: themeManager.getBackgroundColor(),
      appBar: AppBar(
        backgroundColor: themeManager.getSurfaceColor(),
        elevation: 0,
        title: Text(
          "Changer le mot de passe",
          style: TextStyle(color: themeManager.accentColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: themeManager.accentColor),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _passwordField(
                label: "Ancien mot de passe",
                controller: _oldPwdCtrl,
                obscure: _hideOld,
                toggle: () => setState(() => _hideOld = !_hideOld),
                // Ici, min. 1 caractère seulement
                validator: (val) {
                  if (val == null || val.isEmpty) return "Champ requis";
                  return null;
                },
              ),
              const SizedBox(height: 18),
                _passwordField(
                  label: "Nouveau mot de passe",
                  controller: _newPwdCtrl,
                  obscure: _hideNew,
                  toggle: () => setState(() => _hideNew = !_hideNew),
                  // Ici, min. 6 caractères
                  validator: (val) {
                    if (val == null || val.length < 6) return "Min. 6 caractères";
                    return null;
                  },
                ),
              const SizedBox(height: 18),
                _passwordField(
                  label: "Confirmer le mot de passe",
                  controller: _confirmPwdCtrl,
                  obscure: _hideConfirm,
                  toggle: () => setState(() => _hideConfirm = !_hideConfirm),
                  validator: (val) {
                    if (val != _newPwdCtrl.text) {
                      return "Les mots de passe ne correspondent pas";
                    }
                    if (val == null || val.length < 6) return "Min. 6 caractères";
                    return null;
                  },
                ),
              const SizedBox(height: 38),
              ElevatedButton(
                onPressed: _loading ? null : _handleChangePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeManager.accentColor,
                  foregroundColor: themeManager.getBackgroundColor(),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: _loading
                    ? SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 3, color: themeManager.getBackgroundColor()))
                    : const Text("Changer le mot de passe"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback toggle,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
 
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock, color: Colors.cyanAccent),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.cyanAccent),
        filled: true,
        fillColor: const Color(0xFF19232b),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.cyanAccent, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.cyanAccent,
          ),
          onPressed: toggle,
        ),
      ),
    );
  }
}
