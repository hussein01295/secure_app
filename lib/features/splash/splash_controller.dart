import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:silencia/core/service/auth_service.dart';

class SplashController {
  final BuildContext context;

  SplashController(this.context);

  Future<void> handleStartup() async {
    final user = await AuthService.getSavedUser();
    await Future.delayed(const Duration(milliseconds: 400));

    if (!context.mounted) return;

    if (user != null) {
      context.go('/home', extra: {
        'token': user['token'],
        'userId': user['userId'],
        'username': user['username'],
      });
    } else {
      context.go('/login');
    }
  }
}
