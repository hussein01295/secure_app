import 'package:flutter/material.dart'; 
import 'package:silencia/core/widgets/cached_profile_avatar.dart';
import 'package:silencia/features/call/models/call_state.dart';
import 'package:silencia/features/call/services/call_simulator_service.dart';
import 'package:silencia/features/call/call_screen.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  late CallSimulatorService _callService;
  List<CallHistory> _callHistory = [];

  @override
  void initState() {
    super.initState();
    _callService = CallSimulatorService();
    _loadCallHistory();
    
    // Générer des données de démonstration si l'historique est vide
    if (_callService.callHistory.isEmpty) {
      _callService.generateSampleCallHistory();
    }
  }

  void _loadCallHistory() {
    _callService.callHistoryStream.listen((history) {
      if (mounted) {
        setState(() {
          _callHistory = history;
        });
      }
    });
    
    setState(() {
      _callHistory = _callService.callHistory;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des appels'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Effacer l\'historique'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'generate',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Générer des données'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _callHistory.isEmpty
          ? _buildEmptyState()
          : _buildCallHistoryList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _simulateIncomingCall,
        tooltip: 'Simuler un appel entrant',
        child: const Icon(Icons.call),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.call,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun appel récent',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos appels apparaîtront ici',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _callService.generateSampleCallHistory(),
            icon: const Icon(Icons.refresh),
            label: const Text('Générer des données de test'),
          ),
        ],
      ),
    );
  }

  Widget _buildCallHistoryList() {
    return ListView.builder(
      itemCount: _callHistory.length,
      itemBuilder: (context, index) {
        final call = _callHistory[index];
        return _CallHistoryTile(
          call: call,
          onTap: () => _showCallDetails(call),
          onCallBack: () => _makeCall(call),
        );
      },
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'clear':
        _showClearHistoryDialog();
        break;
      case 'generate':
        _callService.generateSampleCallHistory();
        break;
    }
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer l\'historique'),
        content: const Text('Voulez-vous vraiment effacer tout l\'historique des appels ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              _callService.clearCallHistory();
              Navigator.of(context).pop();
            },
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }

  void _showCallDetails(CallHistory call) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _CallDetailsBottomSheet(call: call),
    );
  }

  void _makeCall(CallHistory call) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          contactName: call.contactName,
          contactId: call.contactId,
          contactAvatar: call.contactAvatar,
          callType: call.callType,
          isIncoming: false,
        ),
      ),
    );
  }

  void _simulateIncomingCall() {
    final contacts = [
      {'id': 'demo1', 'name': 'Alice Martin'},
      {'id': 'demo2', 'name': 'Bob Dupont'},
      {'id': 'demo3', 'name': 'Claire Moreau'},
    ];
    
    final contact = contacts[DateTime.now().millisecond % contacts.length];
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          contactName: contact['name']!,
          contactId: contact['id']!,
          callType: CallType.audio,
          isIncoming: true,
        ),
      ),
    );
  }
}

class _CallHistoryTile extends StatelessWidget {
  final CallHistory call;
  final VoidCallback onTap;
  final VoidCallback onCallBack;

  const _CallHistoryTile({
    required this.call,
    required this.onTap,
    required this.onCallBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: CachedProfileAvatar(
        username: call.contactName,
        radius: 24,
      ),
      title: Text(
        call.contactName,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Row(
        children: [
          Icon(
            _getCallIcon(),
            size: 16,
            color: _getCallIconColor(colorScheme),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${_getCallTypeText()} • ${_formatTimestamp()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _getCallIconColor(colorScheme),
              ),
            ),
          ),
          if (call.duration != null)
            Text(
              call.formattedDuration,
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
      trailing: IconButton(
        onPressed: onCallBack,
        icon: Icon(
          call.callType == CallType.video ? Icons.videocam : Icons.call,
          color: colorScheme.primary,
        ),
      ),
      onTap: onTap,
    );
  }

  IconData _getCallIcon() {
    if (!call.wasAnswered) {
      return call.isIncoming ? Icons.call_received : Icons.call_made;
    }
    
    if (call.isIncoming) {
      return Icons.call_received;
    } else {
      return Icons.call_made;
    }
  }

  Color _getCallIconColor(ColorScheme colorScheme) {
    if (!call.wasAnswered) {
      return Colors.red;
    }
    
    return call.isIncoming ? Colors.green : colorScheme.primary;
  }

  String _getCallTypeText() {
    if (!call.wasAnswered) {
      return call.isIncoming ? 'Appel manqué' : 'Appel non abouti';
    }
    
    final typeText = call.callType == CallType.video ? 'Appel vidéo' : 'Appel vocal';
    final directionText = call.isIncoming ? 'entrant' : 'sortant';
    
    return '$typeText $directionText';
  }

  String _formatTimestamp() {
    final now = DateTime.now();
    final difference = now.difference(call.timestamp);
    
    if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }
}

class _CallDetailsBottomSheet extends StatelessWidget {
  final CallHistory call;

  const _CallDetailsBottomSheet({required this.call});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CachedProfileAvatar(
                username: call.contactName,
                radius: 30,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      call.contactName,
                      style: theme.textTheme.headlineSmall,
                    ),
                    Text(
                      call.callStatusText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          _DetailRow(
            icon: Icons.access_time,
            label: 'Heure',
            value: _formatDetailedTimestamp(),
          ),
          
          _DetailRow(
            icon: call.callType == CallType.video ? Icons.videocam : Icons.call,
            label: 'Type',
            value: call.callType == CallType.video ? 'Appel vidéo' : 'Appel vocal',
          ),
          
          if (call.duration != null)
            _DetailRow(
              icon: Icons.timer,
              label: 'Durée',
              value: call.formattedDuration,
            ),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Ouvrir le chat
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('Message'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Rappeler
                  },
                  icon: Icon(call.callType == CallType.video ? Icons.videocam : Icons.call),
                  label: const Text('Rappeler'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDetailedTimestamp() {
    final now = DateTime.now();
    final callDate = call.timestamp;
    
    if (now.day == callDate.day && 
        now.month == callDate.month && 
        now.year == callDate.year) {
      return 'Aujourd\'hui à ${callDate.hour.toString().padLeft(2, '0')}:${callDate.minute.toString().padLeft(2, '0')}';
    }
    
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.day == callDate.day && 
        yesterday.month == callDate.month && 
        yesterday.year == callDate.year) {
      return 'Hier à ${callDate.hour.toString().padLeft(2, '0')}:${callDate.minute.toString().padLeft(2, '0')}';
    }
    
    return '${callDate.day}/${callDate.month}/${callDate.year} à ${callDate.hour.toString().padLeft(2, '0')}:${callDate.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
