import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class EmotionCheckIn extends StatelessWidget {
  final DatabaseReference databaseRef = FirebaseDatabase.instance.ref(); // Database reference

  void logEmotion(String emotion) async {
    final emotionData = {
      'emotion': emotion,
      'date': DateTime.now().toString().substring(0, 10), // YYYY-MM-DD
      'timestamp': DateTime.now().millisecondsSinceEpoch, // Sortable timestamp
    };

    await databaseRef.child('emotions').push().set(emotionData).then((_) {
      debugPrint('Emotion logged successfully: $emotion');
    }).catchError((error) {
      debugPrint('Failed to log emotion: $error');
    });
  }

  Future<void> fetchLatestEmotion() async {
    databaseRef.child('emotions').orderByChild('timestamp').limitToLast(1).onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        data.forEach((key, value) {
          String latestEmotion = value['emotion'];
          debugPrint('Latest Emotion: $latestEmotion');
          // Use this emotion for pet behavior adjustment
        });
      }
    });
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
                  onPressed: () => logEmotion('happy'),
                ),
                IconButton(
                  icon: const Icon(Icons.sentiment_dissatisfied, size: 50),
                  onPressed: () => logEmotion('sad'),
                ),
                IconButton(
                  icon: const Icon(Icons.sentiment_neutral, size: 50),
                  onPressed: () => logEmotion('neutral'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
