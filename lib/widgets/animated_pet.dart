import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;

class AnimatedPet extends StatefulWidget {
  final String status;
  final VoidCallback onPet;
  final VoidCallback onFeed;
  final double size;
  final Map<String, dynamic>? petData; // Add pet data to control animations based on metrics
  
  const AnimatedPet({
    Key? key,
    required this.status,
    required this.onPet,
    required this.onFeed,
    this.size = 200,
    this.petData,
  }) : super(key: key);

  @override
  State<AnimatedPet> createState() => _AnimatedPetState();
}

class _AnimatedPetState extends State<AnimatedPet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isAnimating = false;
  
  // Animation states
  bool _isBeingPet = false;
  bool _isBeingFed = false;
  bool _isPlaying = false;
  bool _isBeingGroomed = false;
  
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
      _isBeingPet = false;
      _isBeingFed = false;
      _isPlaying = false;
      _isBeingGroomed = false;
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
    setState(() {
      _isBeingFed = true;
    });
    
    // Show feeding animation then return to idle
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isBeingFed = false;
        });
        _startIdleAnimation();
      }
    });
  }
  
  void _triggerPetAnimation() {
    _stopAnimation();
    setState(() {
      _isBeingPet = true;
    });
    
    // Show petting animation then return to idle
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isBeingPet = false;
        });
        _startIdleAnimation();
      }
    });
  }
  
  void _triggerPlayAnimation() {
    _stopAnimation();
    setState(() {
      _isPlaying = true;
    });
    
    // Show play animation then return to idle
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
        _startIdleAnimation();
      }
    });
  }
  
  void _triggerGroomAnimation() {
    _stopAnimation();
    setState(() {
      _isBeingGroomed = true;
    });
    
    // Show grooming animation then return to idle
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _isBeingGroomed = false;
        });
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
      onDoubleTap: () {
        widget.onFeed();
        _triggerFeedAnimation();
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
    final eyeSize = widget.size * 0.08;
    
    return Stack(
      children: [
        // Body - main pet body
        Center(
          child: _buildBody(bodySize),
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
        
        // Eyes
        Positioned(
          top: widget.size * 0.33,
          left: widget.size * 0.35,
          child: _buildEye(isLeft: true, size: eyeSize),
        ),
        Positioned(
          top: widget.size * 0.33,
          right: widget.size * 0.35,
          child: _buildEye(isLeft: false, size: eyeSize),
        ),
        
        // Mouth - express mood
        Positioned(
          bottom: widget.size * 0.33,
          left: 0,
          right: 0,
          child: _buildMouth(bodySize * 0.4),
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
        
        // Animation effects
        if (_isBeingPet) _buildPettingEffect(),
        if (_isBeingFed) _buildFeedingEffect(),
        if (_isPlaying) _buildPlayingEffect(),
        if (_isBeingGroomed) _buildGroomingEffect(),
        
        // Status indicators
        if (_isHungry) _buildHungerIndicator(),
        if (_needsAffection) _buildAffectionIndicator(),
        if (_isUnhappy) _buildUnhappyIndicator(),
      ],
    );
  }
  
  Widget _buildBody(double size) {
    final baseWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getStatusColor(),
        shape: BoxShape.circle,
      ),
    );
    
    if (_isBeingPet) {
      // Subtle pulsing when being pet
      return baseWidget.animate()
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.07, 1.07),
          duration: 400.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          begin: const Offset(1.07, 1.07),
          end: const Offset(1.0, 1.0),
          duration: 400.ms,
          curve: Curves.easeInOut,
        );
    } else if (_isBeingFed) {
      // Wiggle when being fed
      return baseWidget.animate()
        .rotate(
          begin: -0.05,
          end: 0.05,
          duration: 200.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .rotate(
          begin: 0.05,
          end: -0.05,
          duration: 200.ms, 
          curve: Curves.easeInOut,
        )
        .then()
        .rotate(
          begin: -0.05,
          end: 0.0,
          duration: 200.ms,
          curve: Curves.easeInOut,
        );
    } else if (_isPlaying) {
      // Bounce when playing
      return baseWidget.animate()
        .moveY(
          begin: 0,
          end: -10,
          duration: 300.ms,
        )
        .then()
        .moveY(
          begin: -10,
          end: 0,
          duration: 300.ms,
        )
        .then()
        .moveY(
          begin: 0,
          end: -5,
          duration: 200.ms,
        )
        .then()
        .moveY(
          begin: -5,
          end: 0,
          duration: 200.ms,
        );
    } else if (_isBeingGroomed) {
      // Sparkle effect when groomed
      return Stack(
        alignment: Alignment.center,
        children: [
          baseWidget,
          Container(
            width: size * 1.1,
            height: size * 1.1,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 2,
              ),
            ),
          ).animate().fade(
            begin: 0,
            end: 1,
            duration: 300.ms,
          ).then().fade(
            begin: 1,
            end: 0,
            duration: 400.ms,
          ),
        ],
      );
    } else {
      // Idle animation - gentle bobbing
      return baseWidget.animate(onPlay: (controller) => controller.repeat())
        .moveY(
          begin: 0,
          end: -3,
          duration: 800.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .moveY(
          begin: -3,
          end: 0,
          duration: 800.ms,
          curve: Curves.easeInOut,
        );
    }
  }
  
  Widget _buildEar({required bool isLeft, required double size}) {
    final baseWidget = Container(
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
    );
    
    if (_isBeingPet) {
      // Ears perk up when pet
      return baseWidget.animate()
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.1, 1.1),
          duration: 400.ms,
        )
        .moveY(begin: 0, end: -2);
    } else if (_isPlaying) {
      // Ears flap when playing
      return baseWidget.animate()
        .rotate(
          begin: isLeft ? -0.1 : 0.1,
          end: isLeft ? 0.1 : -0.1,
          duration: 300.ms,
        )
        .then()
        .rotate(
          begin: isLeft ? 0.1 : -0.1,
          end: isLeft ? -0.1 : 0.1,
          duration: 300.ms,
        );
    } else {
      // Default idle ear animation
      return baseWidget
        .animate(controller: _controller)
        .rotate(
          begin: isLeft ? -0.05 : 0.05,
          end: isLeft ? 0.05 : -0.05,
          curve: Curves.easeInOut,
        );
    }
  }
  
  Widget _buildEye({required bool isLeft, required double size}) {
    // Eye color and shape based on mood
    Color pupilColor = Colors.black;
    double pupilSize = size * 0.6;
    
    if (_isUnhappy) {
      // Sad eyes
      pupilSize = size * 0.5;
    } else if (widget.status == 'Happy' || widget.status == 'Ecstatic') {
      // Happy eyes
      pupilSize = size * 0.65;
    }
    
    final baseWidget = Container(
      width: size,
      height: _isUnhappy ? size * 0.7 : size,  // Squint eyes when unhappy
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: _getStatusColor().darker(20),
          width: 1,
        ),
      ),
      child: Center(
        child: Container(
          width: pupilSize,
          height: pupilSize,
          decoration: BoxDecoration(
            color: pupilColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
    
    if (_isBeingPet) {
      // Eyes close slightly when pet (happy squint)
      return baseWidget.animate()
        .custom(
          builder: (context, value, child) {
            return Container(
              width: size,
              height: size * (1 - value * 0.3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(size * 0.5),
                  bottom: Radius.circular(size * 0.5),
                ),
                border: Border.all(
                  color: _getStatusColor().darker(20),
                  width: 1,
                ),
              ),
              child: Center(
                child: Container(
                  width: pupilSize,
                  height: pupilSize * (1 - value * 0.5),
                  decoration: BoxDecoration(
                    color: pupilColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(pupilSize * 0.5),
                      bottom: Radius.circular(pupilSize * 0.5),
                    ),
                  ),
                ),
              ),
            );
          },
          begin: 0,
          end: 0.7,
          duration: 400.ms,
        );
    } else if (_isBeingFed) {
      // Eyes widen when fed
      return baseWidget.animate()
        .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.15, 1.15))
        .then()
        .scale(begin: const Offset(1.15, 1.15), end: const Offset(1.0, 1.0));
    } else if (_isPlaying) {
      // Eyes bounce when playing
      return baseWidget.animate()
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.1, 1.1),
          duration: 300.ms,
        )
        .then()
        .scale(
          begin: const Offset(1.1, 1.1),
          end: const Offset(1.0, 1.0),
          duration: 300.ms,
        );
    } else {
      // Default idle eye animation - slight blinking occasionally
      return baseWidget;
    }
  }
  
  Widget _buildMouth(double width) {
    // Mouth shape based on mood
    if (_isBeingFed) {
      // Open mouth when feeding
      return Container(
        width: width,
        height: width * 0.6,
        decoration: BoxDecoration(
          color: Colors.red.shade300,
          borderRadius: BorderRadius.circular(width * 0.3),
        ),
        child: Center(
          child: Container(
            width: width * 0.6,
            height: width * 0.3,
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(width * 0.15),
            ),
          ),
        ),
      );
    } else if (_isUnhappy) {
      // Sad mouth - upside down curve
      return CustomPaint(
        size: Size(width, width * 0.3),
        painter: _MouthPainter(
          isHappy: false,
          mouthWidth: width,
          color: _getStatusColor().darker(30),
        ),
      );
    } else if (widget.status == 'Happy' || widget.status == 'Ecstatic' || _isBeingPet) {
      // Happy mouth - curve
      return CustomPaint(
        size: Size(width, width * 0.3),
        painter: _MouthPainter(
          isHappy: true,
          mouthWidth: width,
          color: _getStatusColor().darker(30),
        ),
      );
    } else {
      // Neutral mouth - straight line
      return Container(
        width: width * 0.6,
        height: 2,
        color: _getStatusColor().darker(30),
      );
    }
  }
  
  Widget _buildPaw({required bool isLeft, required double size}) {
    final baseWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.8),
        shape: BoxShape.circle,
      ),
    );
    
    if (_isPlaying) {
      // Paws move more when playing
      return baseWidget.animate(onPlay: (controller) => controller.repeat())
        .moveX(
          begin: isLeft ? -5 : 5,
          end: isLeft ? 5 : -5,
          duration: 300.ms,
        )
        .then()
        .moveX(
          begin: isLeft ? 5 : -5,
          end: isLeft ? -5 : 5,
          duration: 300.ms,
        );
    } else {
      // Default idle paw animation
      return baseWidget
        .animate(controller: _controller)
        .moveX(
          begin: isLeft ? -2 : 2,
          end: isLeft ? 2 : -2,
          curve: Curves.easeInOut,
        );
    }
  }
  
  // Animation effects
  Widget _buildPettingEffect() {
    return Positioned(
      top: widget.size * 0.15,
      right: widget.size * 0.15,
      child: Icon(
        Icons.favorite,
        color: Colors.pink.withOpacity(0.7),
        size: widget.size * 0.2,
      ).animate()
        .fade(begin: 0, end: 1, duration: 200.ms)
        .then()
        .fade(begin: 1, end: 0, delay: 400.ms, duration: 200.ms)
        .moveY(begin: 0, end: -15, duration: 600.ms)
        .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.2, 1.2)),
    );
  }
  
  Widget _buildFeedingEffect() {
    return Positioned(
      bottom: widget.size * 0.25,
      left: widget.size * 0.2,
      child: Icon(
        Icons.restaurant,
        color: Colors.orange.withOpacity(0.7),
        size: widget.size * 0.2,
      ).animate()
        .fade(begin: 0, end: 1, duration: 200.ms)
        .then()
        .fade(begin: 1, end: 0, delay: 400.ms, duration: 200.ms)
        .moveY(begin: 0, end: -15, duration: 600.ms)
        .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.2, 1.2)),
    );
  }
  
  Widget _buildPlayingEffect() {
    return Positioned(
      top: widget.size * 0.1,
      left: widget.size * 0.2,
      child: Icon(
        Icons.sports_esports,
        color: Colors.blue.withOpacity(0.7),
        size: widget.size * 0.2,
      ).animate()
        .fade(begin: 0, end: 1, duration: 200.ms)
        .then()
        .fade(begin: 1, end: 0, delay: 400.ms, duration: 200.ms)
        .moveY(begin: 0, end: -15, duration: 600.ms)
        .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.2, 1.2)),
    );
  }
  
  Widget _buildGroomingEffect() {
    return Positioned.fill(
      child: OverflowBox(
        maxWidth: widget.size * 1.2,
        maxHeight: widget.size * 1.2,
        child: Container(
          width: widget.size * 1.2,
          height: widget.size * 1.2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withOpacity(0.7),
                Colors.white.withOpacity(0),
              ],
              stops: const [0.7, 1.0],
            ),
          ),
        ).animate()
          .fade(begin: 0, end: 1, duration: 300.ms)
          .then()
          .fade(begin: 1, end: 0, duration: 700.ms),
      ),
    );
  }
  
  // Need indicators
  Widget _buildHungerIndicator() {
    return Positioned(
      bottom: widget.size * 0.1,
      right: widget.size * 0.1,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.restaurant,
          color: Colors.orange,
          size: widget.size * 0.12,
        ),
      ).animate(onPlay: (controller) => controller.repeat())
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.15, 1.15),
          duration: 600.ms,
        )
        .then()
        .scale(
          begin: const Offset(1.15, 1.15),
          end: const Offset(1.0, 1.0),
          duration: 600.ms,
        ),
    );
  }
  
  Widget _buildAffectionIndicator() {
    return Positioned(
      top: widget.size * 0.1,
      right: widget.size * 0.1,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.pets,
          color: Colors.pink,
          size: widget.size * 0.12,
        ),
      ).animate(onPlay: (controller) => controller.repeat())
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.15, 1.15),
          duration: 600.ms,
        )
        .then()
        .scale(
          begin: const Offset(1.15, 1.15),
          end: const Offset(1.0, 1.0),
          duration: 600.ms,
        ),
    );
  }
  
  Widget _buildUnhappyIndicator() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Icon(
        Icons.cloud,
        color: Colors.grey.withOpacity(0.6),
        size: widget.size * 0.25,
      ).animate(onPlay: (controller) => controller.repeat())
        .moveY(
          begin: 0,
          end: -3,
          duration: 1200.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .moveY(
          begin: -3,
          end: 0,
          duration: 1200.ms,
          curve: Curves.easeInOut,
        ),
    );
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case 'Ecstatic':
        return Colors.green.shade300;
      case 'Happy':
        return Colors.lightGreen.shade300;
      case 'Content':
        return Colors.blue.shade300;
      case 'Neutral':
        return Colors.lightBlue.shade300;
      case 'Sad':
        return Colors.indigo.shade300;
      case 'Depressed':
        return Colors.purple.shade300;
      default:
        return Colors.blue.shade300;
    }
  }
  
  // Need detection from pet data
  bool get _isHungry => widget.petData != null && 
      widget.petData!['hunger'] != null && 
      (widget.petData!['hunger'] <= 30);
      
  bool get _needsAffection => widget.petData != null && 
      widget.petData!['affection'] != null && 
      (widget.petData!['affection'] <= 30);
      
  bool get _isUnhappy => widget.petData != null && 
      widget.petData!['happiness'] != null && 
      (widget.petData!['happiness'] <= 40);
}

// Extension to make colors darker
extension ColorExtension on Color {
  Color darker(int percent) {
    assert(1 <= percent && percent <= 100);
    final value = 1 - percent / 100;
    return Color.fromARGB(
      alpha,
      (red * value).round(),
      (green * value).round(),
      (blue * value).round(),
    );
  }
}

// Custom painter for mouth shape
class _MouthPainter extends CustomPainter {
  final bool isHappy;
  final double mouthWidth;
  final Color color;
  
  _MouthPainter({
    required this.isHappy,
    required this.mouthWidth, 
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
      
    final path = Path();
    path.moveTo(0, isHappy ? size.height : 0);
    
    path.quadraticBezierTo(
      size.width / 2,
      isHappy ? 0 : size.height,
      size.width,
      isHappy ? size.height : 0,
    );
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(_MouthPainter oldDelegate) => 
    oldDelegate.isHappy != isHappy || 
    oldDelegate.mouthWidth != mouthWidth ||
    oldDelegate.color != color;
} 