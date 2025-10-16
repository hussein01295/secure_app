import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; 
import 'package:go_router/go_router.dart'; 
import 'package:silencia/core/widgets/cached_profile_avatar.dart';
import 'package:silencia/features/call/widgets/call_controls.dart';
import 'package:silencia/features/call/widgets/call_timer.dart';
import 'package:silencia/features/call/models/call_state.dart';


class CallScreen extends StatefulWidget {
  final String contactName;
  final String contactId;
  final String? contactAvatar;
  final CallType callType;
  final bool isIncoming;
  final String? callId;

  const CallScreen({
    super.key,
    required this.contactName,
    required this.contactId,
    this.contactAvatar,
    required this.callType,
    this.isIncoming = false,
    this.callId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with TickerProviderStateMixin {

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  
  CallState _callState = CallState.connecting;
  Duration _callDuration = Duration.zero;
  Timer? _callTimer;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoEnabled = true;
  bool _isBackCamera = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCall();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();
  }

  void _initializeCall() {

    
    if (widget.isIncoming) {
      _callState = CallState.incoming;
      _pulseController.repeat(reverse: true);
    } else {
      _callState = CallState.connecting;
      _simulateCallConnection();
    }
  }

  void _simulateCallConnection() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _callState = CallState.connected;
      });
      _startCallTimer();
      _pulseController.stop();
    }
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration = Duration(seconds: timer.tick);
        });
      }
    });
  }

  void _answerCall() {
    HapticFeedback.lightImpact();
    setState(() {
      _callState = CallState.connected;
    });
    _startCallTimer();
    _pulseController.stop();
  }

  void _declineCall() {
    HapticFeedback.mediumImpact();
    _endCall();
  }

  void _endCall() {
    _callTimer?.cancel();
    _pulseController.stop();
    context.pop();
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleSpeaker() {
    HapticFeedback.selectionClick();
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  void _toggleVideo() {
    HapticFeedback.selectionClick();
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
  }

  void _switchCamera() {
    HapticFeedback.selectionClick();
    setState(() {
      _isBackCamera = !_isBackCamera;
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      body: SlideTransition(
        position: _slideAnimation,
        child: SafeArea(
          child: Column(
            children: [
              _buildTopSection(),
              Expanded(
                child: _buildMainContent(),
              ),
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.callType == CallType.video && _callState == CallState.connected) {
      return Colors.black;
    }
    return isDark ? const Color(0xFF1a1a1a) : const Color(0xFF2c5f5f);
  }

  Widget _buildTopSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 28,
            ),
          ),
          if (widget.callType == CallType.video && _callState == CallState.connected)
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(
                Icons.flip_camera_ios,
                color: Colors.white,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (widget.callType == CallType.video && _callState == CallState.connected) {
      return _buildVideoCallContent();
    }
    return _buildAudioCallContent();
  }

  Widget _buildAudioCallContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Avatar avec animation de pulsation
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _callState == CallState.incoming ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: CachedProfileAvatar(
                  username: widget.contactName,
                  radius: 100,
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 40),
        
        // Nom du contact
        Text(
          widget.contactName,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w300,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 16),
        
        // Statut de l'appel
        Text(
          _getCallStatusText(),
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        
        // Timer de l'appel
        if (_callState == CallState.connected) ...[
          const SizedBox(height: 8),
          CallTimer(duration: _callDuration),
        ],
      ],
    );
  }

  Widget _buildVideoCallContent() {
    return Stack(
      children: [
        // Vidéo principale (simulée)
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade900,
                Colors.purple.shade900,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Vidéo simulée',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Vidéo locale (petite fenêtre)
        Positioned(
          top: 20,
          right: 20,
          child: Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.shade700,
                      Colors.teal.shade700,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Informations de l'appel en overlay
        Positioned(
          top: 60,
          left: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.contactName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              CallTimer(
                duration: _callDuration,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: CallControls(
        callType: widget.callType,
        callState: _callState,
        isMuted: _isMuted,
        isSpeakerOn: _isSpeakerOn,
        isVideoEnabled: _isVideoEnabled,
        onAnswer: _answerCall,
        onDecline: _declineCall,
        onEndCall: _endCall,
        onToggleMute: _toggleMute,
        onToggleSpeaker: _toggleSpeaker,
        onToggleVideo: _toggleVideo,
      ),
    );
  }

  String _getCallStatusText() {
    switch (_callState) {
      case CallState.incoming:
        return 'Appel entrant...';
      case CallState.connecting:
        return 'Connexion...';
      case CallState.connected:
        return widget.callType == CallType.video ? 'Appel vidéo' : 'Appel vocal';
      case CallState.ended:
        return 'Appel terminé';
    }
  }
}
