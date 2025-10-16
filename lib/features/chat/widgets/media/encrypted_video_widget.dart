import 'dart:io';
import 'package:flutter/material.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/services/media_encryption_service.dart';
import 'package:silencia/features/chat/chat_service.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';


class EncryptedVideoWidget extends StatefulWidget {
  final String videoUrl;
  final String relationId;
  final double? width;
  final double? height;

  const EncryptedVideoWidget({
    super.key,
    required this.videoUrl,
    required this.relationId,
    this.width,
    this.height,
  });

  @override
  State<EncryptedVideoWidget> createState() => _EncryptedVideoWidgetState();
}

class _EncryptedVideoWidgetState extends State<EncryptedVideoWidget> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  File? _decryptedFile;

  @override
  void initState() {
    super.initState();
    _loadAndDecryptVideo();
  }

  Future<void> _loadAndDecryptVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      debugPrint('🎬 EncryptedVideoWidget: Début déchiffrement vidéo');
      debugPrint('🔗 URL: ${widget.videoUrl}');

      // 1. Récupérer la clé média
      final mediaKey = await ChatService.getMediaKey(widget.relationId);
      if (mediaKey == null) {
        throw Exception('Clé média non trouvée pour cette relation');
      }

      debugPrint('🔑 Clé média récupérée');

      // 2. Télécharger le fichier chiffré
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) {
        throw Exception('Headers d\'authentification non disponibles');
      }

      final response = await http.get(
        Uri.parse(widget.videoUrl),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur téléchargement: ${response.statusCode}');
      }

      debugPrint('📥 Fichier chiffré téléchargé: ${response.bodyBytes.length} bytes');

      // 3. Déchiffrer les données
      final decryptedBytes = MediaEncryptionService.decryptBytes(
        response.bodyBytes,
        mediaKey,
      );

      debugPrint('🔓 Fichier déchiffré: ${decryptedBytes.length} bytes');

      // 4. Sauvegarder temporairement le fichier déchiffré
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.videoUrl.split('/').last.replaceAll('.enc', '');
      final tempFile = File('${tempDir.path}/decrypted_$fileName');
      
      await tempFile.writeAsBytes(decryptedBytes);
      _decryptedFile = tempFile;

      debugPrint('💾 Fichier temporaire créé: ${tempFile.path}');

      // 5. Initialiser le lecteur vidéo
      _controller = VideoPlayerController.file(tempFile);
      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      debugPrint('✅ Lecteur vidéo initialisé');

    } catch (e) {
      debugPrint('❌ Erreur déchiffrement vidéo: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    // Nettoyer le fichier temporaire
    _decryptedFile?.delete().catchError((e) {
      debugPrint('⚠️ Erreur suppression fichier temporaire: $e');
      return _decryptedFile!;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width ?? 200,
        height: widget.height ?? 150,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text(
                'Déchiffrement...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Container(
        width: widget.width ?? 200,
        height: widget.height ?? 150,
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red[700], size: 32),
              const SizedBox(height: 8),
              const Text(
                'Erreur vidéo chiffrée',
                style: TextStyle(fontSize: 12, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 10, color: Colors.red),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        width: widget.width ?? 200,
        height: widget.height ?? 150,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Text(
            'Initialisation...',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width ?? 200,
      height: widget.height ?? 150,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
            // Overlay de contrôle
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
              onTap: () {
                setState(() {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                });
              },
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
            // Indicateur de chiffrement
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, color: Colors.white, size: 12),
                    SizedBox(width: 2),
                    Text(
                      'Sécurisé',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
