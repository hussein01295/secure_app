import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:silencia/core/widgets/cached_profile_avatar.dart';
import 'package:silencia/features/call/models/call_state.dart';

class IncomingCallOverlay extends StatefulWidget {
  final String contactName;
  final String contactId;
  final String? contactAvatar;
  final CallType callType;
  final VoidCallback onAnswer;
  final VoidCallback onDecline;
  final VoidCallback? onDismiss;

  const IncomingCallOverlay({
    super.key,
    required this.contactName,
    required this.contactId,
    this.contactAvatar,
    required this.callType,
    required this.onAnswer,
    required this.onDecline,
    this.onDismiss,
  });

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
  }

  void _startAnimations() {
    _slideController.forward();
    _pulseController.repeat(reverse: true);
    _rippleController.repeat();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.9),
              ],
            ),
          ),
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
      ),
    );
  }

  Widget _buildTopSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.callType == CallType.video ? 'Appel vidéo entrant' : 'Appel entrant',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.onDismiss != null)
            IconButton(
              onPressed: widget.onDismiss,
              icon: const Icon(
                Icons.keyboard_arrow_up,
                color: Colors.white,
                size: 28,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Avatar avec effet de pulsation et ondulations
        Stack(
          alignment: Alignment.center,
          children: [
            // Ondulations
            AnimatedBuilder(
              animation: _rippleAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(300, 300),
                  painter: RipplePainter(
                    animationValue: _rippleAnimation.value,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                );
              },
            ),
            
            // Avatar avec pulsation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 180,
                    height: 180,
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
                      radius: 90,
                    ),
                  ),
                );
              },
            ),
          ],
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
        
        // Type d'appel
        Text(
          widget.callType == CallType.video ? 'Appel vidéo' : 'Appel vocal',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Bouton Décliner
          _CallActionButton(
            icon: Icons.call_end,
            backgroundColor: Colors.red,
            size: 70,
            onPressed: () {
              HapticFeedback.mediumImpact();
              widget.onDecline();
            },
          ),
          
          // Bouton Message (optionnel)
          _CallActionButton(
            icon: Icons.message,
            backgroundColor: Colors.grey.shade700,
            size: 60,
            onPressed: () {
              HapticFeedback.lightImpact();
              // Envoyer un message rapide
              _showQuickMessageOptions();
            },
          ),
          
          // Bouton Répondre
          _CallActionButton(
            icon: widget.callType == CallType.video ? Icons.videocam : Icons.call,
            backgroundColor: Colors.green,
            size: 70,
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.onAnswer();
            },
          ),
        ],
      ),
    );
  }

  void _showQuickMessageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuickMessageSheet(
        contactName: widget.contactName,
        onMessageSent: () {
          Navigator.of(context).pop();
          widget.onDecline(); // Décliner l'appel après avoir envoyé le message
        },
      ),
    );
  }
}

class _CallActionButton extends StatefulWidget {
  final IconData icon;
  final Color backgroundColor;
  final double size;
  final VoidCallback onPressed;

  const _CallActionButton({
    required this.icon,
    required this.backgroundColor,
    required this.size,
    required this.onPressed,
  });

  @override
  State<_CallActionButton> createState() => _CallActionButtonState();
}

class _CallActionButtonState extends State<_CallActionButton>
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onPressed,
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
                    color: widget.backgroundColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 3,
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

class _QuickMessageSheet extends StatelessWidget {
  final String contactName;
  final VoidCallback onMessageSent;

  const _QuickMessageSheet({
    required this.contactName,
    required this.onMessageSent,
  });

  @override
  Widget build(BuildContext context) {
    final quickMessages = [
      'Je ne peux pas répondre maintenant',
      'Je te rappelle plus tard',
      'Envoie-moi un message',
      'Je suis en réunion',
      'Je conduis',
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Message rapide à $contactName',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ...quickMessages.map((message) => ListTile(
            title: Text(message),
            onTap: () {
              // Simuler l'envoi du message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Message envoyé : "$message"'),
                  duration: const Duration(seconds: 2),
                ),
              );
              onMessageSent();
            },
          )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class RipplePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  RipplePainter({
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Dessiner plusieurs ondulations
    for (int i = 0; i < 3; i++) {
      final progress = (animationValue + i * 0.3) % 1.0;
      final radius = maxRadius * progress;
      final opacity = (1.0 - progress) * 0.5;
      
      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
