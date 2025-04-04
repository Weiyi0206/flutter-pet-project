import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const AnimatedChatBubble({
    Key? key,
    required this.message,
    required this.isUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final fontSize = screenSize.width * 0.04;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(
          vertical: screenSize.height * 0.01,
          horizontal: screenSize.width * 0.03,
        ),
        padding: EdgeInsets.all(screenSize.width * 0.03),
        decoration: BoxDecoration(
          color: isUser ? Colors.purple.shade100 : Colors.blue.shade100,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: screenSize.width * 0.7,
        ),
        child: isUser
            ? Text(
                message,
                style: TextStyle(fontSize: fontSize),
              )
            : AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    message,
                    speed: const Duration(milliseconds: 50),
                    textStyle: TextStyle(fontSize: fontSize),
                  ),
                ],
                totalRepeatCount: 1,
                displayFullTextOnTap: true,
              ),
      ).animate().fade(duration: 300.ms).scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
            duration: 300.ms,
          ),
    );
  }
} 