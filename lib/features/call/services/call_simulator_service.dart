import 'dart:async';
import 'dart:math'; 
import '../models/call_state.dart';

class CallSimulatorService {
  static final CallSimulatorService _instance = CallSimulatorService._internal();
  factory CallSimulatorService() => _instance;
  CallSimulatorService._internal();

  final List<CallHistory> _callHistory = [];
  final StreamController<CallData?> _activeCallController = StreamController<CallData?>.broadcast();
  final StreamController<List<CallHistory>> _callHistoryController = StreamController<List<CallHistory>>.broadcast();
  
  CallData? _activeCall;
  Timer? _simulationTimer;

  // Streams
  Stream<CallData?> get activeCallStream => _activeCallController.stream;
  Stream<List<CallHistory>> get callHistoryStream => _callHistoryController.stream;
  
  // Getters
  CallData? get activeCall => _activeCall;
  List<CallHistory> get callHistory => List.unmodifiable(_callHistory);

  // Simuler un appel sortant
  Future<CallData> initiateCall({
    required String contactId,
    required String contactName,
    String? contactAvatar,
    required CallType callType,
  }) async {
    final callId = _generateCallId();
    
    final callData = CallData(
      callId: callId,
      contactId: contactId,
      contactName: contactName,
      contactAvatar: contactAvatar,
      callType: callType,
      isIncoming: false,
      startTime: DateTime.now(),
      state: CallState.connecting,
    );

    _activeCall = callData;
    _activeCallController.add(_activeCall);

    // Simuler la connexion après 2-4 secondes
    _simulationTimer = Timer(
      Duration(seconds: 2 + Random().nextInt(3)),
      () => _simulateCallAnswer(callData),
    );

    return callData;
  }

  // Simuler un appel entrant
  Future<CallData> simulateIncomingCall({
    required String contactId,
    required String contactName,
    String? contactAvatar,
    required CallType callType,
  }) async {
    final callId = _generateCallId();
    
    final callData = CallData(
      callId: callId,
      contactId: contactId,
      contactName: contactName,
      contactAvatar: contactAvatar,
      callType: callType,
      isIncoming: true,
      startTime: DateTime.now(),
      state: CallState.incoming,
    );

    _activeCall = callData;
    _activeCallController.add(_activeCall);

    // Simuler un timeout après 30 secondes si pas de réponse
    _simulationTimer = Timer(
      const Duration(seconds: 30),
      () => _simulateCallTimeout(callData),
    );

    return callData;
  }

  // Répondre à un appel
  void answerCall() {
    if (_activeCall?.state == CallState.incoming) {
      _simulationTimer?.cancel();
      _simulateCallAnswer(_activeCall!);
    }
  }

  // Décliner un appel
  void declineCall() {
    if (_activeCall != null) {
      _simulationTimer?.cancel();
      _endCall(wasAnswered: false);
    }
  }

  // Terminer un appel
  void endCall() {
    if (_activeCall != null) {
      _simulationTimer?.cancel();
      _endCall(wasAnswered: _activeCall!.state == CallState.connected);
    }
  }

  // Simuler la réponse à un appel
  void _simulateCallAnswer(CallData callData) {
    if (_activeCall?.callId == callData.callId) {
      _activeCall = callData.copyWith(state: CallState.connected);
      _activeCallController.add(_activeCall);
    }
  }

  // Simuler un timeout d'appel
  void _simulateCallTimeout(CallData callData) {
    if (_activeCall?.callId == callData.callId) {
      _endCall(wasAnswered: false);
    }
  }

  // Terminer un appel et l'ajouter à l'historique
  void _endCall({required bool wasAnswered}) {
    if (_activeCall == null) return;

    final duration = wasAnswered 
        ? DateTime.now().difference(_activeCall!.startTime)
        : null;

    // Ajouter à l'historique
    final historyEntry = CallHistory(
      id: _generateCallId(),
      contactId: _activeCall!.contactId,
      contactName: _activeCall!.contactName,
      contactAvatar: _activeCall!.contactAvatar,
      callType: _activeCall!.callType,
      isIncoming: _activeCall!.isIncoming,
      wasAnswered: wasAnswered,
      timestamp: _activeCall!.startTime,
      duration: duration,
    );

    _callHistory.insert(0, historyEntry); // Ajouter au début
    _callHistoryController.add(_callHistory);

    // Nettoyer l'appel actif
    _activeCall = null;
    _activeCallController.add(null);
  }

  // Générer un ID d'appel unique
  String _generateCallId() {
    return 'call_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  // Simuler des appels manqués pour la démo
  void generateSampleCallHistory() {
    final sampleContacts = [
      {'id': 'user1', 'name': 'Alice Martin', 'avatar': null},
      {'id': 'user2', 'name': 'Bob Dupont', 'avatar': null},
      {'id': 'user3', 'name': 'Claire Moreau', 'avatar': null},
      {'id': 'user4', 'name': 'David Leroy', 'avatar': null},
    ];

    final random = Random();
    final now = DateTime.now();

    for (int i = 0; i < 10; i++) {
      final contact = sampleContacts[random.nextInt(sampleContacts.length)];
      final isIncoming = random.nextBool();
      final wasAnswered = random.nextBool();
      final callType = random.nextBool() ? CallType.audio : CallType.video;
      
      final timestamp = now.subtract(Duration(
        hours: random.nextInt(72), // Dans les 3 derniers jours
        minutes: random.nextInt(60),
      ));

      Duration? duration;
      if (wasAnswered) {
        duration = Duration(
          minutes: random.nextInt(30),
          seconds: random.nextInt(60),
        );
      }

      final historyEntry = CallHistory(
        id: _generateCallId(),
        contactId: contact['id']!,
        contactName: contact['name']!,
        contactAvatar: contact['avatar'],
        callType: callType,
        isIncoming: isIncoming,
        wasAnswered: wasAnswered,
        timestamp: timestamp,
        duration: duration,
      );

      _callHistory.add(historyEntry);
    }

    // Trier par timestamp décroissant
    _callHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _callHistoryController.add(_callHistory);
  }

  // Nettoyer l'historique
  void clearCallHistory() {
    _callHistory.clear();
    _callHistoryController.add(_callHistory);
  }

  // Supprimer un appel de l'historique
  void removeCallFromHistory(String callId) {
    _callHistory.removeWhere((call) => call.id == callId);
    _callHistoryController.add(_callHistory);
  }

  // Nettoyer les ressources
  void dispose() {
    _simulationTimer?.cancel();
    _activeCallController.close();
    _callHistoryController.close();
  }
}
