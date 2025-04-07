import 'package:flutter/material.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import '../main.dart'; // Import ChatMessage definition

class ConversationDetailScreen extends StatelessWidget {
  final String dateString; // To display in AppBar
  final List<ChatMessage> messages;

  const ConversationDetailScreen({
    super.key,
    required this.dateString,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Conversation: $dateString'), // Show the date
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        itemCount: messages.length,
        padding: const EdgeInsets.symmetric(vertical: 8.0), // Add some padding
        itemBuilder: (context, index) {
          final message = messages[index];
          // Use the same bubble widget as before
          return BubbleSpecialThree(
            text: message.text,
            color: message.isUser ? Theme.of(context).colorScheme.primaryContainer : Colors.grey.shade200,
            tail: true, // Consider logic for showing tail only on last message from sender
            isSender: message.isUser,
            textStyle: TextStyle(
               color: message.isUser ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.black87,
               fontSize: 16
            )
          );
        },
      ),
    );
  }
}