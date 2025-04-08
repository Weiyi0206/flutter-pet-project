import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
// import 'dart:convert';

class AttendanceReward {
  final String name;
  final int coinReward;
  final String? imageUrl;

  AttendanceReward({
    required this.name,
    required this.coinReward,
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

  // Helper method to get user-specific key for SharedPreferences
  String _getUserKey(String baseKey) {
    if (_userId == null) return baseKey;
    return '${_userId}_$baseKey';
  }

  // Clear all attendance data for current user from SharedPreferences
  // This should be called when user logs out
  Future<void> clearAttendanceData() async {
    if (_userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove user-specific keys
      await prefs.remove(_getUserKey(_lastCheckInKey));
      await prefs.remove(_getUserKey(_streakKey));
      await prefs.remove(_getUserKey(_attendanceDatesKey));
      await prefs.remove(_getUserKey(_totalCoinsKey));

      // For backward compatibility, also clear keys without user prefix
      await prefs.remove(_lastCheckInKey);
      await prefs.remove(_streakKey);
      await prefs.remove(_attendanceDatesKey);

      print('Cleared attendance data for user: $_userId');
    } catch (e) {
      print('Error clearing attendance data: $e');
    }
  }

  // Get total happiness coins earned
  Future<int> getTotalCoins() async {
    if (_userId == null || _userId!.isEmpty) return 0;

    // --- If Firestore is primary source (Recommended) ---
    try {
      final doc = await _firestore.collection('users').doc(_userId).get();
      if (doc.exists && doc.data() != null) {
        // Check for both field names for backward compatibility
        final totalCoins = doc.data()!['totalCoins'] as int?;
        final totalHappinessCoins = doc.data()!['totalHappinessCoins'] as int?;

        // Use totalCoins if available, otherwise use totalHappinessCoins, default to 0 if neither exists
        return totalCoins ?? totalHappinessCoins ?? 0;
      } else {
        // User doc might not exist yet, check SharedPreferences as fallback or return 0
        final prefs = await SharedPreferences.getInstance();
        return prefs.getInt(_getUserKey(_totalCoinsKey)) ?? 0;
      }
    } catch (e) {
      print(
        "Error getting total coins from Firestore: $e. Falling back to SharedPreferences.",
      );
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_getUserKey(_totalCoinsKey)) ?? 0;
    }

    // --- If SharedPreferences is primary source ---
    /*
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${_userId}_$_totalCoinsKey') ?? 0;
    */
  }

  // Update total happiness coins
  Future<void> _updateTotalCoins(int additionalCoins) async {
    if (_userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final currentCoins = prefs.getInt(_getUserKey(_totalCoinsKey)) ?? 0;
    final newTotal = currentCoins + additionalCoins;

    print(
      'DEBUG: Adding $additionalCoins coins. Current: $currentCoins, New total: $newTotal',
    );
    await prefs.setInt(_getUserKey(_totalCoinsKey), newTotal);

    // Also update in Firestore for backup
    try {
      // Use FieldValue.increment for safer concurrent updates
      await _firestore.collection('users').doc(_userId).set({
        'totalCoins': FieldValue.increment(additionalCoins),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // For backward compatibility, also update the old field name
      await _firestore.collection('users').doc(_userId).set({
        'totalHappinessCoins': FieldValue.increment(additionalCoins),
      }, SetOptions(merge: true));

      print('DEBUG: Successfully updated coins in Firestore');
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
          'coins':
              data['reward']?['coinReward'] ??
              data['reward']?['happinessBoost'] ??
              0,
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
    final lastCheckIn = prefs.getString(_getUserKey(_lastCheckInKey));

    if (lastCheckIn == null) return false;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return lastCheckIn == today;
  }

  // Get the current streak
  Future<int> getStreak() async {
    if (_userId == null) return 0;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_getUserKey(_streakKey)) ?? 0;
  }

  // Get all attendance dates for the calendar
  Future<List<Map<String, dynamic>>> getAttendanceDatesWithMoods() async {
    if (_userId == null) return [];

    print('DEBUG: Getting attendance dates with moods for user: $_userId');

    final prefs = await SharedPreferences.getInstance();
    final dateStrings =
        prefs.getStringList(_getUserKey(_attendanceDatesKey)) ?? [];

    print(
      'DEBUG: Found ${dateStrings.length} attendance dates in SharedPreferences',
    );

    final moodData = <Map<String, dynamic>>[];

    // Get mood data for each date
    for (final dateStr in dateStrings) {
      final date = DateTime.parse(dateStr);
      final moodKey = _getUserKey('mood_$dateStr');
      String? moodEmoji = prefs.getString(moodKey);

      print(
        'DEBUG: Loading mood for date $dateStr with key $moodKey: ${moodEmoji ?? 'null'}',
      );

      moodData.add({
        'date': date,
        'moodEmoji':
            moodEmoji ?? '😊', // Default to happy if no mood was stored
      });
    }

    print('DEBUG: Returning ${moodData.length} dates with moods');
    return moodData;
  }

  // For backward compatibility, keep the original method
  Future<List<DateTime>> getAttendanceDates() async {
    if (_userId == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final dateStrings =
        prefs.getStringList(_getUserKey(_attendanceDatesKey)) ?? [];

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
    final lastCheckIn = prefs.getString(_getUserKey(_lastCheckInKey));
    int currentStreak = prefs.getInt(_getUserKey(_streakKey)) ?? 0;

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
    await prefs.setString(_getUserKey(_lastCheckInKey), today);
    await prefs.setInt(_getUserKey(_streakKey), currentStreak);

    // Add today's date to attendance dates list
    List<String> attendanceDates =
        prefs.getStringList(_getUserKey(_attendanceDatesKey)) ?? [];
    attendanceDates.add(today);
    await prefs.setStringList(
      _getUserKey(_attendanceDatesKey),
      attendanceDates,
    );

    // Save the mood emoji for this date
    final moodEmoji = _getMoodEmoji(mood);
    final moodKey = _getUserKey('mood_$today');
    await prefs.setString(moodKey, moodEmoji);
    print(
      'DEBUG: Saved mood emoji $moodEmoji for date $today with key $moodKey',
    );

    // Create reward based on streak
    AttendanceReward reward;
    if (currentStreak % 7 == 0) {
      // Weekly special reward
      reward = AttendanceReward(
        name: 'Weekly Special Treat',
        coinReward: 20,
        imageUrl: 'assets/images/special_treat.png',
      );
    } else if (currentStreak % 30 == 0) {
      // Monthly super reward
      reward = AttendanceReward(
        name: 'Monthly Super Toy',
        coinReward: 50,
        imageUrl: 'assets/images/super_toy.png',
      );
    } else {
      // Regular daily reward
      reward = AttendanceReward(name: 'Daily Pet Treat', coinReward: 10);
    }

    int moodBonus = 0;

    // Update total coins with reward only
    await _updateTotalCoins(reward.coinReward + moodBonus);

    // Fetch the latest coin count after updating
    final totalCoins = await getTotalCoins();
    print('DEBUG: Updated total coins after check-in: $totalCoins');

    // Save check-in to Firestore
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
            'reward': {'name': reward.name, 'coinReward': reward.coinReward},
            'moodBonus': moodBonus,
            'totalCoinsEarned': reward.coinReward + moodBonus,
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

  // Combined function for check-in, mood tracking, and emotion recording
  Future<AttendanceResult> checkInWithEmotionTracking(
    String mood, {
    String? note,
  }) async {
    if (_userId == null) {
      return AttendanceResult(
        success: false,
        message: 'You need to be logged in to check in',
        streak: 0,
        totalCoins: 0,
      );
    }

    // First mark attendance and get streak/reward information
    final attendanceResult = await markAttendanceWithMood(mood);

    // If attendance check-in was successful, also record the emotion with optional note
    if (attendanceResult.success) {
      try {
        final now = DateTime.now();
        final dateStr = DateFormat('yyyy-MM-dd').format(now);
        final timeStr = DateFormat('HH:mm:ss').format(now);

        // Create a record in the emotions collection
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('emotions')
            .add({
              'emotion': mood,
              'note': note,
              'date': dateStr,
              'time': timeStr,
              'timestamp': FieldValue.serverTimestamp(),
            });

        print('DEBUG: Successfully recorded emotion with check-in: $mood');
        print('DEBUG: Total coins in result: ${attendanceResult.totalCoins}');
      } catch (e) {
        print('Error recording emotion during check-in: $e');
        // Continue anyway since the attendance was marked successfully
      }
    }

    return attendanceResult;
  }

  Future<void> addCoins(int amount) async {
    if (_userId == null || _userId!.isEmpty || amount <= 0)
      return; // Basic validation

    // --- Option 1: Update Firestore Directly (Recommended for persistence) ---
    final userDocRef = _firestore
        .collection('users')
        .doc(_userId); // Adjust if your collection/doc path is different
    try {
      // Use FieldValue.increment for safe addition
      // Make sure 'totalCoins' (or your field name) exists in the user document
      await userDocRef.update({
        'totalCoins': FieldValue.increment(
          amount,
        ), // Replace 'totalCoins' with your actual field name
      });
      print(
        "[AttendanceService] Added $amount coins for user $_userId in Firestore.",
      );

      // --- Also update SharedPreferences for immediate local consistency (Optional but good) ---
      final prefs = await SharedPreferences.getInstance();
      final currentCoins = prefs.getInt(_getUserKey(_totalCoinsKey)) ?? 0;
      await prefs.setInt(_getUserKey(_totalCoinsKey), currentCoins + amount);
      print("[AttendanceService] Updated SharedPreferences coins locally.");
    } catch (e) {
      print("Error adding coins for user $_userId in Firestore: $e");
      // Consider creating the field if it doesn't exist or the user doc doesn't exist
      // This might happen on the very first coin award
      try {
        await userDocRef.set({'totalCoins': amount}, SetOptions(merge: true));
        print("[AttendanceService] Initialized coins field for user $_userId.");
        // Update SharedPreferences too if initializing
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_getUserKey(_totalCoinsKey), amount);
      } catch (initError) {
        print("Error initializing coins field for user $_userId: $initError");
        rethrow; // Rethrow the original error or the init error
      }
    }

    // --- Option 2: Update SharedPreferences Only (Simpler but less robust) ---
    /*
    final prefs = await SharedPreferences.getInstance();
    final currentCoins = prefs.getInt('${_userId}_$_totalCoinsKey') ?? 0; // Use user-specific key
    await prefs.setInt('${_userId}_$_totalCoinsKey', currentCoins + amount);
    print("[AttendanceService] Added $amount coins for user $_userId in SharedPreferences.");
    */
    // Note: If using only SharedPreferences, getTotalCoins should also only read from SharedPreferences.
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
