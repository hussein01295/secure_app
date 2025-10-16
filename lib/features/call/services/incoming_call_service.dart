import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/call_state.dart';
import '../widgets/incoming_call_overlay.dart';
import '../call_screen.dart';

class IncomingCallService {
  static final IncomingCallService _instance = IncomingCallService._internal();
  factory IncomingCallService() => _instance;
  IncomingCallService._internal();

  Timer? _simulationTimer;
  bool _isSimulationActive = false;
  OverlayEntry? _currentCallOverlay;
  
  final List<Map<String, String>> _sampleContacts = [
    {'id': 'demo1', 'name': 'Alice Martin'},
    {'id': 'demo2', 'name': 'Bob Dupont'},
    {'id': 'demo3', 'name': 'Claire Moreau'},
    {'id': 'demo4', 'name': 'David Leroy'},
    {'id': 'demo5', 'name': 'Emma Rousseau'},
    {'id': 'demo6', 'name': 'François Bernard'},
    {'id': 'demo7', 'name': 'Gabrielle Petit'},
    {'id': 'demo8', 'name': 'Hugo Durand'},
  ];

  // Démarrer la simulation d'appels entrants aléatoires
  void startRandomIncomingCalls(BuildContext context) {
    if (_isSimulationActive) return;
    
    _isSimulationActive = true;
    _scheduleNextCall(context);
  }

  // Arrêter la simulation
  void stopRandomIncomingCalls() {
    _isSimulationActive = false;
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  // Programmer le prochain appel
  void _scheduleNextCall(BuildContext context) {
    if (!_isSimulationActive) return;
    
    // Appel aléatoire entre 30 secondes et 5 minutes
    final delay = Duration(
      seconds: 30 + Random().nextInt(270), // 30s à 5min
    );
    
    _simulationTimer = Timer(delay, () {
      if (_isSimulationActive && context.mounted) {
        _triggerIncomingCall(context);
        _scheduleNextCall(context); // Programmer le suivant
      }
    });
  }

  // Déclencher un appel entrant
  void _triggerIncomingCall(BuildContext context) {
    if (_currentCallOverlay != null) return; // Déjà un appel en cours
    
    final contact = _sampleContacts[Random().nextInt(_sampleContacts.length)];
    final callType = Random().nextBool() ? CallType.audio : CallType.video;
    
    showIncomingCall(
      context: context,
      contactName: contact['name']!,
      contactId: contact['id']!,
      callType: callType,
    );
  }

  // Afficher un appel entrant spécifique
  void showIncomingCall({
    required BuildContext context,
    required String contactName,
    required String contactId,
    String? contactAvatar,
    required CallType callType,
  }) {
    if (_currentCallOverlay != null) return;
    
    // Vibration pour signaler l'appel
    HapticFeedback.heavyImpact();
    
    _currentCallOverlay = OverlayEntry(
      builder: (context) => IncomingCallOverlay(
        contactName: contactName,
        contactId: contactId,
        contactAvatar: contactAvatar,
        callType: callType,
        onAnswer: () => _answerCall(context, contactName, contactId, contactAvatar, callType),
        onDecline: () => _declineCall(),
        onDismiss: () => _minimizeCall(context, contactName, contactId, contactAvatar, callType),
      ),
    );
    
    Overlay.of(context, rootOverlay: true).insert(_currentCallOverlay!);
    
    // Auto-timeout après 30 secondes
    Timer(const Duration(seconds: 30), () {
      if (_currentCallOverlay != null) {
        _declineCall();
      }
    });
  }

  // Répondre à l'appel
  void _answerCall(
    BuildContext context,
    String contactName,
    String contactId,
    String? contactAvatar,
    CallType callType,
  ) {
    _removeCurrentOverlay();
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          contactName: contactName,
          contactId: contactId,
          contactAvatar: contactAvatar,
          callType: callType,
          isIncoming: true,
        ),
      ),
    );
  }

  // Décliner l'appel
  void _declineCall() {
    HapticFeedback.mediumImpact();
    _removeCurrentOverlay();
  }

  // Minimiser l'appel (afficher en petit)
  void _minimizeCall(
    BuildContext context,
    String contactName,
    String contactId,
    String? contactAvatar,
    CallType callType,
  ) {
    _removeCurrentOverlay();
    _showMinimizedCall(context, contactName, contactId, contactAvatar, callType);
  }

  // Afficher l'appel minimisé
  void _showMinimizedCall(
    BuildContext context,
    String contactName,
    String contactId,
    String? contactAvatar,
    CallType callType,
  ) {
    _currentCallOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        right: 20,
        child: _MinimizedCallWidget(
          contactName: contactName,
          contactId: contactId,
          contactAvatar: contactAvatar,
          callType: callType,
          onAnswer: () => _answerCall(context, contactName, contactId, contactAvatar, callType),
          onDecline: () => _declineCall(),
          onExpand: () {
            _removeCurrentOverlay();
            showIncomingCall(
              context: context,
              contactName: contactName,
              contactId: contactId,
              contactAvatar: contactAvatar,
              callType: callType,
            );
          },
        ),
      ),
    );
    
    Overlay.of(context, rootOverlay: true).insert(_currentCallOverlay!);
  }

  // Supprimer l'overlay actuel
  void _removeCurrentOverlay() {
    _currentCallOverlay?.remove();
    _currentCallOverlay = null;
  }

  // Nettoyer les ressources
  void dispose() {
    stopRandomIncomingCalls();
    _removeCurrentOverlay();
  }
}

class _MinimizedCallWidget extends StatefulWidget {
  final String contactName;
  final String contactId;
  final String? contactAvatar;
  final CallType callType;
  final VoidCallback onAnswer;
  final VoidCallback onDecline;
  final VoidCallback onExpand;

  const _MinimizedCallWidget({
    required this.contactName,
    required this.contactId,
    this.contactAvatar,
    required this.callType,
    required this.onAnswer,
    required this.onDecline,
    required this.onExpand,
  });

  @override
  State<_MinimizedCallWidget> createState() => _MinimizedCallWidgetState();
}

class _MinimizedCallWidgetState extends State<_MinimizedCallWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GestureDetector(
            onTap: widget.onExpand,
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.callType == CallType.video ? Icons.videocam : Icons.call,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.contactName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: widget.onDecline,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onAnswer,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.callType == CallType.video ? Icons.videocam : Icons.call,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
