import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:silencia/features/profil/profile_me_controller.dart';
import 'package:share_plus/share_plus.dart';

import 'package:silencia/core/theme/app_theme.dart';
import 'package:silencia/core/widgets/cached_profile_avatar.dart';
import 'package:silencia/core/service/profile_cache_service.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:silencia/features/call/models/call_state.dart';

class ProfileView extends StatefulWidget {
  final String username;
  final String? displayName;
  final bool isCurrentUser;
  final String? userId;
  final ProfileController controller;

  const ProfileView({
    super.key,
    required this.username,
    this.displayName,
    this.isCurrentUser = false,
    this.userId,
    required this.controller,
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> with TickerProviderStateMixin {
  late final ProfileController _controller;
  // ✅ OPTIMISATION: Plus d'état de chargement, affichage instantané
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // Données du profil étendues
  // ✅ OPTIMISATION: Valeurs par défaut pour affichage instantané
  bool _isOnline = true;
  String _customStatus = 'Disponible pour discuter 💬';
  String _statusEmoji = '😊';
  int _totalMessages = 0;
  int _totalGroups = 0;
  DateTime? _lastSeen;
  bool _isOfflineMode = false;
  final ProfileCacheService _cacheService = ProfileCacheService();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _setupAnimations();

    // ✅ Démarrer l'animation immédiatement
    _animationController.forward();

    // Charger les données en arrière-plan
    _load();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
    );

    if (_isOnline) {
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _load() async {
    // ✅ OPTIMISATION: Charger le cache immédiatement
    await _loadFromCache();

    // ✅ OPTIMISATION: Charger depuis le serveur en arrière-plan (non bloquant)
    _loadFromServerInBackground();
  }

  /// Charge les données depuis le serveur en arrière-plan sans bloquer l'UI
  Future<void> _loadFromServerInBackground() async {
    try {
      // Vérifier la connectivité
      await _checkConnectivity();

      // Si hors ligne, ne pas essayer de charger depuis le serveur
      if (_isOfflineMode) return;

      // Charger depuis le serveur en parallèle
      await Future.wait([
        _controller.fetchInitial(),
        _loadExtendedProfileData(),
      ]);

      // Mettre à jour l'UI avec les nouvelles données
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement serveur en arrière-plan: $e');
      // En cas d'erreur, garder les données du cache
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      _isOfflineMode = connectivityResult == ConnectivityResult.none;

      if (_isOfflineMode && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Text('Mode hors ligne - Données en cache'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _isOfflineMode = true;
    }
  }

  Future<void> _loadFromCache() async {
    try {
      if (widget.isCurrentUser) {
        // Charger le profil utilisateur depuis le cache
        final cachedProfile = await _cacheService.getMyProfile();
        if (cachedProfile != null) {

          // Charger les statistiques depuis le cache
          final userId = await AuthService.getUserId();
          if (userId != null) {
            final cachedStats = await _cacheService.getProfileStats(userId);
            if (cachedStats != null) {
              _totalMessages = cachedStats['totalMessages'] ?? 1247;
              _totalGroups = cachedStats['totalGroups'] ?? 8;
              _isOnline = cachedStats['isOnline'] ?? true;
              _customStatus = cachedStats['customStatus'] ?? "Disponible pour discuter 💬";
              _statusEmoji = cachedStats['statusEmoji'] ?? "😊";

              if (cachedStats['lastSeen'] != null) {
                _lastSeen = DateTime.parse(cachedStats['lastSeen']);
              }
            } else {
              // Valeurs par défaut si pas de cache
              _setDefaultValues();
            }
          }
        }
      } else {
        // Charger le profil d'un autre utilisateur depuis le cache
        if (widget.userId != null) {
          final cachedProfile = await _cacheService.getUserProfile(widget.userId!);
          if (cachedProfile != null) {
            // Profile data loaded from cache
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement cache: $e');
      _setDefaultValues();
    }
  }

  void _setDefaultValues() {
    _totalMessages = 1247;
    _totalGroups = 8;
    _isOnline = true;
    _customStatus = widget.isCurrentUser ? "Disponible pour discuter 💬" : "En ligne";
    _statusEmoji = "😊";
    _lastSeen = DateTime.now().subtract(const Duration(minutes: 5));
  }

  Future<void> _loadExtendedProfileData() async {
    try {
      // Si on est en mode hors ligne, ne pas essayer de charger depuis le serveur
      if (_isOfflineMode) {
        return;
      }

      // ✅ OPTIMISATION: Suppression du délai artificiel de 500ms
      // Charger les données étendues depuis le serveur (à implémenter avec vraie API)

      if (mounted) {
        setState(() {
          _isOnline = true;
          _customStatus = widget.isCurrentUser ? "Disponible pour discuter 💬" : "En ligne";
          _statusEmoji = "😊";
          _totalMessages = 1247;
          _totalGroups = 8;
          _lastSeen = DateTime.now().subtract(const Duration(minutes: 5));
        });

        // Sauvegarder les données en cache
        await _saveToCache();
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement données étendues: $e');
      // En cas d'erreur, garder les valeurs par défaut ou du cache
    }
  }

  Future<void> _saveToCache() async {
    try {
      if (widget.isCurrentUser) {
        // Sauvegarder le profil utilisateur
        final userId = await AuthService.getUserId();
        if (userId != null) {
          await _cacheService.saveMyProfile(
            userId: userId,
            username: widget.username,
            displayName: widget.displayName,
          );

          // Sauvegarder les statistiques
          await _cacheService.saveProfileStats(
            userId: userId,
            totalMessages: _totalMessages,
            totalGroups: _totalGroups,
            lastSeen: _lastSeen,
            isOnline: _isOnline,
            customStatus: _customStatus,
            statusEmoji: _statusEmoji,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde cache: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // ✅ OPTIMISATION: Affichage instantané, plus d'écran de chargement
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, colorScheme),
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: _buildProfileContent(context, colorScheme),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: colorScheme.surface,
      elevation: 0,
      leading: (!widget.isCurrentUser)
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: colorScheme.primary),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: _isOfflineMode ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Text(
            'Hors ligne',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ) : null,
      actions: [
        if (widget.isCurrentUser) ...[
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: Icon(Icons.settings, color: colorScheme.primary),
          ),
          IconButton(
            onPressed: () => _showProfileOptions(context),
            icon: Icon(Icons.more_vert, color: colorScheme.primary),
          ),
        ] else ...[
          IconButton(
            onPressed: () => _shareProfile(),
            icon: Icon(Icons.share, color: colorScheme.primary),
          ),
          IconButton(
            onPressed: () => _showMoreOptions(context),
            icon: Icon(Icons.more_vert, color: colorScheme.primary),
          ),
        ],
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withValues(alpha: 0.1),
                colorScheme.secondary.withValues(alpha: 0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, ColorScheme colorScheme) {


    return Padding(
      padding: const EdgeInsets.all(16.0), // Réduit de 20 à 16
      child: Column(
        children: [
          // Avatar et informations principales
          _buildProfileHeader(context, colorScheme),
          const SizedBox(height: 20), // Réduit de 24 à 20

          // Statut personnalisé
          _buildCustomStatus(context, colorScheme),
          const SizedBox(height: 16), // Réduit de 24 à 16

          // Statistiques
          _buildStatsSection(context, colorScheme),
          const SizedBox(height: 16), // Réduit de 24 à 16

          // Actions rapides
          _buildQuickActions(context, colorScheme),
          const SizedBox(height: 20), // Réduit de 24 à 20

          // Bouton principal (edit, ajouter, etc)
          _buildRelationOrEditButton(context, colorScheme),
          const SizedBox(height: 20), // Réduit de 32 à 20

          // Sections supplémentaires
          if (widget.isCurrentUser) ...[
            _buildMyProfileSections(context, colorScheme),
          ] else ...[
            _buildOtherProfileSections(context, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, ColorScheme colorScheme) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Avatar avec indicateur de statut
        Stack(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isOnline ? _pulseAnimation.value : 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: LargeProfileAvatar(
                      username: widget.username,
                      displayName: widget.displayName,
                      radius: 60,
                      showOnlineStatus: true,
                      isOnline: _isOnline,
                      enablePulseAnimation: true,
                    ),
                  ),
                );
              },
            ),
            // Indicateur de statut en ligne
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _isOnline ? AppTheme.success : theme.colorScheme.outline,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.surface, width: 3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Nom et username
        Text(
          widget.displayName?.isNotEmpty == true ? widget.displayName! : widget.username,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          "@${widget.username}",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),

        // Dernière connexion pour les autres utilisateurs
        if (!widget.isCurrentUser && _lastSeen != null) ...[
          const SizedBox(height: 8),
          Text(
            _isOnline ? "En ligne" : "Vu il y a ${_formatLastSeen(_lastSeen!)}",
            style: theme.textTheme.bodySmall?.copyWith(
              color: _isOnline ? AppTheme.success : colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomStatus(BuildContext context, ColorScheme colorScheme) {
    if (_customStatus.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_statusEmoji.isNotEmpty) ...[
            Text(_statusEmoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              _customStatus,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16), // Réduit de 20 à 16
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12), // Réduit de 16 à 12
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05), // Réduit l'ombre
            blurRadius: 6, // Réduit de 10 à 6
            offset: const Offset(0, 1), // Réduit de 2 à 1
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            colorScheme,
            widget.isCurrentUser && _controller is ProfileMeController
                ? _controller.friendsCount.toString()
                : "0",
            "Amis",
            Icons.people,
            onTap: widget.isCurrentUser && _controller is ProfileMeController
                ? () => _showFriendsList(context, colorScheme)
                : null,
          ),
          _buildStatItem(
            context,
            colorScheme,
            _totalGroups.toString(),
            "Groupes",
            Icons.group,
          ),
          _buildStatItem(
            context,
            colorScheme,
            _formatNumber(_totalMessages),
            "Messages",
            Icons.message,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    ColorScheme colorScheme,
    String value,
    String label,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(icon, color: colorScheme.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ColorScheme colorScheme) {
    if (widget.isCurrentUser) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildQuickActionButton(
          context,
          colorScheme,
          Icons.message,
          "Message",
          () => _startConversation(context),
        ),
        _buildQuickActionButton(
          context,
          colorScheme,
          Icons.call,
          "Appeler",
          () => _makeCall(context),
        ),
        _buildQuickActionButton(
          context,
          colorScheme,
          Icons.videocam,
          "Vidéo",
          () => _makeVideoCall(context),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context,
    ColorScheme colorScheme,
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: colorScheme.onPrimary, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMyProfileSections(BuildContext context, ColorScheme colorScheme) {
    return const SizedBox.shrink(); // Suppression des sections pour mon profil
  }

  Widget _buildOtherProfileSections(BuildContext context, ColorScheme colorScheme) {
    return Column(
      children: [
        _buildCompactSectionCard(
          context,
          colorScheme,
          "Amis en commun",
          [
            _buildMutualFriendsItem(context, colorScheme),
          ],
        ),
        const SizedBox(height: 12), // Réduit de 16 à 12
        _buildCompactSectionCard(
          context,
          colorScheme,
          "Groupes en commun",
          [
            _buildMutualGroupsItem(context, colorScheme),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactSectionCard(
    BuildContext context,
    ColorScheme colorScheme,
    String title,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12), // Réduit de 16 à 12
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12), // Réduit de 16 à 12
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith( // Changé de titleMedium à titleSmall
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8), // Réduit de 12 à 8
          ...children,
        ],
      ),
    );
  }

  Widget _buildMutualFriendsItem(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primary,
              child: Icon(Icons.person, size: 16, color: colorScheme.onPrimary),
            ),
            Positioned(
              left: 20,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.secondary,
                child: Icon(Icons.person, size: 16, color: colorScheme.onSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Text(
            "3 amis en commun",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        TextButton(
          onPressed: () => _showMutualFriends(context),
          child: const Text("Voir"),
        ),
      ],
    );
  }

  Widget _buildMutualGroupsItem(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(Icons.group, color: colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            "2 groupes en commun",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        TextButton(
          onPressed: () => _showMutualGroups(context),
          child: const Text("Voir"),
        ),
      ],
    );
  }



  Widget _buildRelationOrEditButton(BuildContext context, ColorScheme colorScheme) {


    // Son propre profil
    if (widget.isCurrentUser) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ElevatedButton(
          onPressed: () {
            // TODO: logique d'édition de profil
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          child: const Text("Edit profile"),
        ),
      );
    }

    // Profil d'autrui
    if (_controller is ProfileUserController) {
      final user = _controller;
      switch (user.relationStatus) {
        case 'accepted':
          return _relationButton(
            colorScheme.surface,
            colorScheme.primary,
            Icons.check,
            'Ami',
            colorScheme.primary,
            onTap: () async {
              // Capturer la référence avant les opérations async
              final messenger = ScaffoldMessenger.of(context);

              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: colorScheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  title: Text("Supprimer cet ami ?", style: TextStyle(color: colorScheme.onSurface)),
                  content: Text("Voulez-vous vraiment supprimer cet ami ?", style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text("Annuler", style: TextStyle(color: colorScheme.primary)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text("Supprimer", style: TextStyle(color: AppTheme.error)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final ok = await user.deleteFriend();
                if (ok && mounted) setState(() {});
                if (ok) {
                  messenger.showSnackBar(
                    SnackBar(content: const Text("Ami supprimé.", style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
          );
        case 'sent':
          return _relationButton(
            colorScheme.surface,
            colorScheme.primary,
            Icons.hourglass_empty,
            'Demande envoyée',
            colorScheme.primary,
          );
        case 'received':
          return _relationButton(
            colorScheme.primary,
            colorScheme.onPrimary,
            Icons.person_add,
            'Accepter la demande',
            colorScheme.onPrimary,
            onTap: () async {
              final ok = await user.acceptFriendRequest();
              if (ok && mounted) setState(() {});
            },
          );
        case 'none':
        default:
          return _relationButton(
            colorScheme.primary,
            colorScheme.onPrimary,
            Icons.person_add_alt_1,
            'Ajouter',
            colorScheme.onPrimary,
            onTap: () async {
              final ok = await user.sendFriendRequest();
              if (ok && mounted) setState(() {});
            },
          );
      }
    }
    return const SizedBox();
  }

  Widget _relationButton(
    Color bg,
    Color fg,
    IconData icon,
    String label,
    Color iconColor, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsListModal(List friends, ColorScheme colorScheme) {
    return SizedBox(
      height: 380,
      child: friends.isEmpty
          ? Center(child: Text("Aucun ami", style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7))))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 20),
              itemCount: friends.length,
              separatorBuilder: (_, __) => Divider(color: colorScheme.onSurface.withValues(alpha: 0.12), height: 1),
              itemBuilder: (ctx, idx) {
                final f = friends[idx];
                return ListTile(
                  leading: CachedProfileAvatar(
                    username: f['username'] ?? "Utilisateur",
                    displayName: f['displayName'],
                    radius: 20,
                  ),
                  title: Text(
                    f['displayName'] ?? f['username'] ?? "Utilisateur",
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('@${f['username'] ?? ""}', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.65))),
                  onTap: () {
                    context.push(
                      '/profile',
                      extra: {
                        'username': f['username'],
                        'displayName': f['displayName'],
                        'userId': f['_id'],
                        'isCurrentUser': false,
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  // Méthodes utilitaires
  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return "à l'instant";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes} min";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h";
    } else {
      return "${difference.inDays}j";
    }
  }

  String _formatNumber(int number) {
    if (number < 1000) return number.toString();
    if (number < 1000000) return "${(number / 1000).toStringAsFixed(1)}k";
    return "${(number / 1000000).toStringAsFixed(1)}M";
  }

  // Méthodes d'action
  void _showProfileOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modifier le profil'),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings/edit-profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Code QR'),
              onTap: () {
                Navigator.pop(context);
                _showQRCode(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Partager le profil'),
              onTap: () {
                Navigator.pop(context);
                _shareProfile();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareProfile() {
    Share.share(
      'Découvre le profil de ${widget.displayName ?? widget.username} sur SecureApp !',
      subject: 'Profil SecureApp',
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Bloquer'),
              onTap: () {
                Navigator.pop(context);
                _blockUser(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Signaler'),
              onTap: () {
                Navigator.pop(context);
                _reportUser(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQRCode(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Code QR du profil'),
        content: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text('QR Code\n(À implémenter)', textAlign: TextAlign.center),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showFriendsList(BuildContext context, ColorScheme colorScheme) {
    if (_controller is ProfileMeController) {
      final me = _controller;
      showModalBottomSheet(
        context: context,
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _buildFriendsListModal(me.friends, colorScheme),
      );
    }
  }

  void _showMutualFriends(BuildContext context) {
    // À implémenter
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité à venir')),
    );
  }

  void _showMutualGroups(BuildContext context) {
    // À implémenter
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité à venir')),
    );
  }

  void _startConversation(BuildContext context) {
    context.push('/chat', extra: {
      'username': widget.username,
      'userId': widget.userId,
    });
  }

  void _makeCall(BuildContext context) {
    context.push('/call', extra: {
      'contactName': widget.username,
      'contactId': widget.userId,
      'callType': CallType.audio,
      'isIncoming': false,
    });
  }

  void _makeVideoCall(BuildContext context) {
    context.push('/call', extra: {
      'contactName': widget.username,
      'contactId': widget.userId,
      'callType': CallType.video,
      'isIncoming': false,
    });
  }

  void _blockUser(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bloquer cet utilisateur'),
        content: const Text('Êtes-vous sûr de vouloir bloquer cet utilisateur ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Logique de blocage à implémenter
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Utilisateur bloqué')),
              );
            },
            child: const Text('Bloquer'),
          ),
        ],
      ),
    );
  }

  void _reportUser(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signaler cet utilisateur'),
        content: const Text('Voulez-vous signaler cet utilisateur pour comportement inapproprié ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Logique de signalement à implémenter
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Utilisateur signalé')),
              );
            },
            child: const Text('Signaler'),
          ),
        ],
      ),
    );
  }
}
