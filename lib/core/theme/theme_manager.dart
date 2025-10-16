import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

// 🌟 Instance globale du gestionnaire de thème
final ThemeManager globalThemeManager = ThemeManager();

class ThemeManager extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  AppThemeMode _currentTheme = AppThemeMode.dark;
  
  AppThemeMode get currentTheme => _currentTheme;
  
  ThemeData get themeData => AppTheme.getTheme(_currentTheme);
  
  bool get isDark => _currentTheme == AppThemeMode.dark || _currentTheme == AppThemeMode.neon;
  
  // 🎨 Initialiser le thème depuis les préférences
  Future<void> initTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? AppThemeMode.dark.index;
    _currentTheme = AppThemeMode.values[themeIndex];
    notifyListeners();
  }
  
  // 🔄 Changer le thème
  Future<void> setTheme(AppThemeMode theme) async {
    if (_currentTheme != theme) {
      _currentTheme = theme;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, theme.index);
      notifyListeners();
    }
  }
  
  // 🌟 Méthodes utilitaires pour les couleurs
  Color getMessageBubbleColor(bool isFromMe) {
    return AppTheme.getMessageBubbleColor(isFromMe, _currentTheme);
  }

  // 🎨 Bordure pour les bulles de messages (thème clair)
  Border? getMessageBubbleBorder(bool isFromMe) {
    return AppTheme.getMessageBubbleBorder(isFromMe, _currentTheme);
  }

  // 🌟 Ombre pour les bulles de messages
  List<BoxShadow>? getMessageBubbleShadow(bool isFromMe) {
    return AppTheme.getMessageBubbleShadow(isFromMe, _currentTheme);
  }
  
  Color getTextColor(bool isFromMe) {
    return AppTheme.getTextColor(isFromMe, _currentTheme);
  }
  
  Color getSecondaryTextColor() {
    return AppTheme.getSecondaryTextColor(_currentTheme);
  }
  
  Color getSurfaceColor() {
    return AppTheme.getSurfaceColor(_currentTheme);
  }
  
  Color getCardColor() {
    return AppTheme.getCardColor(_currentTheme);
  }
  
  Color getBorderColor() {
    return AppTheme.getBorderColor(_currentTheme);
  }
  
  Color getBackgroundColor() {
    return AppTheme.getBackgroundColor(_currentTheme);
  }

  // 🎨 Background amélioré pour les chats
  Color getChatBackgroundColor() {
    switch (_currentTheme) {
      case AppThemeMode.light:
        return const Color(0xFFF8F9FA); // Gris très clair
      case AppThemeMode.dark:
        return const Color(0xFF0F1419); // Noir doux au lieu du noir absolu
      case AppThemeMode.neon:
        return const Color(0xFF0A0A0F); // Noir profond avec une teinte violette
    }
  }
  
  LinearGradient getPrimaryGradient() {
    return AppTheme.getPrimaryGradient(_currentTheme);
  }
  
  LinearGradient getMessageGradient(bool isFromMe) {
    return AppTheme.getMessageGradient(isFromMe, _currentTheme);
  }
  
  // 🎯 Méthodes pour l'interface
  String getThemeName() {
    return AppTheme.getThemeName(_currentTheme);
  }
  
  IconData getThemeIcon() {
    return AppTheme.getThemeIcon(_currentTheme);
  }
  
  // 🌈 Obtenir tous les thèmes disponibles
  List<AppThemeMode> get availableThemes => AppThemeMode.values;
  
  // 🎨 Obtenir la couleur d'accent selon le thème
  Color get accentColor {
    switch (_currentTheme) {
      case AppThemeMode.light:
        return AppTheme.lightAccent;
      case AppThemeMode.dark:
        return AppTheme.darkAccent;
      case AppThemeMode.neon:
        return AppTheme.neonAccent;
    }
  }
  
  // ✨ Vérifier si le thème supporte les gradients
  bool get supportsGradients => _currentTheme == AppThemeMode.neon;
  
  // 🌟 Obtenir la couleur primaire du thème
  Color get primaryColor {
    switch (_currentTheme) {
      case AppThemeMode.light:
        return AppTheme.primaryBlue;
      case AppThemeMode.dark:
        return AppTheme.primaryBlue;
      case AppThemeMode.neon:
        return AppTheme.neonPurple;
    }
  }
}
