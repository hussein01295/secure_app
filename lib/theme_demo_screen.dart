import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

class ThemeDemoScreen extends StatefulWidget {
  const ThemeDemoScreen({super.key});

  @override
  State<ThemeDemoScreen> createState() => _ThemeDemoScreenState();
}

class _ThemeDemoScreenState extends State<ThemeDemoScreen> {
  AppThemeMode _currentTheme = AppThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Démo Thèmes Révolutionnaires',
      theme: AppTheme.getTheme(_currentTheme),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('🎨 Thèmes Époustouflants'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🌟 Sélecteur de thème
              _buildThemeSelector(),
              
              const SizedBox(height: 24),
              
              // 💬 Aperçu des messages
              _buildChatPreview(),
              
              const SizedBox(height: 24),
              
              // 🎨 Palette de couleurs
              _buildColorPalette(),
              
              const SizedBox(height: 24),
              
              // 🔘 Composants UI
              _buildUIComponents(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎨 Sélecteur de Thème',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: AppThemeMode.values.map((theme) {
                final isSelected = _currentTheme == theme;
                return GestureDetector(
                  onTap: () => setState(() => _currentTheme = theme),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: _getThemeGradient(theme),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: _getAccentColor(theme).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ] : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          AppTheme.getThemeIcon(theme),
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppTheme.getThemeName(theme),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💬 Aperçu des Messages',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Message reçu
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 250),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.getMessageBubbleColor(false, _currentTheme),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: Text(
                  'Salut ! Comment tu trouves les nouveaux thèmes ? 😍',
                  style: TextStyle(
                    color: AppTheme.getTextColor(false, _currentTheme),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Message envoyé
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 250),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.getMessageBubbleColor(true, _currentTheme),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  'WOUAHHHHH ! Ils sont incroyables ! 🚀✨',
                  style: TextStyle(
                    color: AppTheme.getTextColor(true, _currentTheme),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎨 Palette de Couleurs',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildColorSwatch('Surface', AppTheme.getSurfaceColor(_currentTheme)),
                _buildColorSwatch('Carte', AppTheme.getCardColor(_currentTheme)),
                _buildColorSwatch('Bordure', AppTheme.getBorderColor(_currentTheme)),
                _buildColorSwatch('Arrière-plan', AppTheme.getBackgroundColor(_currentTheme)),
                if (_currentTheme == AppThemeMode.neon) ...[
                  _buildColorSwatch('Néon Violet', AppTheme.neonPurple),
                  _buildColorSwatch('Néon Rose', AppTheme.neonPink),
                  _buildColorSwatch('Néon Bleu', AppTheme.neonBlue),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSwatch(String name, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildUIComponents() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔘 Composants UI',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Boutons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Bouton Principal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Bouton Secondaire'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Champ de texte
            TextField(
              decoration: const InputDecoration(
                labelText: 'Champ de texte',
                hintText: 'Tapez quelque chose...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getThemeGradient(AppThemeMode theme) {
    return AppTheme.getPrimaryGradient(theme);
  }

  Color _getAccentColor(AppThemeMode theme) {
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
