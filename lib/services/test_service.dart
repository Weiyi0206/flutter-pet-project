import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/test.dart';

class TestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<TestQuestion>> getTestQuestions(String testId) async {
    try {
      final snapshot =
          await _firestore
              .collection('tests')
              .doc(testId)
              .collection('questions')
              .orderBy('order')
              .get();

      return snapshot.docs
          .map((doc) => TestQuestion.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching test questions: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTestScoring(String testId) async {
    try {
      final doc = await _firestore.collection('tests').doc(testId).get();
      return {
        'ranges': doc.data()?['scoring_ranges'] ?? {},
        'interpretation': doc.data()?['interpretation'] ?? {},
      };
    } catch (e) {
      print('Error fetching test scoring: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getTestDetails(String testType) async {
    try {
      final doc = await _firestore.collection('tests').doc(testType).get();
      print('Fetched test details for $testType: ${doc.data()}');
      return doc.data();
    } catch (e) {
      print('Error fetching test details: $e');
      return null;
    }
  }

  Future<void> saveTestResult(TestHistory result) async {
    try {
      await _firestore
          .collection('test_history')
          .doc(result.id)
          .set(result.toMap());
      print('Test result saved successfully');
    } catch (e) {
      print('Error saving test result: $e');
      throw e;
    }
  }

  Future<List<TestHistory>> getTestHistory() async {
    try {
      final snapshot =
          await _firestore
              .collection('test_history')
              .orderBy('dateTime', descending: true)
              .get();

      return snapshot.docs
          .map((doc) => TestHistory.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching test history: $e');
      return [];
    }
  }
}
