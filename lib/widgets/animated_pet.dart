import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedPet extends StatefulWidget {
  final String status;
  final VoidCallback onPet;
  final VoidCallback onFeed;
  final double size;
  
  const AnimatedPet({
    Key? key,
    required this.status,
    required this.onPet,
    required this.onFeed,
    this.size = 200,
  }) : super(key: key);

  @override
  State<AnimatedPet> createState() => _AnimatedPetState();
}

class _AnimatedPetState extends State<AnimatedPet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isAnimating = false;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed && _isAnimating) {
        _controller.forward();
      }
    });
    
    // Start idle animation
    _startIdleAnimation();
  }
  
  void _startIdleAnimation() {
    setState(() {
      _isAnimating = true;
    });
    _controller.forward();
  }
  
  void _stopAnimation() {
    setState(() {
      _isAnimating = false;
    });
  }
  
  void _triggerFeedAnimation() {
    _stopAnimation();
    setState(() {});
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _startIdleAnimation();
      }
    });
  }
  
  void _triggerPetAnimation() {
    _stopAnimation();
    setState(() {});
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _startIdleAnimation();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onPet();
        _triggerPetAnimation();
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _getStatusColor().withOpacity(0.3),
              blurRadius: widget.size * 0.075,
              spreadRadius: widget.size * 0.025,
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return _buildPet();
          },
        ),
      ),
    );
  }

  Widget _buildPet() {
    final bodySize = widget.size * 0.6;
    final earSize = widget.size * 0.15;
    final pawSize = widget.size * 0.125;
    
    return Stack(
      children: [
        // Body
        Center(
          child: Container(
            width: bodySize,
            height: bodySize,
            decoration: BoxDecoration(
              color: _getStatusColor(),
              shape: BoxShape.circle,
            ),
          ),
        ),
        
        // Ears
        Positioned(
          top: widget.size * 0.15,
          left: widget.size * 0.25,
          child: _buildEar(isLeft: true, size: earSize),
        ),
        Positioned(
          top: widget.size * 0.15,
          right: widget.size * 0.25,
          child: _buildEar(isLeft: false, size: earSize),
        ),
        
        // Paws
        Positioned(
          bottom: widget.size * 0.15,
          left: widget.size * 0.2,
          child: _buildPaw(isLeft: true, size: pawSize),
        ),
        Positioned(
          bottom: widget.size * 0.15,
          right: widget.size * 0.2,
          child: _buildPaw(isLeft: false, size: pawSize),
        ),
        
        // Face
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: widget.size * 0.08,
                    height: widget.size * 0.08,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: widget.size * 0.1),
                  Container(
                    width: widget.size * 0.08,
                    height: widget.size * 0.08,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              SizedBox(height: widget.size * 0.05),
              Container(
                width: widget.size * 0.2,
                height: widget.size * 0.05,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(widget.size * 0.025),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildEar({required bool isLeft, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.8),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isLeft ? size * 0.17 : size * 0.5),
          topRight: Radius.circular(isLeft ? size * 0.5 : size * 0.17),
          bottomLeft: Radius.circular(size * 0.17),
          bottomRight: Radius.circular(size * 0.17),
        ),
      ),
    )
    .animate(controller: _controller)
    .rotate(
      begin: isLeft ? -0.05 : 0.05,
      end: isLeft ? 0.05 : -0.05,
      curve: Curves.easeInOut,
    );
  }
  
  Widget _buildPaw({required bool isLeft, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.8),
        shape: BoxShape.circle,
      ),
    )
    .animate(controller: _controller)
    .moveX(
      begin: isLeft ? -2 : 2,
      end: isLeft ? 2 : -2,
      curve: Curves.easeInOut,
    );
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case 'Happy':
        return Colors.green.shade400;
      case 'Sad':
        return Colors.red.shade300;
      default:
        return Colors.blue.shade300;
    }
  }
} 