import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:silencia/core/theme/theme.dart'; // ✅ le bon import
import 'package:silencia/core/theme/app_theme.dart';
import 'package:silencia/core/theme/theme_manager.dart';

import 'package:silencia/features/setting/widgets/biometric_settings_widget.dart';
import 'package:share_plus/share_plus.dart';

import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/service/socket_service.dart';
import 'package:silencia/core/services/auto_backup_service.dart';
import 'package:silencia/core/services/key_backup_service.dart';
import 'package:silencia/core/services/local_language_backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Etat pour les différentes options
  bool notificationEnabled = true;
  bool localKeyPresent = true;

  // Nouveaux états pour la confidentialité
  bool showOnlineStatus = true;
  bool readReceiptsEnabled = true;
  bool _autoBackupEnabled = false;
  bool _autoBackupLoading = true;
  bool _hasBackup = false;
  bool _backupStatusLoading = true;
  bool _localAutoBackupEnabled = false;
  bool _localAutoLoading = true;
  bool _hasLocalBackup = false;
  bool _autoBackupNeedsAttention = false;
  bool _localRequiresRegeneration = false;

  // 🎨 Gestionnaire de thème global
  AppThemeMode get _currentTheme => globalThemeManager.currentTheme;

  void _setTheme(AppThemeMode theme) {
    globalThemeManager.setTheme(theme);
    setState(() {}); // Forcer le rebuild de l'interface
  }

  Future<void> logout() async {
    await AuthService.logout(); // Supprime les tokens de session
    SocketService().dispose(); // Ferme proprement la connexion socket
    if (mounted) context.go('/login');
  }

  @override
  void initState() {
    super.initState();
    _loadAutoBackupPreference();
    _loadBackupStatus();
    _loadLocalAutoBackupPreference();
    _loadLocalBackupStatus();
    _loadAutoBackupHealth();
    _loadLocalRegenerationFlag();
  }

  Future<void> _loadAutoBackupPreference() async {
    final bool enabled = await AutoBackupService.isAutoBackupEnabled();
    if (!mounted) return;
    setState(() {
      _autoBackupEnabled = enabled;
      _autoBackupLoading = false;
    });
    if (enabled) {
      await AutoBackupService.flushPendingBackups();
      await _loadAutoBackupHealth();
    }
  }

  Future<void> _loadBackupStatus() async {
    final String? token = await AuthService.getToken();
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _backupStatusLoading = false;
        _hasBackup = false;
      });
      return;
    }
    final bool hasBackup = await KeyBackupService.hasBackup(token);
    if (!mounted) return;
    setState(() {
      _hasBackup = hasBackup;
      _backupStatusLoading = false;
    });
  }

  Future<void> _loadLocalAutoBackupPreference() async {
    final bool enabled = await LocalLanguageBackupService.isAutoUpdateEnabled();
    if (!mounted) return;
    setState(() {
      _localAutoBackupEnabled = enabled;
      _localAutoLoading = false;
    });
    await _loadLocalRegenerationFlag();
  }

  Future<void> _loadLocalBackupStatus() async {
    final bool exists = await LocalLanguageBackupService.backupExists();
    if (!mounted) return;
    setState(() {
      _hasLocalBackup = exists;
    });
    await _loadLocalRegenerationFlag();
  }

  Future<void> _loadAutoBackupHealth() async {
    final bool hasIssues = await AutoBackupService.hasPendingFailures();
    if (!mounted) return;
    setState(() {
      _autoBackupNeedsAttention = hasIssues;
    });
    if (hasIssues) {
      await AutoBackupService.clearFailureFlag();
    }
  }

  Future<void> _loadLocalRegenerationFlag() async {
    final bool needs = await LocalLanguageBackupService.needsRegeneration();
    if (!mounted) return;
    setState(() {
      _localRequiresRegeneration = needs;
    });
  }

  Future<bool> _toggleAutoBackup(bool value) async {
    if (value) {
      final bool ready = await _ensureAutoBackupReady();
      if (!ready) {
        if (mounted) {
          setState(() => _autoBackupEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Create a backup before enabling auto backup.'),
            ),
          );
        }
        return false;
      }
    }

    try {
      if (mounted) {
        setState(() {
          _autoBackupEnabled = value;
          if (!value) {
            _autoBackupNeedsAttention = false;
          }
        });
      }
      await AutoBackupService.setAutoBackupEnabled(value);
      if (value) {
        await AutoBackupService.scheduleFullSync(origin: 'manual-enable');
      } else {
        await AutoBackupService.clearFailureFlag();
      }
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Auto backup enabled.' : 'Auto backup disabled.',
            ),
          ),
        );
      }
      await _loadAutoBackupHealth();
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _autoBackupEnabled = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto backup error: $e')),
        );
      }
      return false;
    }
  }


  Future<bool> _ensureAutoBackupReady() async {
    if (_hasBackup) return true;
    final String? token = await AuthService.getToken();
    bool hasBackup = _hasBackup;
    if (token != null) {
      try {
        hasBackup = await KeyBackupService.hasBackup(token);
      } catch (_) {
        hasBackup = false;
      }
      if (hasBackup && mounted) {
        setState(() => _hasBackup = true);
        return true;
      }
    }
    if (!mounted) return false;
    final bool? shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup required'),
        content: const Text(
          'Create a secure backup before enabling automatic uploads.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open backup setup'),
          ),
        ],
      ),
    );
    if (shouldOpen == true) {
      await context.push('/backup-choice');
      if (!mounted) return false;
      await _loadBackupStatus();
      return _hasBackup;
    }
    return false;
  }

  Future<void> _toggleLocalAutoBackup(bool value) async {
    if (value) {
      final bool exists = await LocalLanguageBackupService.backupExists();
      final bool hasKey =
          await LocalLanguageBackupService.hasStoredDerivedKey();
      final bool needsRegen =
          await LocalLanguageBackupService.needsRegeneration();
      if (!exists || !hasKey || needsRegen) {
        if (!mounted) return;
        final bool? openSetup = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Local backup required'),
            content: const Text(
              'Create or refresh your encrypted file before enabling automatic updates.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open local backup'),
              ),
            ],
          ),
        );
        if (openSetup == true) {
          await context.push('/local-backup-choice');
          if (!mounted) return;
          await _loadLocalBackupStatus();
          await _loadLocalRegenerationFlag();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Local backup required before enabling auto update.'),
            ),
          );
        }
        return;
      }
    }

    await LocalLanguageBackupService.setAutoUpdateEnabled(value);
    await _loadLocalRegenerationFlag();
    if (!mounted) return;
    setState(() => _localAutoBackupEnabled = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Local auto update enabled.' : 'Local auto update disabled.',
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text("Paramètres", style: theme.appBarTheme.titleTextStyle),
        centerTitle: true,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          // PROFIL
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: colorScheme.primary,
                child: Icon(
                  Icons.person,
                  color: colorScheme.onPrimary,
                  size: 36,
                ),
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "User",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "@User",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // COMPTE
          _sectionTitle("Compte", colorScheme),
          _settingsTile(
            icon: Icons.edit,
            label: "Modifier le profil",
            colorScheme: colorScheme,
            onTap: () {
              context.push('/settings/edit-profile');
            },
          ),
          _settingsTile(
            icon: Icons.lock_reset_rounded,
            label: "Changer le mot de passe",
            colorScheme: colorScheme,
            onTap: () {
              context.push('/settings/change-password');
            },
          ),
          const SizedBox(height: 22),

          // SÉCURITÉ
          _sectionTitle("Sécurité", colorScheme),
          _settingsTile(
            icon: Icons.shield_rounded,
            label: "Chiffrement : AES-256",
            colorScheme: colorScheme,
            trailing: localKeyPresent
                ? Text(
                    "Clé locale ✅",
                    style: TextStyle(color: Colors.cyanAccent, fontSize: 13),
                  )
                : Text(
                    "Aucune clé",
                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
            onTap: () {},
          ),
          const SizedBox(height: 16),

          // Widget biométrique avancé
          const BiometricSettingsWidget(),
          const SizedBox(height: 22),

          // CONFIDENTIALITÉ
          _sectionTitle("Confidentialité", colorScheme),
          _switchTile(
            icon: Icons.visibility_rounded,
            label: "Afficher mon statut en ligne",
            value: showOnlineStatus,
            colorScheme: colorScheme,
            onChanged: (v) => setState(() => showOnlineStatus = v),
          ),
          _switchTile(
            icon: Icons.done_all_rounded,
            label: "Accusé de lecture (messages vus)",
            value: readReceiptsEnabled,
            colorScheme: colorScheme,
            onChanged: (v) => setState(() => readReceiptsEnabled = v),
          ),
          _settingsTile(
            icon: Icons.block,
            label: "Utilisateurs bloqués",
            colorScheme: colorScheme,
            trailing: Text(
              "3",
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => _showBlockedUsers(context, colorScheme),
          ),
          _settingsTile(
            icon: Icons.history,
            label: "Effacer l'historique des conversations",
            colorScheme: colorScheme,
            onTap: () => _showClearHistoryDialog(context, colorScheme),
          ),
          const SizedBox(height: 22),

          // PARTAGE ET SAUVEGARDE
          _sectionTitle("Partage & Sauvegarde", colorScheme),
          _settingsTile(
            icon: Icons.share,
            label: "Partager l'application",
            colorScheme: colorScheme,
            onTap: () => _shareApp(),
          ),
          _settingsTile(
            icon: Icons.backup,
            label: "Backup des clés",
            colorScheme: colorScheme,
            trailing: _backupStatusLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _hasBackup ? Icons.check_circle : Icons.cloud_upload,
                    color: _hasBackup
                        ? Colors.greenAccent
                        : colorScheme.primary,
                  ),
            onTap: () => _showBackupOptions(context, colorScheme),
          ),
          if (_autoBackupNeedsAttention)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              child: Text(
                'Auto backup has pending retries. Check connectivity or credentials.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.orangeAccent,
                ),
              ),
            ),

          _settingsTile(
            icon: Icons.restore,
            label: "Restaurer un backup",
            colorScheme: colorScheme,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.push('/restore-backup'),
          ),
          _settingsTile(
            icon: Icons.folder,
            label: "Sauvegarde locale des langues",
            subtitle: _hasLocalBackup
                ? "Fichier chiffré disponible"
                : "Aucun fichier local",
            colorScheme: colorScheme,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              await context.push('/local-backup-choice');
              if (!mounted) return;
              await _loadLocalBackupStatus();
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Automatic local file update'),
            subtitle: Text(
              !_hasLocalBackup
                  ? 'Create a local backup before enabling this option.'
                  : _localRequiresRegeneration
                      ? 'Regenerate the encrypted file to restore auto update.'
                      : 'Refreshes the file whenever a new language is stored.',
            ),
            value: _localAutoBackupEnabled,
            onChanged: (_localAutoLoading || !_hasLocalBackup)
                ? null
                : (bool value) async {
                    await _toggleLocalAutoBackup(value);
                  },
          ),

          _settingsTile(
            icon: Icons.download,
            label: "Exporter mes données",
            colorScheme: colorScheme,
            onTap: () => _exportUserData(context),
          ),
          const SizedBox(height: 22),

          // AVANCÉ
          _sectionTitle("Avancé", colorScheme),
          _settingsTile(
            icon: Icons.storage,
            label: "Stockage et données",
            colorScheme: colorScheme,
            trailing: Text(
              "2.3 GB",
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            onTap: () => _showStorageInfo(context, colorScheme),
          ),
          _settingsTile(
            icon: Icons.language,
            label: "Langue",
            colorScheme: colorScheme,
            trailing: Text(
              "Français",
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            onTap: () => _showLanguageOptions(context, colorScheme),
          ),
          _settingsTile(
            icon: Icons.update,
            label: "Vérifier les mises à jour",
            colorScheme: colorScheme,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "À jour",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            onTap: () => _checkForUpdates(context),
          ),
          const SizedBox(height: 22),

          // NOTIFICATIONS
          _sectionTitle("Notifications", colorScheme),
          _switchTile(
            icon: Icons.notifications_active_rounded,
            label: "Activer les notifications",
            value: notificationEnabled,
            colorScheme: colorScheme,
            onChanged: (v) => setState(() => notificationEnabled = v),
          ),
          const SizedBox(height: 22),

          // APPARENCE - NOUVEAU SYSTÈME DE THÈMES 🎨
          _sectionTitle("Apparence", colorScheme),

          // 🌟 Sélecteur de thème révolutionnaire
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.palette_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Thèmes de l'application",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                  )],
                ),
                const SizedBox(height: 8),
                Text(
                  "Choisissez le thème qui vous correspond",
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                // 🎨 Grille des thèmes
                _buildThemeGrid(colorScheme),
              ],
            ),
          ),
          // --- BOUTON MATERIAL 3 ---
          ListTile(
            leading: Icon(Icons.palette_outlined, color: colorScheme.primary),
            title: Text(
              "Theme Material 3 (Preview)",
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
            ),
            subtitle: Text(
              material3Notifier.value
                  ? "Activé (nouveau look Google)"
                  : "Désactivé (classique)",
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            onTap: () => _showMaterial3Modal(context, colorScheme),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 28),

          // ASTUCE SÉCURITÉ
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.indigo[900]?.withValues(alpha: 0.38)
                  : Colors.indigo[50]?.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb, color: Colors.cyanAccent),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    "Astuce : Ne partage jamais ta clé de chiffrement avec qui que ce soit.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // === BOUTON DECONNEXION ===
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              "Déconnexion",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            onPressed: logout,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, ColorScheme colorScheme) => Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 7, top: 10),
    child: Text(
      title,
      style: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 1,
      ),
    ),
  );

  Widget _settingsTile({
    required IconData icon,
    required String label,
    String? subtitle,
    required ColorScheme colorScheme,
    Widget? trailing,
    Function()? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(
        label,
        style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      hoverColor: colorScheme.primary.withValues(alpha: 0.08),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String label,
    required bool value,
    required ColorScheme colorScheme,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(
        label,
        style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.cyanAccent,
        inactiveThumbColor: colorScheme.onSurface.withValues(alpha: 0.1),
        inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.05),
      ),
    );
  }

  void _showMaterial3Modal(BuildContext context, ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Material 3 (Material You)",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Essayez le nouveau style Google !",
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 18),
              SwitchListTile(
                title: const Text("Activer Material 3"),
                value: material3Notifier.value,
                activeThumbColor: Colors.cyanAccent,
                onChanged: (v) {
                  material3Notifier.value = v;
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              const SizedBox(height: 6),
              Text(
                "Material 3 propose :\n- Des formes arrondies\n- Couleurs dynamiques\n- Composants modernes\n- Transitions améliorées\n\nRedémarrage non nécessaire.",
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.left,
              ),
            ],
          ),
        );
      },
    );
  }

  // Nouvelles méthodes pour les fonctionnalités ajoutées
  void _showBlockedUsers(BuildContext context, ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Utilisateurs bloqués",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            // Liste simulée d'utilisateurs bloqués
            ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.primary,
                child: Icon(Icons.person, color: colorScheme.onPrimary),
              ),
              title: Text("Utilisateur1"),
              subtitle: Text("Bloqué il y a 2 jours"),
              trailing: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Utilisateur débloqué")),
                  );
                },
                child: Text("Débloquer"),
              ),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.primary,
                child: Icon(Icons.person, color: colorScheme.onPrimary),
              ),
              title: Text("Utilisateur2"),
              subtitle: Text("Bloqué il y a 1 semaine"),
              trailing: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Utilisateur débloqué")),
                  );
                },
                child: Text("Débloquer"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          "Effacer l'historique",
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: Text(
          "Cette action supprimera définitivement tous vos messages. Cette action est irréversible.",
          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Historique effacé"),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text("Effacer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _shareApp() {
    Share.share(
      'Découvre SecureApp, l\'application de messagerie la plus sécurisée ! Télécharge-la maintenant.',
      subject: 'SecureApp - Messagerie sécurisée',
    );
  }

  void _showBackupOptions(BuildContext context, ColorScheme colorScheme) {
    bool localAutoValue = _autoBackupEnabled;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Options de sauvegarde',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(
                      Icons.cloud_upload,
                      color: colorScheme.primary,
                    ),
                    title: const Text('Créer ou mettre à jour un backup'),
                    subtitle: _backupStatusLoading
                        ? const Text('Vérification…')
                        : Text(
                            _hasBackup
                                ? 'Une sauvegarde est disponible'
                                : 'Aucun backup enregistré',
                          ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      context
                          .push('/backup-choice')
                          .then((_) => _loadBackupStatus());
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.restore, color: colorScheme.primary),
                    title: const Text('Restaurer un backup'),
                    subtitle: const Text(
                      'Mot de passe maître ou phrase de récupération',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      context
                          .push('/restore-backup')
                          .then((_) => _loadBackupStatus());
                    },
                  ),
                  const Divider(height: 32),
                  if (_autoBackupLoading)
                    const ListTile(
                      leading: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      title: Text('Chargement des préférences…'),
                    )
                  else
                    SwitchListTile.adaptive(
                      value: localAutoValue,
                      onChanged: (value) async {
                        modalSetState(() => localAutoValue = value);
                        final bool success = await _toggleAutoBackup(value);
                        if (!success) {
                          modalSetState(() => localAutoValue = _autoBackupEnabled);
                        }
                      },
                      title: const Text('Automatic cloud backup'),
                      subtitle: Text(
                        _autoBackupNeedsAttention
                            ? 'Pending retries detected. Review connectivity or credentials.'
                            : 'Adds new language keys to the remote backup automatically.',
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _exportUserData(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Exporter mes données"),
        content: Text(
          "Vos données seront exportées dans un fichier JSON sécurisé.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Export en cours...")),
              );
            },
            child: Text("Exporter"),
          ),
        ],
      ),
    );
  }

  void _showStorageInfo(BuildContext context, ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Stockage et données",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _storageItem("Messages", "1.8 GB", colorScheme),
            _storageItem("Médias", "450 MB", colorScheme),
            _storageItem("Cache", "50 MB", colorScheme),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Cache vidé")));
              },
              child: Text("Vider le cache"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storageItem(String label, String size, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface)),
          Text(
            size,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageOptions(BuildContext context, ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Choisir la langue",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _languageItem("🇫🇷", "Français", true, colorScheme),
            _languageItem("🇺🇸", "English", false, colorScheme),
            _languageItem("🇪🇸", "Español", false, colorScheme),
            _languageItem("🇩🇪", "Deutsch", false, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _languageItem(
    String flag,
    String language,
    bool selected,
    ColorScheme colorScheme,
  ) {
    return ListTile(
      leading: Text(flag, style: TextStyle(fontSize: 24)),
      title: Text(language),
      trailing: selected ? Icon(Icons.check, color: colorScheme.primary) : null,
      onTap: () {
        Navigator.pop(context);
        if (!selected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Langue changée vers $language")),
          );
        }
      },
    );
  }

  void _checkForUpdates(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Vérification des mises à jour"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text("Recherche de mises à jour..."),
          ],
        ),
      ),
    );

    // Simuler la vérification
    // Capturer les références avant l'opération async
    final navigator = Navigator.of(context);

    Future.delayed(Duration(seconds: 2), () {
      if (!mounted) return;
      navigator.pop();

      // Utiliser showDialog de manière sécurisée
      if (mounted) {
        // ignore: use_build_context_synchronously
        showDialog(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (context) => AlertDialog(
            title: Text("✅ Application à jour"),
            content: Text("Vous utilisez la dernière version de SecureApp."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          ),
        );
      }
    });
  }

  // 🎨 Méthode pour construire la grille des thèmes
  Widget _buildThemeGrid(ColorScheme colorScheme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: AppThemeMode.values.length,
      itemBuilder: (context, index) {
        final theme = AppThemeMode.values[index];
        final isSelected = _currentTheme == theme;

        return _buildThemeCard(theme, isSelected, colorScheme);
      },
    );
  }

  // 🌟 Méthode pour construire une carte de thème
  Widget _buildThemeCard(
    AppThemeMode theme,
    bool isSelected,
    ColorScheme colorScheme,
  ) {
    final themeName = AppTheme.getThemeName(theme);
    final themeIcon = AppTheme.getThemeIcon(theme);

    return GestureDetector(
      onTap: () => _setTheme(theme),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: _getThemeGradient(theme),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _getAccentColor(theme) : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            if (isSelected) ...[
              BoxShadow(
                color: _getAccentColor(theme).withValues(alpha: 0.3),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(themeIcon, size: 28, color: Colors.white),
            ),

            const SizedBox(height: 8),

            // 📝 Nom du thème
            Text(
              themeName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 4),

            // ✨ Indicateur de sélection
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
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

  // 🌈 Méthode pour obtenir le gradient du thème
  LinearGradient _getThemeGradient(AppThemeMode theme) {
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
          colors: [AppTheme.neonPurple, AppTheme.neonPink, AppTheme.neonBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  // 🎯 Méthode pour obtenir la couleur d'accent du thème
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
