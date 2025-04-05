import 'package:flutter/material.dart';
import 'help_support_screen.dart';
import 'test_page.dart';
import '../models/test.dart'; // Add this import
import '../services/test_service.dart'; // Add this import

class TestResultScreen extends StatelessWidget {
  final int score;
  final int maxScore; // Add this field
  final String result;
  final String description;
  final String testName;
  final DateTime testDate;
  final Map<String, dynamic> tips;
  final String testType;

  const TestResultScreen({
    required this.score,
    required this.maxScore, // Add this parameter
    required this.result,
    required this.description,
    required this.testName,
    required this.testDate,
    required this.tips,
    required this.testType,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String formattedDate =
        "${testDate.toLocal().toString().split('.')[0].substring(0, 16)}";

    // Save test to history
    TestHistory.addTest(
      TestHistory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        testId: testType,
        testTitle: testName,
        score: score,
        result: result,
        dateTime: testDate,
        answers: {}, // You can add actual answers if needed
        testType: testType, // Add this line
        maxScore: maxScore, // Add this line
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Results'),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurpleAccent, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24),
            child: Column(
              children: [
                // Image
                CircleAvatar(
                  radius: 100,
                  backgroundImage: NetworkImage(
                    'https://cdn.pixabay.com/photo/2022/02/11/23/23/heart-7008170_1280.png',
                  ),
                ),
                const SizedBox(height: 20),

                // Score Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.quiz, 'Test Name:', testName),
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          Icons.score,
                          'Your Score:',
                          '$score/$maxScore',
                        ),
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          Icons.analytics,
                          'Result:',
                          result,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          Icons.calendar_today,
                          'Test Date:',
                          formattedDate,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Description
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    description,
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),

                // Tips
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recommended Tips:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                ...tips.entries.map(
                  (tip) => Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.white,
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const Icon(
                        Icons.lightbulb_outline,
                        color: Colors.deepPurple,
                      ),
                      title: Text(
                        tip.value,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Add disclaimer text
                const Text(
                  '*This tool should be used for screening and monitoring symptom severity and cannot replace a clinical assessment and diagnosis.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Replace single button with row of two buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TestPage(testType: testType),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake Test'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HelpSupportScreen(),
                          ),
                        );
                      },
                      label: const Text('Get More Help'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color ?? Colors.black54),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize:
                  label == 'Test Name:' ? 14 : 16, // 👈 Adjust font size here
              color: color ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
