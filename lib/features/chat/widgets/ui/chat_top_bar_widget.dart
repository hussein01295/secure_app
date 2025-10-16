import 'package:flutter/material.dart';
import 'package:silencia/core/theme/app_theme.dart';
import 'package:silencia/core/theme/theme_migration_helper.dart';
import 'package:silencia/core/widgets/modern_ui_components.dart';

/// Barre d'en-tÃªte du chat avec gestion de la traduction et des statuts de langue.
class ChatTopBar extends StatelessWidget {
  final VoidCallback onToggleTranslation;
  final bool estTraduit;
  final String myLangStatus;
  final String otherLangStatus;
  final VoidCallback? onShowDebugInfo;
  final Map<String, String>? langMap;

  const ChatTopBar({
    super.key,
    required this.onToggleTranslation,
    required this.estTraduit,
    required this.myLangStatus,
    required this.otherLangStatus,
    this.onShowDebugInfo,
    this.langMap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: ThemeMigrationHelper.getCardColorLegacy(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: ThemeMigrationHelper.getBorderColorLegacy(isDark),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ModernButton(
              text: estTraduit ? 'Afficher code' : 'Traduire',
              icon: Icons.g_translate_rounded,
              onPressed: onToggleTranslation,
              isSecondary: true,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          if (onShowDebugInfo != null && langMap != null)
            IconButton(
              icon: Icon(
                Icons.info_outline,
                color: isDark ? Colors.cyan : Colors.blue,
                size: 20,
              ),
              onPressed: onShowDebugInfo,
              tooltip: 'Infos debug langues',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          if (onShowDebugInfo != null && langMap != null)
            const SizedBox(width: AppTheme.spacing8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusIndicator(
                label: 'Vous',
                status: myLangStatus,
                isDark: isDark,
              ),
              const SizedBox(height: AppTheme.spacing4),
              _StatusIndicator(
                label: 'Contact',
                status: otherLangStatus,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fonction de compatibilitÃ© pour l'ancien appel fonctionnel.
Widget buildTopBar({
  required VoidCallback onToggleTranslation,
  required bool estTraduit,
  required String myLangStatus,
  required String otherLangStatus,
  required VoidCallback? onShowDebugInfo,
  required Map<String, String>? langMap,
}) {
  return ChatTopBar(
    onToggleTranslation: onToggleTranslation,
    estTraduit: estTraduit,
    myLangStatus: myLangStatus,
    otherLangStatus: otherLangStatus,
    onShowDebugInfo: onShowDebugInfo,
    langMap: langMap,
  );
}

class ChatTopBarStatus {
  static const success = 'success';
  static const pending = 'pending';
  static const error = 'error';
}

class _StatusIndicator extends StatelessWidget {
  final String label;
  final String status;
  final bool isDark;

  const _StatusIndicator({
    required this.label,
    required this.status,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor();
    final icon = _resolveIcon();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: ThemeMigrationHelper.getSecondaryTextColorLegacy(isDark),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: AppTheme.spacing4),
        Icon(icon, size: 14, color: color),
      ],
    );
  }

  Color _resolveColor() {
    switch (status) {
      case ChatTopBarStatus.success:
        return AppTheme.success;
      case ChatTopBarStatus.pending:
        return AppTheme.warning;
      case ChatTopBarStatus.error:
        return AppTheme.error;
      default:
        return ThemeMigrationHelper.getSecondaryTextColorLegacy(isDark);
    }
  }

  IconData _resolveIcon() {
    switch (status) {
      case ChatTopBarStatus.success:
        return Icons.check_circle_rounded;
      case ChatTopBarStatus.pending:
        return Icons.schedule_rounded;
      case ChatTopBarStatus.error:
        return Icons.error_rounded;
      default:
        return Icons.help_rounded;
    }
  }
}
