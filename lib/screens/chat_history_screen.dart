import 'package:flutter/material.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:collection/collection.dart'; // For groupBy

import '../main.dart'; // Import ChatMessage definition (if needed, or move ChatMessage to own file)
import '../models/pet_model.dart'; // Import PetModel
import 'conversation_detail_screen.dart'; // Import the new screen we will create

class ChatHistoryScreen extends StatefulWidget {
  final String userId; // Receive userId

  const ChatHistoryScreen({super.key, required this.userId});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final PetModel _petModel = PetModel(); // Create instance to use methods
  // Store the results after loading to pass to the detail screen
  Map<String, List<ChatMessage>> _loadedConversations = {};
  late Future<void> _loadHistoryFuture; // Future to track loading state

  @override
  void initState() {
    super.initState();
    _loadHistoryFuture = _loadAndGroupHistory();
  }

  // Fetch all dates, then fetch messages for each date, store in state
  Future<void> _loadAndGroupHistory() async {
    Map<String, List<ChatMessage>> groupedMessages = {};
    // Reset state in case of reload
    _loadedConversations = {};

    try {
      final List<String> dateStrings = await _petModel.getChatHistoryDates();
      if (!mounted) return;

      for (String dateStr in dateStrings) {
        final List<Map<String, dynamic>> messagesData = await _petModel.loadChatHistoryForDate(dateStr);
        if (!mounted) return;

        final List<ChatMessage> messages = messagesData
            .map((data) => ChatMessage.fromMap(data))
            .toList();
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        groupedMessages[dateStr] = messages;
      }
      // Store the loaded data in the state variable
      _loadedConversations = groupedMessages;
      print("Loaded history for dates: ${_loadedConversations.keys.join(', ')}");

    } catch (e) {
      print("Error in _loadAndGroupHistory: $e");
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading chat history: $e'), backgroundColor: Colors.red)
         );
      }
      // Re-throw the error so the FutureBuilder can catch it
      rethrow;
    }
  }

  // Helper to format date string for display
  String _formatDisplayDate(String dateString) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      if (date == today) {
        return 'Today';
      } else if (date == yesterday) {
        return 'Yesterday';
      } else {
        // Format as "Month day, Year" e.g., "October 27, 2023"
        return DateFormat('MMMM d, yyyy').format(date);
      }
    } catch (_) {
      return dateString; // Fallback to raw string if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<void>( // Future is now void, we use the state variable _loadedConversations
        future: _loadHistoryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            // Error is handled in _loadAndGroupHistory with Snackbar, show simple message here
            return Center(child: Text('Error loading history. Please try again.'));
          }

          // Check the state variable directly
          if (_loadedConversations.isEmpty) {
            return const Center(child: Text('No chat history found.'));
          }

          // Get sorted date keys from the loaded data
          final dateKeys = _loadedConversations.keys.toList();

          // Build a list of tappable date entries
          return ListView.separated(
            itemCount: dateKeys.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final dateString = dateKeys[index];
              final displayDate = _formatDisplayDate(dateString);
              final conversationPreview = _loadedConversations[dateString]!.isNotEmpty
                  ? _loadedConversations[dateString]!.first.text // Show first message as preview
                  : 'No messages'; // Or some placeholder

              return ListTile(
                title: Text(displayDate, style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  conversationPreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to the detail screen, passing the messages for the selected date
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConversationDetailScreen(
                        dateString: displayDate, // Pass formatted date for AppBar title
                        messages: _loadedConversations[dateString]!, // Pass the list of messages
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
