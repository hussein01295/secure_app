import 'package:flutter/material.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:video_player/video_player.dart';

 
class VideoMessageWidget extends StatefulWidget {
  final String videoUrl;
  final double width;
  final bool isFromMe;
  final String time;
  final bool isRead;

  const VideoMessageWidget({
    super.key,
    required this.videoUrl,
    this.width = 250,
    required this.isFromMe,
    required this.time,
    required this.isRead,
  });

  @override
  State<VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Obtenir les headers d'authentification
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) {
        throw Exception('Impossible d\'obtenir les headers d\'authentification');
      }

      debugPrint('🎥 Initialisation vidéo: ${widget.videoUrl}');

      // Créer le contrôleur avec les headers d'authentification
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: headers,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }

      debugPrint('✅ Vidéo initialisée: ${_controller!.value.size}');
    } catch (e) {
      debugPrint('❌ Erreur initialisation vidéo: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller != null && _isInitialized) {
      setState(() {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: widget.isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildVideoContent(),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.time,
              style: TextStyle(
                color: widget.isFromMe ? Colors.cyan : Colors.black45,
                fontSize: 12,
              ),
            ),
            if (widget.isFromMe) ...[
              const SizedBox(width: 4),
              Icon(
                widget.isRead ? Icons.done_all : Icons.done,
                size: 15,
                color: widget.isRead ? Colors.cyanAccent : Colors.black38,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildVideoContent() {
    if (_isLoading) {
      return SizedBox(
        height: 200,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Chargement de la vidéo...'),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              const Text('Erreur de chargement'),
              if (_errorMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],

            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return SizedBox(
        height: 200,
        child: const Center(
          child: Text('Vidéo non disponible'),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
        // Overlay avec contrôles
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
              ],
            ),
          ),
        ),
        // Bouton play/pause
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        // Indicateur de durée
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatDuration(_controller!.value.duration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
