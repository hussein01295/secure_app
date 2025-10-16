import 'package:flutter/material.dart';
import 'package:silencia/core/theme/theme_manager.dart';
import 'package:silencia/core/theme/app_theme.dart';
import 'package:silencia/core/service/ephemeral_service.dart';

class EphemeralSettingsScreen extends StatefulWidget {
  final String relationId;
  final String contactName;

  const EphemeralSettingsScreen({
    super.key,
    required this.relationId,
    required this.contactName,
  });

  @override
  State<EphemeralSettingsScreen> createState() => _EphemeralSettingsScreenState();
}

class _EphemeralSettingsScreenState extends State<EphemeralSettingsScreen> {
  bool _isLoading = true;
  bool _enabled = false;
  String _durationType = 'timer';
  int _timerDuration = 86400000; // 24h par défaut
  int? _customDuration;
  bool _deleteAfterRead = false;
  bool _autoDelete = true;
  bool _notifyBeforeExpiry = false;
  int _notifyMinutes = 60;

  // Pour la durée personnalisée
  int _customValue = 1;
  String _customUnit = 'hours'; // 'minutes', 'hours', 'days'

  final Map<int, String> _durationLabels = {
    60000: '1 minute',
    3600000: '1 heure',
    43200000: '12 heures',
    86400000: '24 heures',
    604800000: '7 jours',
    1209600000: '14 jours',
    2678400000: '31 jours',
    7776000000: '90 jours',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await EphemeralService.getSettings(widget.relationId);
      setState(() {
        _enabled = settings['enabled'] ?? false;
        _durationType = settings['durationType'] ?? 'timer';
        _timerDuration = settings['timerDuration'] ?? 86400000;
        _customDuration = settings['customDuration'];
        _deleteAfterRead = settings['deleteAfterRead'] ?? false;
        _autoDelete = settings['autoDelete'] ?? true;
        _notifyBeforeExpiry = settings['notifyBeforeExpiry'] ?? false;
        _notifyMinutes = settings['notifyMinutes'] ?? 60;

        // Calculer la valeur et l'unité pour la durée personnalisée
        if (_customDuration != null) {
          _parseCustomDuration(_customDuration!);
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur lors du chargement des paramètres');
    }
  }

  Future<void> _saveSettings() async {
    try {
      setState(() => _isLoading = true);

      // Calculer la durée personnalisée si nécessaire
      int? finalCustomDuration = _customDuration;
      if (_durationType == 'custom') {
        finalCustomDuration = _calculateCustomDuration();
      }

      await EphemeralService.updateSettings(widget.relationId, {
        'enabled': _enabled,
        'durationType': _durationType,
        'timerDuration': _timerDuration,
        'customDuration': finalCustomDuration,
        'deleteAfterRead': _deleteAfterRead,
        'autoDelete': _autoDelete,
        'notifyBeforeExpiry': _notifyBeforeExpiry,
        'notifyMinutes': _notifyMinutes,
      });

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Paramètres sauvegardés avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur lors de la sauvegarde');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _sendHelpMessage() async {
    try {
      await EphemeralService.sendHelpMessage(widget.relationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💡 Message d\'aide envoyé dans le chat'),
            backgroundColor: Colors.blue,
          ),
        );

        // Retourner au chat après avoir envoyé l'aide
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('Erreur lors de l\'envoi du message d\'aide');
    }
  }

  void _parseCustomDuration(int durationMs) {
    // Convertir les millisecondes en valeur et unité
    if (durationMs % 86400000 == 0) {
      // Jours
      _customValue = durationMs ~/ 86400000;
      _customUnit = 'days';
    } else if (durationMs % 3600000 == 0) {
      // Heures
      _customValue = durationMs ~/ 3600000;
      _customUnit = 'hours';
    } else {
      // Minutes
      _customValue = durationMs ~/ 60000;
      _customUnit = 'minutes';
    }
  }

  int _calculateCustomDuration() {
    switch (_customUnit) {
      case 'minutes':
        return _customValue * 60000;
      case 'hours':
        return _customValue * 3600000;
      case 'days':
        return _customValue * 86400000;
      default:
        return _customValue * 3600000; // Par défaut en heures
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = globalThemeManager;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages éphémères'),
        backgroundColor: themeManager.currentTheme == AppThemeMode.neon
            ? Colors.transparent
            : null,
        flexibleSpace: themeManager.currentTheme == AppThemeMode.neon
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6A1B9A),
                      const Color(0xFFAD1457),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              )
            : null,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildHelpButton(),
                  const SizedBox(height: 24),
                  _buildMainToggle(),
                  if (_enabled) ...[
                    const SizedBox(height: 24),
                    _buildDurationTypeSelector(),
                    const SizedBox(height: 16),
                    if (_durationType == 'timer') _buildTimerDurationSelector(),
                    if (_durationType == 'custom') _buildCustomDurationInput(),
                    if (_durationType == 'after_read') _buildAfterReadInfo(),
                    const SizedBox(height: 24),
                    _buildAdvancedOptions(),
                  ],
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_delete, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Messages éphémères avec ${widget.contactName}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Les messages éphémères se suppriment automatiquement selon vos paramètres. Cette fonctionnalité améliore votre confidentialité.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainToggle() {
    return Card(
      child: SwitchListTile(
        title: const Text('Activer les messages éphémères'),
        subtitle: Text(_enabled 
            ? 'Les nouveaux messages seront éphémères'
            : 'Les messages seront conservés normalement'),
        value: _enabled,
        onChanged: (value) => setState(() => _enabled = value),
        secondary: Icon(
          _enabled ? Icons.visibility_off : Icons.visibility,
          color: _enabled ? Colors.orange : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDurationTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type de suppression',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              onChanged: (value) => setState(() {
                _durationType = value!;
                _deleteAfterRead = value == 'after_read';
              }),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Après lecture'),
                    subtitle: const Text('Supprimé quand le destinataire quitte le chat'),
                    value: 'after_read',
                  ),
                  RadioListTile<String>(
                    title: const Text('Durée prédéfinie'),
                    subtitle: const Text('Choisir parmi les durées proposées'),
                    value: 'timer',
                  ),
                  RadioListTile<String>(
                    title: const Text('Durée personnalisée'),
                    subtitle: const Text('Définir votre propre durée'),
                    value: 'custom',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerDurationSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Durée avant suppression',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _durationLabels.entries.map((entry) {
                final isSelected = _timerDuration == entry.key;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _timerDuration = entry.key);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomDurationInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Durée personnalisée',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: _customValue.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Valeur',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final val = int.tryParse(value);
                      if (val != null && val > 0) {
                        setState(() {
                          _customValue = val;
                          _customDuration = _calculateCustomDuration();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _customUnit,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'minutes', child: Text('Minutes')),
                      DropdownMenuItem(value: 'hours', child: Text('Heures')),
                      DropdownMenuItem(value: 'days', child: Text('Jours')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _customUnit = value;
                          _customDuration = _calculateCustomDuration();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Durée: $_customValue ${_getUnitLabel(_customUnit)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getUnitLabel(String unit) {
    switch (unit) {
      case 'minutes':
        return _customValue == 1 ? 'minute' : 'minutes';
      case 'hours':
        return _customValue == 1 ? 'heure' : 'heures';
      case 'days':
        return _customValue == 1 ? 'jour' : 'jours';
      default:
        return unit;
    }
  }

  Widget _buildAfterReadInfo() {
    return Card(
      color: Colors.orange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Les messages seront supprimés 5 secondes après que le destinataire ait quitté le chat.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Options avancées',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Suppression automatique'),
              subtitle: const Text('Supprimer automatiquement les messages expirés'),
              value: _autoDelete,
              onChanged: (value) => setState(() => _autoDelete = value),
            ),
            if (_durationType == 'timer' || _durationType == 'custom')
              SwitchListTile(
                title: const Text('Notification avant expiration'),
                subtitle: const Text('Être prévenu avant la suppression'),
                value: _notifyBeforeExpiry,
                onChanged: (value) => setState(() => _notifyBeforeExpiry = value),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpButton() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.help_outline,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Besoin d\'aide ?',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Envoyer un guide dans le chat',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _sendHelpMessage,
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Envoyer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveSettings,
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(_isLoading ? 'Sauvegarde...' : 'Sauvegarder les paramètres'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
