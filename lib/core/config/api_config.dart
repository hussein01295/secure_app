// lib/core/config/api_config.dart
import 'package:flutter/foundation.dart';

class ApiConfig {
  // 🚀 CONFIGURATION PRODUCTION
  static const String _prodBaseUrl = "http://54.165.222.234:3000/api";

  // 🔧 CONFIGURATION LOCALE (pour développement)       // Émulateur Android
  // static const String baseUrl = "http://192.168.1.143:3000/api";   // Téléphone physique


  // 🔧 CONFIGURATION DÉVELOPPEMENT
  static const String _devBaseUrl = "http://192.168.1.143:3000/api"; // Émulateur Android

  // URL dynamique selon l'environnement
  static String get baseUrl => kDebugMode ? _devBaseUrl : _prodBaseUrl;

  static String get baseHost => baseUrl.replaceFirst('/api', '');
  static String uploads(String path) => "$baseHost/uploads/$path";

  // Configuration des timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Méthode utilitaire pour connaître l'environnement actuel
  static bool get isProduction => !kDebugMode;
  static bool get isDevelopment => kDebugMode;
}
