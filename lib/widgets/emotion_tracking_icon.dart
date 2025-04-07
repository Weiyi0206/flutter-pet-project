import 'package:flutter/material.dart';
import 'dart:math' as math;

class EmotionTrackingIcon extends StatefulWidget {
  final String emotion;
  final double size;
  final VoidCallback onTap;

  const EmotionTrackingIcon({
    Key? key,
    required this.emotion,
    this.size = 60.0,
    required this.onTap,
  }) : super(key: key);

  @override
  State<EmotionTrackingIcon> createState() => _EmotionTrackingIconState();
}

class _EmotionTrackingIconState extends State<EmotionTrackingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getEmotionColor() {
    switch (widget.emotion.toLowerCase()) {
      case 'happy':
        return Colors.yellow;
      case 'calm':
        return Colors.blue.shade300;
      case 'sad':
        return Colors.indigo.shade300;
      case 'angry':
        return Colors.red.shade400;
      case 'anxious':
        return Colors.purple.shade300;
      default:
        return Colors.grey.shade400; // Neutral
    }
  }

  String _getEmotionEmoji() {
    switch (widget.emotion.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'calm':
        return '😌';
      case 'sad':
        return '😔';
      case 'angry':
        return '😡';
      case 'anxious':
        return '😰';
      default:
        return '😐'; // Neutral
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Determine if this emotion should pulse or not
          final shouldPulse = widget.emotion.toLowerCase() == 'anxious' ||
                            widget.emotion.toLowerCase() == 'angry';
          
          final animation = shouldPulse ? _pulseAnimation : _scaleAnimation;
          
          return Transform.scale(
            scale: animation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _getEmotionColor().withOpacity(0.2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _getEmotionColor().withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _getEmotionEmoji(),
                  style: TextStyle(fontSize: widget.size * 0.6),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 