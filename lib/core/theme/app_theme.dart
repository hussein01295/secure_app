import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppThemeMode {
  light,
  dark,
  neon,
}

class AppTheme {
  // 🎨 Couleurs principales améliorées
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color primaryBlueDark = Color(0xFF0056CC);
  static const Color accentCyan = Color(0xFF00D4FF);
  static const Color accentCyanDark = Color(0xFF00A8CC);

  // 🌈 NOUVEAU: Couleurs Néon/Gradient Theme
  static const Color neonPurple = Color(0xFF8B5CF6);
  static const Color neonPink = Color(0xFFEC4899);
  static const Color neonBlue = Color(0xFF06B6D4);
  static const Color neonGreen = Color(0xFF10B981);
  static const Color neonOrange = Color(0xFFF59E0B);

  // 🌟 Gradients époustouflants
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient neonGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D), Color(0xFF4ECDC4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient oceanGradient = LinearGradient(
    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // 🌙 Mode sombre amélioré - Ultra moderne
  static const Color darkBackground = Color(0xFF0D1117);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkCard = Color(0xFF21262D);
  static const Color darkBorder = Color(0xFF30363D);
  static const Color darkAccent = Color(0xFF238636);

  // ☀️ Mode clair amélioré - Élégant et doux
  static const Color lightBackground = Color(0xFFFDFDFD);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF6F8FA);
  static const Color lightBorder = Color(0xFFD0D7DE);
  static const Color lightAccent = Color(0xFF0969DA);

  // 🌈 Mode Néon - Futuriste et vibrant
  static const Color neonBackground = Color(0xFF0A0A0F);
  static const Color neonSurface = Color(0xFF1A1A2E);
  static const Color neonCard = Color(0xFF16213E);
  static const Color neonBorder = Color(0xFF0F3460);
  static const Color neonAccent = Color(0xFFE94560);
  
  // 💬 Couleurs des bulles de chat améliorées
  static const Color myMessageDark = Color(0xFF007AFF);
  static const Color myMessageLight = Color(0xFF007AFF);
  static const Color myMessageNeon = Color(0xFF8B5CF6);
  static const Color otherMessageDark = Color(0xFF21262D);
  static const Color otherMessageLight = Color(0xFFFFFFFF); // Blanc pur pour plus de contraste
  static const Color otherMessageNeon = Color(0xFF16213E);

  // 🎨 Couleurs de bordure pour les bulles
  static const Color messageBorderLight = Color(0xFFE1E8ED); // Bordure gris clair
  static const Color messageBorderDark = Color(0xFF30363D); // Bordure gris foncé
  static const Color messageBorderNeon = Color(0xFF8B5CF6); // Bordure néon

  // 📝 Couleurs de texte optimisées
  static const Color textPrimaryDark = Color(0xFFF0F6FC);
  static const Color textSecondaryDark = Color(0xFF8B949E);
  static const Color textTertiaryDark = Color(0xFF6E7681);

  static const Color textPrimaryLight = Color(0xFF24292F);
  static const Color textSecondaryLight = Color(0xFF656D76);
  static const Color textTertiaryLight = Color(0xFF8C959F);

  // 🌈 Couleurs de texte néon
  static const Color textPrimaryNeon = Color(0xFFFFFFFF);
  static const Color textSecondaryNeon = Color(0xFFB794F6);
  static const Color textTertiaryNeon = Color(0xFF9F7AEA);
  
  // 🎯 Couleurs d'état
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF007AFF);
  
  // 📏 Espacements cohérents
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  
  // 🔄 Rayons de bordure
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  
  // 🎭 Thème sombre
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Couleurs principales
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        primaryContainer: primaryBlueDark,
        secondary: accentCyan,
        secondaryContainer: accentCyanDark,
        surface: darkSurface,
        surfaceContainerHighest: darkBackground,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryDark,
        onError: Colors.white,
      ),
      
      // AppBar moderne
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // Cartes élégantes
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: darkBorder, width: 0.5),
        ),
      ),
      
      // Boutons modernes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
        ),
      ),
      
      // Champs de texte élégants
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      
      // Typographie moderne
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPrimaryDark),
        bodyMedium: TextStyle(color: textSecondaryDark),
        bodySmall: TextStyle(color: textTertiaryDark),
        labelLarge: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: textSecondaryDark),
        labelSmall: TextStyle(color: textTertiaryDark),
      ),
      
      // Icônes
      iconTheme: const IconThemeData(
        color: textSecondaryDark,
        size: 24,
      ),
      
      // Dividers subtils
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 0.5,
        space: 1,
      ),
    );
  }
  
  // ☀️ Thème clair
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Couleurs principales
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        primaryContainer: primaryBlueDark,
        secondary: accentCyan,
        secondaryContainer: accentCyanDark,
        surface: lightSurface,
        surfaceContainerHighest: lightBackground,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
        onError: Colors.white,
      ),
      
      // AppBar moderne
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 1,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // Cartes élégantes
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: lightBorder, width: 0.5),
        ),
      ),
      
      // Boutons modernes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
        ),
      ),
      
      // Champs de texte élégants
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      
      // Typographie moderne
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPrimaryLight),
        bodyMedium: TextStyle(color: textSecondaryLight),
        bodySmall: TextStyle(color: textTertiaryLight),
        labelLarge: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: textSecondaryLight),
        labelSmall: TextStyle(color: textTertiaryLight),
      ),
      
      // Icônes
      iconTheme: const IconThemeData(
        color: textSecondaryLight,
        size: 24,
      ),
      
      // Dividers subtils
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 0.5,
        space: 1,
      ),
    );
  }

  // 🌈 NOUVEAU: Thème Néon Futuriste - WOUAHHHHH!
  static ThemeData get neonTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Couleurs néon époustouflantes
      colorScheme: const ColorScheme.dark(
        primary: neonPurple,
        primaryContainer: neonPink,
        secondary: neonBlue,
        secondaryContainer: neonGreen,
        surface: neonSurface,
        surfaceContainerHighest: neonBackground,
        error: neonOrange,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimaryNeon,
        onError: Colors.white,
        outline: neonBorder,
        outlineVariant: neonAccent,
      ),

      // AppBar avec effet glassmorphism
      appBarTheme: AppBarTheme(
        backgroundColor: neonSurface.withValues(alpha: 0.8),
        foregroundColor: textPrimaryNeon,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(
          color: textPrimaryNeon,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),

      // Cartes avec effet néon
      cardTheme: CardThemeData(
        color: neonCard,
        elevation: 8,
        shadowColor: neonPurple.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(
            color: neonPurple.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),

      // Boutons avec gradients néon
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonPurple,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: neonPurple.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
        ),
      ),

      // Champs de texte futuristes
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neonCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: BorderSide(color: neonBorder.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: BorderSide(color: neonPurple.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: neonPurple, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),

      // Typographie futuriste
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimaryNeon,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          color: textPrimaryNeon,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.25,
        ),
        displaySmall: TextStyle(
          color: textPrimaryNeon,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: TextStyle(
          color: textPrimaryNeon,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.25,
        ),
        headlineMedium: TextStyle(
          color: textPrimaryNeon,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: textPrimaryNeon,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: textPrimaryNeon,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        titleMedium: TextStyle(
          color: textSecondaryNeon,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: textSecondaryNeon,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: textPrimaryNeon),
        bodyMedium: TextStyle(color: textSecondaryNeon),
        bodySmall: TextStyle(color: textTertiaryNeon),
        labelLarge: TextStyle(
          color: textPrimaryNeon,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        labelMedium: TextStyle(color: textSecondaryNeon),
        labelSmall: TextStyle(color: textTertiaryNeon),
      ),

      // Icônes avec effet néon
      iconTheme: IconThemeData(
        color: neonPurple,
        size: 24,
      ),

      // Dividers avec effet lumineux
      dividerTheme: DividerThemeData(
        color: neonPurple.withValues(alpha: 0.3),
        thickness: 1,
        space: 1,
      ),

      // Floating Action Button avec gradient
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: neonPurple,
        foregroundColor: Colors.white,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // 🎨 Méthodes utilitaires pour les couleurs améliorées
  static Color getMessageBubbleColor(bool isFromMe, AppThemeMode themeMode) {
    if (isFromMe) {
      switch (themeMode) {
        case AppThemeMode.light:
          return myMessageLight;
        case AppThemeMode.dark:
          return myMessageDark;
        case AppThemeMode.neon:
          return myMessageNeon;
      }
    } else {
      switch (themeMode) {
        case AppThemeMode.light:
          return otherMessageLight;
        case AppThemeMode.dark:
          return otherMessageDark;
        case AppThemeMode.neon:
          return otherMessageNeon;
      }
    }
  }

  // 🎨 Bordures pour les bulles de messages
  static Border? getMessageBubbleBorder(bool isFromMe, AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        // Bordure subtile pour le thème clair
        return Border.all(
          color: messageBorderLight,
          width: 1.0,
        );
      case AppThemeMode.dark:
        // Bordure subtile pour le thème sombre
        return Border.all(
          color: messageBorderDark,
          width: 0.5,
        );
      case AppThemeMode.neon:
        // Bordure lumineuse pour le thème néon
        return isFromMe
          ? Border.all(
              color: neonPurple.withValues(alpha: 0.4),
              width: 1.0,
            )
          : Border.all(
              color: neonBlue.withValues(alpha: 0.3),
              width: 1.0,
            );
    }
  }

  // 🌟 Ombres pour les bulles de messages
  static List<BoxShadow>? getMessageBubbleShadow(bool isFromMe, AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        // Ombre douce pour le thème clair
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ];
      case AppThemeMode.dark:
        // Ombre subtile pour le thème sombre
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ];
      case AppThemeMode.neon:
        // Ombre lumineuse pour le thème néon
        return [
          BoxShadow(
            color: isFromMe
              ? neonPurple.withValues(alpha: 0.3)
              : neonBlue.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ];
    }
  }

  static Color getTextColor(bool isFromMe, AppThemeMode themeMode) {
    if (isFromMe) {
      return Colors.white;
    } else {
      switch (themeMode) {
        case AppThemeMode.light:
          return textPrimaryLight;
        case AppThemeMode.dark:
          return textPrimaryDark;
        case AppThemeMode.neon:
          return textPrimaryNeon;
      }
    }
  }

  static Color getSecondaryTextColor(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return textSecondaryLight;
      case AppThemeMode.dark:
        return textSecondaryDark;
      case AppThemeMode.neon:
        return textSecondaryNeon;
    }
  }

  static Color getSurfaceColor(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return lightSurface;
      case AppThemeMode.dark:
        return darkSurface;
      case AppThemeMode.neon:
        return neonSurface;
    }
  }

  static Color getCardColor(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return lightCard;
      case AppThemeMode.dark:
        return darkCard;
      case AppThemeMode.neon:
        return neonCard;
    }
  }

  static Color getBorderColor(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return lightBorder;
      case AppThemeMode.dark:
        return darkBorder;
      case AppThemeMode.neon:
        return neonBorder;
    }
  }

  static Color getBackgroundColor(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return lightBackground;
      case AppThemeMode.dark:
        return darkBackground;
      case AppThemeMode.neon:
        return neonBackground;
    }
  }

  // 🌈 Méthodes pour les gradients
  static LinearGradient getPrimaryGradient(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AppThemeMode.dark:
        return const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF4A6741)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AppThemeMode.neon:
        return neonGradient;
    }
  }

  static LinearGradient getMessageGradient(bool isFromMe, AppThemeMode themeMode) {
    if (themeMode == AppThemeMode.neon) {
      if (isFromMe) {
        return const LinearGradient(
          colors: [neonPurple, neonPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      } else {
        return const LinearGradient(
          colors: [neonBlue, neonGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      }
    }
    // Pour les autres thèmes, retourner un gradient neutre
    return LinearGradient(
      colors: [
        getMessageBubbleColor(isFromMe, themeMode),
        getMessageBubbleColor(isFromMe, themeMode),
      ],
    );
  }

  // 🎯 Méthode pour obtenir le thème complet
  static ThemeData getTheme(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return lightTheme;
      case AppThemeMode.dark:
        return darkTheme;
      case AppThemeMode.neon:
        return neonTheme;
    }
  }

  // 📱 Méthode pour obtenir le nom du thème
  static String getThemeName(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return 'Clair';
      case AppThemeMode.dark:
        return 'Sombre';
      case AppThemeMode.neon:
        return 'Néon';
    }
  }

  // 🎨 Méthode pour obtenir l'icône du thème
  static IconData getThemeIcon(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.neon:
        return Icons.auto_awesome;
    }
  }
}
