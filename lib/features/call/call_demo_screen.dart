import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:silencia/features/call/models/call_state.dart';
import 'package:silencia/features/call/services/incoming_call_service.dart';
import 'package:silencia/features/call/services/call_simulator_service.dart';
import 'package:silencia/features/call/widgets/call_button.dart';

class CallDemoScreen extends StatefulWidget {
  const CallDemoScreen({super.key});

  @override
  State<CallDemoScreen> createState() => _CallDemoScreenState();
}

class _CallDemoScreenState extends State<CallDemoScreen> {
  late IncomingCallService _incomingCallService;
  late CallSimulatorService _callSimulatorService;
  bool _isRandomCallsActive = false;

  @override
  void initState() {
    super.initState();
    _incomingCallService = IncomingCallService();
    _callSimulatorService = CallSimulatorService();
    
    // Générer des données de démonstration
    _callSimulatorService.generateSampleCallHistory();
  }

  @override
  void dispose() {
    _incomingCallService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Démonstration des Appels'),
        backgroundColor: colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('🎮 Contrôles de Simulation'),
            _buildSimulationControls(),
            
            const SizedBox(height: 32),
            
            _buildSectionTitle('📞 Appels Sortants'),
            _buildOutgoingCallsSection(),
            
            const SizedBox(height: 32),
            
            _buildSectionTitle('📱 Appels Entrants'),
            _buildIncomingCallsSection(),
            
            const SizedBox(height: 32),
            
            _buildSectionTitle('📋 Historique des Appels'),
            _buildCallHistorySection(),
            
            const SizedBox(height: 32),
            
            _buildSectionTitle('🎨 Widgets d\'Appel'),
            _buildCallWidgetsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSimulationControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Appels entrants aléatoires'),
              subtitle: const Text('Simule des appels entrants toutes les 30s-5min'),
              value: _isRandomCallsActive,
              onChanged: (value) {
                setState(() {
                  _isRandomCallsActive = value;
                });
                
                if (value) {
                  _incomingCallService.startRandomIncomingCalls(context);
                } else {
                  _incomingCallService.stopRandomIncomingCalls();
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Régénérer l\'historique'),
              subtitle: const Text('Créer de nouveaux appels de démonstration'),
              onTap: () {
                _callSimulatorService.generateSampleCallHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Historique des appels régénéré'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutgoingCallsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.call, color: Colors.green),
              title: const Text('Appel vocal vers Alice'),
              subtitle: const Text('Démarrer un appel vocal simulé'),
              onTap: () => _makeCall('Alice Martin', 'alice123', CallType.audio),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.blue),
              title: const Text('Appel vidéo vers Bob'),
              subtitle: const Text('Démarrer un appel vidéo simulé'),
              onTap: () => _makeCall('Bob Dupont', 'bob456', CallType.video),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.phone_callback, color: Colors.orange),
              title: const Text('Appel vers contact aléatoire'),
              subtitle: const Text('Appel vers un contact généré aléatoirement'),
              onTap: _makeRandomCall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingCallsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.call_received, color: Colors.green),
              title: const Text('Appel entrant vocal'),
              subtitle: const Text('Simuler un appel vocal entrant'),
              onTap: () => _simulateIncomingCall(CallType.audio),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.video_call, color: Colors.blue),
              title: const Text('Appel entrant vidéo'),
              subtitle: const Text('Simuler un appel vidéo entrant'),
              onTap: () => _simulateIncomingCall(CallType.video),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.call_missed, color: Colors.red),
              title: const Text('Appel entrant aléatoire'),
              subtitle: const Text('Type d\'appel et contact aléatoires'),
              onTap: _simulateRandomIncomingCall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallHistorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Voir l\'historique complet'),
              subtitle: const Text('Ouvrir l\'écran d\'historique des appels'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => context.push('/call-history'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.clear_all),
              title: const Text('Effacer l\'historique'),
              subtitle: const Text('Supprimer tous les appels de l\'historique'),
              onTap: () {
                _callSimulatorService.clearCallHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Historique des appels effacé'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallWidgetsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Exemples de widgets d\'appel',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            
            // Boutons d'appel simples
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CallButton(
                  contactName: 'Alice Martin',
                  contactId: 'alice123',
                  callType: CallType.audio,
                  size: 56,
                ),
                CallButton(
                  contactName: 'Alice Martin',
                  contactId: 'alice123',
                  callType: CallType.video,
                  size: 56,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Rangée de boutons d'appel
            CallButtonRow(
              contactName: 'Bob Dupont',
              contactId: 'bob456',
              buttonSize: 48,
            ),
            
            const SizedBox(height: 16),
            
            // Chips d'action d'appel
            Wrap(
              spacing: 8,
              children: [
                CallActionChip(
                  contactName: 'Claire Moreau',
                  contactId: 'claire789',
                  callType: CallType.audio,
                ),
                CallActionChip(
                  contactName: 'Claire Moreau',
                  contactId: 'claire789',
                  callType: CallType.video,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _makeCall(String contactName, String contactId, CallType callType) {
    context.push('/call', extra: {
      'contactName': contactName,
      'contactId': contactId,
      'callType': callType,
      'isIncoming': false,
    });
  }

  void _makeRandomCall() {
    final contacts = [
      {'name': 'Alice Martin', 'id': 'alice123'},
      {'name': 'Bob Dupont', 'id': 'bob456'},
      {'name': 'Claire Moreau', 'id': 'claire789'},
      {'name': 'David Leroy', 'id': 'david012'},
    ];
    
    final contact = contacts[DateTime.now().millisecond % contacts.length];
    final callType = DateTime.now().millisecond % 2 == 0 ? CallType.audio : CallType.video;
    
    _makeCall(contact['name']!, contact['id']!, callType);
  }

  void _simulateIncomingCall(CallType callType) {
    _incomingCallService.showIncomingCall(
      context: context,
      contactName: 'Emma Rousseau',
      contactId: 'emma345',
      callType: callType,
    );
  }

  void _simulateRandomIncomingCall() {
    final contacts = [
      {'name': 'François Bernard', 'id': 'francois678'},
      {'name': 'Gabrielle Petit', 'id': 'gabrielle901'},
      {'name': 'Hugo Durand', 'id': 'hugo234'},
    ];
    
    final contact = contacts[DateTime.now().millisecond % contacts.length];
    final callType = DateTime.now().millisecond % 2 == 0 ? CallType.audio : CallType.video;
    
    _incomingCallService.showIncomingCall(
      context: context,
      contactName: contact['name']!,
      contactId: contact['id']!,
      callType: callType,
    );
  }
}
