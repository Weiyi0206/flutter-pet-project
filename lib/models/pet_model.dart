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

  // Pet data structure
  Map<String, dynamic> _petData = {
    'level': 1,
    'experience': 0,
    'energy': 100,
    'maxEnergy': 100,
    // New metrics for a more realistic pet experience
    'hunger': 100, // 100 = full, 0 = starving
    'affection': 70, // 100 = very loving, 0 = feeling neglected
    'hygiene': 100, // 100 = clean, 0 = needs grooming
    'happiness': 80, // Overall happiness based on other metrics
    'mood': 'Content', // Text representation of current mood
    'learnedTricks': [],
    'availableTricks': ['Sit', 'Stay', 'Roll Over', 'High Five', 'Dance'],
    'lastInteractionTimes': {
      'pet': null,
      'feed': null,
      'play': null,
      'groom': null,
    },
    'lastMetricUpdateTime': null, // Track when metrics were last naturally decreased
    'isSleeping': false,
    'lastUpdated': FieldValue.serverTimestamp(),
    'achievements': [],

    // --- New fields for daily tracking ---
    'petsToday': 0,
    'lastPetDate': null, // Store as Timestamp in Firestore
    'mealsToday': 0,
    'lastFeedDate': null, // Store as Timestamp in Firestore
    // --- New fields for task status ---
    'dailyTaskStatus': <String, bool>{}, // Map task ID to claimed status (true/false)
    'lastTaskStatusResetDate': null, // Store as Timestamp in Firestore
    // --- Add fields for Play/Groom tracking ---
    'playsToday': 0,
    'lastPlayDate': null,
    'groomsToday': 0,
    'lastGroomDate': null,
    // --- End Play/Groom tracking fields ---
  };

  // Initialize pet data
  Future<void> initializePet() async {
    final docRef = _firestore.collection('pets').doc(_userId);
    final doc = await docRef.get();
    if (!doc.exists) {
      // Set initial values for new fields
      _petData['lastMetricUpdateTime'] = FieldValue.serverTimestamp();
      _petData['lastPetDate'] = FieldValue.serverTimestamp(); // Initialize date
      _petData['lastFeedDate'] = FieldValue.serverTimestamp(); // Initialize date
      _petData['petsToday'] = 0;
      _petData['mealsToday'] = 0;
      _petData['lastTaskStatusResetDate'] = FieldValue.serverTimestamp(); // Initialize date
      _petData['dailyTaskStatus'] = {}; // Initialize empty map
      _petData['lastPlayDate'] = FieldValue.serverTimestamp();
      _petData['playsToday'] = 0;
      _petData['lastGroomDate'] = FieldValue.serverTimestamp();
      _petData['groomsToday'] = 0;
      await docRef.set(_petData);
    } else {
       // Ensure existing documents have the fields, if not, add them
       Map<String, dynamic> data = doc.data() ?? {};
       Map<String, dynamic> updates = {};
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
       if (updates.isNotEmpty) {
          await docRef.update(updates);
       }
    }
  }

  // Load pet data
  Future<Map<String, dynamic>> loadPetData() async {
    final doc = await _firestore.collection('pets').doc(_userId).get();
    if (doc.exists) {
       // Start with default structure to ensure all keys exist
      Map<String, dynamic> defaultData = Map.from(_petData);
      Map<String, dynamic>? serverData = doc.data();

      if (serverData != null) {
        // Merge server data over default data
        _petData = {...defaultData, ...serverData};

        // Convert Firestore timestamps to DateTime, handling potential nulls
        _petData['lastInteractionTimes'] = _convertTimestamps(_petData['lastInteractionTimes'] ?? {});

        _petData['lastMetricUpdateTime'] = _convertToDateTime(_petData['lastMetricUpdateTime']);
        _petData['lastPetDate'] = _convertToDateTime(_petData['lastPetDate']);
        _petData['lastFeedDate'] = _convertToDateTime(_petData['lastFeedDate']);
        _petData['lastTaskStatusResetDate'] = _convertToDateTime(_petData['lastTaskStatusResetDate']);
        _petData['lastPlayDate'] = _convertToDateTime(_petData['lastPlayDate']);
        _petData['lastGroomDate'] = _convertToDateTime(_petData['lastGroomDate']);

        // Ensure daily counts are integers, default to 0 if null/missing
        _petData['petsToday'] = _petData['petsToday'] as int? ?? 0;
        _petData['mealsToday'] = _petData['mealsToday'] as int? ?? 0;
        _petData['playsToday'] = _petData['playsToday'] as int? ?? 0;
        _petData['groomsToday'] = _petData['groomsToday'] as int? ?? 0;

        // Ensure task status is the correct type
        _petData['dailyTaskStatus'] = Map<String, bool>.from(_petData['dailyTaskStatus'] ?? {});

        // --- Reset task status if it's a new day ---
        final DateTime? lastReset = _petData['lastTaskStatusResetDate'];
        final now = DateTime.now();
        if (!_isSameDay(lastReset, now)) {
            print("New day detected for tasks. Resetting task status.");
            _petData['dailyTaskStatus'] = <String, bool>{}; // Reset locally
            // Update Firestore immediately with reset status and new date
            await _firestore.collection('pets').doc(_userId).update({
                'dailyTaskStatus': {},
                'lastTaskStatusResetDate': FieldValue.serverTimestamp()
            });
            _petData['lastTaskStatusResetDate'] = now; // Update local date
        }
        // --- End task status reset ---

        // Update metrics based on time passed
        await _updateMetricsBasedOnTime();
      } else {
         // Document exists but has no data? Use defaults.
         _petData = defaultData;
      }

    } else {
       // Document doesn't exist, try initializing it
       print("Pet document for $_userId not found, attempting initialization.");
       await initializePet();
       // Try loading again after initialization
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

  // Update metrics naturally based on time passed
  Future<void> _updateMetricsBasedOnTime() async {
    // --- Ensure lastPetDate and lastFeedDate are DateTime before use ---
    final DateTime? lastPetDate = _petData['lastPetDate'];
    final DateTime? lastFeedDate = _petData['lastFeedDate'];
    final DateTime? lastPlayDate = _petData['lastPlayDate'];
    final DateTime? lastGroomDate = _petData['lastGroomDate'];
    final now = DateTime.now();

    Map<String, dynamic> timeBasedUpdates = {};

    // Check if daily counts need resetting
    if (!_isSameDay(lastPetDate, now)) {
      print("New day detected for petting. Resetting count.");
      timeBasedUpdates['petsToday'] = 0;
      // Don't update lastPetDate here, it's updated on interaction
    }
    if (!_isSameDay(lastFeedDate, now)) {
      print("New day detected for feeding. Resetting count.");
      timeBasedUpdates['mealsToday'] = 0;
      // Don't update lastFeedDate here, it's updated on interaction
    }
    if (!_isSameDay(lastPlayDate, now)) {
      print("New day detected for playing. Resetting count.");
      timeBasedUpdates['playsToday'] = 0;
    }
    if (!_isSameDay(lastGroomDate, now)) {
      print("New day detected for grooming. Resetting count.");
      timeBasedUpdates['groomsToday'] = 0;
    }

    // Apply daily count resets locally first if needed
    if (timeBasedUpdates.isNotEmpty) {
       _petData = {..._petData, ...timeBasedUpdates};
       // Persist reset counts immediately if day changed
       await updatePetData(timeBasedUpdates);
    }

    // Proceed with metric degradation logic
    final lastUpdate = _petData['lastMetricUpdateTime']; // Already converted to DateTime in loadPetData
    if (lastUpdate == null) {
      _petData['lastMetricUpdateTime'] = DateTime.now();
      await updatePetData({'lastMetricUpdateTime': FieldValue.serverTimestamp()});
      return;
    }

    final hoursPassed = now.difference(lastUpdate).inHours;

    if (hoursPassed >= 1) {
      print("Updating metrics based on time ($hoursPassed hours passed)...");
      try {
        final updates = <String, dynamic>{};

        updates['hunger'] = _decreaseMetric(_petData['hunger'] ?? 100, hoursPassed * 4);
        updates['affection'] = _decreaseMetric(_petData['affection'] ?? 70, hoursPassed * 3);
        updates['hygiene'] = _decreaseMetric(_petData['hygiene'] ?? 100, hoursPassed * 2);

        if (_petData['isSleeping'] == true) {
          updates['energy'] = _increaseMetric(
            _petData['energy'] ?? 0,
            hoursPassed * 10,
            _petData['maxEnergy'] ?? 100
          );
        }

        final currentHappiness = _petData['happiness'] ?? 80;
        final hungerFactor = (updates['hunger'] / 100.0); // 0-1
        final affectionFactor = (updates['affection'] / 100.0); // 0-1
        final hygieneFactor = (updates['hygiene'] / 100.0); // 0-1
        // Average needs fulfillment and scale to happiness range (e.g., 0-100)
        updates['happiness'] = math.max(0, math.min(100, ((hungerFactor + affectionFactor + hygieneFactor) / 3 * 100).round()));

        updates['mood'] = _getMoodFromHappiness(updates['happiness']);
        updates['lastMetricUpdateTime'] = FieldValue.serverTimestamp(); // Use server timestamp for saving

        // Apply updates locally
        _petData = {..._petData, ...updates};

        // Save to database
        await updatePetData(updates);
        print("Metrics updated successfully based on time.");
      } catch (e) {
        print('Error updating metrics based on time: $e');
      }
    }
  }
  
  // Helper method to decrease a metric without going below 0
  int _decreaseMetric(int currentValue, double amount) {
    return math.max(0, currentValue - amount.round());
  }
  
  // Helper method to increase a metric without exceeding max
  int _increaseMetric(int currentValue, double amount, int maxValue) {
    return math.min(maxValue, currentValue + amount.round());
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
    // Avoid updating lastUpdated field within this method, let Firestore handle it on write
    // updates['lastUpdated'] = FieldValue.serverTimestamp();
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

  // Feed the pet
  Future<void> feedPet() async {
    try {
      final now = DateTime.now();
      final lastFeedDate = _petData['lastFeedDate']; // Already DateTime or null
      int currentMealsToday = _petData['mealsToday'] ?? 0;
      int updatedMealsToday;

      if (!_isSameDay(lastFeedDate, now)) {
        print("[feedPet] First meal of the day.");
        updatedMealsToday = 1; // Reset count for the new day
      } else {
        updatedMealsToday = currentMealsToday + 1;
      }

      print("[feedPet] mealsToday count updated to $updatedMealsToday");

      // Different foods could have different impacts
      final hunger = math.min(100, (_petData['hunger'] ?? 0) + 30);
      final energy = math.min(_petData['maxEnergy'] ?? 100, (_petData['energy'] ?? 0) + 20);
      final happiness = math.min(100, (_petData['happiness'] ?? 0) + 5);
      
      final updates = {
        'hunger': hunger,
        'energy': energy,
        'happiness': happiness,
        'mood': _getMoodFromHappiness(happiness),
        'mealsToday': updatedMealsToday, // Store updated count
        'lastFeedDate': FieldValue.serverTimestamp(), // Update last feed time
        'lastInteractionTimes.feed': FieldValue.serverTimestamp(), // Keep this for general interaction tracking if needed
      };
      
      // Update local and remote
      _petData = {..._petData, ...updates};
      // Update the timestamp locally *after* adding ServerTimestamp to updates map
      _petData['lastFeedDate'] = now;

      await updatePetData(updates);
      print("[feedPet] Pet fed successfully.");
    } catch (e) {
      print('Error feeding pet: $e');
      rethrow;
    }
  }
  
  // Pet the pet (show affection)
  Future<void> petPet() async {
    try {
      final now = DateTime.now();
      final lastPetDate = _petData['lastPetDate']; // Already DateTime or null
      int currentPetsToday = _petData['petsToday'] ?? 0;
      int updatedPetsToday;

      if (!_isSameDay(lastPetDate, now)) {
         print("[petPet] First pet of the day.");
        updatedPetsToday = 1; // Reset count for the new day
      } else {
        updatedPetsToday = currentPetsToday + 1;
      }

      print("[petPet] petsToday count updated to $updatedPetsToday");

      // Petting increases affection and happiness
      final affection = math.min(100, (_petData['affection'] ?? 0) + 15);
      final happiness = math.min(100, (_petData['happiness'] ?? 0) + 5);
      
      final updates = {
        'affection': affection,
        'happiness': happiness,
        'mood': _getMoodFromHappiness(happiness),
        'petsToday': updatedPetsToday, // Store updated count
        'lastPetDate': FieldValue.serverTimestamp(), // Update last pet time
        'lastInteractionTimes.pet': FieldValue.serverTimestamp(), // Keep this for general interaction tracking if needed
      };
      
      // Update local and remote
      _petData = {..._petData, ...updates};
      // Update the timestamp locally *after* adding ServerTimestamp to updates map
      _petData['lastPetDate'] = now;

      await updatePetData(updates);
       print("[petPet] Pet petted successfully.");
    } catch (e) {
      print('Error petting pet: $e');
      rethrow;
    }
  }
  
  // Play with the pet
  Future<void> playWithPet() async {
    try {
      // --- Add daily tracking logic ---
      final now = DateTime.now();
      final lastPlayDate = _petData['lastPlayDate'];
      int currentPlaysToday = _petData['playsToday'] ?? 0;
      int updatedPlaysToday;
      if (!_isSameDay(lastPlayDate, now)) {
        updatedPlaysToday = 1;
      } else {
        updatedPlaysToday = currentPlaysToday + 1;
      }
      print("[playWithPet] playsToday count updated to $updatedPlaysToday");
      // --- End tracking logic ---

      // Playing costs energy but boosts happiness and affection
      final energy = math.max(0, (_petData['energy'] ?? 0) - 20);
      final affection = math.min(100, (_petData['affection'] ?? 0) + 20);
      final happiness = math.min(100, (_petData['happiness'] ?? 0) + 15);
      final experience = (_petData['experience'] ?? 0) + 10;
      
      // Check for level up
      int level = _petData['level'] ?? 1;
      int newExperience = experience;
      
      if (experience >= 100) {
        level += 1;
        newExperience = experience - 100;
      }
      
      final updates = {
        'energy': energy,
        'affection': affection,
        'happiness': happiness,
        'experience': newExperience,
        'level': level,
        'mood': _getMoodFromHappiness(happiness),
        'lastInteractionTimes.play': FieldValue.serverTimestamp(),
        'playsToday': updatedPlaysToday,
        'lastPlayDate': FieldValue.serverTimestamp(),
      };
      
      // Update max energy if leveled up
      if (level > (_petData['level'] ?? 1)) {
        updates['maxEnergy'] = 100 + ((level - 1) * 10);
      }
      
      // Update local and remote
      _petData = {..._petData, ...updates};
      _petData['lastPlayDate'] = now; // Update local date after adding server timestamp
      await updatePetData(updates);
    } catch (e) {
      print('Error playing with pet: $e');
      rethrow;
    }
  }
  
  // Groom the pet
  Future<void> groomPet() async {
    try {
      // --- Add daily tracking logic ---
       final now = DateTime.now();
      final lastGroomDate = _petData['lastGroomDate'];
      int currentGroomsToday = _petData['groomsToday'] ?? 0;
      int updatedGroomsToday;
      if (!_isSameDay(lastGroomDate, now)) {
        updatedGroomsToday = 1;
      } else {
        updatedGroomsToday = currentGroomsToday + 1;
      }
       print("[groomPet] groomsToday count updated to $updatedGroomsToday");
      // --- End tracking logic ---

      // Grooming improves hygiene and slightly boosts happiness
      final hygiene = math.min(100, (_petData['hygiene'] ?? 0) + 40);
      final happiness = math.min(100, (_petData['happiness'] ?? 0) + 10);
      
      final updates = {
        'hygiene': hygiene,
        'happiness': happiness,
        'mood': _getMoodFromHappiness(happiness),
        'lastInteractionTimes.groom': FieldValue.serverTimestamp(),
        'groomsToday': updatedGroomsToday,
        'lastGroomDate': FieldValue.serverTimestamp(),
      };
      
      // Update local and remote
      _petData = {..._petData, ...updates};
      _petData['lastGroomDate'] = now; // Update local date after adding server timestamp
      await updatePetData(updates);
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

  // Update energy
  Future<void> updateEnergy(int newEnergy) async {
    await updatePetData({'energy': newEnergy});
  }

  // Update experience and level
  Future<void> updateExperienceAndLevel(int newExperience, int newLevel) async {
    final updates = {
      'experience': newExperience,
      'level': newLevel,
      'maxEnergy': 100 + ((newLevel - 1) * 10),
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

  // Check for new achievements
  Future<void> checkForNewAchievements() async {
    // Ensure latest data is loaded before checking
    final currentPetData = await loadPetData();
    final achievements = currentPetData['achievements'] ?? [];
    final currentAchievementTitles = Set<String>.from(achievements.map((a) => a['title']));

    // Level achievements
    if (currentPetData['level'] >= 5 && !currentAchievementTitles.contains('Level 5')) {
      await addAchievement('Level 5', 'star', Colors.amber, 10); // Use string for icon
    }
    if (currentPetData['level'] >= 10 && !currentAchievementTitles.contains('Level 10')) {
      await addAchievement('Level 10', 'star', Colors.amber, 20);
    }

    // Trick achievements
    if ((currentPetData['learnedTricks']?.length ?? 0) >= 3 && !currentAchievementTitles.contains('Trick Master')) {
      await addAchievement('Trick Master', 'pets', Colors.purple, 15);
    }
    if ((currentPetData['learnedTricks']?.length ?? 0) >= 5 && !currentAchievementTitles.contains('Trick Expert')) {
      await addAchievement('Trick Expert', 'pets', Colors.purple, 25);
    }

    // Energy achievements
    if (currentPetData['maxEnergy'] >= 150 && !currentAchievementTitles.contains('Energy Boost')) {
      await addAchievement('Energy Boost', 'energy_savings_leaf', Colors.blue, 15);
    }
    
    // New care achievements
    if (currentPetData['happiness'] >= 90 && !currentAchievementTitles.contains('Happy Pet')) {
      await addAchievement('Happy Pet', 'sentiment_very_satisfied', Colors.yellow, 20);
    }
    if (currentPetData['affection'] >= 95 && !currentAchievementTitles.contains('Best Friends')) {
      await addAchievement('Best Friends', 'favorite', Colors.pink, 25);
    }
    // Add more achievement checks as needed
  }

  // --- Method to update the task status map ---
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