import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/test.dart';
import '../services/test_service.dart';
import 'test_result_screen.dart';

class TestPage extends StatefulWidget {
  final String testType;

  const TestPage({required this.testType, Key? key}) : super(key: key);

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  Map<String, dynamic>? testData;
  Map<int, int> answers = {};
  bool isLoading = true;
  int currentQuestion = 0;
  List<Map<String, dynamic>> sortedQuestions = [];

  @override
  void initState() {
    super.initState();
    _loadTestData();
  }

  Future<void> _loadTestData() async {
    try {
      print('Loading test type: ${widget.testType}');

      final doc =
          await FirebaseFirestore.instance
              .collection('tests')
              .doc(widget.testType)
              .get();

      if (!doc.exists) {
        print('Document does not exist!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final data = doc.data()!;
      print('Document data: $data');

      // Convert questions array to List and sort by order
      final questions =
          (data['questions'] as List)
              .map((q) => q as Map<String, dynamic>)
              .toList()
            ..sort((a, b) => (a['order'] as num).compareTo(b['order'] as num));

      setState(() {
        testData = data;
        sortedQuestions = questions;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading test: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading test: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _submitAnswer(String answer) {
    setState(() {
      // Unified scoring logic based on test type
      final score = switch (widget.testType) {
        'anxiety_test' => switch (answer) {
          "Not at all" => 0,
          "Several days" => 1,
          "More than half the days" => 2,
          "Nearly every day" => 3,
          _ => 0,
        },
        'stress_test' => switch (answer) {
          "Never" => 0,
          "Almost never" => 1,
          "Sometimes" => 2,
          "Fairly often" => 3,
          "Very often" => 4,
          _ => 0,
        },
        _ => switch (answer) {
          // For depression_test and others
          "Did not apply to me at all" => 0,
          "Applied to me to some degree, or some of the time" => 1,
          "Applied to me to a considerable degree, good part of time" => 2,
          "Applied to me very much, or most of the time" => 3,
          _ => 0,
        },
      };

      answers[currentQuestion] = score;

      if (currentQuestion < sortedQuestions.length - 1) {
        currentQuestion++;
      } else {
        _finishTest();
      }
    });
  }

  void _finishTest() async {
    try {
      final totalScore = answers.values.reduce((sum, score) => sum + score);
      String result = '';
      String description = '';
      final maxScore =
          testData!['maxScore'] as int; // Get maxScore from Firebase

      final ranges = testData!['scoring_ranges'] as Map<String, dynamic>;
      for (var entry in ranges.entries) {
        if (totalScore >= entry.value['min'] &&
            totalScore <= entry.value['max']) {
          result = entry.key;
          description = entry.value['description'] ?? '';
          break;
        }
      }

      // Fix the answers map conversion
      final testHistory = TestHistory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        testId: widget.testType,
        testTitle: testData!['title'],
        score: totalScore,
        result: result,
        dateTime: DateTime.now(),
        answers: answers.map(
          (key, value) => MapEntry(key.toString(), value),
        ), // Convert keys to String
        testType: widget.testType,
        maxScore: maxScore,
      );

      await TestService().saveTestResult(testHistory);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => TestResultScreen(
                  score: totalScore,
                  maxScore: maxScore, // Add this parameter
                  result: result,
                  description: description,
                  testName: testData!['title'],
                  testDate: DateTime.now(),
                  tips: Map<String, dynamic>.from(ranges[result]['tips']),
                  testType: widget.testType,
                ),
          ),
        );
      }
    } catch (e) {
      print('Error in _finishTest: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error completing test. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            testData?['title'] ?? 'Loading...',
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6A9BF5),
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentQuestionData = sortedQuestions[currentQuestion];
    final progress = (currentQuestion + 1) / sortedQuestions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          testData!['title'] ?? '',
          style: GoogleFonts.fredoka(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6A9BF5),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.blue.shade50,
              color: const Color(0xFF6A9BF5),
            ),
            const SizedBox(height: 24),
            Text(
              'Question ${currentQuestion + 1} of ${sortedQuestions.length}',
              style: GoogleFonts.fredoka(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Text(
              currentQuestionData['questions'] as String? ??
                  'Question not found',
              style: GoogleFonts.fredoka(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ..._getAnswerOptions().map((answer) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton(
                  onPressed: () => _submitAnswer(answer),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: const Color(0xFF6A9BF5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    answer,
                    style: GoogleFonts.fredoka(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<String> _getAnswerOptions() {
    switch (widget.testType) {
      case 'anxiety_test':
        return [
          "Not at all",
          "Several days",
          "More than half the days",
          "Nearly every day",
        ];
      case 'stress_test':
        return [
          "Never",
          "Almost never",
          "Sometimes",
          "Fairly often",
          "Very often",
        ];
      default: // For depression_test and others
        return [
          "Did not apply to me at all",
          "Applied to me to some degree, or some of the time",
          "Applied to me to a considerable degree, good part of time",
          "Applied to me very much, or most of the time",
        ];
    }
  }
}
