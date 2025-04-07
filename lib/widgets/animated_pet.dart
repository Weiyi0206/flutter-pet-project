import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import 'dart:async'; // Import for Timer

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
  State<AnimatedPet> createState() => AnimatedPetState();
}

class AnimatedPetState extends State<AnimatedPet> with TickerProviderStateMixin {
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
  
  // --- Add public methods to trigger animations ---
  void triggerPlay() {
    _triggerPlayAnimation();
  }

  void triggerGroom() {
    _triggerGroomAnimation();
  }

  void triggerPet() {
    _triggerPetAnimation();
  }

  void triggerFeed() {
    _triggerFeedAnimation();
  }
  // --- End added methods ---
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double idleBobAmount = _calculateIdleBobAmount();
    final Duration idleBobDuration = _calculateIdleBobDuration();

    return GestureDetector(
      onTap: widget.onPet,
      onDoubleTap: widget.onFeed,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _getStatusColor().withOpacity(0.25),
              blurRadius: widget.size * 0.15,
              spreadRadius: widget.size * 0.01,
            ),
          ],
        ),
        child: _buildPet(idleBobAmount, idleBobDuration),
      ),
    );
  }

  double _calculateIdleBobAmount() {
    int happiness = widget.petData?['happiness'] as int? ?? 80;
    if (happiness >= 90) return -7.0;
    if (happiness >= 75) return -5.0;
    if (happiness >= 40) return -3.5;
    return -2.0;
  }

  Duration _calculateIdleBobDuration() {
    int happiness = widget.petData?['happiness'] as int? ?? 80;
    if (happiness >= 90) return 550.ms;
    if (happiness >= 75) return 650.ms;
    if (happiness >= 40) return 800.ms;
    return 1100.ms;
  }

  Widget _buildPet(double idleBobAmount, Duration idleBobDuration) {
    final double effectiveSize = widget.size;
    final bodySize = effectiveSize * 0.55;
    final earSize = effectiveSize * 0.18;
    final pawSize = effectiveSize * 0.13;
    final eyeSize = effectiveSize * 0.12;
    
    final bool isIdle = !_isBeingPet && !_isBeingFed && !_isPlaying && !_isBeingGroomed;

    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: const Alignment(-0.45, -0.65),
          child: _buildEar(isLeft: true, size: earSize, isIdle: isIdle, idleBobDuration: idleBobDuration),
        ),
        Align(
          alignment: const Alignment(0.45, -0.65),
          child: _buildEar(isLeft: false, size: earSize, isIdle: isIdle, idleBobDuration: idleBobDuration),
        ),
        
        Align(
          alignment: const Alignment(-0.35, 0.7),
          child: _buildPaw(isLeft: true, size: pawSize, isIdle: isIdle, idleBobDuration: idleBobDuration),
        ),
        Align(
          alignment: const Alignment(0.35, 0.7),
          child: _buildPaw(isLeft: false, size: pawSize, isIdle: isIdle, idleBobDuration: idleBobDuration),
        ),
        
        _buildBody(bodySize, isIdle: isIdle, idleBobAmount: idleBobAmount, idleBobDuration: idleBobDuration),
        
        Align(
          alignment: const Alignment(-0.4, 0.25),
          child: _buildCheek(size: effectiveSize * 0.1),
        ),
        Align(
          alignment: const Alignment(0.4, 0.25),
          child: _buildCheek(size: effectiveSize * 0.1),
        ),
        
        Align(
          alignment: const Alignment(-0.3, -0.15),
          child: _buildEye(isLeft: true, size: eyeSize, isIdle: isIdle),
        ),
        Align(
          alignment: const Alignment(0.3, -0.15),
          child: _buildEye(isLeft: false, size: eyeSize, isIdle: isIdle),
        ),
        
        Align(
          alignment: const Alignment(0.0, 0.3),
          child: _buildMouth(bodySize * 0.35),
        ),
        
        if (_isBeingPet) Align(alignment: const Alignment(0.6, -0.7), child: _buildPettingEffect()),
        if (_isBeingFed) Align(alignment: const Alignment(-0.6, 0.7), child: _buildFeedingEffect()),
        if (_isPlaying) Align(alignment: const Alignment(-0.7, -0.6), child: _buildPlayingEffect()),
        if (_isBeingGroomed) Align(alignment: Alignment.center, child: _buildGroomingEffect()),
        
        if (_isHungry && isIdle) Align(alignment: const Alignment(0.8, 0.8), child: _buildHungerIndicator()),
        if (_needsAffection && isIdle) Align(alignment: const Alignment(0.8, -0.8), child: _buildAffectionIndicator()),
        if (_isUnhappy && isIdle) Align(alignment: const Alignment(0.0, -1.15), child: _buildUnhappyIndicator()),
      ],
    );
  }
  
  Widget _buildBody(double size, {required bool isIdle, required double idleBobAmount, required Duration idleBobDuration}) {
    final baseWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.0, -0.2),
          radius: 0.8,
          colors: [
            _getStatusColor().lighter(10),
            _getStatusColor(),
            _getStatusColor().darker(5),
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: _getStatusColor().darker(10), width: 1.0),
      ),
    );
    
    if (_isBeingPet) {
      return baseWidget.animate()
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.12, 1.12),
          duration: 350.ms,
          curve: Curves.easeOutBack,
        ).shake(
           hz: 5,
           duration: 600.ms,
           offset: const Offset(0.5, 0)
        ).then(delay: 200.ms)
        .scale(
          end: const Offset(1.0, 1.0),
          duration: 400.ms,
          curve: Curves.easeOut,
        );
    } else if (_isBeingFed) {
      return baseWidget.animate()
          .moveY(begin: 0, end: -8, duration: 150.ms, curve: Curves.easeOut)
          .then()
          .moveY(end: 0, duration: 250.ms, curve: Curves.bounceOut);
    } else if (_isPlaying) {
      return baseWidget.animate()
        .moveY(
          begin: 0,
          end: -18,
          duration: 300.ms,
          curve: Curves.easeOut,
        )
        .then()
        .moveY(
          end: 0,
          duration: 450.ms,
          curve: Curves.bounceOut,
        )
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.05, 0.95),
          duration: 300.ms,
        )
        .then()
        .scale(
          end: const Offset(1.0, 1.0),
          duration: 450.ms,
          curve: Curves.easeOut,
        )
        .rotate(
          begin: 0,
          end: 0.05,
          duration: 400.ms,
        )
        .then()
        .rotate(
          end: 0,
          duration: 400.ms,
        );
    } else if (_isBeingGroomed) {
      return baseWidget.animate()
        .shake(
          hz: 7,
          offset: const Offset(1.5, 0),
          duration: 600.ms,
        )
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.05, 1.05),
          duration: 200.ms,
          curve: Curves.easeOut,
        )
        .then(
          delay: 400.ms,
        )
        .scale(
          end: const Offset(1.0, 1.0),
          duration: 300.ms,
        );
    } else if (isIdle) {
      return baseWidget.animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(
          begin: 0,
          end: idleBobAmount,
          duration: idleBobDuration,
          curve: Curves.easeInOut,
        );
    }
    return baseWidget;
  }
  
  Widget _buildEar({required bool isLeft, required double size, required bool isIdle, required Duration idleBobDuration}) {
    final baseWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getStatusColor().lighter(5).withOpacity(0.85),
        borderRadius: BorderRadius.circular(size * 0.5),
      ),
    );
    
    if (_isBeingPet) {
      return baseWidget.animate()
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.2, 1.2),
          duration: 300.ms,
          curve: Curves.easeOutBack,
        )
        .moveY(
          begin: 0,
          end: -5,
          duration: 300.ms,
        )
        .then(
          delay: 500.ms,
        )
        .moveY(
          end: 0,
          duration: 400.ms,
        )
        .scale(
          end: const Offset(1.0, 1.0),
          duration: 400.ms,
        );
    } else if (_isPlaying) {
      return baseWidget.animate()
        .rotate(
          begin: isLeft ? -0.2 : 0.2,
          end: isLeft ? 0.2 : -0.2,
          duration: 250.ms,
          curve: Curves.easeOut,
        )
        .then()
        .rotate(
          end: isLeft ? -0.2 : 0.2,
          duration: 350.ms,
          curve: Curves.elasticOut,
        );
    } else if (isIdle) {
      return baseWidget.animate(onPlay: (c) => c.repeat(reverse: true))
        .rotate(
          begin: isLeft ? -0.04 : 0.04,
          end: isLeft ? 0.04 : -0.04,
          duration: idleBobDuration * 1.1,
          curve: Curves.easeInOut,
        )
        .then(
          delay: 2.5.seconds,
        )
        .shake(
          hz: 6,
          duration: 200.ms,
          offset: Offset(isLeft ? -0.1 : 0.1, 0.05),
        );
    }
    return baseWidget;
  }
  
  Widget _buildEye({required bool isLeft, required double size, required bool isIdle}) {
    Color pupilColor = const Color(0xFF3A3A3A);
    double pupilSize = size * 0.7;
    double eyeHeightFactor = 1.0;
    double highlightSize = pupilSize * 0.25;
    Alignment highlightAlignment = isLeft ? const Alignment(-0.3, -0.4) : const Alignment(0.3, -0.4);

    if (_isUnhappy) {
      pupilSize = size * 0.6;
      eyeHeightFactor = 0.60;
      highlightSize = pupilSize * 0.2;
    } else if (widget.status == 'Happy' || widget.status == 'Ecstatic') {
      pupilSize = size * 0.75;
    }
    
    if (_isBeingPet) {
      eyeHeightFactor = 0.1;
    } else if (_isBeingFed) {
      pupilSize = size * 0.85;
    }
    
    Widget eyeContent = Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: pupilSize,
          height: pupilSize,
          decoration: BoxDecoration(
            color: pupilColor,
            shape: BoxShape.circle,
          ),
        ),
        Positioned(
          top: size * 0.15,
          left: isLeft ? size * 0.2 : null,
          right: isLeft ? null : size * 0.2,
          child: Container(
            width: highlightSize,
            height: highlightSize,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
            ),
          ).animate(delay: 500.ms)
            .scale(begin: const Offset(0,0), end: const Offset(1,1), duration: 200.ms)
            .fade(duration: 200.ms),
        ),
      ],
    );

    Widget baseWidget = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: _getStatusColor().darker(15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1)
          )
        ]
      ),
      child: Transform.scale(
        scaleY: eyeHeightFactor,
        child: eyeContent,
      )
    );

    if (_isBeingPet) {
      return baseWidget.animate()
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.0, 0.1),
          duration: 300.ms,
          curve: Curves.easeOut,
        )
        .then(
          delay: 500.ms,
        )
        .scale(
          end: const Offset(1.0, 1.0),
          duration: 300.ms,
        );
    } else if (_isBeingFed) {
      return baseWidget.animate()
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.2, 1.2),
          duration: 200.ms,
          curve: Curves.easeOutBack,
        )
        .then(
          delay: 400.ms,
        )
        .scale(
          end: const Offset(1.0, 1.0),
          duration: 200.ms,
        );
    } else if (_isPlaying) {
      return baseWidget.animate()
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.1, 1.2),
          duration: 250.ms,
          curve: Curves.easeOut,
        )
        .then()
        .scale(
          end: const Offset(1.0, 1.0),
          duration: 350.ms,
          curve: Curves.elasticOut,
        );
    } else if (isIdle) {
      return baseWidget.animate(onPlay: (c) => c.repeat())
         // 1. Start with the delay (representing the open state duration)
         .then(delay: math.Random().nextInt(3500).toDouble().ms + 1500.ms)
         // 2. Close the eye
        .scale(
          begin: const Offset(1.0, 1.0), // Ensure start is open
          end: const Offset(1.0, 0.05), // Close
          duration: 200.ms, // Closing duration
          curve: Curves.easeOut,
        )
         // 3. Delay while closed
        .then(delay: 150.ms)
         // 4. Open the eye
        .scale(
          // Start from closed state is implied by the chain
          end: const Offset(1.0, 1.0), // Open
          duration: 250.ms, // Opening duration
          curve: Curves.easeIn,
        );
    }
    return baseWidget;
  }
  
  Widget _buildMouth(double width) {
    final int happiness = widget.petData?['happiness'] as int? ?? 60;

    if (_isBeingFed) {
       // Keep feeding mouth animation
       return Container(
         width: width * 0.6,
         height: width * 0.4,
         decoration: BoxDecoration(
           color: Colors.pink.shade200,
           borderRadius: BorderRadius.circular(width * 0.2),
           border: Border.all(color: _getStatusColor().darker(30), width: 1.0),
         ),
       ).animate(onPlay: (c)=> c.repeat(reverse: true, count: 2))
         .scaleXY(begin: 1.0, end: 1.5, duration: 150.ms, curve: Curves.easeOut)
         .then(delay: 50.ms)
         .scaleXY(end: 0.8, duration: 150.ms, curve: Curves.easeIn);
    }
    else if (happiness >= 100) {
       return CustomPaint(
         size: Size(width * 1.2, width * 0.5),
         painter: _MouthPainter(
           isHappy: true,
           mouthWidth: width * 1.2,
           color: _getStatusColor().darker(30),
           curvature: 1.8,
         ),
       );
    } else if (happiness == 0) {
       // Min Happiness: Big Frown
       return CustomPaint(
         size: Size(width * 0.9, width * 0.4), // Standard frown size
         painter: _MouthPainter(
           isHappy: false,
           mouthWidth: width * 0.9,
           color: _getStatusColor().darker(40),
           curvature: 1.8, // Extra curvy frown
         ),
       );
    }
    // --- END NEW CHECKS ---
    else if (_isUnhappy) { // Use the existing getter for sad range (1-40)
      // Standard Frown
      return CustomPaint(
        size: Size(width, width * 0.3),
        painter: _MouthPainter(isHappy: false, mouthWidth: width, color: _getStatusColor().darker(40), curvature: 1.0),
      );
    } else if (widget.status == 'Happy' || widget.status == 'Ecstatic' || _isBeingPet) { // Includes pet interaction smile
       // Standard Smile (covers 75-99 and Petting)
      return CustomPaint(
        size: Size(width * 1.1, width * 0.4),
        painter: _MouthPainter(isHappy: true, mouthWidth: width * 1.1, color: _getStatusColor().darker(30), curvature: 1.2),
      );
    } else {
      // Neutral mouth (covers 41-74 approx)
      return Container(
        width: width * 0.4,
        height: 1.5,
        decoration: BoxDecoration(
          color: _getStatusColor().darker(40),
          borderRadius: BorderRadius.circular(1),
        ),
      );
    }
  }
  
  Widget _buildPaw({required bool isLeft, required double size, required bool isIdle, required Duration idleBobDuration}) {
    final baseWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getStatusColor().lighter(5).withOpacity(0.9),
        shape: BoxShape.circle,
      ),
    );
    
    if (_isPlaying) {
      return baseWidget.animate(onPlay: (controller) => controller.repeat(reverse: true))
        .move(
          begin: Offset(isLeft ? -8 : 8, 0),
          end: Offset(isLeft ? 6 : -6, -5),
          duration: 300.ms,
          curve: Curves.easeOut,
        )
        .rotate(
          begin: 0,
          end: isLeft ? -0.15 : 0.15,
          duration: 300.ms,
        )
        .then()
        .move(
          end: Offset(isLeft ? -8 : 8, 0),
          duration: 400.ms,
          curve: Curves.elasticOut,
        )
        .rotate(
          end: 0,
          duration: 400.ms,
        );
    } else if (isIdle) {
      return baseWidget.animate(onPlay: (c) => c.repeat(reverse: true))
        .moveX(
          begin: isLeft ? -2.0 : 2.0,
          end: isLeft ? 2.0 : -2.0,
          duration: idleBobDuration,
          curve: Curves.easeInOut,
        );
    }
    return baseWidget;
  }
  
  Widget _buildPettingEffect() {
    return Stack(
      children: List.generate(3, (index) => Positioned(
        child: Icon(
          Icons.favorite,
          color: Colors.pink.withOpacity(0.8),
          size: widget.size * (0.25 - index * 0.05),
        ).animate(delay: (index * 80).ms)
          .scale(
            begin: const Offset(0.3, 0.3),
            end: const Offset(1.5, 1.5),
            duration: 600.ms,
            curve: Curves.elasticOut,
          )
          .moveY(
            begin: 0,
            end: -30,
            duration: 800.ms,
            curve: Curves.easeOut,
          )
          .then(delay: 100.ms)
          .fade(
            begin: 1,
            end: 0,
            duration: 300.ms,
          ),
      )),
    );
  }
  
  Widget _buildFeedingEffect() {
    return Positioned(
      bottom: widget.size * 0.3,
      left: widget.size * 0.35,
      right: widget.size * 0.35,
      child: Icon(
        Icons.bakery_dining,
        color: Colors.brown.withOpacity(0.9),
        size: widget.size * 0.22,
      ).animate()
        .fadeIn(duration: 150.ms)
        .moveY(begin: 15, end: 0, duration: 300.ms, curve: Curves.easeOut)
        .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0), duration: 300.ms)
        .then(delay: 350.ms)
        .scale(end: const Offset(0.0, 0.0), duration: 200.ms, curve: Curves.easeIn)
        .fadeOut(duration: 150.ms),
    );
  }
  
  Widget _buildPlayingEffect() {
    return Stack(
      children: List.generate(5, (index) => Positioned(
        child: Icon(
          Icons.sports_esports,
          color: Colors.blue.withOpacity(0.7),
          size: widget.size * (0.12 + math.Random().nextDouble() * 0.12),
        ).animate(delay: (index * 100).ms)
          .scale(
            begin: const Offset(0.3, 0.3),
            end: const Offset(1.3, 1.3),
            duration: 500.ms,
            curve: Curves.elasticOut,
          )
          .move(
            begin: Offset.zero,
            end: Offset(math.Random().nextDouble() * 20 - 10, -15),
            duration: 700.ms,
          )
          .then(
            delay: 200.ms,
          )
          .fade(
            end: 0,
            duration: 300.ms,
          ),
      )),
    );
  }
  
  Widget _buildGroomingEffect() {
    return Stack(
      children: List.generate(7, (index) => Positioned.fill(
        child: Align(
          alignment: Alignment.center,
          child: Icon(
            Icons.star,
            color: Colors.yellow.withOpacity(0.7),
            size: widget.size * (0.12 + math.Random().nextDouble() * 0.15),
          ).animate(delay: (index * 80).ms)
            .scale(
              begin: const Offset(0.0, 0.0),
              end: const Offset(1.0, 1.0),
              duration: 350.ms,
              curve: Curves.elasticOut,
            )
            .then(
              delay: 250.ms,
            )
            .scale(
              end: const Offset(0.0, 0.0),
              duration: 350.ms,
            )
            .fade(
              end: 0,
              duration: 350.ms,
            ),
        ),
      )),
    );
  }
  
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

  Widget _buildCheek({required double size}) {
    return Container(
      width: size,
      height: size * 0.6,
      decoration: BoxDecoration(
        color: Colors.pink.shade100.withOpacity(0.5),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
    ).animate(onPlay: (c)=> c.repeat(reverse: true), delay: 1.seconds)
      .fade(begin: 0.4, end: 0.6, duration: 1500.ms);
  }

  Color _getStatusColor() {
    int happiness = widget.petData?['happiness'] as int? ?? 80;

    if (happiness >= 90) return const Color(0xFFFFF59D);
    if (happiness >= 75) return const Color(0xFFA5D6A7);
    if (happiness >= 60) return const Color(0xFF90CAF9);
    if (happiness >= 40) return const Color(0xFFB3E5FC);
    if (happiness >= 25) return const Color(0xFFCE93D8);
    return const Color(0xFFBDBDBD);
  }
  
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

  Color lighter(int percent) {
    assert(1 <= percent && percent <= 100);
    final double value = percent / 100;
    int red = (this.red + (255 - this.red) * value).round().clamp(0, 255);
    int green = (this.green + (255 - this.green) * value).round().clamp(0, 255);
    int blue = (this.blue + (255 - this.blue) * value).round().clamp(0, 255);
    return Color.fromARGB(alpha, red, green, blue);
  }
}

class _MouthPainter extends CustomPainter {
  final bool isHappy;
  final double mouthWidth;
  final Color color;
  final double curvature;
  final double strokeWidth = 1.5;
  
  _MouthPainter({
    required this.isHappy,
    required this.mouthWidth, 
    required this.color,
    required this.curvature,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final double rectWidth = size.width;
    final double rectHeight = math.max(size.height * 0.5, size.height * curvature * 0.8);

    final Rect rect;
    if (isHappy) {
      rect = Rect.fromCenter(
        center: Offset(size.width / 2, rectHeight * 0.05),
        width: rectWidth,
        height: rectHeight,
      );
    } else {
      rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height - rectHeight * 0.5),
        width: rectWidth,
        height: rectHeight,
      );
    }

    final double startAngle;
    final double sweepAngle;

    if (isHappy) {
      startAngle = math.pi * 0.1;
      sweepAngle = math.pi * 0.8;
    } else {
      startAngle = math.pi * -0.1;
      sweepAngle = math.pi * -0.8;
    }

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }
  
  @override
  bool shouldRepaint(_MouthPainter oldDelegate) => 
    oldDelegate.isHappy != isHappy || 
    oldDelegate.mouthWidth != mouthWidth ||
    oldDelegate.color != color ||
    oldDelegate.curvature != curvature;
} 