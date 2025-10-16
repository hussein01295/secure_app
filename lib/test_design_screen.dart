import 'package:flutter/material.dart';
import 'package:silencia/features/chat/widgets/chat_widgets.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_migration_helper.dart';
import 'core/widgets/modern_ui_components.dart'; 

class TestDesignScreen extends StatefulWidget {
  const TestDesignScreen({super.key});

  @override
  State<TestDesignScreen> createState() => _TestDesignScreenState();
}

class _TestDesignScreenState extends State<TestDesignScreen> {
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
      child: Scaffold(
        appBar: ModernAppBar(
          title: 'Test du Nouveau Design',
          actions: [
            IconButton(
              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                setState(() {
                  isDarkMode = !isDarkMode;
                });
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Test des couleurs
              _buildColorSection(),
              
              const SizedBox(height: AppTheme.spacing24),
              
              // Test des boutons
              _buildButtonSection(),
              
              const SizedBox(height: AppTheme.spacing24),
              
              // Test des cartes
              _buildCardSection(),

              const SizedBox(height: AppTheme.spacing24),

              // Test du champ de recherche
              _buildSearchSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorSection() {
    final isDark = isDarkMode;
    
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎨 Palette de Couleurs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ThemeMigrationHelper.getTextColorLegacy(false, isDark),
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          
          // Couleurs primaires
          Row(
            children: [
              _buildColorSwatch('Primaire', AppTheme.primaryBlue),
              const SizedBox(width: AppTheme.spacing12),
              _buildColorSwatch('Secondaire', AppTheme.primaryBlueDark),
              const SizedBox(width: AppTheme.spacing12),
              _buildColorSwatch('Succès', AppTheme.success),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacing12),
          
          Row(
            children: [
              _buildColorSwatch('Attention', AppTheme.warning),
              const SizedBox(width: AppTheme.spacing12),
              _buildColorSwatch('Erreur', AppTheme.error),
              const SizedBox(width: AppTheme.spacing12),
              _buildColorSwatch('Surface', ThemeMigrationHelper.getSurfaceColorLegacy(isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorSwatch(String name, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          name,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildButtonSection() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔘 Boutons Modernes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacing16),
          
          // Bouton primaire
          ModernButton(
            text: 'Bouton Primaire',
            icon: Icons.send_rounded,
            onPressed: () {},
          ),
          
          const SizedBox(height: AppTheme.spacing12),
          
          // Bouton secondaire
          ModernButton(
            text: 'Bouton Secondaire',
            icon: Icons.favorite_rounded,
            onPressed: () {},
            isSecondary: true,
          ),
          
          const SizedBox(height: AppTheme.spacing12),
          
          // Bouton en chargement
          ModernButton(
            text: 'Chargement...',
            onPressed: () {},
            isLoading: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🃏 Cartes Modernes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTheme.spacing12),
        
        ModernCard(
          onTap: () {},
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Carte Interactive',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      'Avec ombres douces et bordures subtiles',
                      style: TextStyle(
                        color: ThemeMigrationHelper.getSecondaryTextColorLegacy(isDarkMode),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchSection() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔍 Champ de Recherche',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacing16),
          
          const ModernSearchField(
            hintText: 'Rechercher dans les messages...',
          ),
        ],
      ),
    );
  }
}
