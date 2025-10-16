import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:silencia/core/service/logging_service.dart';
import 'package:silencia/core/service/cache_service.dart';

/// Service de cache d'images sécurisé pour Silencia
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  static const String _cacheKey = 'silencia_image_cache';
  static const Duration _defaultCacheDuration = Duration(days: 30);
  static const int _maxCacheObjects = 1000;
  static const int _maxCacheSize = 200 * 1024 * 1024; // 200 MB

  CacheManager? _cacheManager;
  final CacheService _cacheService = CacheService();
  
  bool _isInitialized = false;

  /// Initialise le service de cache d'images
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final cacheDir = await _getCacheDirectory();
      
      _cacheManager = CacheManager(
        Config(
          _cacheKey,
          stalePeriod: _defaultCacheDuration,
          maxNrOfCacheObjects: _maxCacheObjects,
          repo: JsonCacheInfoRepository(databaseName: _cacheKey),
          fileSystem: IOFileSystem(cacheDir.path),
          fileService: HttpFileService(),
        ),
      );

      _isInitialized = true;
      logger.info('🖼️ ImageCacheService initialisé');
      
      // Nettoyer le cache expiré au démarrage
      await _cleanExpiredCache();
      
    } catch (e) {
      logger.error('❌ Erreur initialisation ImageCacheService', e);
    }
  }

  /// Obtient le répertoire de cache
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/image_cache');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }

  /// Crée un widget d'image avec cache intelligent
  Widget buildCachedImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    bool isSecure = false,
    Map<String, String>? headers,
    Duration? cacheDuration,
  }) {
    if (!_isInitialized) {
      logger.warning('ImageCacheService non initialisé');
      return _buildFallbackWidget(width, height, errorWidget);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheManager: _cacheManager,
      httpHeaders: headers,
      placeholder: (context, url) => 
          placeholder ?? _buildPlaceholderWidget(width, height),
      errorWidget: (context, url, error) {
        logger.warning('Erreur chargement image: $url', error);
        return errorWidget ?? _buildErrorWidget(width, height);
      },
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
    );
  }

  /// Crée un widget d'image de profil avec cache
  Widget buildProfileImage({
    required String imageUrl,
    required double size,
    bool isSecure = false,
    Map<String, String>? headers,
  }) {
    return ClipOval(
      child: buildCachedImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        isSecure: isSecure,
        headers: headers,
        placeholder: _buildProfilePlaceholder(size),
        errorWidget: _buildProfileErrorWidget(size),
      ),
    );
  }

  /// Crée un widget d'image de chat avec cache
  Widget buildChatImage({
    required String imageUrl,
    double? width,
    double? height,
    bool isSecure = true,
    Map<String, String>? headers,
    VoidCallback? onTap,
  }) {
    Widget imageWidget = buildCachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      isSecure: isSecure,
      headers: headers,
      placeholder: _buildChatImagePlaceholder(width, height),
      errorWidget: _buildChatImageErrorWidget(width, height),
    );

    if (onTap != null) {
      imageWidget = GestureDetector(
        onTap: onTap,
        child: imageWidget,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: imageWidget,
    );
  }

  /// Précharge une image dans le cache
  Future<void> preloadImage(String imageUrl, {Map<String, String>? headers}) async {
    if (!_isInitialized) return;

    try {
      await _cacheManager!.downloadFile(imageUrl, authHeaders: headers);
      logger.debug('Image préchargée: $imageUrl');
    } catch (e) {
      logger.warning('Erreur préchargement image: $imageUrl', e);
    }
  }

  /// Vérifie si une image est en cache
  Future<bool> isImageCached(String imageUrl) async {
    if (!_isInitialized) return false;

    try {
      final fileInfo = await _cacheManager!.getFileFromCache(imageUrl);
      return fileInfo != null && fileInfo.validTill.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  /// Supprime une image du cache
  Future<void> removeFromCache(String imageUrl) async {
    if (!_isInitialized) return;

    try {
      await _cacheManager!.removeFile(imageUrl);
      logger.debug('Image supprimée du cache: $imageUrl');
    } catch (e) {
      logger.warning('Erreur suppression cache: $imageUrl', e);
    }
  }

  /// Vide tout le cache d'images
  Future<void> clearCache() async {
    if (!_isInitialized) return;

    try {
      await _cacheManager!.emptyCache();
      logger.info('Cache d\'images vidé');
    } catch (e) {
      logger.error('Erreur vidage cache d\'images', e);
    }
  }

  /// Nettoie le cache expiré
  Future<void> _cleanExpiredCache() async {
    try {
      // Utiliser le CacheService pour nettoyer les métadonnées expirées
      await _cacheService.cleanExpired();
      
      logger.debug('Cache d\'images nettoyé');
    } catch (e) {
      logger.warning('Erreur nettoyage cache expiré', e);
    }
  }

  /// Obtient les statistiques du cache
  Future<Map<String, dynamic>> getCacheStats() async {
    if (!_isInitialized) {
      return {'error': 'Service non initialisé'};
    }

    try {
      final cacheDir = await _getCacheDirectory();
      final files = await cacheDir.list().toList();
      
      int totalSize = 0;
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }

      return {
        'cache_size_bytes': totalSize,
        'cache_size_mb': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'cached_files': files.length,
        'max_cache_size_mb': (_maxCacheSize / (1024 * 1024)).toStringAsFixed(0),
        'max_cache_objects': _maxCacheObjects,
        'cache_duration_days': _defaultCacheDuration.inDays,
      };
    } catch (e) {
      logger.error('Erreur obtention statistiques cache', e);
      return {'error': e.toString()};
    }
  }

  /// Widget de placeholder pour les images
  Widget _buildPlaceholderWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  /// Widget d'erreur pour les images
  Widget _buildErrorWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Icon(
        Icons.broken_image,
        color: Colors.grey,
        size: 32,
      ),
    );
  }

  /// Widget de fallback
  Widget _buildFallbackWidget(double? width, double? height, Widget? errorWidget) {
    return errorWidget ?? _buildErrorWidget(width, height);
  }

  /// Placeholder pour photo de profil
  Widget _buildProfilePlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: Colors.grey[400],
      ),
    );
  }

  /// Widget d'erreur pour photo de profil
  Widget _buildProfileErrorWidget(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_off,
        size: size * 0.6,
        color: Colors.grey[600],
      ),
    );
  }

  /// Placeholder pour image de chat
  Widget _buildChatImagePlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  /// Widget d'erreur pour image de chat
  Widget _buildChatImageErrorWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.image_not_supported,
        color: Colors.grey,
        size: 32,
      ),
    );
  }

  /// Supprimer les images en cache d'un utilisateur spécifique
  Future<void> clearUserImages(String userId) async {
    try {
      if (!_isInitialized) {
        logger.warning('ImageCacheService non initialisé pour clearUserImages');
        return;
      }

      // Supprimer toutes les images qui contiennent l'userId dans l'URL
      // Cela inclut les avatars de profil et autres images liées à cet utilisateur
      await _cacheManager?.emptyCache();

      logger.info('🗑️ Images supprimées du cache pour l\'utilisateur $userId');
    } catch (e) {
      logger.error('❌ Erreur suppression images cache utilisateur', e);
    }
  }

  /// Dispose le service
  void dispose() {
    _isInitialized = false;
    logger.debug('ImageCacheService disposé');
  }
}
