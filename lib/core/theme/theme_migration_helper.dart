import 'package:flutter/material.dart';
import 'app_theme.dart';

// 🔄 Helper pour la migration des anciens appels AppTheme
class ThemeMigrationHelper {
  
  // 🎨 Méthodes de compatibilité pour les anciens appels avec bool isDark
  static Color getMessageBubbleColorLegacy(bool isFromMe, bool isDark) {
    final themeMode = isDark ? AppThemeMode.dark : AppThemeMode.light;
    return AppTheme.getMessageBubbleColor(isFromMe, themeMode);
  }

  static Color getTextColorLegacy(bool isFromMe, bool isDark) {
    final themeMode = isDark ? AppThemeMode.dark : AppThemeMode.light;
    return AppTheme.getTextColor(isFromMe, themeMode);
  }

  static Color getSecondaryTextColorLegacy(bool isDark) {
    final themeMode = isDark ? AppThemeMode.dark : AppThemeMode.light;
    return AppTheme.getSecondaryTextColor(themeMode);
  }

  static Color getSurfaceColorLegacy(bool isDark) {
    final themeMode = isDark ? AppThemeMode.dark : AppThemeMode.light;
    return AppTheme.getSurfaceColor(themeMode);
  }

  static Color getCardColorLegacy(bool isDark) {
    final themeMode = isDark ? AppThemeMode.dark : AppThemeMode.light;
    return AppTheme.getCardColor(themeMode);
  }

  static Color getBorderColorLegacy(bool isDark) {
    final themeMode = isDark ? AppThemeMode.dark : AppThemeMode.light;
    return AppTheme.getBorderColor(themeMode);
  }

  static Color getBackgroundColorLegacy(bool isDark) {
    final themeMode = isDark ? AppThemeMode.dark : AppThemeMode.light;
    return AppTheme.getBackgroundColor(themeMode);
  }
}

// 🎯 Extension pour faciliter l'utilisation avec BuildContext
extension ThemeContextExtension on BuildContext {
  
  // 🌟 Obtenir le ThemeManager depuis le contexte
  // ThemeManager get themeManager => Provider.of<ThemeManager>(this, listen: false);
  
  // 🎨 Méthodes de raccourci pour les couleurs
  Color messageColor(bool isFromMe) {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return ThemeMigrationHelper.getMessageBubbleColorLegacy(isFromMe, isDark);
  }
  
  Color textColor(bool isFromMe) {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return ThemeMigrationHelper.getTextColorLegacy(isFromMe, isDark);
  }
  
  Color get secondaryTextColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return ThemeMigrationHelper.getSecondaryTextColorLegacy(isDark);
  }
  
  Color get surfaceColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return ThemeMigrationHelper.getSurfaceColorLegacy(isDark);
  }
  
  Color get cardColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return ThemeMigrationHelper.getCardColorLegacy(isDark);
  }
  
  Color get borderColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return ThemeMigrationHelper.getBorderColorLegacy(isDark);
  }
  
  Color get backgroundColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return ThemeMigrationHelper.getBackgroundColorLegacy(isDark);
  }
  
  // 🎯 Vérifier si le thème est sombre
  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;
}

// 🌈 Mixin pour les widgets qui utilisent les thèmes
mixin ThemeAwareMixin<T extends StatefulWidget> on State<T> {
  
  // 🎨 Obtenir les couleurs selon le thème actuel
  Color getMessageBubbleColor(bool isFromMe) {
    return context.messageColor(isFromMe);
  }
  
  Color getTextColor(bool isFromMe) {
    return context.textColor(isFromMe);
  }
  
  Color get secondaryTextColor => context.secondaryTextColor;
  Color get surfaceColor => context.surfaceColor;
  Color get cardColor => context.cardColor;
  Color get borderColor => context.borderColor;
  Color get backgroundColor => context.backgroundColor;
  bool get isDark => context.isDarkTheme;
}

// 🎯 Widget de base pour les composants thématiques
abstract class ThemedWidget extends StatelessWidget {
  const ThemedWidget({super.key});
  
  // 🎨 Méthodes utilitaires pour les couleurs
  Color getMessageBubbleColor(BuildContext context, bool isFromMe) {
    return context.messageColor(isFromMe);
  }
  
  Color getTextColor(BuildContext context, bool isFromMe) {
    return context.textColor(isFromMe);
  }
  
  Color getSecondaryTextColor(BuildContext context) {
    return context.secondaryTextColor;
  }
  
  Color getSurfaceColor(BuildContext context) {
    return context.surfaceColor;
  }
  
  Color getCardColor(BuildContext context) {
    return context.cardColor;
  }
  
  Color getBorderColor(BuildContext context) {
    return context.borderColor;
  }
  
  Color getBackgroundColor(BuildContext context) {
    return context.backgroundColor;
  }
  
  bool isDarkTheme(BuildContext context) {
    return context.isDarkTheme;
  }
}

// 🌟 Constantes pour les transitions
class ThemeConstants {
  static const Duration transitionDuration = Duration(milliseconds: 300);
  static const Duration longTransitionDuration = Duration(milliseconds: 600);
  static const Curve transitionCurve = Curves.easeInOut;
  static const Curve elasticCurve = Curves.elasticOut;
  
  // 🎨 Couleurs d'animation
  static const Color shimmerBaseColor = Color(0xFFE0E0E0);
  static const Color shimmerHighlightColor = Color(0xFFF5F5F5);
  static const Color shimmerBaseColorDark = Color(0xFF2A2A2A);
  static const Color shimmerHighlightColorDark = Color(0xFF3A3A3A);
  
  // 🌈 Gradients d'animation
  static const LinearGradient loadingGradient = LinearGradient(
    colors: [
      Color(0xFFE0E0E0),
      Color(0xFFF5F5F5),
      Color(0xFFE0E0E0),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.0, 0.0),
    end: Alignment(1.0, 0.0),
  );
  
  static const LinearGradient loadingGradientDark = LinearGradient(
    colors: [
      Color(0xFF2A2A2A),
      Color(0xFF3A3A3A),
      Color(0xFF2A2A2A),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.0, 0.0),
    end: Alignment(1.0, 0.0),
  );
}
