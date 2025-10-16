import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:silencia/core/config/api_config.dart'; 
import 'register_screen.dart';

mixin RegisterController on State<RegisterScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final displayNameController = TextEditingController();
  bool isLoading = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> register() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;
    final displayName = displayNameController.text.trim();

    if (username.isEmpty || password.isEmpty || displayName.isEmpty) {
      showMessage("Tous les champs sont requis");
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/auth/register"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'displayName': displayName,
        }),
      );

      if (res.statusCode == 201) {
        showMessage("✅ Compte créé avec succès !");
        if (mounted) context.go('/login');
      } else {
        final err = jsonDecode(res.body)['message'] ?? "Erreur inconnue";
        showMessage("❌ $err");
      }
    } catch (e) {
      showMessage("Erreur : $e");
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    displayNameController.dispose();
    super.dispose();
  }
}
