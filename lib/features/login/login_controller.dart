import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/service/socket_service.dart';
import 'package:silencia/core/utils/rsa_serrvice.dart';
import 'login_screen.dart';

mixin LoginController on State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      showMessage("Tous les champs sont requis");
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/auth/login"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];
        final userId = data['userId'];
        final username = data['username'];

        if ([accessToken, refreshToken, userId, username].contains(null)) {
          showMessage("Réponse invalide du serveur");
          return;
        }

        await AuthService.saveLogin(accessToken, refreshToken, userId, username);
        SocketService().initSocket(accessToken);

        // === EMIT ONLINE GLOBALEMENT ===
        Future.delayed(const Duration(milliseconds: 200), () {
          SocketService().socket.emit('online', userId);
        });

        await RSAKeyService.generateAndStoreKeyPair(accessToken);

        if (mounted) {
          context.go('/home', extra: {
            'token': accessToken,
            'userId': userId,
            'username': username,
          });
        }
      } else {
        final error = jsonDecode(res.body)['message'] ?? 'Erreur inconnue';
        showMessage(error);
      }
    } catch (e) {
      showMessage("Erreur de connexion : $e");
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
