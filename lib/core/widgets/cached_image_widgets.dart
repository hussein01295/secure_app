import 'package:flutter/material.dart';
import 'package:silencia/core/service/image_cache_service.dart';

/// Widget d'image avec cache pour les messages de chat
class CachedChatImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final Map<String, String>? headers;
  final VoidCallback? onTap;
  final bool showFullScreenOnTap;

  const CachedChatImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.headers,
    this.onTap,
    this.showFullScreenOnTap = true,
  });

  @override
  Widget build(BuildContext context) {
    return ImageCacheService().buildChatImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      headers: headers,
      onTap: onTap ?? (showFullScreenOnTap ? () => _showFullScreen(context) : null),
    );
  }

  void _showFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrl: imageUrl,
          headers: headers,
        ),
      ),
    );
  }
}

/// Widget d'image avec cache pour les galeries
class CachedGalleryImage extends StatelessWidget {
  final String imageUrl;
  final double size;
  final Map<String, String>? headers;
  final VoidCallback? onTap;

  const CachedGalleryImage({
    super.key,
    required this.imageUrl,
    this.size = 100,
    this.headers,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ImageCacheService().buildCachedImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        headers: headers,
      ),
    );
  }
}

/// Widget d'image avec cache pour les aperçus
class CachedThumbnailImage extends StatelessWidget {
  final String imageUrl;
  final double size;
  final Map<String, String>? headers;
  final VoidCallback? onTap;

  const CachedThumbnailImage({
    super.key,
    required this.imageUrl,
    this.size = 60,
    this.headers,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ImageCacheService().buildCachedImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        headers: headers,
      ),
    );

    if (onTap != null) {
      imageWidget = GestureDetector(
        onTap: onTap,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Visualiseur d'image plein écran avec cache
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final Map<String, String>? headers;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.headers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implémenter le partage d'image
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // TODO: Implémenter le téléchargement d'image
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: ImageCacheService().buildCachedImage(
            imageUrl: imageUrl,
            headers: headers,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// Widget d'image avec cache et indicateur de chargement personnalisé
class CachedImageWithProgress extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final Map<String, String>? headers;
  final BoxFit fit;
  final Color? progressColor;

  const CachedImageWithProgress({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.headers,
    this.fit = BoxFit.cover,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return ImageCacheService().buildCachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      headers: headers,
      placeholder: _buildProgressPlaceholder(context),
    );
  }

  Widget _buildProgressPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            progressColor ?? Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Widget d'image avec cache et effet de shimmer
class CachedImageWithShimmer extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final Map<String, String>? headers;
  final BoxFit fit;

  const CachedImageWithShimmer({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.headers,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return ImageCacheService().buildCachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      headers: headers,
      placeholder: _buildShimmerPlaceholder(context),
    );
  }

  Widget _buildShimmerPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[300]!,
            Colors.grey[100]!,
            Colors.grey[300]!,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.image,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
}

/// Widget d'image avec cache pour les cartes de contenu
class CachedCardImage extends StatelessWidget {
  final String imageUrl;
  final double height;
  final Map<String, String>? headers;
  final VoidCallback? onTap;

  const CachedCardImage({
    super.key,
    required this.imageUrl,
    this.height = 200,
    this.headers,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: ImageCacheService().buildCachedImage(
        imageUrl: imageUrl,
        height: height,
        fit: BoxFit.cover,
        headers: headers,
      ),
    );

    if (onTap != null) {
      imageWidget = GestureDetector(
        onTap: onTap,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Utilitaires pour le cache d'images
class ImageCacheUtils {
  /// Précharge une liste d'images
  static Future<void> preloadImages(
    List<String> imageUrls, {
    Map<String, String>? headers,
  }) async {
    final imageService = ImageCacheService();
    
    for (final url in imageUrls) {
      try {
        await imageService.preloadImage(url, headers: headers);
      } catch (e) {
        debugPrint('Erreur préchargement image: $url - $e');
      }
    }
  }

  /// Vide le cache d'images
  static Future<void> clearCache() async {
    await ImageCacheService().clearCache();
  }

  /// Obtient les statistiques du cache
  static Future<Map<String, dynamic>> getCacheStats() async {
    return await ImageCacheService().getCacheStats();
  }
}
