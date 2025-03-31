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

  AttendanceResult({
    required this.success,
    required this.message,
    required this.streak,
    this.reward,
  });
}

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Keys for shared preferences
  static const String _lastCheckInKey = 'last_check_in';
  static const String _streakKey = 'attendance_streak';
  static const String _attendanceDatesKey = 'attendance_dates';

  // Get the current user ID or return null if not logged in
  String? get _userId => _auth.currentUser?.uid;

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
  Future<List<DateTime>> getAttendanceDates() async {
    if (_userId == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final dateStrings = prefs.getStringList(_attendanceDatesKey) ?? [];

    return dateStrings.map((dateStr) {
      return DateTime.parse(dateStr);
    }).toList();
  }

  // Mark attendance for today
  Future<AttendanceResult> markAttendance() async {
    if (_userId == null) {
      return AttendanceResult(
        success: false,
        message: 'You need to be logged in to check in',
        streak: 0,
      );
    }

    // Check if already checked in today
    if (await hasCheckedInToday()) {
      final streak = await getStreak();
      return AttendanceResult(
        success: false,
        message: 'You have already checked in today',
        streak: streak,
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
            'reward': {
              'name': reward.name,
              'happinessBoost': reward.happinessBoost,
            },
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
              ? 'Check-in successful! ${currentStreak} day streak!'
              : 'Check-in successful!',
      streak: currentStreak,
      reward: reward,
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
