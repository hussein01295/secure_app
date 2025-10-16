import 'package:flutter/material.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/service/image_cache_service.dart';

/// Widget pour afficher des images avec authentification et déchiffrement
/// Gère automatiquement les headers d'authentification et le cache
class AuthenticatedImage extends StatefulWidget {
  final String imageUrl;
  final double width;
  final BoxFit fit;
  final String? relationId; // Pour récupérer la clé média

  const AuthenticatedImage({
    super.key,
    required this.imageUrl,
    this.width = 170,
    this.fit = BoxFit.cover,
    this.relationId,
  });

  @override
  State<AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<AuthenticatedImage> {
  Map<String, String>? _headers;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  Future<void> _loadHeaders() async {
    try {
      final headers = await AuthService.getAuthorizedHeaders(context: context);
      if (mounted) {
        setState(() {
          _headers = headers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur d\'authentification';
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
        height: widget.width,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _headers == null) {
      return Container(
        width: widget.width,
        height: widget.width,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.error, color: Colors.red),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ImageCacheService().buildCachedImage(
        imageUrl: widget.imageUrl,
        headers: _headers!,
        width: widget.width,
        fit: widget.fit,
        placeholder: Container(
          width: widget.width,
          height: widget.width,
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: Container(
          width: widget.width,
          height: widget.width,
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
