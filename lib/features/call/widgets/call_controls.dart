import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/call_state.dart';

class CallControls extends StatelessWidget {
  final CallType callType;
  final CallState callState;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isVideoEnabled;
  final VoidCallback? onAnswer;
  final VoidCallback? onDecline;
  final VoidCallback? onEndCall;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleSpeaker;
  final VoidCallback? onToggleVideo;

  const CallControls({
    super.key,
    required this.callType,
    required this.callState,
    required this.isMuted,
    required this.isSpeakerOn,
    required this.isVideoEnabled,
    this.onAnswer,
    this.onDecline,
    this.onEndCall,
    this.onToggleMute,
    this.onToggleSpeaker,
    this.onToggleVideo,
  });

  @override
  Widget build(BuildContext context) {
    if (callState == CallState.incoming) {
      return _buildIncomingCallControls();
    }
    
    return _buildActiveCallControls();
  }

  Widget _buildIncomingCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Bouton Décliner
        _CallControlButton(
          icon: Icons.call_end,
          backgroundColor: Colors.red,
          size: 70,
          onPressed: onDecline,
        ),
        
        // Bouton Répondre
        _CallControlButton(
          icon: callType == CallType.video ? Icons.videocam : Icons.call,
          backgroundColor: Colors.green,
          size: 70,
          onPressed: onAnswer,
        ),
      ],
    );
  }

  Widget _buildActiveCallControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Première rangée de contrôles
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Bouton Muet
            _CallControlButton(
              icon: isMuted ? Icons.mic_off : Icons.mic,
              backgroundColor: isMuted ? Colors.red : Colors.grey.shade700,
              onPressed: onToggleMute,
            ),
            
            // Bouton Haut-parleur (seulement pour les appels audio)
            if (callType == CallType.audio)
              _CallControlButton(
                icon: isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                backgroundColor: isSpeakerOn ? Colors.blue : Colors.grey.shade700,
                onPressed: onToggleSpeaker,
              ),
            
            // Bouton Vidéo (seulement pour les appels vidéo)
            if (callType == CallType.video)
              _CallControlButton(
                icon: isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                backgroundColor: isVideoEnabled ? Colors.blue : Colors.red,
                onPressed: onToggleVideo,
              ),
            
            // Bouton Raccrocher
            _CallControlButton(
              icon: Icons.call_end,
              backgroundColor: Colors.red,
              onPressed: onEndCall,
            ),
          ],
        ),
      ],
    );
  }
}

class _CallControlButton extends StatefulWidget {
  final IconData icon;
  final Color backgroundColor;
  final double size;
  final VoidCallback? onPressed;

  const _CallControlButton({
    required this.icon,
    required this.backgroundColor,
    this.size = 60,
    this.onPressed,
  });

  @override
  State<_CallControlButton> createState() => _CallControlButtonState();
}

class _CallControlButtonState extends State<_CallControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onPressed?.call();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.backgroundColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: widget.size * 0.4,
              ),
            ),
          );
        },
      ),
    );
  }
}

class CallControlsOverlay extends StatelessWidget {
  final CallType callType;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isVideoEnabled;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleSpeaker;
  final VoidCallback? onToggleVideo;
  final VoidCallback? onEndCall;

  const CallControlsOverlay({
    super.key,
    required this.callType,
    required this.isMuted,
    required this.isSpeakerOn,
    required this.isVideoEnabled,
    this.onToggleMute,
    this.onToggleSpeaker,
    this.onToggleVideo,
    this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton Muet
          _CallControlButton(
            icon: isMuted ? Icons.mic_off : Icons.mic,
            backgroundColor: isMuted ? Colors.red : Colors.grey.shade700,
            size: 50,
            onPressed: onToggleMute,
          ),
          
          const SizedBox(width: 16),
          
          // Bouton Haut-parleur ou Vidéo
          if (callType == CallType.audio)
            _CallControlButton(
              icon: isSpeakerOn ? Icons.volume_up : Icons.volume_down,
              backgroundColor: isSpeakerOn ? Colors.blue : Colors.grey.shade700,
              size: 50,
              onPressed: onToggleSpeaker,
            )
          else
            _CallControlButton(
              icon: isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              backgroundColor: isVideoEnabled ? Colors.blue : Colors.red,
              size: 50,
              onPressed: onToggleVideo,
            ),
          
          const SizedBox(width: 16),
          
          // Bouton Raccrocher
          _CallControlButton(
            icon: Icons.call_end,
            backgroundColor: Colors.red,
            size: 50,
            onPressed: onEndCall,
          ),
        ],
      ),
    );
  }
}
