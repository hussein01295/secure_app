import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silencia/core/service/ephemeral_service.dart';
import 'package:silencia/features/chat/ephemeral_settings_screen.dart';
import 'package:silencia/core/widgets/cached_profile_avatar.dart';
import 'package:silencia/core/service/image_cache_service.dart';

class ProfileConversationScreen extends StatefulWidget {
  final String contactName;
  final String username;
  final bool isOnline;
  final String lastSeen;
  final String secureStatus;
  final int exchangedMessages;
  final String lastMessage;
  final String lastMessageDate;
  final List<String> sharedPhotos;
  final String? contactId;
  final String? relationId;

  const ProfileConversationScreen({
    super.key,
    required this.contactName,
    required this.username,
    required this.isOnline,
    required this.lastSeen,
    required this.secureStatus,
    required this.exchangedMessages,
    required this.lastMessage,
    required this.lastMessageDate,
    required this.sharedPhotos,
    this.contactId,
    this.relationId,
  });

  @override
  State<ProfileConversationScreen> createState() => _ProfileConversationScreenState();
}

class _ProfileConversationScreenState extends State<ProfileConversationScreen>
    with TickerProviderStateMixin {
  AnimationController? _headerAnimationController;
  AnimationController? _fabAnimationController;
  Animation<double>? _headerAnimation;
  Animation<double>? _fabAnimation;

  bool _isNotificationsMuted = false;
  bool _isBlocked = false;
  bool _showAdvancedStats = false;
  int _selectedMediaTab = 0; // 0: Photos, 1: Vidéos, 2: Documents, 3: Liens

  // 🔥 Variables pour les messages éphémères
  String _ephemeralStatus = 'Chargement...';
  bool _ephemeralEnabled = false;

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
      value: 0.0, // Commencer avec une valeur valide
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
      value: 0.0, // Commencer avec une valeur valide
    );

    // 🔥 Charger les paramètres de messages éphémères
    _loadEphemeralSettings();

    _headerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController!,
      curve: Curves.easeOutBack,
    ));

    _fabAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController!,
      curve: Curves.elasticOut,
    ));

    // Démarrer les animations après un délai pour éviter les erreurs d'opacité
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerAnimationController?.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        _fabAnimationController?.forward();
      });
    });
  }

  @override
  void dispose() {
    _headerAnimationController?.dispose();
    _fabAnimationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
            onPressed: () => _showMoreOptions(context),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Header avec avatar et infos
          SliverToBoxAdapter(
            child: _headerAnimation != null
                ? AnimatedBuilder(
                    animation: _headerAnimation!,
                    builder: (context, child) {
                      final animationValue = _headerAnimation!.value.clamp(0.0, 1.0);
                      return Transform.translate(
                        offset: Offset(0, 50 * (1 - animationValue)),
                        child: Opacity(
                          opacity: animationValue,
                          child: _buildHeader(context, theme, isDark, colorScheme),
                        ),
                      );
                    },
                  )
                : _buildHeader(context, theme, isDark, colorScheme),
          ),

          // Actions rapides
          SliverToBoxAdapter(
            child: _buildQuickActions(context, theme, colorScheme),
          ),

          // Statistiques
          SliverToBoxAdapter(
            child: _buildStatistics(context, theme, colorScheme),
          ),

          // Médias partagés
          SliverToBoxAdapter(
            child: _buildSharedMedia(context, theme, colorScheme),
          ),

          // Paramètres de conversation
          SliverToBoxAdapter(
            child: _buildConversationSettings(context, theme, colorScheme),
          ),

          // Actions de sécurité
          SliverToBoxAdapter(
            child: _buildSecurityActions(context, theme, colorScheme),
          ),

          // Espacement final
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),

      // FAB animé
      floatingActionButton: _fabAnimation != null
          ? AnimatedBuilder(
              animation: _fabAnimation!,
              builder: (context, child) {
                final scaleValue = _fabAnimation!.value.clamp(0.0, 1.0);
                return Transform.scale(
                  scale: scaleValue,
                  child: FloatingActionButton.extended(
                    onPressed: () => _startCall(context),
                    icon: const Icon(Icons.call),
                    label: const Text('Appeler'),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                );
              },
            )
          : FloatingActionButton.extended(
              onPressed: () => _startCall(context),
              icon: const Icon(Icons.call),
              label: const Text('Appeler'),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
    );
  }

  // Header avec avatar et informations
  Widget _buildHeader(BuildContext context, ThemeData theme, bool isDark, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 32),
      child: Column(
        children: [
          // Avatar avec animation
          Hero(
            tag: 'avatar_${widget.contactId}',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LargeProfileAvatar(
                username: widget.username,
                displayName: widget.contactName,
                radius: 60,
                showOnlineStatus: true,
                isOnline: widget.isOnline,
                enablePulseAnimation: true,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Nom du contact
          Text(
            widget.contactName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Username
          Text(
            '@${widget.username}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 12),

          // Statut en ligne
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isOnline
                  ? Colors.green.withValues(alpha: 0.1)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isOnline ? Colors.green : colorScheme.outline,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isOnline ? "En ligne" : "Vu ${widget.lastSeen}",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: widget.isOnline ? Colors.green : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Actions rapides
  Widget _buildQuickActions(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickActionButton(
            icon: Icons.message,
            label: 'Message',
            color: colorScheme.primary,
            onTap: () => Navigator.pop(context),
          ),
          _buildQuickActionButton(
            icon: Icons.videocam,
            label: 'Vidéo',
            color: Colors.green,
            onTap: () => _startVideoCall(context),
          ),
          _buildQuickActionButton(
            icon: Icons.search,
            label: 'Rechercher',
            color: Colors.orange,
            onTap: () => _searchInConversation(context),
          ),
          _buildQuickActionButton(
            icon: Icons.info_outline,
            label: 'Infos',
            color: Colors.blue,
            onTap: () => _showContactInfo(context),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Statistiques de conversation
  Widget _buildStatistics(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Statistiques',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAdvancedStats = !_showAdvancedStats;
                  });
                },
                child: Text(_showAdvancedStats ? 'Masquer' : 'Voir plus'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Cartes de statistiques
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.message,
                  title: 'Messages',
                  value: widget.exchangedMessages.toString(),
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.photo,
                  title: 'Photos',
                  value: widget.sharedPhotos.length.toString(),
                  color: Colors.green,
                ),
              ),
            ],
          ),

          if (_showAdvancedStats) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.thumb_up,
                    title: 'Réactions',
                    value: '${math.Random().nextInt(50) + 10}',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.schedule,
                    title: 'Jours actifs',
                    value: '${math.Random().nextInt(30) + 5}',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // Médias partagés avec onglets
  Widget _buildSharedMedia(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Médias partagés',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 16),

          // Onglets de médias
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildMediaTab('Photos', 0, Icons.photo),
                _buildMediaTab('Vidéos', 1, Icons.videocam),
                _buildMediaTab('Documents', 2, Icons.description),
                _buildMediaTab('Liens', 3, Icons.link),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Contenu des médias
          _buildMediaContent(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildMediaTab(String title, int index, IconData icon) {
    final isSelected = _selectedMediaTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMediaTab = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(ThemeData theme, ColorScheme colorScheme) {
    switch (_selectedMediaTab) {
      case 0: // Photos
        return _buildPhotosGrid();
      case 1: // Vidéos
        return _buildVideosGrid();
      case 2: // Documents
        return _buildDocumentsList();
      case 3: // Liens
        return _buildLinksList();
      default:
        return _buildPhotosGrid();
    }
  }

  Widget _buildPhotosGrid() {
    if (widget.sharedPhotos.isEmpty) {
      return _buildEmptyState('Aucune photo partagée', Icons.photo);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: math.min(widget.sharedPhotos.length, 6),
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageCacheService().buildChatImage(
                imageUrl: widget.sharedPhotos[index],
                onTap: () {
                  // TODO: Ouvrir la galerie d'images
                },
              ),
              if (index == 5 && widget.sharedPhotos.length > 6)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Text(
                      '+${widget.sharedPhotos.length - 6}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideosGrid() {
    return _buildEmptyState('Aucune vidéo partagée', Icons.videocam);
  }

  Widget _buildDocumentsList() {
    return _buildEmptyState('Aucun document partagé', Icons.description);
  }

  Widget _buildLinksList() {
    return _buildEmptyState('Aucun lien partagé', Icons.link);
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Paramètres de conversation
  Widget _buildConversationSettings(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paramètres de conversation',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                _buildSettingTile(
                  icon: Icons.security,
                  title: 'Canal sécurisé',
                  subtitle: widget.secureStatus,
                  trailing: Icon(Icons.verified, color: Colors.green),
                  onTap: () => _showSecurityDetails(context),
                ),
                _buildSettingTile(
                  icon: _isNotificationsMuted ? Icons.notifications_off : Icons.notifications,
                  title: 'Notifications',
                  subtitle: _isNotificationsMuted ? 'Désactivées' : 'Activées',
                  trailing: Switch(
                    value: !_isNotificationsMuted,
                    onChanged: (value) {
                      setState(() {
                        _isNotificationsMuted = !value;
                      });
                      _toggleNotifications(value);
                    },
                  ),
                  onTap: () {
                    setState(() {
                      _isNotificationsMuted = !_isNotificationsMuted;
                    });
                    _toggleNotifications(!_isNotificationsMuted);
                  },
                ),
                _buildSettingTile(
                  icon: Icons.wallpaper,
                  title: 'Fond d\'écran',
                  subtitle: 'Personnaliser le chat',
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => _changeWallpaper(context),
                ),
                _buildSettingTile(
                  icon: Icons.auto_delete,
                  title: 'Messages éphémères',
                  subtitle: _ephemeralStatus,
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => _configureEphemeralMessages(context),
                ),
                _buildSettingTile(
                  icon: Icons.search,
                  title: 'Rechercher dans les messages',
                  subtitle: 'Trouver un message dans la conversation',
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => _openSearchInChat(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Actions de sécurité
  Widget _buildSecurityActions(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                _buildSettingTile(
                  icon: Icons.flag_outlined,
                  title: 'Signaler',
                  subtitle: 'Signaler ce contact',
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => _reportContact(context),
                  textColor: Colors.orange,
                ),
                _buildSettingTile(
                  icon: _isBlocked ? Icons.person_add : Icons.block,
                  title: _isBlocked ? 'Débloquer' : 'Bloquer',
                  subtitle: _isBlocked ? 'Débloquer ce contact' : 'Bloquer ce contact',
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => _toggleBlockContact(context),
                  textColor: Colors.red,
                ),
                _buildSettingTile(
                  icon: Icons.delete_outline,
                  title: 'Supprimer la conversation',
                  subtitle: 'Supprimer tout l\'historique',
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => _deleteConversation(context),
                  textColor: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (textColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: textColor ?? Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  // Méthodes d'action
  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.share),
              title: Text('Partager le contact'),
              onTap: () {
                Navigator.pop(context);
                _shareContact(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.qr_code),
              title: Text('Code QR'),
              onTap: () {
                Navigator.pop(context);
                _showQRCode(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Modifier le contact'),
              onTap: () {
                Navigator.pop(context);
                _editContact(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startCall(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appel vers ${widget.contactName}...'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () {},
        ),
      ),
    );
  }

  void _startVideoCall(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appel vidéo vers ${widget.contactName}...'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () {},
        ),
      ),
    );
  }

  void _searchInConversation(BuildContext context) {
    showSearch(
      context: context,
      delegate: ConversationSearchDelegate(),
    );
  }

  void _showContactInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Informations du contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nom: ${widget.contactName}'),
            Text('Username: @${widget.username}'),
            Text('Statut: ${widget.isOnline ? "En ligne" : "Hors ligne"}'),
            Text('Messages échangés: ${widget.exchangedMessages}'),
            Text('Dernier message: ${widget.lastMessageDate}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showSecurityDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.green),
            SizedBox(width: 8),
            Text('Sécurité'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cette conversation est protégée par un chiffrement de bout en bout.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16),
            Text('• Messages chiffrés avec AES-256'),
            Text('• Clés échangées via RSA-2048'),
            Text('• Vérification d\'intégrité'),
            Text('• Pas de stockage sur serveur'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Compris'),
          ),
        ],
      ),
    );
  }

  void _toggleNotifications(bool enabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Notifications activées pour ${widget.contactName}'
              : 'Notifications désactivées pour ${widget.contactName}',
        ),
      ),
    );
  }

  void _changeWallpaper(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildWallpaperSelector(context),
    );
  }

  Widget _buildWallpaperSelector(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Liste des fonds d'écran disponibles
    final wallpapers = [
      {
        'name': 'Par défaut',
        'type': 'default',
        'color': colorScheme.surface,
        'icon': Icons.wallpaper,
      },
      {
        'name': 'Dégradé bleu',
        'type': 'gradient_blue',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[400]!, Colors.blue[800]!],
        ),
        'icon': Icons.gradient,
      },
      {
        'name': 'Dégradé violet',
        'type': 'gradient_purple',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple[400]!, Colors.purple[800]!],
        ),
        'icon': Icons.gradient,
      },
      {
        'name': 'Dégradé vert',
        'type': 'gradient_green',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green[400]!, Colors.green[800]!],
        ),
        'icon': Icons.gradient,
      },
      {
        'name': 'Dégradé rose',
        'type': 'gradient_pink',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.pink[400]!, Colors.pink[800]!],
        ),
        'icon': Icons.gradient,
      },
      {
        'name': 'Sombre uni',
        'type': 'solid_dark',
        'color': Colors.grey[900],
        'icon': Icons.circle,
      },
      {
        'name': 'Clair uni',
        'type': 'solid_light',
        'color': Colors.grey[100],
        'icon': Icons.circle_outlined,
      },
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Titre
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Choisir un fond d\'écran',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),

          // Liste des fonds d'écran
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: wallpapers.length,
              itemBuilder: (context, index) {
                final wallpaper = wallpapers[index];
                return _buildWallpaperOption(context, wallpaper);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperOption(BuildContext context, Map<String, dynamic> wallpaper) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => _selectWallpaper(context, wallpaper),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Aperçu du fond d'écran
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: wallpaper['color'],
                  gradient: wallpaper['gradient'],
                ),
              ),

              // Overlay avec nom et icône
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      wallpaper['icon'],
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wallpaper['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectWallpaper(BuildContext context, Map<String, dynamic> wallpaper) async {
    // Capturer les références avant l'opération async
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Sauvegarder le fond d'écran sélectionné
      await _saveWallpaperPreference(wallpaper['type']);

      // Vérifier si le widget est encore monté
      if (!mounted) return;

      // Fermer le sélecteur
      navigator.pop();

      // Afficher confirmation
      messenger.showSnackBar(
        SnackBar(
          content: Text('Fond d\'écran "${wallpaper['name']}" appliqué'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Retourner au chat avec le nouveau fond d'écran
      navigator.pop({'action': 'wallpaperChanged', 'wallpaper': wallpaper['type']});

    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'application du fond d\'écran'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveWallpaperPreference(String wallpaperType) async {
    // Sauvegarder dans les préférences locales
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_wallpaper_${widget.relationId}', wallpaperType);
  }

  // 🔥 Charger les paramètres de messages éphémères
  Future<void> _loadEphemeralSettings() async {
    if (widget.relationId == null) {
      setState(() {
        _ephemeralStatus = 'Non disponible';
      });
      return;
    }

    try {
      final settings = await EphemeralService.getSettings(widget.relationId!);
      setState(() {
        _ephemeralEnabled = settings['enabled'] ?? false;
        _ephemeralStatus = _ephemeralEnabled
            ? EphemeralService.getEphemeralDescription(settings)
            : 'Désactivé';
      });
    } catch (e) {
      setState(() {
        _ephemeralStatus = 'Erreur de chargement';
      });
    }
  }

  // 🔥 Configurer les messages éphémères
  void _configureEphemeralMessages(BuildContext context) async {
    // 🔍 DEBUG: Logs pour diagnostiquer le problème
    debugPrint('🔍 DEBUG: _configureEphemeralMessages appelé');
    debugPrint('🔍 DEBUG: widget.relationId = ${widget.relationId}');
    debugPrint('🔍 DEBUG: widget.relationId == null = ${widget.relationId == null}');
    debugPrint('🔍 DEBUG: widget.relationId?.isEmpty = ${widget.relationId?.isEmpty}');

    if (widget.relationId == null || widget.relationId!.isEmpty || widget.relationId!.trim().isEmpty) {
      debugPrint('❌ DEBUG: Relation non disponible - relationId est null, vide ou whitespace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Relation non disponible (relationId: "${widget.relationId}")'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    debugPrint('✅ DEBUG: relationId valide, navigation vers EphemeralSettingsScreen');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EphemeralSettingsScreen(
          relationId: widget.relationId!,
          contactName: widget.contactName,
        ),
      ),
    );

    // Recharger les paramètres après modification
    if (result != null) {
      await _loadEphemeralSettings();
    }
  }

  // 🔍 Ouvrir la recherche dans le chat
  void _openSearchInChat(BuildContext context) {
    // Retourner au chat avec un indicateur pour activer la recherche
    Navigator.pop(context, {'action': 'openSearch'});
  }

  void _reportContact(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Signaler ${widget.contactName}'),
        content: Text('Voulez-vous signaler ce contact pour comportement inapproprié ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Contact signalé')),
              );
            },
            child: Text('Signaler', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleBlockContact(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isBlocked ? 'Débloquer ${widget.contactName}' : 'Bloquer ${widget.contactName}'),
        content: Text(
          _isBlocked
              ? 'Ce contact pourra à nouveau vous envoyer des messages.'
              : 'Ce contact ne pourra plus vous envoyer de messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _isBlocked = !_isBlocked;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isBlocked ? 'Contact bloqué' : 'Contact débloqué'),
                ),
              );
            },
            child: Text(
              _isBlocked ? 'Débloquer' : 'Bloquer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteConversation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer la conversation'),
        content: Text('Cette action supprimera définitivement tous les messages. Continuer ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Retour à la liste des conversations
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Conversation supprimée')),
              );
            },
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _shareContact(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Partage du contact ${widget.contactName}')),
    );
  }

  void _showQRCode(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Code QR de ${widget.contactName}'),
        content: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code, size: 80, color: Colors.grey[600]),
                SizedBox(height: 8),
                Text('Code QR', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _editContact(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Édition du contact ${widget.contactName}')),
    );
  }
}

// Délégué de recherche pour la conversation
class ConversationSearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Center(
      child: Text('Recherche: "$query"'),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: Icon(Icons.search),
          title: Text('Rechercher "$query"'),
          onTap: () {
            showResults(context);
          },
        ),
      ],
    );
  }
}
