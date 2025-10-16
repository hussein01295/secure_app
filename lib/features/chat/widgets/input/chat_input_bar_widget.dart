import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:silencia/core/theme/theme_manager.dart';
import 'package:silencia/core/theme/app_theme.dart';

/// Champ de saisie principal du chat avec gestion de l'envoi et enregistrement vocal.
class ChatInputBar extends StatefulWidget {
  final Future<void> Function() onSendMessage;
  final void Function(File audioFile, int durationSeconds)? onSendVoice;
  final void Function(String text)? onSendText;
  final TextEditingController controller;
  final bool enabled;
  final dynamic chatController;

  const ChatInputBar({
    super.key,
    required this.onSendMessage,
    required this.controller,
    required this.chatController,
    this.onSendVoice,
    this.onSendText,
    this.enabled = true,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with TickerProviderStateMixin {
  late bool _hasText;

  // --- États d'enregistrement
  bool _isRecording = false;
  bool _cancelReady = false; // true quand seuil d'annulation dépassé
  Duration _recordDuration = Duration.zero;
  Timer? _timer;

  // --- Enregistrement audio réel
  AudioRecorder? _recorder;
  String? _currentRecordingPath;
  bool _hasAudioPermission = false;

  // --- Constantes UX (selon spécification)
  static const double _cancelThreshold = 120.0; // mobile
  static const Duration _pulseDuration = Duration(milliseconds: 900);
  static const Duration _animDuration = Duration(milliseconds: 180);

  // --- Animation du cercle "on parle" (pulse)
  late final AnimationController _pulseCtrl;

  // --- Variables pour le glissement
  double _dx = 0.0; // déplacement horizontal (négatif vers la gauche)
  bool _hapticsPlayed = false; // pour jouer l'haptique une seule fois

  TextEditingController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.trim().isNotEmpty;
    _controller.addListener(_handleControllerChange);

    // Initialiser l'animation de pulsation (cercle "on parle")
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: _pulseDuration,
    );

    // Initialiser l'enregistreur audio
    _initAudioRecorder();
  }

  Future<void> _initAudioRecorder() async {
    try {
      // Vérifier les permissions microphone
      final permission = await Permission.microphone.status;
      if (permission != PermissionStatus.granted) {
        final result = await Permission.microphone.request();
        if (result != PermissionStatus.granted) {
          debugPrint('⚠️ Permission microphone refusée');
          _hasAudioPermission = false;
          return;
        }
      }

      _recorder = AudioRecorder();
      final isAvailable = await _recorder!.hasPermission();
      if (!isAvailable) {
        debugPrint('⚠️ Enregistrement non disponible');
        _hasAudioPermission = false;
        return;
      }

      _hasAudioPermission = true;
      debugPrint('✅ Audio réel initialisé avec permissions');
    } catch (e) {
      debugPrint('⚠️ Erreur audio réel: $e');
      _hasAudioPermission = false;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    _timer?.cancel();
    _pulseCtrl.dispose();
    _recorder?.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  // --- Gestion de l'enregistrement selon spécification

  Future<void> _startRecording() async {
    if (_isRecording) return;

    if (!_hasAudioPermission) {
      debugPrint('⚠️ Permission microphone non accordée');
      return;
    }

    setState(() {
      _isRecording = true;
      _cancelReady = false;
      _hapticsPlayed = false;
      _dx = 0.0;
      _recordDuration = Duration.zero;
    });

    // Démarrer l'enregistrement audio réel
    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = path;

      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      debugPrint('🎤 Enregistrement démarré: $path');
    } catch (e) {
      debugPrint('❌ Erreur démarrage enregistrement: $e');
      setState(() {
        _isRecording = false;
      });
      return;
    }

    _pulseCtrl.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _recordDuration += const Duration(seconds: 1);
      });
    });
  }

  // Variables pour tracker la position initiale du drag
  double _dragStartX = 0.0;

  void _updateDrag(DragUpdateDetails details) {
    if (!_isRecording) return;
    setState(() {
      // Calculer le déplacement depuis le début du drag
      final currentDx = details.globalPosition.dx - _dragStartX;
      _dx = math.min(0, currentDx); // on ne compte que vers la gauche (négatif)

      final progress = _cancelProgress;
      final nowReady = progress >= 1.0;

      // Transition vers cancelReady avec haptique
      if (nowReady && !_cancelReady) {
        _cancelReady = true;
        if (!_hapticsPlayed) {
          HapticFeedback.selectionClick();
          _hapticsPlayed = true;
        }
      } else if (!nowReady && _cancelReady) {
        // Retour en arrière : l'utilisateur a reglissé vers la droite
        _cancelReady = false;
        // Rejouer l'haptique si on repasse le seuil
        _hapticsPlayed = false;
      }
    });
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    _pulseCtrl.stop();
    _pulseCtrl.reset();

    // Arrêter l'enregistrement audio
    if (_recorder != null && _currentRecordingPath != null) {
      try {
        await _recorder!.stop();
        // Supprimer le fichier annulé
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
        debugPrint('🗑️ Enregistrement annulé et fichier supprimé');
      } catch (e) {
        debugPrint('❌ Erreur annulation enregistrement: $e');
      }
    }

    setState(() {
      _isRecording = false;
      _cancelReady = false;
      _dx = 0.0;
      _recordDuration = Duration.zero;
      _hapticsPlayed = false;
      _currentRecordingPath = null;
    });
  }

  Future<void> _stopAndResolve() async {
    _timer?.cancel();
    _pulseCtrl.stop();
    _pulseCtrl.reset();

    final shouldCancel = _cancelReady;
    final duration = _recordDuration;
    final recordingPath = _currentRecordingPath;

    // Arrêter l'enregistrement audio
    if (_recorder != null && recordingPath != null) {
      try {
        await _recorder!.stop();
        debugPrint('✅ Enregistrement arrêté: $recordingPath');
      } catch (e) {
        debugPrint('❌ Erreur arrêt enregistrement: $e');
      }
    }

    setState(() {
      _isRecording = false;
      _cancelReady = false;
      _dx = 0.0;
      _recordDuration = Duration.zero;
      _hapticsPlayed = false;
      _currentRecordingPath = null;
    });

    if (shouldCancel) {
      // Annulation : supprimer le fichier
      if (recordingPath != null) {
        try {
          final file = File(recordingPath);
          if (await file.exists()) {
            await file.delete();
          }
          debugPrint('🗑️ Fichier annulé supprimé');
        } catch (e) {
          debugPrint('❌ Erreur suppression fichier: $e');
        }
      }
    } else if (duration > Duration.zero && recordingPath != null) {
      // Envoi du vocal
      final audioFile = File(recordingPath);
      if (await audioFile.exists()) {
        widget.onSendVoice?.call(audioFile, duration.inSeconds);
      } else {
        debugPrint('❌ Fichier audio non trouvé: $recordingPath');
      }
    }
  }

  // Calcul du progress d'annulation (0..1)
  double get _cancelProgress {
    return (_dx.abs() / _cancelThreshold).clamp(0.0, 1.0);
  }

  // Interpolation de couleur
  Color _interpolateColor(Color a, Color b, double t) {
    return Color.lerp(a, b, t) ?? a;
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // --- UI d'enregistrement selon spécification "slide-to-cancel"
  Widget _buildRecordingUI(ThemeData theme, dynamic themeManager) {
    final t = _cancelProgress;

    // Interpolation des couleurs selon la progression
    final baseBg = theme.colorScheme.surfaceContainerHighest;
    final alertBg = theme.colorScheme.errorContainer;
    final pillBg = _interpolateColor(baseBg, alertBg, t);

    final baseFg = theme.colorScheme.onSurfaceVariant;
    final alertFg = theme.colorScheme.onErrorContainer;
    final pillFg = _interpolateColor(baseFg, alertFg, t);

    final pillTranslateX = -8 * t; // léger déplacement du pavé

    return AnimatedContainer(
      key: const ValueKey('recording-ui'), // ✅ Clé pour AnimatedSwitcher
      duration: _animDuration,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _cancelReady
                ? theme.colorScheme.error.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Transform.translate(
        offset: Offset(pillTranslateX, 0),
        child: Row(
          children: [
            // Flèche qui glisse vers la gauche avec la progression
            Transform.translate(
              offset: Offset(-40 * t, 0), // Glisse vers la gauche
              child: Opacity(
                opacity: (1.0 - t).clamp(0.3, 1.0), // Reste légèrement visible
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: pillFg,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Texte
            Expanded(
              child: Text(
                _cancelReady ? 'Relâchez pour annuler' : 'Glisser pour annuler',
                style: TextStyle(
                  color: pillFg,
                  fontSize: 14,
                  fontWeight: _cancelReady ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Durée
            Text(
              _formatDuration(_recordDuration),
              style: TextStyle(
                color: pillFg,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),

            const SizedBox(width: 12),

            // Indicateur de progression circulaire
            SizedBox(
              width: 28,
              height: 28,
              child: Stack(
                children: [
                  // Cercle de fond
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: pillFg.withValues(alpha: 0.3),
                        width: 2.5,
                      ),
                    ),
                  ),
                  // Progression
                  CircularProgressIndicator(
                    value: t,
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(pillFg),
                    backgroundColor: Colors.transparent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = globalThemeManager;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: themeManager.getSurfaceColor(),
        border: themeManager.currentTheme == AppThemeMode.light
            ? const Border(top: BorderSide(color: Color(0xFFE1E8ED), width: 1))
            : null,
        boxShadow: themeManager.currentTheme == AppThemeMode.light
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Bouton photo/média avec transition fluide
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: animation,
                  child: child,
                ),
              );
            },
            child: _isRecording
                ? Container(
                    key: const ValueKey('recording-trash'),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _cancelReady
                          ? theme.colorScheme.errorContainer
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1.1).animate(_pulseCtrl),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: _cancelReady
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                  )
                : IconButton(
                    key: const ValueKey('photo'),
                    icon: Icon(
                      Icons.photo,
                      color: widget.enabled
                          ? themeManager.accentColor
                          : theme.colorScheme.outline,
                    ),
                    onPressed: widget.enabled
                        ? () => widget.chatController.pickAndSendFile(context)
                        : null,
                  ),
          ),

          // Champ texte avec transition fluide
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isRecording
                    ? (themeManager.currentTheme == AppThemeMode.light
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : theme.colorScheme.primaryContainer.withValues(alpha: 0.2))
                    : (themeManager.currentTheme == AppThemeMode.light
                        ? Colors.grey[50]
                        : themeManager.getSurfaceColor()),
                borderRadius: BorderRadius.circular(20),
                border: themeManager.currentTheme == AppThemeMode.light
                    ? Border.all(
                        color: _isRecording
                            ? theme.colorScheme.primary.withValues(alpha: 0.3)
                            : const Color(0xFFE1E8ED),
                        width: 1,
                      )
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _isRecording
                    ? _buildRecordingUI(theme, themeManager)
                    : TextField(
                        key: const ValueKey('text-field'),
                        enabled: widget.enabled,
                        controller: _controller,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: widget.enabled
                              ? 'Ecrire un message...'
                              : 'Connexion securisee requise',
                          hintStyle: TextStyle(
                            color: themeManager.getSecondaryTextColor(),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (text) {
                          _handleControllerChange();
                          if (widget.enabled) {
                            _handleTyping(text);
                          }
                        },
                      ),
              ),
            ),
          ),

          // Bouton principal : Envoyer (si texte) sinon Micro
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _hasText
                ? IconButton.filled(
                    key: const ValueKey('send'),
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) {
                        widget.onSendText?.call(text);
                        _controller.clear();
                        setState(() {});
                      }
                    },
                    tooltip: 'Envoyer',
                  )
                : GestureDetector(
                    key: const ValueKey('mic'),
                    onPanDown: (details) {
                      _dragStartX = details.globalPosition.dx; // ✅ Sauvegarder position initiale
                      _startRecording(); // ✅ Démarrage instantané
                    },
                    onPanUpdate: _updateDrag,
                    onPanEnd: (_) => _stopAndResolve(),
                    onPanCancel: () => _stopAndResolve(),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Cercle "on parle" avec animation fluide
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecording
                                ? _interpolateColor(
                                    theme.colorScheme.primaryContainer,
                                    theme.colorScheme.errorContainer,
                                    _cancelProgress,
                                  )
                                : themeManager.accentColor,
                            boxShadow: _isRecording
                                ? [
                                    BoxShadow(
                                      color: (_cancelReady
                                              ? theme.colorScheme.error
                                              : theme.colorScheme.primary)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: ScaleTransition(
                            scale: _isRecording
                                ? Tween<double>(begin: 0.95, end: 1.05).animate(_pulseCtrl)
                                : AlwaysStoppedAnimation(1.0),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        // Icône micro avec animation
                        AnimatedScale(
                          scale: _isRecording ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 26,
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

  void _handleTyping(String text) {
    if (!widget.enabled) {
      return;
    }

    if (widget.chatController.mounted == true) {
      widget.chatController.setState(() {});
    }

    final socket = widget.chatController.getSocket();
    socket.emit('typing', {
      'relationId': widget.chatController.widget.relationId,
      'userId': widget.chatController.widget.userId,
    });

    widget.chatController.typingDebounce?.cancel();
    widget.chatController.typingDebounce = Timer(
      const Duration(seconds: 1),
      () {
        socket.emit('stopTyping', {
          'relationId': widget.chatController.widget.relationId,
          'userId': widget.chatController.widget.userId,
        });
      },
    );
  }
}

/// Fonction legacy pour compatibilite avec l ancienne API.
Widget buildInputBar(
  BuildContext context,
  Future<void> Function() sendMessage,
  TextEditingController controller, {
  bool enabled = true,
  required dynamic chatController,
  void Function(File audioFile, int durationSeconds)? onSendVoice,
  void Function(String text)? onSendText,
}) {
  return ChatInputBar(
    onSendMessage: sendMessage,
    controller: controller,
    chatController: chatController,
    enabled: enabled,
    onSendVoice: onSendVoice,
    onSendText: onSendText,
  );
}
