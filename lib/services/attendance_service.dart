import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
// import 'dart:convert';

class AttendanceReward {
  final String name;
  final int happinessBoost;
  final String? imageUrl;

  AttendanceReward({
    required this.name,
    required this.happinessBoost,
    this.imageUrl,
  });
}

class AttendanceResult {
  final bool success;
  final String message;
  final int streak;
  final AttendanceReward? reward;
  final String? mood;
  final int totalCoins;

  AttendanceResult({
    required this.success,
    required this.message,
    required this.streak,
    this.reward,
    this.mood,
    required this.totalCoins,
  });
}

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Keys for shared preferences
  static const String _lastCheckInKey = 'last_check_in';
  static const String _streakKey = 'attendance_streak';
  static const String _attendanceDatesKey = 'attendance_dates';
  static const String _totalCoinsKey = 'total_happiness_coins';

  // Get the current user ID or return null if not logged in
  String? get _userId => _auth.currentUser?.uid;

  // Get total happiness coins earned
  Future<int> getTotalCoins() async {
    if (_userId == null) return 0;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${_userId}_$_totalCoinsKey') ?? 0;
  }

  // Update total happiness coins
  Future<void> _updateTotalCoins(int additionalCoins) async {
    if (_userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final currentCoins = prefs.getInt('${_userId}_$_totalCoinsKey') ?? 0;
    final newTotal = currentCoins + additionalCoins;

    await prefs.setInt('${_userId}_$_totalCoinsKey', newTotal);

    // Also update in Firestore for backup
    try {
      await _firestore.collection('users').doc(_userId).set({
        'totalHappinessCoins': newTotal,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating coins in Firestore: $e');
    }
  }

  // Get happiness coin history (coins earned per day)
  Future<List<Map<String, dynamic>>> getCoinHistory() async {
    if (_userId == null) return [];

    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('attendance')
              .orderBy('date', descending: true)
              .limit(30) // Get last 30 days
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'date': doc.id,
          'coins': data['reward']?['happinessBoost'] ?? 0,
          'mood': data['mood'] ?? 'Unknown',
          'moodEmoji': data['moodEmoji'] ?? '😐',
        };
      }).toList();
    } catch (e) {
      print('Error fetching coin history: $e');
      return [];
    }
  }

  // new added
  Future<bool> shouldShowCheckInPrompt() async {
    if (_userId == null) return false;

    // Check if user hasn't checked in today
    final hasChecked = await hasCheckedInToday();
    return !hasChecked;
  }

  // Check if the user has already checked in today
  Future<bool> hasCheckedInToday() async {
    if (_userId == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final lastCheckIn = prefs.getString(_lastCheckInKey);

    if (lastCheckIn == null) return false;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return lastCheckIn == today;
  }

  // Get the current streak
  Future<int> getStreak() async {
    if (_userId == null) return 0;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  // Get all attendance dates for the calendar
  Future<List<Map<String, dynamic>>> getAttendanceDatesWithMoods() async {
    if (_userId == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final dateStrings = prefs.getStringList(_attendanceDatesKey) ?? [];
    final moodData = <Map<String, dynamic>>[];

    // Get mood data for each date
    for (final dateStr in dateStrings) {
      final date = DateTime.parse(dateStr);
      String? moodEmoji = prefs.getString('${_userId}_mood_$dateStr');

      moodData.add({
        'date': date,
        'moodEmoji':
            moodEmoji ?? '😊', // Default to happy if no mood was stored
      });
    }

    return moodData;
  }

  // For backward compatibility, keep the original method
  Future<List<DateTime>> getAttendanceDates() async {
    if (_userId == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final dateStrings = prefs.getStringList(_attendanceDatesKey) ?? [];

    return dateStrings.map((dateStr) {
      return DateTime.parse(dateStr);
    }).toList();
  }

  // Map mood name to emoji
  String _getMoodEmoji(String mood) {
    switch (mood) {
      case 'Happy':
        return '😊';
      case 'Calm':
        return '😌';
      case 'Neutral':
        return '😐';
      case 'Sad':
        return '😔';
      case 'Angry':
        return '😡';
      case 'Anxious':
        return '😰';
      default:
        return '😊';
    }
  }

  // Mark attendance for today
  Future<AttendanceResult> markAttendanceWithMood(String mood) async {
    if (_userId == null) {
      return AttendanceResult(
        success: false,
        message: 'You need to be logged in to check in',
        streak: 0,
        totalCoins: 0,
      );
    }

    // Check if already checked in today
    if (await hasCheckedInToday()) {
      final streak = await getStreak();
      final totalCoins = await getTotalCoins();
      return AttendanceResult(
        success: false,
        message: 'You have already checked in today',
        streak: streak,
        totalCoins: totalCoins,
      );
    }

    // Get shared preferences
    final prefs = await SharedPreferences.getInstance();

    // Save today's date as last check-in
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().subtract(const Duration(days: 1)));

    // Check if the user checked in yesterday to maintain streak
    final lastCheckIn = prefs.getString(_lastCheckInKey);
    int currentStreak = prefs.getInt(_streakKey) ?? 0;

    if (lastCheckIn == yesterday) {
      // Consecutive day, increase streak
      currentStreak++;
    } else if (lastCheckIn != null && lastCheckIn != today) {
      // Streak broken, reset to 1
      currentStreak = 1;
    } else if (lastCheckIn == null) {
      // First time checking in
      currentStreak = 1;
    }

    // Save the current streak and today's check-in
    await prefs.setString(_lastCheckInKey, today);
    await prefs.setInt(_streakKey, currentStreak);

    // Add today's date to attendance dates list
    List<String> attendanceDates =
        prefs.getStringList(_attendanceDatesKey) ?? [];
    attendanceDates.add(today);
    await prefs.setStringList(_attendanceDatesKey, attendanceDates);

    // Save the mood emoji for this date
    final moodEmoji = _getMoodEmoji(mood);
    await prefs.setString('${_userId}_mood_$today', moodEmoji);

    // Create reward based on streak
    AttendanceReward reward;
    if (currentStreak % 7 == 0) {
      // Weekly special reward
      reward = AttendanceReward(
        name: 'Weekly Special Treat',
        happinessBoost: 20,
        imageUrl: 'assets/images/special_treat.png',
      );
    } else if (currentStreak % 30 == 0) {
      // Monthly super reward
      reward = AttendanceReward(
        name: 'Monthly Super Toy',
        happinessBoost: 50,
        imageUrl: 'assets/images/super_toy.png',
      );
    } else {
      // Regular daily reward
      reward = AttendanceReward(name: 'Daily Pet Treat', happinessBoost: 10);
    }

    // No mood bonuses - all moods get the same reward
    int moodBonus = 0;
    // Removed mood-specific bonuses

    // Update total coins with reward only (no mood bonus)
    await _updateTotalCoins(reward.happinessBoost + moodBonus);

    // Get updated total coins
    final totalCoins = await getTotalCoins();

    // Save check-in to Firestore for backup
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('attendance')
          .doc(today)
          .set({
            'date': today,
            'streak': currentStreak,
            'mood': mood,
            'moodEmoji': moodEmoji,
            'reward': {
              'name': reward.name,
              'happinessBoost': reward.happinessBoost,
            },
            'moodBonus':
                moodBonus, // Kept for backward compatibility, always 0 now
            'totalCoinsEarned':
                reward.happinessBoost +
                moodBonus, // Equal to happinessBoost now
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error saving attendance to Firestore: $e');
      // Continue anyway since we saved locally
    }

    return AttendanceResult(
      success: true,
      message:
          currentStreak > 1
              ? 'Check-in successful! $currentStreak day streak!'
              : 'Check-in successful!',
      streak: currentStreak,
      reward: reward,
      mood: mood,
      totalCoins: totalCoins,
    );
  }
}

// Reward types
enum RewardType { basic, medium, special }

// Pet reward class
class PetReward {
  final RewardType type;
  final String name;
  final int happinessBoost;
  final String description;

  PetReward({
    required this.type,
    required this.name,
    required this.happinessBoost,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'name': name,
      'happinessBoost': happinessBoost,
      'description': description,
    };
  }

  factory PetReward.fromJson(Map<String, dynamic> json) {
    return PetReward(
      type: RewardType.values[json['type'] as int],
      name: json['name'] as String,
      happinessBoost: json['happinessBoost'] as int,
      description: json['description'] as String,
    );
  }
}
