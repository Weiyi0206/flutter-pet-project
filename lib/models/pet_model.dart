import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

// Helper function to check if two DateTime objects represent the same calendar day
bool _isSameDay(DateTime? date1, DateTime? date2) {
  if (date1 == null || date2 == null) {
    return false; // Treat null as different days
  }
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

class PetModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Pet data structure - Simplified
  Map<String, dynamic> _petData = {
    'level': 1,
    'experience': 0,
    'happiness': 80, // Overall happiness - now managed directly
    'mood': 'Content', // Text representation of current mood
    'learnedTricks': [],
    'availableTricks': ['Sit', 'Stay', 'Roll Over', 'High Five', 'Dance'],
    'lastInteractionTimes': {
      'pet': null,
      'feed': null,
      'play': null,
      'groom': null,
    },
    'isSleeping': false, // Keep sleep status if needed for other features
    'lastUpdated': FieldValue.serverTimestamp(),
    'achievements': [],

    // --- Daily tracking fields ---
    'petsToday': 0,
    'lastPetDate': null,
    'mealsToday': 0,
    'lastFeedDate': null,
    'playsToday': 0,
    'lastPlayDate': null,
    'groomsToday': 0,
    'lastGroomDate': null,

    // --- Task fields ---
    'dailyTaskStatus': <String, bool>{},
    'lastTaskStatusResetDate': null,

    // --- ADDED: Timestamp for hourly decay ---
    'lastHappinessUpdateTime': null,
  };

  // Initialize pet data
  Future<void> initializePet() async {
    final docRef = _firestore.collection('pets').doc(_userId);
    final doc = await docRef.get();
    if (!doc.exists) {
      // Set initial values
      _petData['lastPetDate'] = FieldValue.serverTimestamp();
      _petData['lastFeedDate'] = FieldValue.serverTimestamp();
      _petData['petsToday'] = 0;
      _petData['mealsToday'] = 0;
      _petData['lastTaskStatusResetDate'] = FieldValue.serverTimestamp();
      _petData['dailyTaskStatus'] = {};
      _petData['lastPlayDate'] = FieldValue.serverTimestamp();
      _petData['playsToday'] = 0;
      _petData['lastGroomDate'] = FieldValue.serverTimestamp();
      _petData['groomsToday'] = 0;
      _petData['happiness'] = 80;
      _petData['mood'] = 'Content';
      // --- ADD initial value for new timestamp ---
      _petData['lastHappinessUpdateTime'] = FieldValue.serverTimestamp();
      await docRef.set(_petData);
    } else {
       // Ensure existing documents have the fields
       Map<String, dynamic> data = doc.data() ?? {};
       Map<String, dynamic> updates = {};
       if (data['happiness'] == null) updates['happiness'] = 80;
       if (data['mood'] == null) updates['mood'] = 'Content';
       if (data['petsToday'] == null) updates['petsToday'] = 0;
       if (data['lastPetDate'] == null) updates['lastPetDate'] = FieldValue.serverTimestamp();
       if (data['mealsToday'] == null) updates['mealsToday'] = 0;
       if (data['lastFeedDate'] == null) updates['lastFeedDate'] = FieldValue.serverTimestamp();
       if (data['dailyTaskStatus'] == null) updates['dailyTaskStatus'] = {};
       if (data['lastTaskStatusResetDate'] == null) {
         updates['lastTaskStatusResetDate'] = FieldValue.serverTimestamp();
       }
       if (data['playsToday'] == null) updates['playsToday'] = 0;
       if (data['lastPlayDate'] == null) updates['lastPlayDate'] = FieldValue.serverTimestamp();
       if (data['groomsToday'] == null) updates['groomsToday'] = 0;
       if (data['lastGroomDate'] == null) updates['lastGroomDate'] = FieldValue.serverTimestamp();

       // --- ADD check for the new timestamp ---
       if (data['lastHappinessUpdateTime'] == null) {
         updates['lastHappinessUpdateTime'] = FieldValue.serverTimestamp();
       }

       // Remove obsolete fields
       if (data.containsKey('energy')) updates['energy'] = FieldValue.delete();
       if (data.containsKey('maxEnergy')) updates['maxEnergy'] = FieldValue.delete();
       if (data.containsKey('hunger')) updates['hunger'] = FieldValue.delete();
       if (data.containsKey('affection')) updates['affection'] = FieldValue.delete();
       if (data.containsKey('hygiene')) updates['hygiene'] = FieldValue.delete();
       if (data.containsKey('lastMetricUpdateTime')) updates['lastMetricUpdateTime'] = FieldValue.delete();

       if (updates.isNotEmpty) {
          await docRef.update(updates);
       }
    }
  }

  // Load pet data
  Future<Map<String, dynamic>> loadPetData() async {
    final doc = await _firestore.collection('pets').doc(_userId).get();
    if (doc.exists) {
      Map<String, dynamic> defaultData = Map.from(_petData); // Start with defaults
      Map<String, dynamic>? serverData = doc.data();

      if (serverData != null) {
        // Merge server data over default data
        // Make sure to exclude removed fields if they still exist in Firestore
        serverData.remove('energy');
        serverData.remove('maxEnergy');
        serverData.remove('hunger');
        serverData.remove('affection');
        serverData.remove('hygiene');
        serverData.remove('lastMetricUpdateTime');

        _petData = {...defaultData, ...serverData};

        // Convert relevant timestamps
        _petData['lastInteractionTimes'] = _convertTimestamps(_petData['lastInteractionTimes'] ?? {});
        _petData['lastPetDate'] = _convertToDateTime(_petData['lastPetDate']);
        _petData['lastFeedDate'] = _convertToDateTime(_petData['lastFeedDate']);
        _petData['lastTaskStatusResetDate'] = _convertToDateTime(_petData['lastTaskStatusResetDate']);
        _petData['lastPlayDate'] = _convertToDateTime(_petData['lastPlayDate']);
        _petData['lastGroomDate'] = _convertToDateTime(_petData['lastGroomDate']);
        _petData['lastHappinessUpdateTime'] = _convertToDateTime(_petData['lastHappinessUpdateTime']);

        // Ensure counts are integers
        _petData['petsToday'] = _petData['petsToday'] as int? ?? 0;
        _petData['mealsToday'] = _petData['mealsToday'] as int? ?? 0;
        _petData['playsToday'] = _petData['playsToday'] as int? ?? 0;
        _petData['groomsToday'] = _petData['groomsToday'] as int? ?? 0;
        _petData['happiness'] = _petData['happiness'] as int? ?? 80; // Ensure happiness exists

        // Ensure task status is the correct type
        _petData['dailyTaskStatus'] = Map<String, bool>.from(_petData['dailyTaskStatus'] ?? {});

        // --- Hourly Happiness Decay Logic ---
        final DateTime now = DateTime.now();
        Map<String, dynamic> timeBasedUpdates = {};
        DateTime? lastUpdate = _petData['lastHappinessUpdateTime'];

        if (lastUpdate != null) {
          final Duration timeDifference = now.difference(lastUpdate);
          final int hoursPassed = timeDifference.inHours; // Get whole hours passed

          if (hoursPassed > 0) {
            print("[loadPetData] $hoursPassed hour(s) passed since last happiness update ($lastUpdate). Applying decay.");
            final int decreasePerHour = 10;
            final int totalDecrease = hoursPassed * decreasePerHour;
            final int currentHappiness = _petData['happiness'];
            final int newHappiness = math.max(0, currentHappiness - totalDecrease); // Don't go below 0

            print("[loadPetData] Happiness decay: $currentHappiness -> $newHappiness (-$totalDecrease)");

            // Only add updates if happiness actually changed
            if (newHappiness != currentHappiness) {
                timeBasedUpdates['happiness'] = newHappiness;
                timeBasedUpdates['mood'] = _getMoodFromHappiness(newHappiness);
            }
            // Always update the timestamp to the *current time* after calculating decay for the passed hours
            timeBasedUpdates['lastHappinessUpdateTime'] = FieldValue.serverTimestamp();
             _petData['lastHappinessUpdateTime'] = now; // Update local cache immediately

          } else {
             print("[loadPetData] Less than an hour passed since last happiness update ($lastUpdate). No decay applied.");
          }
        } else {
           // If timestamp is missing for some reason, set it now
           print("[loadPetData] lastHappinessUpdateTime was null. Setting it to now.");
           timeBasedUpdates['lastHappinessUpdateTime'] = FieldValue.serverTimestamp();
            _petData['lastHappinessUpdateTime'] = now; // Update local cache immediately
        }
        // --- End Hourly Happiness Decay Logic ---

        // --- Handle Daily Resets Here ---
        Map<String, dynamic> dailyResets = {};
        bool isNewDayForTasks = !_isSameDay(_petData['lastTaskStatusResetDate'], now);

        // Reset interaction counts
        if (!_isSameDay(_petData['lastPetDate'], now)) dailyResets['petsToday'] = 0;
        if (!_isSameDay(_petData['lastFeedDate'], now)) dailyResets['mealsToday'] = 0;
        if (!_isSameDay(_petData['lastPlayDate'], now)) dailyResets['playsToday'] = 0;
        if (!_isSameDay(_petData['lastGroomDate'], now)) dailyResets['groomsToday'] = 0;

        // Reset task status
        if (isNewDayForTasks) {
          print("[loadPetData] New day detected for tasks. Resetting task status.");
          dailyResets['dailyTaskStatus'] = <String, bool>{};
          dailyResets['lastTaskStatusResetDate'] = FieldValue.serverTimestamp();
           _petData['lastTaskStatusResetDate'] = now; // Update local date immediately
        }

        // Apply and persist resets if needed
        if (dailyResets.isNotEmpty) {
          print("[loadPetData] Applying daily resets: $dailyResets");
          _petData = {..._petData, ...dailyResets}; // Apply locally first
          await updatePetData(dailyResets); // Persist resets to Firestore
        }
        // --- End Daily Resets ---

        // --- Apply and Persist All Updates ---
        // Combine updates from time decay and daily resets
        final Map<String, dynamic> allUpdates = {...timeBasedUpdates, ...dailyResets};

        if (allUpdates.isNotEmpty) {
          print("[loadPetData] Applying updates: $allUpdates");
          // Apply locally first, ensuring time updates overwrite older values if keys conflict
          _petData = {..._petData, ...allUpdates};
          await updatePetData(allUpdates); // Persist combined updates to Firestore
        }
        // --- End Apply Updates ---

        // Ensure mood reflects the final happiness state after all updates
        _petData['mood'] = _getMoodFromHappiness(_petData['happiness']);

      } else {
         _petData = defaultData;
      }

    } else {
       print("Pet document for $_userId not found, attempting initialization.");
       await initializePet();
       return await loadPetData();
    }
    return _petData;
  }

  // Helper to safely convert Firestore Timestamp or null to DateTime or null
  DateTime? _convertToDateTime(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return null;
  }

  // Convert happiness value to mood string
  String _getMoodFromHappiness(int happiness) {
    if (happiness >= 90) return 'Ecstatic';
    if (happiness >= 75) return 'Happy';
    if (happiness >= 60) return 'Content';
    if (happiness >= 40) return 'Neutral';
    if (happiness >= 25) return 'Sad';
    return 'Depressed';
  }

  // Update pet data
  Future<void> updatePetData(Map<String, dynamic> updates) async {
    await _firestore.collection('pets').doc(_userId).update(updates);
  }

  // Convert Firestore timestamps to DateTime
  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> times) {
    final converted = <String, dynamic>{};
    times.forEach((key, value) {
      converted[key] = _convertToDateTime(value); // Use helper function
    });
    return converted;
  }

  // Save interaction time
  Future<void> saveInteractionTime(String interactionType) async {
    final updates = {
      'lastInteractionTimes.$interactionType': FieldValue.serverTimestamp(),
    };
    await updatePetData(updates);
  }

  // Feed the pet - Simplified
  Future<void> feedPet() async {
    try {
      final now = DateTime.now();
      int updatedMealsToday = _petData['mealsToday'] ?? 0;
      if (!_isSameDay(_petData['lastFeedDate'], now)) {
        updatedMealsToday = 1;
      } else {
        updatedMealsToday += 1;
      }
      print("[feedPet] mealsToday count updated to $updatedMealsToday");

      // Simple happiness boost for feeding
      final happiness = math.min(100, (_petData['happiness'] ?? 0) + 5); // Small boost

      final updates = {
        'happiness': happiness,
        'mood': _getMoodFromHappiness(happiness), // Update mood
        'mealsToday': updatedMealsToday,
        'lastFeedDate': FieldValue.serverTimestamp(),
        'lastInteractionTimes.feed': FieldValue.serverTimestamp(),
      };

      _petData = {..._petData, ...updates};
      _petData['lastFeedDate'] = now; // Update local time

      await updatePetData(updates);
      print("[feedPet] Pet fed successfully (simplified).");
    } catch (e) {
      print('Error feeding pet: $e');
      rethrow;
    }
  }

  // Pet the pet (show affection) - Simplified
  Future<void> petPet() async {
    try {
      final now = DateTime.now();
      int updatedPetsToday = _petData['petsToday'] ?? 0;
      if (!_isSameDay(_petData['lastPetDate'], now)) {
        updatedPetsToday = 1;
      } else {
        updatedPetsToday += 1;
      }
      print("[petPet] petsToday count updated to $updatedPetsToday");

      // Simple happiness boost for petting
      final happiness = math.min(100, (_petData['happiness'] ?? 0) + 8); // Slightly larger boost

      final updates = {
        'happiness': happiness,
        'mood': _getMoodFromHappiness(happiness), // Update mood
        'petsToday': updatedPetsToday,
        'lastPetDate': FieldValue.serverTimestamp(),
        'lastInteractionTimes.pet': FieldValue.serverTimestamp(),
      };

      _petData = {..._petData, ...updates};
      _petData['lastPetDate'] = now; // Update local time

      await updatePetData(updates);
      print("[petPet] Pet petted successfully (simplified).");
    } catch (e) {
      print('Error petting pet: $e');
      rethrow;
    }
  }

  // Play with the pet - Simplified
  Future<void> playWithPet() async {
    try {
      final now = DateTime.now();
      int updatedPlaysToday = _petData['playsToday'] ?? 0;
      if (!_isSameDay(_petData['lastPlayDate'], now)) {
        updatedPlaysToday = 1;
      } else {
        updatedPlaysToday += 1;
      }
      print("[playWithPet] playsToday count updated to $updatedPlaysToday");

      // Playing boosts happiness and gives experience
      final happiness = math.min(100, (_petData['happiness'] ?? 0) + 12); // Good boost
      final experience = (_petData['experience'] ?? 0) + 10; // Keep experience gain

      int level = _petData['level'] ?? 1;
      int newExperience = experience;
      if (experience >= 100) { // Simple level up logic
        level += 1;
        newExperience = experience - 100;
      }

      final updates = {
        'happiness': happiness,
        'mood': _getMoodFromHappiness(happiness), // Update mood
        'experience': newExperience,
        'level': level,
        'playsToday': updatedPlaysToday,
        'lastPlayDate': FieldValue.serverTimestamp(),
        'lastInteractionTimes.play': FieldValue.serverTimestamp(),
      };

      _petData = {..._petData, ...updates};
      _petData['lastPlayDate'] = now;

      await updatePetData(updates);
      print("[playWithPet] Pet played with successfully (simplified).");
    } catch (e) {
      print('Error playing with pet: $e');
      rethrow;
    }
  }

  // Groom the pet - Simplified
  Future<void> groomPet() async {
    try {
      final now = DateTime.now();
      int updatedGroomsToday = _petData['groomsToday'] ?? 0;
      if (!_isSameDay(_petData['lastGroomDate'], now)) {
        updatedGroomsToday = 1;
      } else {
        updatedGroomsToday += 1;
      }
      print("[groomPet] groomsToday count updated to $updatedGroomsToday");

      // Grooming slightly boosts happiness
      final happiness = math.min(100, (_petData['happiness'] ?? 0) + 6); // Moderate boost

      final updates = {
        'happiness': happiness,
        'mood': _getMoodFromHappiness(happiness), // Update mood
        'groomsToday': updatedGroomsToday,
        'lastGroomDate': FieldValue.serverTimestamp(),
        'lastInteractionTimes.groom': FieldValue.serverTimestamp(),
      };

      _petData = {..._petData, ...updates};
      _petData['lastGroomDate'] = now;

      await updatePetData(updates);
      print("[groomPet] Pet groomed successfully (simplified).");
    } catch (e) {
      print('Error grooming pet: $e');
      rethrow;
    }
  }

  // Save learned trick
  Future<void> saveLearnedTrick(String trick) async {
    final updates = {
      'learnedTricks': FieldValue.arrayUnion([trick]),
      'availableTricks': FieldValue.arrayRemove([trick]),
      'experience': (_petData['experience'] ?? 0) + 15, // Learning tricks gives experience
    };
    await updatePetData(updates);
  }

  // Update experience and level - Simplified
  Future<void> updateExperienceAndLevel(int newExperience, int newLevel) async {
    final updates = {
      'experience': newExperience,
      'level': newLevel,
    };
    await updatePetData(updates);
  }

  // Update sleep status
  Future<void> updateSleepStatus(bool isSleeping) async {
    await updatePetData({'isSleeping': isSleeping});
  }

  // Add achievement
  Future<void> addAchievement(String title, String icon, Color color, int points) async {
    final achievement = {
      'title': title,
      'icon': icon,
      'color': color.value,
      'points': points,
      'date': FieldValue.serverTimestamp(),
    };

    final updates = {
      'achievements': FieldValue.arrayUnion([achievement]),
    };

    await updatePetData(updates);
  }

  // Get achievements
  Future<List<Map<String, dynamic>>> getAchievements() async {
    final doc = await _firestore.collection('pets').doc(_userId).get();
    if (doc.exists) {
      final data = doc.data();
      final achievements = List<Map<String, dynamic>>.from(data?['achievements'] ?? []);
      // Convert Firestore timestamps and color values
      return achievements.map((achievement) {
        if (achievement['date'] is Timestamp) {
          achievement['date'] = achievement['date'].toDate().toString(); // Convert date for display
        }
        if (achievement['color'] is int) {
          achievement['color'] = Color(achievement['color']); // Recreate Color object
        }
        // You might need a way to map icon string back to IconData if needed for display elsewhere
        return achievement;
      }).toList();
    }
    return [];
  }

  // Check for new achievements - Simplified
  Future<void> checkForNewAchievements() async {
    final currentPetData = await loadPetData(); // Load latest data
    final achievements = currentPetData['achievements'] ?? [];
    final currentAchievementTitles = Set<String>.from(achievements.map((a) => a['title']));

    // Level achievements
    if (currentPetData['level'] >= 5 && !currentAchievementTitles.contains('Level 5')) {
      await addAchievement('Level 5', 'star', Colors.amber, 10);
    }
    if (currentPetData['level'] >= 10 && !currentAchievementTitles.contains('Level 10')) {
      await addAchievement('Level 10', 'star', Colors.amber, 20);
    }

    // Trick achievements
    if ((currentPetData['learnedTricks']?.length ?? 0) >= 3 && !currentAchievementTitles.contains('Trick Master')) {
      await addAchievement('Trick Master', 'pets', Colors.purple, 15);
    }
    // REMOVED: Energy achievement check
    // REMOVED: Affection achievement check

    // Happiness achievement check
    if (currentPetData['happiness'] >= 90 && !currentAchievementTitles.contains('Happy Pet')) {
      await addAchievement('Happy Pet', 'sentiment_very_satisfied', Colors.yellow, 20);
    }
  }

  // Method to update the task status map
  Future<void> updateTaskStatus(Map<String, bool> newStatus) async {
    try {
       await _firestore.collection('pets').doc(_userId).update({
           'dailyTaskStatus': newStatus
       });
       // Update local cache as well
       _petData['dailyTaskStatus'] = newStatus;
       print("[PetModel] Updated dailyTaskStatus: $newStatus");
    } catch (e) {
       print("Error updating task status: $e");
       rethrow;
    }
  }
} 