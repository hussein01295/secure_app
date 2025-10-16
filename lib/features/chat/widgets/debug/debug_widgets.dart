import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget pour afficher les informations de debug du chat
/// Utile pour le développement et le débogage
class ChatDebugWidget extends StatelessWidget {
  final Map<String, dynamic>? debugData;
  final VoidCallback? onRefresh;

  const ChatDebugWidget({
    super.key,
    this.debugData,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Debug Chat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualiser',
                ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Fermer',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (debugData != null) ...[
            _buildDebugSection('Données locales', debugData!),
          ] else ...[
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebugSection(String title, Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.entries.map((entry) {
              return _buildDebugItem(entry.key, entry.value);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDebugItem(String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$key:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _copyToClipboard(value.toString()),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  _formatValue(value),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String && value.length > 50) {
      return '${value.substring(0, 50)}...';
    }
    if (value is Map || value is List) {
      return value.toString();
    }
    return value.toString();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }
}

/// Widget pour afficher un exemple de transformation de langue
Widget buildExampleTransformation(String text, Map<String, String> langMap, bool isDark) {
  final transformed = text.split('').map((c) => langMap[c] ?? c).join('');

  return Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Original:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 16),
      const Icon(Icons.arrow_forward, size: 16),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transformé:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            Text(
              transformed,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Widget pour afficher les données locales
Widget buildLocalDataSection(Map<String, dynamic> data, bool isDark) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Données locales',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      const SizedBox(height: 8),
      if (data.containsKey('localPackage'))
        buildLocalPackageSection(
          data['localPackage'],
          data['packageType'] ?? 'Inconnu',
          isDark,
        ),
      if (data.containsKey('localLangMap'))
        buildLocalPackageSection(
          {'langMap': data['localLangMap']},
          data['packageType'] ?? 'v1.0 (legacy)',
          isDark,
        ),
      if (data.containsKey('localMediaKey'))
        buildLocalMediaKeySection(data['localMediaKey'], isDark),
    ],
  );
}

/// Widget pour afficher un package local
Widget buildLocalPackageSection(Map<String, dynamic> package, String packageType, bool isDark) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: isDark ? Colors.grey[800] : Colors.grey[100],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Package local ($packageType)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.green[400] : Colors.green[700],
          ),
        ),
        const SizedBox(height: 4),
        ...package.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${entry.key}: ${_formatDebugValue(entry.value)}',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          );
        }).toList(),
      ],
    ),
  );
}

/// Widget pour afficher la clé média locale
Widget buildLocalMediaKeySection(String mediaKey, bool isDark) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: isDark ? Colors.blue[900] : Colors.blue[50],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: isDark ? Colors.blue[700]! : Colors.blue[200]!,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clé média locale',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.blue[400] : Colors.blue[700],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          mediaKey,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: isDark ? Colors.blue[300] : Colors.blue[600],
          ),
        ),
      ],
    ),
  );
}

/// Widget pour afficher une section de payload
Widget buildPayloadSection(String title, Map<String, dynamic> payload, bool isDark, bool isEncrypted) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isEncrypted
            ? (isDark ? Colors.red[900] : Colors.red[50])
            : (isDark ? Colors.grey[800] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEncrypted
              ? (isDark ? Colors.red[700]! : Colors.red[200]!)
              : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isEncrypted)
              Text(
                '🔒 Données chiffrées',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.red[400] : Colors.red[700],
                ),
              ),
            ...payload.entries.map((entry) {
              return buildPayloadField(entry.key, entry.value, isDark);
            }).toList(),
          ],
        ),
      ),
    ],
  );
}

/// Widget pour afficher un champ de payload
Widget buildPayloadField(String label, dynamic value, bool isDark) {
  final valueStr = value?.toString() ?? 'null';
  final isLongValue = valueStr.length > 50;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        Text(
          isLongValue ? '${valueStr.substring(0, 50)}...' : valueStr,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        if (isLongValue) const SizedBox(height: 4),
      ],
    ),
  );
}

String _formatDebugValue(dynamic value) {
  if (value == null) return 'null';
  if (value is String && value.length > 30) {
    return '${value.substring(0, 30)}...';
  }
  if (value is Map) {
    return 'Map(${value.length} items)';
  }
  if (value is List) {
    return 'List(${value.length} items)';
  }
  return value.toString();
}
