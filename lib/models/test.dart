class TestHistory {
  final String id;
  final String testId;
  final String testTitle;
  final int score;
  final String result;
  final DateTime dateTime;
  final Map<String, int> answers;
  final String testType;
  final int maxScore; // Add this field

  TestHistory({
    required this.id,
    required this.testId,
    required this.testTitle,
    required this.score,
    required this.result,
    required this.dateTime,
    required this.answers,
    required this.testType,
    required this.maxScore, // Add this parameter
  });

  factory TestHistory.fromMap(Map<String, dynamic> map) {
    return TestHistory(
      id: map['id'] as String,
      testId: map['testId'] as String,
      testTitle: map['testTitle'] as String,
      score: map['score'] as int,
      result: map['result'] as String,
      dateTime: DateTime.parse(map['dateTime'] as String),
      answers: Map<String, int>.from(map['answers'] as Map),
      testType: map['testType'] as String,
      maxScore: map['maxScore'] as int, // Add this mapping
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'testId': testId,
      'testTitle': testTitle,
      'score': score,
      'result': result,
      'dateTime': dateTime.toIso8601String(),
      'answers': answers,
      'testType': testType,
      'maxScore': maxScore, // Add this field
    };
  }

  static List<TestHistory> _history = [];

  static List<TestHistory> get history =>
      List.from(_history.reversed); // Return reversed list for newest first

  static void addTest(TestHistory test) {
    _history.add(test);
  }

  static void clearHistory() {
    _history.clear();
  }
}

class MentalHealthTest {
  final String id;
  final String title;
  final String description;
  final List<TestQuestion> questions;
  final Map<String, TestResult> resultRanges;

  MentalHealthTest({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
    required this.resultRanges,
  });

  factory MentalHealthTest.fromMap(Map<String, dynamic> map) {
    return MentalHealthTest(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      questions:
          (map['questions'] as List)
              .map((q) => TestQuestion.fromMap(q as Map<String, dynamic>))
              .toList(),
      resultRanges: Map.fromEntries(
        (map['resultRanges'] as Map<String, dynamic>).entries.map(
          (e) => MapEntry(
            e.key,
            TestResult.fromMap(e.value as Map<String, dynamic>),
          ),
        ),
      ),
    );
  }

  String calculateResult(int score) {
    for (var result in resultRanges.values) {
      if (score >= result.minScore && score <= result.maxScore) {
        return result.title;
      }
    }
    return 'No result found';
  }
}

class TestQuestion {
  final String question;
  final Map<String, dynamic> answers = {
    "Did not apply to me at all": 0,
    "Applied to me to some degree, or some of the time": 1,
    "Applied to me to a considerable degree, good part of time": 2,
    "Applied to me very much, or most of the time": 3,
  };

  TestQuestion({required this.question});

  factory TestQuestion.fromMap(Map<String, dynamic> map) {
    return TestQuestion(question: map['question'] as String);
  }
}

class TestResult {
  final String title;
  final String description;
  final int minScore;
  final int maxScore;

  TestResult({
    required this.title,
    required this.description,
    required this.minScore,
    required this.maxScore,
  });

  factory TestResult.fromMap(Map<String, dynamic> map) {
    return TestResult(
      title: map['title'] as String,
      description: map['description'] as String,
      minScore: map['minScore'] as int,
      maxScore: map['maxScore'] as int,
    );
  }
}
