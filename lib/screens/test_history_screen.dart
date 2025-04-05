import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/test.dart';

class TestHistoryScreen extends StatefulWidget {
  const TestHistoryScreen({super.key});

  @override
  State<TestHistoryScreen> createState() => _TestHistoryScreenState();
}

class _TestHistoryScreenState extends State<TestHistoryScreen> {
  IconData _getIconForTestType(String testType) {
    switch (testType) {
      case 'depression_test':
        return Icons.psychology;
      case 'anxiety_test':
        return Icons.healing;
      case 'stress_test':
        return Icons.spa;
      default:
        return Icons.psychology;
    }
  }

  Color _getColorForTestType(String testType) {
    switch (testType) {
      case 'depression_test':
        return Colors.blue;
      case 'anxiety_test':
        return Colors.green;
      case 'stress_test':
        return Colors.purple;
      default:
        return const Color(0xFF6A9BF5);
    }
  }

  Future<void> _showClearHistoryDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Clear History',
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6A9BF5),
            ),
          ),
          content: Text(
            'Are you sure you want to clear all test history?',
            style: GoogleFonts.fredoka(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.fredoka(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                TestHistory.clearHistory();
                Navigator.pop(context);
                setState(() {}); // Trigger rebuild after clearing history
                // Show confirmation snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'History cleared',
                      style: GoogleFonts.fredoka(),
                    ),
                    backgroundColor: const Color(0xFF6A9BF5),
                  ),
                );
              },
              child: Text(
                'Clear',
                style: GoogleFonts.fredoka(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = TestHistory.history;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Test History',
          style: GoogleFonts.fredoka(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6A9BF5),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFF6A9BF5)),
              onPressed: () => _showClearHistoryDialog(context),
            ),
        ],
      ),
      body:
          history.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No test history yet',
                      style: GoogleFonts.fredoka(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final test = history[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        test.testTitle,
                        style: GoogleFonts.fredoka(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            'Result: ${test.result}',
                            style: TextStyle(
                              color: _getColorForTestType(test.testType),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Score: ${test.score}/${test.maxScore}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          Text(
                            'Date: ${test.dateTime.toString().split('.')[0]}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getColorForTestType(
                            test.testType,
                          ).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIconForTestType(test.testType),
                          color: _getColorForTestType(test.testType),
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
