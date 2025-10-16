import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/services/media_encryption_service.dart';
import 'package:silencia/features/chat/chat_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class EncryptedVoiceWidget extends StatefulWidget {
  final String voiceUrl;
  final String relationId;
  final int duration; // en secondes
  final bool isFromMe;

  const EncryptedVoiceWidget({
    super.key,
    required this.voiceUrl,
    required this.relationId,
    required this.duration,
    this.isFromMe = false,
  });

  @override
  State<EncryptedVoiceWidget> createState() => _EncryptedVoiceWidgetState();
}

class _EncryptedVoiceWidgetState extends State<EncryptedVoiceWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  File? _decryptedFile;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isSeeking = false; // Pour éviter les conflits pendant le seek

  @override
  void initState() {
    super.initState();
    _totalDuration = Duration(seconds: widget.duration);

    // Écouter les changements de position avec mise à jour fluide
    _audioPlayer.positionStream.listen((position) {
      if (mounted && !_isSeeking) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // Écouter les changements d'état de lecture
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
      
      // Réinitialiser quand la lecture est terminée
      if (state.processingState == ProcessingState.completed) {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
      }
    });

    // Écouter la durée totale
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null && mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });
  }

  Future<void> _loadAndDecryptAudio() async {
    if (_decryptedFile != null) {
      // Déjà déchiffré, juste jouer
      await _playAudio();
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      // Vérifier que l'URL est valide
      if (widget.voiceUrl.isEmpty) {
        throw Exception('URL du fichier audio vide');
      }

      // 1. Récupérer la clé média
      final mediaKey = await ChatService.getMediaKey(widget.relationId);
      if (mediaKey == null) {
        throw Exception('Clé média non trouvée pour cette relation');
      }

      // 2. Télécharger le fichier chiffré
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) {
        throw Exception('Headers d\'authentification non disponibles');
      }

      // Construire l'URL complète si nécessaire
      String fullUrl = widget.voiceUrl;
      if (!fullUrl.startsWith('http')) {
        // Ajouter le baseUrl si l'URL est relative
        fullUrl = '${ApiConfig.baseUrl}${widget.voiceUrl.startsWith('/') ? '' : '/'}${widget.voiceUrl}';
      }

      final response = await http.get(
        Uri.parse(fullUrl),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur téléchargement: ${response.statusCode}');
      }

      // 3. Déchiffrer les données
      final decryptedBytes = MediaEncryptionService.decryptBytes(
        response.bodyBytes,
        mediaKey,
      );

      // 4. Sauvegarder temporairement le fichier déchiffré
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.voiceUrl.split('/').last.replaceAll('.enc', '');
      final tempFile = File('${tempDir.path}/decrypted_$fileName');

      await tempFile.writeAsBytes(decryptedBytes);
      _decryptedFile = tempFile;

      setState(() {
        _isLoading = false;
      });

      // 5. Jouer l'audio
      await _playAudio();

    } catch (e, stackTrace) {
      debugPrint('❌ Erreur déchiffrement audio: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _playAudio() async {
    if (_decryptedFile == null) return;

    try {
      await _audioPlayer.setFilePath(_decryptedFile!.path);
      await _audioPlayer.play();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Erreur de lecture: $e';
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_decryptedFile == null) {
        await _loadAndDecryptAudio();
      } else {
        await _audioPlayer.play();
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    // Nettoyer le fichier temporaire
    _decryptedFile?.delete().catchError((e) => _decryptedFile!);
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Couleurs Material 3
    final backgroundColor = widget.isFromMe
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foregroundColor = widget.isFromMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final accentColor = widget.isFromMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.primary;

    if (_hasError) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Impossible de lire l\'audio',
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 300),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton play/pause avec animation
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _togglePlayPause,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: _isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                      )
                    : Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: accentColor,
                        size: 28,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Waveform et durée
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform visuel
                _buildWaveform(accentColor, foregroundColor),
                const SizedBox(height: 8),

                // Durée et icône de chiffrement
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isPlaying || _currentPosition.inSeconds > 0
                          ? _formatDuration(_currentPosition)
                          : _formatDuration(_totalDuration),
                      style: TextStyle(
                        color: foregroundColor.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          color: foregroundColor.withValues(alpha: 0.5),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Chiffré',
                          style: TextStyle(
                            color: foregroundColor.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Waveform visuel animé et interactif
  Widget _buildWaveform(Color accentColor, Color foregroundColor) {
    final progress = _totalDuration.inMilliseconds > 0
        ? (_currentPosition.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Waveform visuel
        SizedBox(
          height: 32,
          child: Row(
            children: List.generate(30, (index) {
              final barProgress = (index / 30);
              final isActive = barProgress <= progress;
              final heights = [0.3, 0.5, 0.8, 1.0, 0.7, 0.4, 0.6, 0.9, 0.5, 0.3];
              final height = heights[index % heights.length];

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    decoration: BoxDecoration(
                      color: isActive
                          ? accentColor
                          : foregroundColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    height: 32 * height,
                  ),
                ),
              );
            }),
          ),
        ),

        // Slider invisible pour une interaction facile
        Positioned.fill(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 32,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0), // Thumb invisible
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 0), // Overlay invisible
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              trackShape: const RectangularSliderTrackShape(),
            ),
            child: Slider(
              value: progress,
              onChangeStart: (_) {
                setState(() {
                  _isSeeking = true;
                });
              },
              onChanged: (value) {
                setState(() {
                  _currentPosition = Duration(
                    milliseconds: (_totalDuration.inMilliseconds * value).round(),
                  );
                });
              },
              onChangeEnd: (value) async {
                final newPosition = Duration(
                  milliseconds: (_totalDuration.inMilliseconds * value).round(),
                );
                await _audioPlayer.seek(newPosition);
                setState(() {
                  _isSeeking = false;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

