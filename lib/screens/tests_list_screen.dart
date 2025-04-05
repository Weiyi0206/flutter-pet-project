import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'test_history_screen.dart'; // Add this import

import 'test_result_screen.dart';

class TestPage extends StatefulWidget {
  final String testId;
  final String title;
  final String description;
  final String testType; // Changed from 'type' to 'testType'

  const TestPage({
    required this.testId,
    required this.title,
    required this.description,
    required this.testType, // Changed from 'type' to 'testType'
    Key? key,
  }) : super(key: key);

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
      final doc =
          await FirebaseFirestore.instance
              .collection('tests')
              .doc(
                widget.testType,
              ) // Changed from widget.type to widget.testType
              .get();

      if (!doc.exists) {
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

      // Convert questions array to List and sort by order
      sortedQuestions =
          (data['questions'] as List)
              .map((q) => q as Map<String, dynamic>)
              .toList()
            ..sort((a, b) => (a['order'] as num).compareTo(b['order'] as num));

      setState(() {
        testData = data;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading test: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading test'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      default: // This includes depression_test
        return [
          "Did not apply to me at all",
          "Applied to me to some degree, or some of the time",
          "Applied to me to a considerable degree, good part of time",
          "Applied to me very much, or most of the time",
        ];
    }
  }

  void _submitAnswer(String answer) {
    setState(() {
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
        'depression_test' || _ => switch (answer) {
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

  void _finishTest() {
    final totalScore = answers.values.reduce((sum, score) => sum + score);
    String result = '';
    String description = '';

    final ranges = testData!['scoring_ranges'] as Map<String, dynamic>;
    for (var entry in ranges.entries) {
      if (totalScore >= entry.value['min'] &&
          totalScore <= entry.value['max']) {
        result = entry.key;
        description = entry.value['description'] ?? '';
        break;
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) => TestResultScreen(
              score: totalScore,
              result: result,
              description: description,
              testName: testData!['name'],
              testDate: DateTime.now(),
              tips: Map<String, dynamic>.from(ranges[result]['tips'] ?? {}),
              testType: widget.testType, // Add this line
              maxScore: testData!['maxScore'] as int, // Add this line
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6A9BF5),
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6A9BF5)),
        ),
      );
    }

    final progress = (currentQuestion + 1) / sortedQuestions.length;
    final currentQuestionData = sortedQuestions[currentQuestion];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
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
              currentQuestionData['questions'] as String,
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
}

class TestsListScreen extends StatelessWidget {
  Future<void> _showTestInfo(BuildContext context, String type) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('tests').doc(type).get();

      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test information not found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final data = doc.data()!;

      if (context.mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                titlePadding: const EdgeInsets.all(16),
                contentPadding: const EdgeInsets.all(16),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? 'Test Information',
                      style: GoogleFonts.fredoka(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6A9BF5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['name'] ?? '', // Add the test name here
                      style: GoogleFonts.fredoka(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Divider(),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'About this test:',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['explanation'] ?? 'No information available',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Time to complete:',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['time_to_complete'] ?? '5-10 minutes',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Scoring Range:',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...[
                            'Minimal',
                            'Mild',
                            'Moderate',
                            'Moderately Severe',
                            'Severe',
                          ]
                          .where(
                            (key) =>
                                (data['scoring_ranges'] as Map<String, dynamic>)
                                    .containsKey(key),
                          )
                          .map((key) {
                            final range = data['scoring_ranges'][key];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '$key: ${range['min']}-${range['max']} points',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Close',
                      style: GoogleFonts.fredoka(
                        color: const Color(0xFF6A9BF5),
                      ),
                    ),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      print('Error fetching test info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error loading test information'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tests = [
      {
        'title': 'Depression Assessment',
        'description': 'PHQ-9 Depression Screening Test',
        'name': 'Patient Health Questionnaire-9 (PHQ-9)',
        'icon': Icons.psychology,
        'color': Colors.blue,
        'type': 'depression_test', // Must match Firestore document ID exactly
      },
      {
        'title': 'Anxiety Assessment',
        'description': 'GAD-7 Anxiety Screening Test',
        'name': 'General Anxiety Disorder-7 (GAD-7)',
        'icon': Icons.healing,
        'color': Colors.green,
        'type': 'anxiety_test', // Must match Firestore document ID exactly
      },
      {
        'title': 'Stress Assessment',
        'description': 'Perceived Stress Scale (PSS)',
        'name': 'PSS',
        'icon': Icons.spa,
        'color': Colors.purple,
        'type': 'stress_test',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mental Health Tests',
          style: GoogleFonts.fredoka(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6A9BF5),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF6A9BF5)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF6A9BF5)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TestHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tests.length,
        itemBuilder: (context, index) {
          final test = tests[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon and title row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: (test['color'] as Color).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          test['icon'] as IconData,
                          color: test['color'] as Color,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          test['title'] as String,
                          style: GoogleFonts.fredoka(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    test['description'] as String,
                    style: GoogleFonts.fredoka(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 140, // Fixed width for the info button
                        child: ElevatedButton(
                          onPressed:
                              () => _showTestInfo(
                                context,
                                test['type'] as String,
                              ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: test['color'] as Color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: test['color'] as Color),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ), // Add padding
                          ),
                          child: Center(
                            // Wrap Text with Center widget
                            child: Text(
                              'View more info',
                              style: GoogleFonts.fredoka(),
                              textAlign: TextAlign.center, // Add text alignment
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => TestPage(
                                      testId: index.toString(),
                                      title: test['title'] as String,
                                      description:
                                          test['description'] as String,
                                      testType:
                                          test['type']
                                              as String, // Changed 'type' parameter to 'testType'
                                    ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: test['color'] as Color,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Start Test',
                            style: GoogleFonts.fredoka(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
