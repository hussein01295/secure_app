import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'register_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with RegisterController {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.cyanAccent, width: 2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add, size: 80, color: Colors.cyanAccent),
              ),
              const SizedBox(height: 24),
              const Text(
                "Créer un compte",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: usernameController,
                decoration: inputDecoration("Nom d'utilisateur", Icons.person),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: inputDecoration("Mot de passe", Icons.lock),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: displayNameController,
                decoration: inputDecoration("Nom affiché", Icons.badge),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Créer un compte", style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text("Retour à la connexion", style: TextStyle(color: Colors.cyanAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.cyan),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.cyan),
      filled: true,
      fillColor: const Color(0xFF19232b),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
