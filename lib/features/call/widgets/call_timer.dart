import 'package:flutter/material.dart';

class CallTimer extends StatelessWidget {
  final Duration duration;
  final TextStyle? style;

  const CallTimer({
    super.key,
    required this.duration,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatDuration(duration),
      style: style ?? TextStyle(
        fontSize: 16,
        color: Colors.white.withValues(alpha: 0.9),
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
             '${minutes.toString().padLeft(2, '0')}:'
             '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
             '${seconds.toString().padLeft(2, '0')}';
    }
  }
}

class AnimatedCallTimer extends StatefulWidget {
  final Duration duration;
  final TextStyle? style;
  final bool isBlinking;

  const AnimatedCallTimer({
    super.key,
    required this.duration,
    this.style,
    this.isBlinking = false,
  });

  @override
  State<AnimatedCallTimer> createState() => _AnimatedCallTimerState();
}

class _AnimatedCallTimerState extends State<AnimatedCallTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _blinkController,
      curve: Curves.easeInOut,
    ));

    if (widget.isBlinking) {
      _blinkController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedCallTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBlinking != oldWidget.isBlinking) {
      if (widget.isBlinking) {
        _blinkController.repeat(reverse: true);
      } else {
        _blinkController.stop();
        _blinkController.reset();
      }
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isBlinking) {
      return AnimatedBuilder(
        animation: _blinkAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _blinkAnimation.value,
            child: CallTimer(
              duration: widget.duration,
              style: widget.style,
            ),
          );
        },
      );
    }

    return CallTimer(
      duration: widget.duration,
      style: widget.style,
    );
  }
}

class CallTimerWithStatus extends StatelessWidget {
  final Duration duration;
  final String status;
  final TextStyle? timerStyle;
  final TextStyle? statusStyle;

  const CallTimerWithStatus({
    super.key,
    required this.duration,
    required this.status,
    this.timerStyle,
    this.statusStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          status,
          style: statusStyle ?? TextStyle(
            fontSize: 18,
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        CallTimer(
          duration: duration,
          style: timerStyle ?? const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
