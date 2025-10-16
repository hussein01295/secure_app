import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:silencia/core/utils/rsa_serrvice.dart';

void showLanguageDebugInfo(
  BuildContext context,
  Map<String, String>? langMap,
  String myLangStatus,
  String otherLangStatus,
  String? mediaKey,
  dynamic chatController,
) {
  if (langMap == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aucune langue disponible pour le debug')),
    );
    return;
  }

  final isDark = Theme.of(context).brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF19232b) : Colors.white,
      title: Text(
        'Debug - Langues gÃƒÂ©nÃƒÂ©rÃƒÂ©es',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statuts
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statuts:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.cyan : Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vous: $myLangStatus',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Contact: $otherLangStatus',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'ClÃƒÂ© mÃƒÂ©dia:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.orange : Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark
                              ? Colors.orange[700]!
                              : Colors.deepOrange[300]!,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (mediaKey != null) ...[
                            Text(
                              'Disponible: Ã¢Å“â€¦',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.green[300]
                                    : Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ClÃƒÂ© (non chiffrÃƒÂ©e):',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              mediaKey,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: isDark
                                    ? Colors.orange[200]
                                    : Colors.deepOrange[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Longueur: ${mediaKey.length} caractÃƒÂ¨res',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Non disponible: Ã¢ÂÅ’',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.red[300]
                                    : Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Aucune clÃƒÂ© mÃƒÂ©dia trouvÃƒÂ©e pour cette conversation',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // DonnÃƒÂ©es locales et payload BDD
              FutureBuilder<Map<String, dynamic>?>(
                future: chatController.getDebugLocalData(),
                builder: (context, snapshot) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.purple[900]?.withValues(alpha: 0.3)
                          : Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DonnÃƒÂ©es Locales & Payload BDD:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.purple[200]
                                : Colors.purple[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) ...[
                          const CircularProgressIndicator(strokeWidth: 2),
                          const SizedBox(height: 4),
                          Text(
                            'RÃƒÂ©cupÃƒÂ©ration des donnÃƒÂ©es...',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ] else if (snapshot.hasError) ...[
                          Text(
                            'Erreur: ${snapshot.error}',
                            style: TextStyle(
                              color: isDark ? Colors.red[300] : Colors.red[700],
                              fontSize: 12,
                            ),
                          ),
                        ] else if (snapshot.hasData &&
                            snapshot.data != null) ...[
                          _buildLocalDataSection(snapshot.data!, isDark),
                        ] else ...[
                          Text(
                            'Aucune donnÃƒÂ©e locale trouvÃƒÂ©e',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Mapping complet
              Text(
                'Mapping complet (${langMap.length} caractÃƒÂ¨res):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.cyan : Colors.blue,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  children: langMap.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.blue[900]
                                  : Colors.blue[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "'${entry.key}'",
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.blue[200]
                                    : Colors.blue[800],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 16),
                          const SizedBox(width: 8),
                          Container(
                            width: 30,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.green[900]
                                  : Colors.green[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "'${entry.value}'",
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.green[200]
                                    : Colors.green[800],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // Exemple de transformation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.purple[900]?.withValues(alpha: 0.3)
                      : Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exemple de transformation:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.purple[200] : Colors.purple[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildExampleTransformation('hello world', langMap, isDark),
                    const SizedBox(height: 4),
                    _buildExampleTransformation('bonjour', langMap, isDark),
                    const SizedBox(height: 4),
                    _buildExampleTransformation('123 test!', langMap, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Fermer',
            style: TextStyle(color: isDark ? Colors.cyan : Colors.blue),
          ),
        ),
      ],
    ),
  );
}

Widget _buildExampleTransformation(
  String text,
  Map<String, String> langMap,
  bool isDark,
) {
  final transformed = text.split('').map((c) => langMap[c] ?? c).join('');

  return Row(
    children: [
      Expanded(
        child: Text(
          '"$text"',
          style: TextStyle(
            fontFamily: 'monospace',
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      const Icon(Icons.arrow_forward, size: 14),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          '"$transformed"',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.orange[200] : Colors.orange[800],
          ),
        ),
      ),
    ],
  );
}

// Helper function to build local data section
Widget _buildLocalDataSection(Map<String, dynamic> data, bool isDark) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Package local
      if (data.containsKey('localPackage')) ...[
        _buildLocalPackageSection(
          data['localPackage'],
          data['packageType'],
          isDark,
        ),
        const SizedBox(height: 12),
      ],

      // ClÃƒÂ© mÃƒÂ©dia locale
      if (data.containsKey('localMediaKey')) ...[
        _buildLocalMediaKeySection(data['localMediaKey'], isDark),
        const SizedBox(height: 12),
      ],

      // Payload BDD (si disponible)
      if (data.containsKey('databasePayload')) ...[
        _buildPayloadSection(
          'Payload BDD (ChiffrÃƒÂ©)',
          data['databasePayload'],
          isDark,
          true,
        ),
        const SizedBox(height: 8),
        _buildPayloadSection(
          'Payload BDD (DÃƒÂ©chiffrÃƒÂ©)',
          data['databasePayload'],
          isDark,
          false,
        ),
      ] else ...[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Aucun payload en BDD (normal si dÃƒÂ©jÃƒÂ  rÃƒÂ©cupÃƒÂ©rÃƒÂ©)',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    ],
  );
}

// Helper function to build local package section
Widget _buildLocalPackageSection(
  Map<String, dynamic> package,
  String packageType,
  bool isDark,
) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: isDark
          ? Colors.green[900]?.withValues(alpha: 0.3)
          : Colors.green[50],
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Package Local:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.green[200] : Colors.green[800],
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        _buildPayloadField(
          'Type',
          packageType == 'complete' ? 'Package complet' : 'Format ancien',
          isDark,
        ),
        if (package.containsKey('langMap')) ...[
          _buildPayloadField(
            'Langue (A-Z)',
            '${(package['langMap'] as Map).length} caractÃƒÂ¨res',
            isDark,
          ),
        ],
        if (package.containsKey('mediaKey')) ...[
          _buildPayloadField(
            'ClÃƒÂ© mÃƒÂ©dia (package)',
            package['mediaKey'],
            isDark,
          ),
        ],
        if (package.containsKey('timestamp')) ...[
          _buildPayloadField('Timestamp', package['timestamp'], isDark),
        ],
        if (package.containsKey('version')) ...[
          _buildPayloadField('Version', package['version'], isDark),
        ],
      ],
    ),
  );
}

// Helper function to build local media key section
Widget _buildLocalMediaKeySection(String mediaKey, bool isDark) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: isDark
          ? Colors.orange[900]?.withValues(alpha: 0.3)
          : Colors.orange[50],
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ClÃƒÂ© MÃƒÂ©dia Locale:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.orange[200] : Colors.orange[800],
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        _buildPayloadField('Disponible', 'Ã¢Å“â€¦', isDark),
        _buildPayloadField('ClÃƒÂ© (non chiffrÃƒÂ©e)', mediaKey, isDark),
        _buildPayloadField(
          'Longueur',
          '${mediaKey.length} caractÃƒÂ¨res',
          isDark,
        ),
      ],
    ),
  );
}

// Helper function to build payload section
Widget _buildPayloadSection(
  String title,
  Map<String, dynamic> payload,
  bool isDark,
  bool isEncrypted,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.purple[300] : Colors.purple[700],
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 6),
      if (isEncrypted) ...[
        // Affichage du payload chiffrÃƒÂ©
        _buildPayloadField('encrypted', payload['encrypted'], isDark),
        _buildPayloadField('iv', payload['iv'], isDark),
        _buildPayloadField('encryptedKey', payload['encryptedKey'], isDark),
        _buildPayloadField('from', payload['from'], isDark),
        _buildPayloadField('to', payload['to'], isDark),
      ] else ...[
        // Affichage du payload dÃƒÂ©chiffrÃƒÂ©
        FutureBuilder<String?>(
          future: _decryptPayload(payload),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            } else if (snapshot.hasError) {
              return Text(
                'Erreur dÃƒÂ©chiffrement: ${snapshot.error}',
                style: TextStyle(
                  color: isDark ? Colors.red[300] : Colors.red[700],
                  fontSize: 11,
                ),
              );
            } else if (snapshot.hasData) {
              try {
                final decryptedData = jsonDecode(snapshot.data!);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (decryptedData is Map) ...[
                      if (decryptedData.containsKey('langMap')) ...[
                        _buildPayloadField(
                          'Type',
                          'Package complet (langue + clÃƒÂ© mÃƒÂ©dia)',
                          isDark,
                        ),
                        _buildPayloadField(
                          'Langue (A-Z)',
                          '${(decryptedData['langMap'] as Map).length} caractÃƒÂ¨res',
                          isDark,
                        ),
                        _buildPayloadField(
                          'ClÃƒÂ© mÃƒÂ©dia',
                          decryptedData['mediaKey'] ?? 'Non disponible',
                          isDark,
                        ),
                        _buildPayloadField(
                          'Timestamp',
                          decryptedData['timestamp'] ?? 'Non disponible',
                          isDark,
                        ),
                        _buildPayloadField(
                          'Version',
                          decryptedData['version'] ?? 'Non disponible',
                          isDark,
                        ),
                      ] else ...[
                        _buildPayloadField(
                          'Type',
                          'Langue seule (ancien format)',
                          isDark,
                        ),
                        _buildPayloadField(
                          'Langue (A-Z)',
                          '${decryptedData.length} caractÃƒÂ¨res',
                          isDark,
                        ),
                      ],
                    ] else ...[
                      _buildPayloadField(
                        'Contenu dÃƒÂ©chiffrÃƒÂ©',
                        snapshot.data!,
                        isDark,
                      ),
                    ],
                  ],
                );
              } catch (e) {
                return _buildPayloadField(
                  'Contenu dÃƒÂ©chiffrÃƒÂ© (brut)',
                  snapshot.data!,
                  isDark,
                );
              }
            } else {
              return Text(
                'Aucune donnÃƒÂ©e dÃƒÂ©chiffrÃƒÂ©e',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 11,
                ),
              );
            }
          },
        ),
      ],
    ],
  );
}

// Helper function to build individual payload field
Widget _buildPayloadField(String label, dynamic value, bool isDark) {
  final valueStr = value?.toString() ?? 'null';
  final isLongValue = valueStr.length > 50;

  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.purple[200] : Colors.purple[600],
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            isLongValue ? '${valueStr.substring(0, 50)}...' : valueStr,
            style: TextStyle(
              fontFamily: 'monospace',
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 10,
            ),
          ),
        ),
      ],
    ),
  );
}

// Helper function to decrypt payload
Future<String?> _decryptPayload(Map<String, dynamic> payload) async {
  try {
    const storage = FlutterSecureStorage();
    final privateKey = await storage.read(key: 'rsa_private_key');
    if (privateKey == null) {
      throw Exception('ClÃƒÂ© privÃƒÂ©e non trouvÃƒÂ©e');
    }

    return RSAKeyService.hybridDecrypt(payload, privateKey);
  } catch (e) {
    throw Exception('Erreur dÃƒÂ©chiffrement: $e');
  }
}
