import 'package:flutter/material.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import '../main.dart';

class ChatHistoryScreen extends StatelessWidget {
  final List<ChatMessage> messages;

  const ChatHistoryScreen({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          return BubbleSpecialThree(
            text: message.text,
            color: message.isUser ? Colors.blue : Colors.grey.shade200,
            tail: true,
            isSender: message.isUser,
          );
        },
      ),
    );
  }
}
