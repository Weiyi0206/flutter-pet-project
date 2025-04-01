import 'package:flutter/material.dart';

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  final List<Map<String, String>> tests = const [
    {
      'title': 'Anxiety Assessment',
      'description':
          'A quick test to check your current anxiety levels and get personalized recommendations.',
    },
    {
      'title': 'Mood Tracker',
      'description':
          'Track your daily mood patterns and identify triggers that affect your emotional well-being.',
    },
    {
      'title': 'Stress Level Check',
      'description':
          'Evaluate your stress levels and learn stress management techniques.',
    },
    {
      'title': 'Sleep Quality Quiz',
      'description':
          'Assess your sleep patterns and get tips for better sleep hygiene.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mental Health Tests'),
        backgroundColor: Colors.orange.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: tests.length,
          itemBuilder: (context, index) {
            return Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tests[index]['title']!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        tests[index]['description']!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: Navigate to specific test
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                        child: const Text('Take Test'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
