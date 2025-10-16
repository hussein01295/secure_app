import 'package:flutter/material.dart';
import 'package:silencia/features/splash/splash_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final SplashController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SplashController(context);
    _controller.handleStartup();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121c23),
      body: Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      ),
    );
  }
}
