import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class EmotionCheckIn extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  EmotionCheckIn({super.key});
  
  void logEmotion(String emotion) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('Failed to log emotion: User not authenticated');
        return;
      }
      
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final timeStr = DateFormat('HH:mm:ss').format(now);
      
      // Create a record in the emotions collection (same format as in emotion_service.dart)
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emotions')
          .add({
        'emotion': emotion,
        'note': null,
        'date': dateStr,
        'time': timeStr,
        'timestamp': Timestamp.now(),
      });
      
      // Also update the attendance record for today with this mood (same as in emotion_service.dart)
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
      
      debugPrint('Emotion logged successfully: $emotion');
    } catch (error) {
      debugPrint('Failed to log emotion: $error');
    }
  }
  
  Future<Map<String, dynamic>?> fetchLatestEmotion() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('Cannot fetch emotion: User not authenticated');
        return null;
      }
      
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emotions')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        debugPrint('Latest Emotion: ${data['emotion']}');
        return data;
      }
      return null;
    } catch (error) {
      debugPrint('Error fetching latest emotion: $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Emotion Check-In')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'How are you feeling today?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.sentiment_very_satisfied, size: 50),
                  onPressed: () => logEmotion('Happy'),
                ),
                IconButton(
                  icon: const Icon(Icons.sentiment_dissatisfied, size: 50),
                  onPressed: () => logEmotion('Sad'),
                ),
                IconButton(
                  icon: const Icon(Icons.sentiment_neutral, size: 50),
                  onPressed: () => logEmotion('Neutral'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
