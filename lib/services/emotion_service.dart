import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EmotionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Record a new emotion
  Future<void> recordEmotion(String emotion, {String? note}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final timeStr = DateFormat('HH:mm:ss').format(now);

      // Create a record in the emotions collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emotions')
          .add({
        'emotion': emotion,
        'note': note,
        'date': dateStr,
        'time': timeStr,
        'timestamp': Timestamp.now(),
      });

      // Also update the attendance record for today with this mood
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('attendance')
          .doc(dateStr)
          .set({
        'mood': emotion,
        'date': dateStr,
        'lastUpdatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error recording emotion: $e');
      rethrow;
    }
  }

  // Get emotions for a specific date range
  Future<List<Map<String, dynamic>>> getEmotions({
    int days = 7,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emotions')
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .orderBy('date', descending: true)
          .orderBy('time', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'emotion': data['emotion'] as String,
          'note': data['note'] as String?,
          'date': data['date'] as String,
          'time': data['time'] as String,
        };
      }).toList();
    } catch (e) {
      print('Error getting emotions: $e');
      return [];
    }
  }

  // Get a summary of emotions for a date range
  Future<Map<String, int>> getEmotionSummary({int days = 7}) async {
    try {
      final emotions = await getEmotions(days: days);
      
      final Map<String, int> summary = {
        'Happy': 0,
        'Calm': 0,
        'Neutral': 0,
        'Sad': 0,
        'Angry': 0,
        'Anxious': 0,
      };

      for (final emotion in emotions) {
        final feel = emotion['emotion'] as String;
        if (summary.containsKey(feel)) {
          summary[feel] = (summary[feel] ?? 0) + 1;
        } else {
          // Handle any custom emotions not in our predefined list
          summary[feel] = 1;
        }
      }

      return summary;
    } catch (e) {
      print('Error getting emotion summary: $e');
      return {
        'Happy': 0,
        'Calm': 0,
        'Neutral': 0,
        'Sad': 0,
        'Angry': 0,
        'Anxious': 0,
      };
    }
  }

  // Get the dominant emotion for a user in the last X days
  Future<String> getDominantEmotion({int days = 7}) async {
    try {
      final summary = await getEmotionSummary(days: days);
      
      if (summary.isEmpty) return 'Neutral';
      
      String dominantEmotion = 'Neutral';
      int maxCount = 0;
      
      summary.forEach((emotion, count) {
        if (count > maxCount) {
          maxCount = count;
          dominantEmotion = emotion;
        }
      });
      
      return dominantEmotion;
    } catch (e) {
      print('Error getting dominant emotion: $e');
      return 'Neutral';
    }
  }
} 