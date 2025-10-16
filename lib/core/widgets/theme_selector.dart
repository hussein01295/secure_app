import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ThemeSelector extends StatefulWidget {
  final AppThemeMode currentTheme;
  final Function(AppThemeMode) onThemeChanged;

  const ThemeSelector({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<ThemeSelector> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🎨 Titre de la section
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Text(
            'Thème de l\'application',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // 🌟 Grille des thèmes
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppTheme.spacing12,
              mainAxisSpacing: AppTheme.spacing12,
              childAspectRatio: 0.8,
            ),
            itemCount: AppThemeMode.values.length,
            itemBuilder: (context, index) {
              final theme = AppThemeMode.values[index];
              final isSelected = widget.currentTheme == theme;

              return _ThemeCard(
                theme: theme,
                isSelected: isSelected,
                onTap: () => widget.onThemeChanged(theme),
              );
            },
          ),
        ),

        const SizedBox(height: AppTheme.spacing24),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final AppThemeMode theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeName = AppTheme.getThemeName(theme);
    final themeIcon = AppTheme.getThemeIcon(theme);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: _getThemeGradient(),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: isSelected 
                ? _getAccentColor() 
                : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            if (isSelected) ...[
              BoxShadow(
                color: _getAccentColor().withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ] else ...[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🎯 Icône du thème
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(
                themeIcon,
                size: 32,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacing8),
            
            // 📝 Nom du thème
            Text(
              themeName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppTheme.spacing4),
            
            // ✨ Indicateur de sélection
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing8,
                  vertical: AppTheme.spacing4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Text(
                  'Actuel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getThemeGradient() {
    switch (theme) {
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
        return const LinearGradient(
          colors: [
            AppTheme.neonPurple,
            AppTheme.neonPink,
            AppTheme.neonBlue,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _getAccentColor() {
    switch (theme) {
      case AppThemeMode.light:
        return AppTheme.lightAccent;
      case AppThemeMode.dark:
        return AppTheme.darkAccent;
      case AppThemeMode.neon:
        return AppTheme.neonAccent;
    }
  }
}

// 🎨 Widget de prévisualisation du thème
class ThemePreview extends StatelessWidget {
  final AppThemeMode theme;

  const ThemePreview({
    super.key,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      margin: const EdgeInsets.all(AppTheme.spacing8),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.getBorderColor(theme),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 📱 Barre d'app simulée
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(theme),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusMedium),
                topRight: Radius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: Center(
              child: Text(
                AppTheme.getThemeName(theme),
                style: TextStyle(
                  color: AppTheme.getTextColor(false, theme),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          
          // 💬 Messages simulés
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              child: Column(
                children: [
                  // Message reçu
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.getMessageBubbleColor(false, theme),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Salut !',
                        style: TextStyle(
                          color: AppTheme.getTextColor(false, theme),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Message envoyé
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.getMessageBubbleColor(true, theme),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Coucou !',
                        style: TextStyle(
                          color: AppTheme.getTextColor(true, theme),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
