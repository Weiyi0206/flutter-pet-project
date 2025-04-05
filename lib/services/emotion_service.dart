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
        print('DEBUG: User not authenticated in recordEmotion');
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final timeStr = DateFormat('HH:mm:ss').format(now);
      
      print('DEBUG: Recording emotion "$emotion" for user $userId on $dateStr at $timeStr');

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
      
      print('DEBUG: Successfully added record to emotions collection');

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
      
      print('DEBUG: Successfully updated attendance record with mood');
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
        print('DEBUG: User not authenticated in getEmotions');
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      
      print('DEBUG: Fetching emotions since $startDateStr for user $userId');

      // First, get data from Firestore
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emotions')
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .orderBy('date', descending: true)
          .orderBy('time', descending: true)
          .get();

      print('DEBUG: Found ${querySnapshot.docs.length} emotion records in Firestore');
      
      final List<Map<String, dynamic>> results = [];
      
      // Process Firestore data
      if (querySnapshot.docs.isNotEmpty) {
        results.addAll(querySnapshot.docs.map((doc) {
          final data = doc.data();
          print('DEBUG: Emotion record from Firestore: ${data.toString()}');
          return {
            'id': doc.id,
            'emotion': data['emotion'] as String,
            'note': data['note'] as String?,
            'date': data['date'] as String,
            'time': data['time'] as String? ?? '12:00:00',
          };
        }));
      }
      
      // If no data found in Firestore, check attendance collection as fallback
      if (results.isEmpty) {
        print('DEBUG: No emotion records found in the emotions collection');
        
        // As a fallback, check attendance collection which also stores mood data
        print('DEBUG: Checking attendance collection as fallback');
        final attendanceSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('attendance')
            .where('date', isGreaterThanOrEqualTo: startDateStr)
            .orderBy('date', descending: true)
            .get();
            
        print('DEBUG: Found ${attendanceSnapshot.docs.length} attendance records with mood data');
        
        // If we have attendance records with mood data, convert them to emotion format
        if (attendanceSnapshot.docs.isNotEmpty) {
          results.addAll(attendanceSnapshot.docs.map((doc) {
            final data = doc.data();
            final mood = data['mood'] as String? ?? 'Neutral';
            final date = data['date'] as String;
            // Use a default time since attendance records might not have time
            const defaultTime = '12:00:00';
            
            return {
              'id': doc.id,
              'emotion': mood,
              'note': null,
              'date': date,
              'time': defaultTime,
            };
          }));
        }
      }
      
      return results;
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