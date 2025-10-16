import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/call_state.dart';

class CallButton extends StatelessWidget {
  final String contactName;
  final String contactId;
  final String? contactAvatar;
  final CallType callType;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  const CallButton({
    super.key,
    required this.contactName,
    required this.contactId,
    this.contactAvatar,
    required this.callType,
    this.size = 48,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _makeCall(context);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (backgroundColor ?? colorScheme.primary).withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          callType == CallType.video ? Icons.videocam : Icons.call,
          color: iconColor ?? Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }

  void _makeCall(BuildContext context) {
    context.push('/call', extra: {
      'contactName': contactName,
      'contactId': contactId,
      'contactAvatar': contactAvatar,
      'callType': callType,
      'isIncoming': false,
    });
  }
}

class CallButtonRow extends StatelessWidget {
  final String contactName;
  final String contactId;
  final String? contactAvatar;
  final MainAxisAlignment alignment;
  final double spacing;
  final double buttonSize;

  const CallButtonRow({
    super.key,
    required this.contactName,
    required this.contactId,
    this.contactAvatar,
    this.alignment = MainAxisAlignment.spaceEvenly,
    this.spacing = 16,
    this.buttonSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        CallButton(
          contactName: contactName,
          contactId: contactId,
          contactAvatar: contactAvatar,
          callType: CallType.audio,
          size: buttonSize,
        ),
        SizedBox(width: spacing),
        CallButton(
          contactName: contactName,
          contactId: contactId,
          contactAvatar: contactAvatar,
          callType: CallType.video,
          size: buttonSize,
        ),
      ],
    );
  }
}

class FloatingCallButton extends StatefulWidget {
  final String contactName;
  final String contactId;
  final String? contactAvatar;
  final CallType callType;

  const FloatingCallButton({
    super.key,
    required this.contactName,
    required this.contactId,
    this.contactAvatar,
    required this.callType,
  });

  @override
  State<FloatingCallButton> createState() => _FloatingCallButtonState();
}

class _FloatingCallButtonState extends State<FloatingCallButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FloatingActionButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _animationController.forward().then((_) {
                _animationController.reverse();
              });
              _makeCall();
            },
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            child: Icon(
              widget.callType == CallType.video ? Icons.videocam : Icons.call,
            ),
          ),
        );
      },
    );
  }

  void _makeCall() {
    context.push('/call', extra: {
      'contactName': widget.contactName,
      'contactId': widget.contactId,
      'contactAvatar': widget.contactAvatar,
      'callType': widget.callType,
      'isIncoming': false,
    });
  }
}

class CallActionChip extends StatelessWidget {
  final String contactName;
  final String contactId;
  final String? contactAvatar;
  final CallType callType;
  final String? label;

  const CallActionChip({
    super.key,
    required this.contactName,
    required this.contactId,
    this.contactAvatar,
    required this.callType,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final displayLabel = label ?? 
        (callType == CallType.video ? 'Appel vidéo' : 'Appel vocal');

    return ActionChip(
      avatar: Icon(
        callType == CallType.video ? Icons.videocam : Icons.call,
        size: 18,
        color: colorScheme.primary,
      ),
      label: Text(displayLabel),
      onPressed: () {
        HapticFeedback.lightImpact();
        _makeCall(context);
      },
      backgroundColor: colorScheme.surface,
      side: BorderSide(color: colorScheme.primary),
    );
  }

  void _makeCall(BuildContext context) {
    context.push('/call', extra: {
      'contactName': contactName,
      'contactId': contactId,
      'contactAvatar': contactAvatar,
      'callType': callType,
      'isIncoming': false,
    });
  }
}
