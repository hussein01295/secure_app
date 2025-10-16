import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/services/media_encryption_service.dart';
import 'package:silencia/features/chat/chat_service.dart';

class EncryptedImageWidget extends StatefulWidget {
  final String imageUrl;
  final double width;
  final String relationId;
  final BoxFit fit;

  const EncryptedImageWidget({
    super.key,
    required this.imageUrl,
    required this.relationId,
    this.width = 170,
    this.fit = BoxFit.cover,
  });

  @override
  State<EncryptedImageWidget> createState() => _EncryptedImageWidgetState();
}

class _EncryptedImageWidgetState extends State<EncryptedImageWidget> {
  static final Map<String, Uint8List> _decryptedCache = {};
  Uint8List? _decryptedImageData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAndDecryptImage();
  }

  Future<void> _loadAndDecryptImage() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Vérifier le cache d'abord
      final cacheKey = '${widget.imageUrl}_${widget.relationId}';
      if (_decryptedCache.containsKey(cacheKey)) {
        debugPrint('🎯 Image trouvée dans le cache: $cacheKey');
        setState(() {
          _decryptedImageData = _decryptedCache[cacheKey];
          _isLoading = false;
        });
        return;
      }

      // Récupérer les headers d'authentification
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) {
        throw Exception('Impossible d\'obtenir les headers d\'authentification');
      }

      // Récupérer la clé média
      final mediaKey = await ChatService.getMediaKey(widget.relationId);
      if (mediaKey == null) {
        throw Exception('Clé média non trouvée pour cette conversation');
      }

      debugPrint('🔐 Chargement image chiffrée: ${widget.imageUrl}');
      debugPrint('🔑 Clé média trouvée: ${mediaKey.substring(0, 8)}...');

      // Télécharger l'image chiffrée
      final response = await http.get(
        Uri.parse(widget.imageUrl),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur téléchargement: ${response.statusCode}');
      }

      // Déchiffrer l'image
      final encryptedData = response.bodyBytes;
      final decryptedData = MediaEncryptionService.decryptBytes(encryptedData, mediaKey);

      // Mettre en cache l'image déchiffrée
      _decryptedCache[cacheKey] = decryptedData;

      // Limiter la taille du cache (garder seulement les 50 dernières images)
      if (_decryptedCache.length > 50) {
        final oldestKey = _decryptedCache.keys.first;
        _decryptedCache.remove(oldestKey);
        debugPrint('🗑️ Cache nettoyé, suppression de: $oldestKey');
      }

      if (mounted) {
        setState(() {
          _decryptedImageData = decryptedData;
          _isLoading = false;
        });
      }

      debugPrint('✅ Image déchiffrée et mise en cache: ${decryptedData.length} bytes');

    } catch (e) {
      debugPrint('❌ Erreur déchiffrement image: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
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
      );
    }

    if (_error != null) {
      return Container(
        width: widget.width,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 32),
            const SizedBox(height: 8),
            const Text(
              'Erreur déchiffrement',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          ],
        ),
      );
    }

    if (_decryptedImageData != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _decryptedImageData!,
          width: widget.width,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: widget.width,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.orange[700], size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Image corrompue',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Container(
      width: widget.width,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'Image non disponible',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }
}
