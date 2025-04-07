import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

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
  };

  // Initialize pet data
  Future<void> initializePet() async {
    final doc = await _firestore.collection('pets').doc(_userId).get();
    if (!doc.exists) {
      _petData['lastMetricUpdateTime'] = FieldValue.serverTimestamp();
      await _firestore.collection('pets').doc(_userId).set(_petData);
    }
  }

  // Load pet data
  Future<Map<String, dynamic>> loadPetData() async {
    final doc = await _firestore.collection('pets').doc(_userId).get();
    if (doc.exists) {
      _petData = doc.data() ?? _petData;
      // Convert Firestore timestamps to DateTime
      _petData['lastInteractionTimes'] = _convertTimestamps(_petData['lastInteractionTimes']);
      
      // Convert lastMetricUpdateTime
      if (_petData['lastMetricUpdateTime'] is Timestamp) {
        _petData['lastMetricUpdateTime'] = (_petData['lastMetricUpdateTime'] as Timestamp).toDate();
      }
      
      // Update metrics based on time passed since last update
      await _updateMetricsBasedOnTime();
    }
    return _petData;
  }

  // Update metrics naturally based on time passed
  Future<void> _updateMetricsBasedOnTime() async {
    final lastUpdate = _petData['lastMetricUpdateTime'];
    if (lastUpdate == null) {
      // Initialize if never updated
      _petData['lastMetricUpdateTime'] = DateTime.now();
      return;
    }

    final now = DateTime.now();
    final hoursPassed = now.difference(lastUpdate).inHours;
    
    if (hoursPassed >= 1) {
      try {
        // Decrease metrics based on time (more realistic degradation)
        final updates = <String, dynamic>{};
        
        // Hunger decreases fastest
        updates['hunger'] = _decreaseMetric(_petData['hunger'] ?? 100, hoursPassed * 4);
        
        // Affection decreases next fastest
        updates['affection'] = _decreaseMetric(_petData['affection'] ?? 70, hoursPassed * 3);
        
        // Hygiene decreases more slowly
        updates['hygiene'] = _decreaseMetric(_petData['hygiene'] ?? 100, hoursPassed * 2);
        
        // Energy regenerates over time if pet is sleeping
        if (_petData['isSleeping'] == true) {
          updates['energy'] = _increaseMetric(
            _petData['energy'] ?? 0, 
            hoursPassed * 10, 
            _petData['maxEnergy'] ?? 100
          );
        }
        
        // Calculate overall happiness based on other metrics
        final avgMetric = (updates['hunger'] + updates['affection'] + updates['hygiene']) / 3;
        updates['happiness'] = avgMetric;
        
        // Set mood based on happiness
        updates['mood'] = _getMoodFromHappiness(updates['happiness']);
        
        // Update timestamp
        updates['lastMetricUpdateTime'] = now;
        
        // Apply updates locally
        _petData = {..._petData, ...updates};
        
        // Save to database
        await updatePetData(updates);
      } catch (e) {
        print('Error updating metrics based on time: $e');
        // Don't rethrow as this is an internal method
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
    updates['lastUpdated'] = FieldValue.serverTimestamp();
    await _firestore.collection('pets').doc(_userId).update(updates);
  }

  // Convert Firestore timestamps to DateTime
  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> times) {
    final converted = <String, dynamic>{};
    times.forEach((key, value) {
      if (value is Timestamp) {
        converted[key] = value.toDate();
      } else {
        converted[key] = value;
      }
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
      // Different foods could have different impacts
      final hunger = math.min(100, (_petData['hunger'] ?? 0) + 30);
      final energy = math.min(_petData['maxEnergy'] ?? 100, (_petData['energy'] ?? 0) + 20);
      final happiness = math.min(100, (_petData['happiness'] ?? 0) + 5);
      
      final updates = {
        'hunger': hunger,
        'energy': energy,
        'happiness': happiness,
        'mood': _getMoodFromHappiness(happiness),
        'lastInteractionTimes.feed': FieldValue.serverTimestamp(),
      };
      
      // Update local and remote
      _petData = {..._petData, ...updates};
      await updatePetData(updates);
    } catch (e) {
      print('Error feeding pet: $e');
      rethrow;
    }
  }
  
  // Pet the pet (show affection)
  Future<void> petPet() async {
    try {
      // Petting increases affection and happiness
      final affection = math.min(100, (_petData['affection'] ?? 0) + 15);
      final happiness = math.min(100, (_petData['happiness'] ?? 0) + 5);
      
      final updates = {
        'affection': affection,
        'happiness': happiness,
        'mood': _getMoodFromHappiness(happiness),
        'lastInteractionTimes.pet': FieldValue.serverTimestamp(),
      };
      
      // Update local and remote
      _petData = {..._petData, ...updates};
      await updatePetData(updates);
    } catch (e) {
      print('Error petting pet: $e');
      rethrow;
    }
  }
  
  // Play with the pet
  Future<void> playWithPet() async {
    try {
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
      };
      
      // Update max energy if leveled up
      if (level > (_petData['level'] ?? 1)) {
        updates['maxEnergy'] = 100 + ((level - 1) * 10);
      }
      
      // Update local and remote
      _petData = {..._petData, ...updates};
      await updatePetData(updates);
    } catch (e) {
      print('Error playing with pet: $e');
      rethrow;
    }
  }
  
  // Groom the pet
  Future<void> groomPet() async {
    try {
      // Grooming improves hygiene and slightly boosts happiness
      final hygiene = math.min(100, (_petData['hygiene'] ?? 0) + 40);
      final happiness = math.min(100, (_petData['happiness'] ?? 0) + 10);
      
      final updates = {
        'hygiene': hygiene,
        'happiness': happiness,
        'mood': _getMoodFromHappiness(happiness),
        'lastInteractionTimes.groom': FieldValue.serverTimestamp(),
      };
      
      // Update local and remote
      _petData = {..._petData, ...updates};
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
      // Convert Firestore timestamps to DateTime
      return achievements.map((achievement) {
        if (achievement['date'] is Timestamp) {
          achievement['date'] = achievement['date'].toDate().toString();
        }
        return achievement;
      }).toList();
    }
    return [];
  }

  // Check for new achievements
  Future<void> checkForNewAchievements(Map<String, dynamic> petData) async {
    final achievements = await getAchievements();
    final currentAchievements = Set<String>.from(achievements.map((a) => a['title']));

    // Level achievements
    if (petData['level'] >= 5 && !currentAchievements.contains('Level 5')) {
      await addAchievement('Level 5', 'Icons.star', Colors.amber, 10);
    }
    if (petData['level'] >= 10 && !currentAchievements.contains('Level 10')) {
      await addAchievement('Level 10', 'Icons.star', Colors.amber, 20);
    }

    // Trick achievements
    if (petData['learnedTricks'].length >= 3 && !currentAchievements.contains('Trick Master')) {
      await addAchievement('Trick Master', 'Icons.pets', Colors.purple, 15);
    }
    if (petData['learnedTricks'].length >= 5 && !currentAchievements.contains('Trick Expert')) {
      await addAchievement('Trick Expert', 'Icons.pets', Colors.purple, 25);
    }

    // Energy achievements
    if (petData['maxEnergy'] >= 150 && !currentAchievements.contains('Energy Boost')) {
      await addAchievement('Energy Boost', 'Icons.energy_savings_leaf', Colors.blue, 15);
    }
    
    // New care achievements
    if (petData['happiness'] >= 90 && !currentAchievements.contains('Happy Pet')) {
      await addAchievement('Happy Pet', 'Icons.sentiment_very_satisfied', Colors.yellow, 20);
    }
    if (petData['affection'] >= 95 && !currentAchievements.contains('Best Friends')) {
      await addAchievement('Best Friends', 'Icons.favorite', Colors.pink, 25);
    }
  }
} 