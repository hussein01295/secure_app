import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service de logs structurés pour Silencia
class LoggingService {
  static final _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  late Logger _logger;
  bool _isInitialized = false;
  String? _deviceInfo;
  String? _appInfo;

  /// Initialise le service de logs
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Collecter les informations de l'appareil et de l'app
      await _collectDeviceInfo();
      await _collectAppInfo();

      // Configuration du logger
      _logger = Logger(
        printer: _SilenciaPrettyPrinter(),
        output: kDebugMode 
          ? MultiOutput([
              ConsoleOutput(),
              if (!kIsWeb) await _createFileOutput(),
            ].whereType<LogOutput>().toList())
          : MultiOutput([
              if (!kIsWeb) await _createFileOutput(),
            ].whereType<LogOutput>().toList()),
        level: kDebugMode ? Level.debug : Level.info,
      );

      _isInitialized = true;
      info('LoggingService initialisé avec succès');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur initialisation LoggingService: $e');
      }
    }
  }

  /// Collecte les informations de l'appareil
  Future<void> _collectDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceInfo = 'Android ${androidInfo.version.release} (${androidInfo.model})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceInfo = 'iOS ${iosInfo.systemVersion} (${iosInfo.model})';
      } else {
        _deviceInfo = Platform.operatingSystem;
      }
    } catch (e) {
      _deviceInfo = 'Inconnu';
    }
  }

  /// Collecte les informations de l'application
  Future<void> _collectAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appInfo = 'Silencia v${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      _appInfo = 'Silencia v?.?';
    }
  }

  /// Crée un output de fichier pour les logs
  Future<LogOutput?> _createFileOutput() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logFile = File('${directory.path}/silencia_logs.txt');
      return FileOutput(file: logFile);
    } catch (e) {
      return null;
    }
  }

  /// Log de niveau DEBUG
  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!_isInitialized) return;
    _logger.d(_formatMessage(message), error: error, stackTrace: stackTrace);
  }

  /// Log de niveau INFO
  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!_isInitialized) return;
    _logger.i(_formatMessage(message), error: error, stackTrace: stackTrace);
  }

  /// Log de niveau WARNING
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!_isInitialized) return;
    _logger.w(_formatMessage(message), error: error, stackTrace: stackTrace);
  }

  /// Log de niveau ERROR
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!_isInitialized) return;
    _logger.e(_formatMessage(message), error: error, stackTrace: stackTrace);
  }

  /// Log de niveau FATAL
  void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!_isInitialized) return;
    _logger.f(_formatMessage(message), error: error, stackTrace: stackTrace);
  }

  /// Log spécialisé pour la sécurité
  void security(String event, Map<String, dynamic>? details) {
    final message = '🔒 SECURITY: $event';
    final formattedDetails = details?.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    
    warning('$message${formattedDetails != null ? ' | $formattedDetails' : ''}');
  }

  /// Log spécialisé pour les performances
  void performance(String operation, Duration duration, [Map<String, dynamic>? details]) {
    final message = '⚡ PERF: $operation took ${duration.inMilliseconds}ms';
    final formattedDetails = details?.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    
    info('$message${formattedDetails != null ? ' | $formattedDetails' : ''}');
  }

  /// Log spécialisé pour les erreurs réseau
  void networkError(String endpoint, int? statusCode, String? errorMessage) {
    error('🌐 NETWORK ERROR: $endpoint | Status: ${statusCode ?? 'N/A'} | Error: ${errorMessage ?? 'Unknown'}');
  }

  /// Log spécialisé pour l'authentification
  void auth(String event, String? userId) {
    info('🔐 AUTH: $event${userId != null ? ' | User: $userId' : ''}');
  }

  /// Formate le message avec les informations contextuelles
  String _formatMessage(String message) {
    final timestamp = DateTime.now().toIso8601String();
    return '[$timestamp] $_appInfo | $_deviceInfo | $message';
  }

  /// Obtient les logs récents (pour debug)
  Future<String?> getRecentLogs() async {
    try {
      if (kIsWeb) return null;
      
      final directory = await getApplicationDocumentsDirectory();
      final logFile = File('${directory.path}/silencia_logs.txt');
      
      if (await logFile.exists()) {
        final content = await logFile.readAsString();
        final lines = content.split('\n');
        
        // Retourner les 100 dernières lignes
        final recentLines = lines.length > 100 
          ? lines.sublist(lines.length - 100)
          : lines;
        
        return recentLines.join('\n');
      }
      return null;
    } catch (e) {
      return 'Erreur lecture logs: $e';
    }
  }

  /// Nettoie les anciens logs
  Future<void> cleanOldLogs() async {
    try {
      if (kIsWeb) return;
      
      final directory = await getApplicationDocumentsDirectory();
      final logFile = File('${directory.path}/silencia_logs.txt');
      
      if (await logFile.exists()) {
        final stat = await logFile.stat();
        final fileAge = DateTime.now().difference(stat.modified);
        
        // Supprimer si plus de 7 jours
        if (fileAge.inDays > 7) {
          await logFile.delete();
          info('Anciens logs supprimés (âge: ${fileAge.inDays} jours)');
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur nettoyage logs: $e');
    }
  }
}

/// Printer personnalisé pour Silencia
class _SilenciaPrettyPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final color = PrettyPrinter.defaultLevelColors[event.level];
    final emoji = _getEmoji(event.level);
    final message = event.message;
    
    return [color!('$emoji $message')];
  }

  String _getEmoji(Level level) {
    switch (level) {
      case Level.debug:
        return '🐛';
      case Level.info:
        return 'ℹ️';
      case Level.warning:
        return '⚠️';
      case Level.error:
        return '❌';
      case Level.fatal:
        return '💀';
      default:
        return '📝';
    }
  }
}

/// Instance globale du service de logs
final logger = LoggingService();
