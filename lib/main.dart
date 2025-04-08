import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/chat_history_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/attendance_screen.dart';
import 'dart:math';
import 'services/gemini_service.dart';
import 'package:logging/logging.dart';
import 'screens/daily_tips_screen.dart';
import 'dart:async';
import 'widgets/animated_pet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'screens/tests_list_screen.dart';
import 'services/attendance_service.dart';
import 'screens/diary_screen.dart'; // Add this import
import 'services/emotion_service.dart';
import 'models/pet_model.dart';
import 'screens/pet_tasks_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Add for date formatting

// --- Import new screens ---
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
// --- End Import new screens ---

// --- Added PetTask class ---
// Define a Task class for better structure (copied from pet_tasks_screen.dart)
class PetTask {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int requiredCount;
  final String
  currentCountKey; // Key in petData for current progress (e.g., 'petsToday')
  final int coinReward;
  // Add other potential rewards like XP if needed
  // final int xpReward;

  PetTask({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.requiredCount,
    required this.currentCountKey,
    required this.coinReward,
    // this.xpReward = 0,
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Initialize logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      debugPrint('Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrint('Stack trace:\n${record.stackTrace}');
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Pet Companion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent),
        useMaterial3: true,
        textTheme: GoogleFonts.fredokaTextTheme(
          Theme.of(context).textTheme,
        ).apply(
          bodyColor:
              ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent).onSurface,
          displayColor:
              ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent).onSurface,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor:
              ColorScheme.fromSeed(
                seedColor: Colors.lightBlueAccent,
              ).primaryContainer,
          foregroundColor:
              ColorScheme.fromSeed(
                seedColor: Colors.lightBlueAccent,
              ).onPrimaryContainer,
          elevation: 6,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
          ),
          titleTextStyle: GoogleFonts.fredoka(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color:
                ColorScheme.fromSeed(
                  seedColor: Colors.lightBlueAccent,
                ).onPrimaryContainer,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
            textStyle: GoogleFonts.fredoka(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.hasData) {
            return const MyHomePage(title: 'Virtual Pet Companion');
          }

          return const AuthWrapper();
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool showLogin = true;

  void toggleView() {
    setState(() {
      showLogin = !showLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLogin) {
      return LoginScreen(onRegisterPress: toggleView);
    } else {
      return RegisterScreen(onLoginPress: toggleView);
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final List<ChatMessage> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  final GeminiService _geminiService = GeminiService();

  // Add PetModel instance
  final PetModel _petModel = PetModel();
  Map<String, dynamic> _petData = {};

  // --- New state variables for daily stats ---
  int _petsTodayCount = 0;
  int _mealsTodayCount = 0;
  final int _maxMealsPerDay = 3; // Define max meals per day

  // --- Added Task Definitions ---
  // Define the list of tasks (copied from pet_tasks_screen.dart)
  // NOTE: Ensure these match the definitions in pet_tasks_screen.dart
  // A shared model file would be a better long-term solution.
  final List<PetTask> _tasks = [
    PetTask(
      id: 'pet_3_times',
      name: 'Show Affection',
      description: 'Pet your companion 3 times today',
      icon: Icons.pets,
      color: Colors.purple,
      requiredCount: 3,
      currentCountKey: 'petsToday',
      coinReward: 2,
    ),
    PetTask(
      id: 'feed_1_time',
      name: 'Meal Time',
      description: 'Feed your pet at least once today',
      icon: Icons.restaurant,
      color: Colors.orange,
      requiredCount: 1,
      currentCountKey: 'mealsToday',
      coinReward: 1,
    ),
    PetTask(
      id: 'play_2_times',
      name: 'Play Session',
      description: 'Play with your pet 2 times',
      icon: Icons.sports_esports,
      color: Colors.blue,
      requiredCount: 2,
      currentCountKey: 'playsToday', // Assumes PetModel tracks this
      coinReward: 2,
    ),
    PetTask(
      id: 'groom_1_time',
      name: 'Grooming',
      description: 'Groom your pet once',
      icon: Icons.cleaning_services,
      color: Colors.green,
      requiredCount: 1,
      currentCountKey: 'groomsToday', // Assumes PetModel tracks this
      coinReward: 1,
    ),
    PetTask(
      id: 'chat_5_times',
      name: 'Friendly Chat',
      description: 'Send 5 messages to your pet today',
      icon: Icons.chat_bubble_outline,
      color: Colors.pink,
      requiredCount: 5,
      // Requires PetModel to track 'chatsToday' - increment in _sendMessage
      currentCountKey: 'chatsToday',
      coinReward: 3,
    ),
    PetTask(
      id: 'write_diary_entry',
      name: 'Dear Diary',
      description: 'Write at least one diary entry today',
      icon: Icons.book_outlined,
      color: Colors.teal,
      requiredCount: 1,
      // Requires PetModel to track 'diaryEntriesToday' - update from DiaryScreen
      currentCountKey: 'diaryEntriesToday',
      coinReward: 2,
    ),
    PetTask(
      id: 'view_daily_tip',
      name: 'Daily Wisdom',
      description: 'Check out the daily tips screen',
      icon: Icons.lightbulb_outline,
      color: Colors.amber,
      requiredCount: 1,
      // Requires PetModel to track 'viewedTipsToday' - update from DailyTipsScreen
      currentCountKey: 'viewedTipsToday',
      coinReward: 1,
    ),
  ];

  // --- Added Completed Tasks Count ---
  int _completedTasksCount = 0;

  int _happiness = 50; // Keep happiness for fallback mood calculation
  String _petStatus = 'Normal';
  String? _currentResponse;
  String? _lastUserMessage;
  int _consecutiveNegativeChats = 0;
  final int _negativeThreshold = 3;
  int _consecutiveNegativeMoods = 0;

  // Emotion detection keywords
  final List<String> lonelyWords = [
    'lonely',
    'alone',
    'no one',
    'by myself',
    'no friends',
    'isolated',
  ];
  final List<String> sadWords = [
    'sad',
    'unhappy',
    'depressed',
    'down',
    'blue',
    'miserable',
  ];
  final List<String> anxiousWords = [
    'anxious',
    'nervous',
    'worry',
    'worried',
    'stress',
    'stressed',
  ];
  final List<String> angryWords = [
    'angry',
    'mad',
    'furious',
    'rage',
    'hate',
    'annoyed',
  ];
  final List<String> happyWords = [
    'happy',
    'joy',
    'excited',
    'great',
    'good',
    'wonderful',
  ];

  Timer? _tipTimer;
  final Random _random = Random();

  List<Map<String, String>> _unusedTips = [];

  final List<String> _companionshipPrompts = [
    "How was your day? I'd love to hear about it!",
    "Want to tell me something interesting you learned today?",
    "I've been waiting to chat with you! What's on your mind?",
    "I missed you! Want to play a game or just chat?",
    "I'm here for you. Want to talk about anything?",
    "Sometimes just sharing your thoughts can help. What's going on in your world?",
  ];

  int _totalHappinessCoins = 0; // Keep variable for display

  // --- Define Cooldown Duration ---
  static const Duration _interactionCooldown = Duration(
    minutes: 1,
  ); // Example: 1 minute cooldown

  // --- Cooldown State ---
  final Map<String, Timer> _cooldownTimers = {}; // Store active timers
  final Map<String, Duration> _remainingCooldowns =
      {}; // Store remaining durations for display

  // --- Fix GlobalKey type ---
  final GlobalKey<AnimatedPetState> _animatedPetKey =
      GlobalKey<AnimatedPetState>(); // Use the public 'AnimatedPetState'

  String _userId = FirebaseAuth.instance.currentUser?.uid ?? ''; // Store userId

  @override
  void initState() {
    super.initState();

    // Register as an observer for lifecycle events
    WidgetsBinding.instance.addObserver(this);

    _userId =
        FirebaseAuth.instance.currentUser?.uid ?? ''; // Ensure userId is set

    // Immediately load happiness coins on startup
    _refreshCoinsDirectlyFromFirestore();

    void showInitialCheckIn() async {
      final attendanceService = AttendanceService();

      if (await attendanceService.shouldShowCheckInPrompt()) {
        if (!mounted) return;

        // Navigate to the attendance screen instead of showing mood tracker
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AttendanceScreen()),
        ).then((result) {
          // When returning from check-in screen on startup, refresh coins
          if (result != null && result is Map<String, dynamic>) {
            final earnedCoins = result['earnedCoins'] as int? ?? 0;
            final totalCoins = result['totalCoins'] as int? ?? 0;

            if (earnedCoins > 0) {
              setState(() {
                _totalHappinessCoins = totalCoins;
              });
              print(
                "[MyHomePage] Updated coins from initial check-in: $totalCoins",
              );
            }
          } else {
            // Fallback: refresh coins if no specific result was received
            _refreshCoinsDirectlyFromFirestore();
          }
        });
      }
    }

    // Show check-in prompt after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showInitialCheckIn();
    });

    // Initialize pet data AND load today's chat
    _initializePetAndLoadChat();

    // Check connection to AI service
    _checkAIConnection();

    // Schedule companionship prompts
    Timer.periodic(const Duration(minutes: 60), (timer) {
      if (mounted && _currentResponse == null) {
        final rand = _random.nextDouble();
        if (rand < 0.4) {
          // 40% chance each hour
          _showCompanionshipPrompt();
        }
      }
    });

    // Start timers for any existing cooldowns after initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateAllCooldownTimers();
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _chatController.dispose();
    // --- Cancel all active cooldown timers ---
    _cooldownTimers.forEach((key, timer) => timer.cancel());
    _cooldownTimers.clear();
    super.dispose();
  }

  Future<void> _checkAIConnection() async {
    final isConnected = await _geminiService.testApiConnection();
    if (!isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to connect to AI service. Please check your internet connection and API key.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // --- Modified methods to update stats ---

  // Renamed and enhanced to update all stats from _petData
  void _updatePetStatsFromData() {
    if (!mounted) return; // Check if widget is still mounted

    // --- Add log ---
    print('[_updatePetStatsFromData] Received _petData: $_petData');

    setState(() {
      // Extract daily counts from _petData, defaulting to 0 if not found
      _petsTodayCount = _petData['petsToday'] as int? ?? 0;
      _mealsTodayCount = _petData['mealsToday'] as int? ?? 0;

      // --- Add logs ---
      print(
        '[_updatePetStatsFromData] Updated state: _petsTodayCount=$_petsTodayCount, _mealsTodayCount=$_mealsTodayCount',
      );

      // Update mood status based on petData first, then fallback to happiness
      if (_petData.isNotEmpty && _petData.containsKey('mood')) {
        _petStatus = _petData['mood'] as String? ?? 'Normal';
        // --- Add log ---
        print(
          '[_updatePetStatsFromData] Updated state: _petStatus=$_petStatus (from _petData)',
        );
      } else {
        // Fallback logic based on happiness (can be adjusted)
        if (_happiness >= 80) {
          _petStatus = 'Happy';
        } else if (_happiness >= 40) {
          _petStatus = 'Content';
        } else {
          _petStatus = 'Sad';
        }
        // --- Add log ---
        print(
          '[_updatePetStatsFromData] Updated state: _petStatus=$_petStatus (from fallback)',
        );
      }
      // Note: _happiness itself might need to be loaded from _petData too
      // _happiness = _petData['happiness'] as int? ?? 50;

      // --- Calculate completed tasks ---
      _calculateCompletedTasks();
    });
  }

  // --- Added Method to Calculate Completed Tasks ---
  void _calculateCompletedTasks() {
    if (_petData.isEmpty) {
      _completedTasksCount = 0;
      return;
    }

    int count = 0;
    for (var task in _tasks) {
      final int currentCount = _petData[task.currentCountKey] as int? ?? 0;
      if (currentCount >= task.requiredCount) {
        count++;
      }
    }
    // No need for setState here as it's called within _updatePetStatsFromData's setState
    _completedTasksCount = count;
    print(
      '[_calculateCompletedTasks] Calculated completed tasks: $_completedTasksCount / ${_tasks.length}',
    );
  }

  // --- Helper to check cooldown ---
  bool _isOnCooldown(String interactionType) {
    final lastInteraction = _petData['lastInteractionTimes']?[interactionType];
    if (lastInteraction is DateTime) {
      // Check if it's a DateTime object
      final now = DateTime.now();
      final difference = now.difference(lastInteraction);
      print(
        "Cooldown check for '$interactionType': Last interaction was $difference ago.",
      );
      return difference < _interactionCooldown;
    }
    return false; // Not on cooldown if no last interaction time found
  }

  // --- Helper to show cooldown message ---
  void _showCooldownMessage(String actionName) {
    if (!mounted) return;
    final lastInteraction =
        _petData['lastInteractionTimes']?[actionName.toLowerCase()];
    String message = '$actionName is on cooldown.';
    if (lastInteraction is DateTime) {
      final timeRemaining =
          _interactionCooldown - DateTime.now().difference(lastInteraction);
      if (timeRemaining.inSeconds > 0) {
        message =
            '$actionName is resting. Try again in ${timeRemaining.inSeconds} seconds.';
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange.shade700,
      ),
    );
  }

  // --- Update Interaction Methods ---

  void _petThePet() async {
    if (_getRemainingCooldown('pet') > Duration.zero) {
      _showCooldownMessage('Petting');
      return;
    }
    print('[_petThePet] Button pressed.');
    try {
      await _petModel.petPet();
      print('[_petThePet] _petModel.petPet() completed.');
      _petData = await _petModel.loadPetData();
      print('[_petThePet] _petModel.loadPetData() completed.');

      // --- ADD Animation Trigger ---
      _animatedPetKey.currentState?.triggerPet();
      // --- END ADD ---

      _updatePetStatsFromData();
      _updateCooldownTimer('pet');
    } catch (e) {
      print('Error petting pet: $e');
      if (mounted) {
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error petting pet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _feedThePet() async {
    if (_getRemainingCooldown('feed') > Duration.zero) {
      _showCooldownMessage('Feeding');
      return;
    }
    print('[_feedThePet] Button pressed.');
    try {
      await _petModel.feedPet();
      print('[_feedThePet] _petModel.feedPet() completed.');
      _petData = await _petModel.loadPetData();
      print('[_feedThePet] _petModel.loadPetData() completed.');

      // --- ADD Animation Trigger ---
      _animatedPetKey.currentState?.triggerFeed();
      // --- END ADD ---

      _updatePetStatsFromData();
      _updateCooldownTimer('feed');
    } catch (e) {
      print('Error feeding pet: $e');
      if (mounted) {
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error feeding pet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _playWithPet() async {
    if (_getRemainingCooldown('play') > Duration.zero) {
      _showCooldownMessage('Playing');
      return;
    }
    print('[_playWithPet] Button pressed.');
    try {
      await _petModel.playWithPet();
      print('[_playWithPet] _petModel.playWithPet() completed.');
      _petData = await _petModel.loadPetData();
      print('[_playWithPet] _petModel.loadPetData() completed.');

      _animatedPetKey.currentState?.triggerPlay();

      _updatePetStatsFromData();
      _updateCooldownTimer('play');
    } catch (e) {
      print('Error playing with pet: $e');
      if (mounted) {
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing with pet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _groomPet() async {
    if (_getRemainingCooldown('groom') > Duration.zero) {
      _showCooldownMessage('Grooming');
      return;
    }
    print('[_groomPet] Button pressed.');
    try {
      await _petModel.groomPet();
      print('[_groomPet] _petModel.groomPet() completed.');
      _petData = await _petModel.loadPetData();
      print('[_groomPet] _petModel.loadPetData() completed.');

      _animatedPetKey.currentState?.triggerGroom();

      _updatePetStatsFromData();
      _updateCooldownTimer('groom');
    } catch (e) {
      print('Error grooming pet: $e');
      if (mounted) {
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error grooming pet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Remove the old _updatePetStatus method as its logic is now in _updatePetStatsFromData
  /*
  void _updatePetStatus() {
    // ... old logic ...
  }
  */

  void _sendMessage() async {
    if (_chatController.text.trim().isEmpty) return;
    if (_userId.isEmpty) {
      print("Cannot send message: User ID is empty.");
      // Optionally show a message to the user
      return;
    }

    final userMessageText = _chatController.text;
    final now = DateTime.now(); // Get current time once

    // Create local message object for immediate display
    final localMessage = ChatMessage(
      text: userMessageText,
      isUser: true,
      timestamp: now, // Use the actual DateTime
    );

    // Prepare data map for Firestore Saving - Use Timestamp.fromDate()
    final messageDataForSave = {
      'text': userMessageText,
      'isUser': true,
      'timestamp': Timestamp.fromDate(
        now,
      ), // Convert DateTime to Firestore Timestamp
    };

    // Enhanced mood detection from the message
    final moodResult = _detectMoodFromText(userMessageText);
    final hasEmotionalContent =
        moodResult['lonely'] == true ||
        moodResult['anxious'] == true ||
        moodResult['sad'] == true ||
        moodResult['angry'] == true;
    final detectedMood = moodResult['mood'];

    // Check for signs of distress in the message
    _processChatMessage(userMessageText);

    // --- Update UI Immediately & Save to DB ---
    setState(() {
      _messages.add(localMessage); // Add to local list for UI
      _lastUserMessage = userMessageText;
      _chatController.clear();
      _currentResponse = null;
    });

    // Save user message to Firestore asynchronously
    try {
      await _petModel.saveChatMessage(
        messageDataForSave,
      ); // Pass map with Timestamp.fromDate()
      print("User message saved to Firestore.");

      // --- ADDED: Increment chat count task ---
      await _petModel.incrementChatCount();
      // --- END ADDED ---
    } catch (e) {
      print("Error saving user message: $e");
      // Optionally revert UI update or show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving your message.'),
            backgroundColor: Colors.red,
          ),
        );
        // Consider removing the message from the local list if saving failed
        // setState(() { _messages.remove(localMessage); });
      }
    }
    // --- End Update UI & Save to DB ---

    // --- Get AI Response ---
    try {
      String responseText;

      // Use the enhanced mental health response if emotional content is detected
      if (hasEmotionalContent) {
        responseText = await _geminiService.getMentalHealthResponse(
          userMessageText,
          moodResult,
        );
      } else {
        // Otherwise use the standard chat response
        responseText = await _geminiService.getChatResponse(
          userMessageText,
          _happiness,
          _petStatus,
          moodResult['lonely'] ?? false,
        );
      }

      // Create response message object
      final responseTimestamp = DateTime.now(); // Get time for response
      final localResponse = ChatMessage(
        text: responseText,
        isUser: false,
        timestamp: responseTimestamp,
      );

      // Prepare response data for saving - Use Timestamp.fromDate()
      final responseDataForSave = {
        'text': responseText,
        'isUser': false,
        'timestamp': Timestamp.fromDate(
          responseTimestamp,
        ), // Convert DateTime to Firestore Timestamp
      };

      if (mounted) {
        // Update UI with response
        setState(() {
          _messages.add(localResponse);
          _currentResponse = responseText; // For the speech bubble

          // Adjust happiness based on detected mood - reward the user for sharing
          if (hasEmotionalContent) {
            _happiness = min(
              _happiness + 5,
              100,
            ); // Happiness boost for emotional sharing
          }
          // Additional happiness adjustments based on detected mood
          if (detectedMood != null) {
            if (detectedMood == 'positive') {
              _happiness = min(_happiness + 3, 100);
            } else if (detectedMood == 'negative') {
              _happiness = min(_happiness + 1, 100);
            }
          }
          // Note: Consider if happiness should directly affect petData and be saved
        });

        // Save AI response to Firestore asynchronously
        try {
          await _petModel.saveChatMessage(
            responseDataForSave,
          ); // Pass map with Timestamp.fromDate()
          print("AI response saved to Firestore.");
        } catch (e) {
          print("Error saving AI response: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error saving AI response.'),
                backgroundColor: Colors.red,
              ),
            );
            // Consider removing the response from the local list
            // setState(() { _messages.remove(localResponse); });
          }
        }

        _updatePetStatsFromData(); // Update pet status

        // Remove speech bubble after delay
        Future.delayed(const Duration(seconds: 15), () {
          if (mounted && _currentResponse == responseText) {
            setState(() {
              _currentResponse = null;
            });
          }
        });
      }
    } catch (e) {
      // Handle AI error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting response: $e'),
            backgroundColor: Colors.red,
          ),
        );
        // Maybe add an error message to the chat?
        // final errorTimestamp = DateTime.now();
        // setState(() {
        //    _messages.add(ChatMessage(text: "Sorry, I couldn't respond.", isUser: false, timestamp: errorTimestamp));
        // });
      }
    }
  }

  void _showDailyCheckIn() {
    if (!mounted) return;

    final TextEditingController moodController = TextEditingController();
    String selectedMood = 'Happy'; // Default mood

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(
              'How are you feeling today?',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                TextField(
                  controller: moodController,
                  decoration: InputDecoration(
                    hintText: 'Share your mood...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildMoodOption('😊', 'Happy', Colors.yellow, (mood) {
                      selectedMood = mood;
                    }),
                    _buildMoodOption('😌', 'Calm', Colors.blue.shade300, (
                      mood,
                    ) {
                      selectedMood = mood;
                    }),
                    _buildMoodOption('😐', 'Neutral', Colors.grey.shade400, (
                      mood,
                    ) {
                      selectedMood = mood;
                    }),
                    _buildMoodOption('😔', 'Sad', Colors.indigo.shade300, (
                      mood,
                    ) {
                      selectedMood = mood;
                    }),
                    _buildMoodOption('😡', 'Angry', Colors.red.shade400, (
                      mood,
                    ) {
                      selectedMood = mood;
                    }),
                    _buildMoodOption('😰', 'Anxious', Colors.purple.shade300, (
                      mood,
                    ) {
                      selectedMood = mood;
                    }),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Later', style: GoogleFonts.fredoka()),
              ),
              ElevatedButton(
                onPressed: () async {
                  final moodText = moodController.text.trim();
                  Navigator.of(context).pop();

                  // Process the selected mood
                  _updateMoodTracking(selectedMood);

                  // Check for distress in their text description
                  if (moodText.isNotEmpty) {
                    _checkUserDistress(moodText, selectedMood);
                  }

                  // Proceed with marking attendance
                  final attendanceService = AttendanceService();
                  await attendanceService.markAttendanceWithMood(selectedMood);
                },
                child: Text('Submit', style: GoogleFonts.fredoka()),
              ),
            ],
          ),
    );
  }

  Widget _buildMoodOption(
    String emoji,
    String label,
    Color color,
    Function(String) onSelected,
  ) {
    return GestureDetector(
      onTap: () => onSelected(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            Text(label, style: GoogleFonts.fredoka(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showCompanionshipPrompt() {
    final prompt =
        _companionshipPrompts[_random.nextInt(_companionshipPrompts.length)];
    setState(() {
      _currentResponse = prompt;
    });

    // Clear message after delay
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _currentResponse == prompt) {
        setState(() {
          _currentResponse = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    // --- Get current cooldown status and remaining times ---
    final Duration petCooldownRemaining =
        _remainingCooldowns['pet'] ?? _getRemainingCooldown('pet');
    final Duration feedCooldownRemaining =
        _remainingCooldowns['feed'] ?? _getRemainingCooldown('feed');
    final Duration playCooldownRemaining =
        _remainingCooldowns['play'] ?? _getRemainingCooldown('play');
    final Duration groomCooldownRemaining =
        _remainingCooldowns['groom'] ?? _getRemainingCooldown('groom');

    final bool isPettingOnCooldown = petCooldownRemaining > Duration.zero;
    final bool isFeedingOnCooldown = feedCooldownRemaining > Duration.zero;
    final bool isPlayingOnCooldown = playCooldownRemaining > Duration.zero;
    final bool isGroomingOnCooldown = groomCooldownRemaining > Duration.zero;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          widget.title,
          style: GoogleFonts.fredoka(
            fontSize: screenSize.width * 0.055, // Responsive font size
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          PopupMenuButton<String>(
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            elevation: 4,
            onSelected: (String result) {
              switch (result) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
                case 'signOut':
                  FirebaseAuth.instance.signOut();
                  break;
              }
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'profile',
                    child: ListTile(
                      leading: Icon(Icons.person),
                      iconColor: Theme.of(context).colorScheme.onSurface,
                      title: Text(
                        'Profile',
                        style: GoogleFonts.fredoka(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings),
                      iconColor: Theme.of(context).colorScheme.onSurface,
                      title: Text(
                        'Settings',
                        style: GoogleFonts.fredoka(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'signOut',
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      iconColor: Theme.of(context).colorScheme.onSurface,
                      title: Text(
                        'Sign Out',
                        style: GoogleFonts.fredoka(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade50, Colors.blue.shade50],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Main content with pet and features
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Pet container - centered
                        Positioned(
                          top:
                              constraints.maxHeight *
                              0.35, // Move pet down a bit
                          left: 0,
                          right: 0,
                          child: Center(
                            child: AnimatedPet(
                              key: _animatedPetKey,
                              status: _petStatus,
                              onPet: _petThePet,
                              onFeed: _feedThePet,
                              size: constraints.maxWidth * 0.55,
                              petData: _petData.isNotEmpty ? _petData : null,
                            ),
                          ),
                        ),

                        // Feature buttons - positioned at the top in a row
                        Positioned(
                          top: constraints.maxHeight * 0.05,
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Happiness Coins Counter
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    margin: const EdgeInsets.only(
                                      bottom: 10,
                                      left: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.amber.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.monetization_on,
                                          color: Colors.amber,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '$_totalHappinessCoins',
                                          style: GoogleFonts.fredoka(
                                            color: Colors.amber.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Coins',
                                          style: GoogleFonts.fredoka(
                                            color: Colors.amber.shade800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Top row of feature buttons
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildFeatureButton(
                                      icon: Icons.check_box,
                                      label: 'Check-In',
                                      onPressed: () async {
                                        print(
                                          "[MyHomePage] Navigating to AttendanceScreen",
                                        );

                                        // Get initial coin count for comparison
                                        final initialCoins =
                                            _totalHappinessCoins;

                                        // Navigate to attendance screen and await result
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    const AttendanceScreen(),
                                          ),
                                        );

                                        print(
                                          "[MyHomePage] Returned from AttendanceScreen with result: $result",
                                        );

                                        // Check if we received a result with earned coins
                                        if (result != null &&
                                            result is Map<String, dynamic>) {
                                          final earnedCoins =
                                              result['earnedCoins'] as int? ??
                                              0;
                                          final totalCoins =
                                              result['totalCoins'] as int? ??
                                              _totalHappinessCoins;

                                          if (earnedCoins > 0) {
                                            print(
                                              "[MyHomePage] Updating coins directly from result: earned=$earnedCoins, total=$totalCoins",
                                            );

                                            // Update the coin display immediately
                                            setState(() {
                                              _totalHappinessCoins = totalCoins;
                                            });

                                            // Show confirmation message to user
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  "You earned $earnedCoins coins!",
                                                ),
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                            return;
                                          }
                                        }

                                        // Fallback: refresh coins if no specific result was received
                                        await _loadHappinessCoins();
                                      },
                                      color: Colors.blue,
                                      size: isSmallScreen ? 40 : 50,
                                    ),
                                    _buildFeatureButton(
                                      icon: Icons.help,
                                      label: 'Help',
                                      onPressed:
                                          () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      const HelpSupportScreen(),
                                            ),
                                          ),
                                      color: Colors.red,
                                      size: isSmallScreen ? 40 : 50,
                                    ),
                                    _buildFeatureButton(
                                      icon: Icons.checklist_rtl,
                                      label: 'Tasks',
                                      onPressed: _navigateToTasks,
                                      color: Colors.cyan,
                                      size: isSmallScreen ? 40 : 50,
                                    ),
                                    _buildFeatureButton(
                                      icon: Icons.science,
                                      label: 'Test',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => TestsListScreen(),
                                          ),
                                        );
                                      },
                                      color: Colors.green,
                                      size: isSmallScreen ? 40 : 50,
                                    ),
                                    _buildFeatureButton(
                                      icon: Icons.book,
                                      label: 'Diary',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    const DiaryScreen(),
                                          ),
                                        );
                                      },
                                      color: Colors.teal,
                                      size: isSmallScreen ? 40 : 50,
                                    ),
                                  ],
                                ),
                                SizedBox(height: constraints.maxHeight * 0.02),
                                // Bottom row with updated buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildFeatureButton(
                                      icon: Icons.pets,
                                      label: 'Pet',
                                      onPressed:
                                          isPettingOnCooldown
                                              ? null
                                              : _petThePet,
                                      color: Colors.purple,
                                      size: isSmallScreen ? 40 : 50,
                                      disabled: isPettingOnCooldown,
                                      cooldownRemaining:
                                          petCooldownRemaining, // Pass remaining time
                                    ),
                                    SizedBox(
                                      width: constraints.maxWidth * 0.05,
                                    ),
                                    _buildFeatureButton(
                                      icon: Icons.sports_esports,
                                      label: 'Play',
                                      onPressed:
                                          (isPlayingOnCooldown ||
                                                  _petData.isEmpty)
                                              ? null
                                              : _playWithPet,
                                      color: Colors.blue,
                                      size: isSmallScreen ? 40 : 50,
                                      disabled: isPlayingOnCooldown,
                                      cooldownRemaining:
                                          playCooldownRemaining, // Pass remaining time
                                    ),
                                    SizedBox(
                                      width: constraints.maxWidth * 0.05,
                                    ),
                                    _buildFeatureButton(
                                      icon: Icons.restaurant,
                                      label: 'Feed',
                                      onPressed:
                                          isFeedingOnCooldown
                                              ? null
                                              : _feedThePet,
                                      color: Colors.orange,
                                      size: isSmallScreen ? 40 : 50,
                                      disabled: isFeedingOnCooldown,
                                      cooldownRemaining:
                                          feedCooldownRemaining, // Pass remaining time
                                    ),
                                    SizedBox(
                                      width: constraints.maxWidth * 0.05,
                                    ),
                                    _buildFeatureButton(
                                      icon: Icons.cleaning_services,
                                      label: 'Groom',
                                      onPressed:
                                          (isGroomingOnCooldown ||
                                                  _petData.isEmpty)
                                              ? null
                                              : _groomPet,
                                      color: Colors.green,
                                      size: isSmallScreen ? 40 : 50,
                                      disabled: isGroomingOnCooldown,
                                      cooldownRemaining:
                                          groomCooldownRemaining, // Pass remaining time
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Pet speech bubble (only shown when there's a response)
                        if (_currentResponse != null)
                          Positioned(
                            top: constraints.maxHeight * 0.28,
                            right: constraints.maxWidth * 0.1,
                            left: constraints.maxWidth * 0.1,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Main bubble
                                Container(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth * 0.8,
                                    maxHeight: constraints.maxHeight * 0.2,
                                  ),
                                  padding: EdgeInsets.all(
                                    constraints.maxWidth * 0.03,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Flexible(
                                        child: SingleChildScrollView(
                                          child: AnimatedTextKit(
                                            animatedTexts: [
                                              TypewriterAnimatedText(
                                                _currentResponse!,
                                                speed: const Duration(
                                                  milliseconds: 50,
                                                ),
                                                textStyle: TextStyle(
                                                  fontSize:
                                                      constraints.maxWidth *
                                                      0.035,
                                                  color: _getStatusTextColor(),
                                                ),
                                              ),
                                            ],
                                            totalRepeatCount: 1,
                                            displayFullTextOnTap: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Triangle pointer
                                Positioned(
                                  bottom: -10,
                                  left: constraints.maxWidth * 0.37,
                                  child: CustomPaint(
                                    size: Size(20, 10),
                                    painter: BubbleTrianglePainter(),
                                  ),
                                ),
                              ],
                            ).animate().fadeIn().slideY(
                              begin: -0.5,
                              end: 0,
                              duration: 300.ms,
                            ),
                          ),

                        // Pet stats and activities section
                        Positioned(
                          bottom:
                              constraints.maxHeight *
                              0.12, // Position it above status bar
                          left: 0,
                          right: 0,
                          child: Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: constraints.maxWidth * 0.05,
                            ),
                            child: Column(
                              children: [
                                // Pet mood and activities
                                Container(
                                  padding: EdgeInsets.all(
                                    constraints.maxWidth * 0.03,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getStatusTextColor()
                                            .withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Today's activities - Updated values
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildActivityStat(
                                            icon: Icons.pets,
                                            label: 'Pets today',
                                            // --- Use state variable ---
                                            value: '$_petsTodayCount',
                                            color: Colors.purple,
                                            constraints: constraints,
                                          ),
                                          _buildActivityStat(
                                            icon: Icons.restaurant,
                                            label: 'Meals',
                                            // --- Use state variables ---
                                            value:
                                                '$_mealsTodayCount/$_maxMealsPerDay',
                                            color: Colors.orange,
                                            constraints: constraints,
                                          ),
                                          _buildActivityStat(
                                            icon:
                                                Icons
                                                    .check_circle_outline, // Changed Icon
                                            label:
                                                'Tasks Done', // Changed Label
                                            value:
                                                '$_completedTasksCount/${_tasks.length}', // Use calculated values
                                            color:
                                                Colors
                                                    .green
                                                    .shade700, // Changed Color
                                            constraints: constraints,
                                          ),
                                        ],
                                      ),

                                      SizedBox(
                                        height: constraints.maxHeight * 0.015,
                                      ),

                                      // --- Replaced Daily streak with Happiness display ---
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical:
                                              constraints.maxHeight * 0.01,
                                          horizontal:
                                              constraints.maxWidth * 0.03,
                                        ),
                                        decoration: BoxDecoration(
                                          // Use a color that fits happiness, maybe based on mood
                                          color: _getStatusTextColor()
                                              .withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: _getStatusTextColor()
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              // Choose an icon for happiness
                                              Icons.favorite,
                                              color:
                                                  _getStatusTextColor(), // Use mood color
                                              size: constraints.maxWidth * 0.05,
                                            ),
                                            SizedBox(
                                              width:
                                                  constraints.maxWidth * 0.02,
                                            ),
                                            Text(
                                              // Display happiness value from _petData
                                              'Happiness: ${_petData['happiness'] ?? '--'}%',
                                              style: GoogleFonts.fredoka(
                                                fontSize:
                                                    constraints.maxWidth *
                                                    0.035,
                                                // Use mood color for text too
                                                color: _getStatusTextColor()
                                                    .withOpacity(0.9),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // --- End of Happiness display ---
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // User's last message (only shown when there's a message)
                        if (_lastUserMessage != null)
                          Positioned(
                            bottom:
                                constraints.maxHeight *
                                0.05, // Position it above the status
                            right: 0,
                            child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth * 0.7,
                                    maxHeight: constraints.maxHeight * 0.1,
                                  ),
                                  margin: EdgeInsets.only(
                                    right: constraints.maxWidth * 0.05,
                                  ),
                                  padding: EdgeInsets.all(
                                    constraints.maxWidth * 0.025,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade100.withOpacity(
                                      0.9,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: constraints.maxWidth * 0.04,
                                        color: Colors.purple.shade700,
                                      ),
                                      SizedBox(
                                        width: constraints.maxWidth * 0.02,
                                      ),
                                      Flexible(
                                        child: Text(
                                          _lastUserMessage!,
                                          style: TextStyle(
                                            fontSize:
                                                constraints.maxWidth * 0.035,
                                            color: Colors.purple.shade800,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .slideX(begin: 0.5, end: 0, duration: 300.ms),
                          ),

                        // --- MOVED Tips and History Buttons ---
                        Positioned(
                          // Adjust top to vertically align with the pet's center
                          top:
                              constraints.maxHeight * 0.35 +
                              (constraints.maxWidth *
                                  0.55 /
                                  4), // Centering attempt
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: constraints.maxWidth * 0.08,
                            ), // Padding from screen edges
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween, // Space them out
                              children: [
                                // Tips Button - Updated
                                _buildFeatureButton(
                                  icon: Icons.lightbulb_outline,
                                  label: 'Tips',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DailyTipsScreen(),
                                      ),
                                    );
                                  },
                                  color: Colors.orange,
                                  size:
                                      40, // Use a fixed size or adjust as needed
                                  // disabled: false, // Default
                                  // cooldownRemaining: null, // Default
                                ),
                                // History Button - Updated
                                _buildFeatureButton(
                                  icon: Icons.history,
                                  label: 'History',
                                  onPressed: () {
                                    if (_userId.isNotEmpty) {
                                      // Only navigate if user ID is available
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => ChatHistoryScreen(
                                                userId: _userId,
                                              ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Cannot view history. User not logged in.',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  },
                                  color: Colors.blueGrey,
                                  size:
                                      40, // Use a fixed size or adjust as needed
                                  // disabled: false, // Default
                                  // cooldownRemaining: null, // Default
                                ),
                              ],
                            ),
                          ),
                        ),
                        // --- END MOVED Buttons ---
                      ],
                    );
                  },
                ),
              ),

              // Chat input
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenSize.width * 0.03,
                  vertical: screenSize.height * 0.015,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        decoration: InputDecoration(
                          hintText: 'Talk to your pet...',
                          hintStyle: GoogleFonts.fredoka(
                            // Use Fredoka font for hint
                            color: Colors.grey.shade600,
                            fontSize: 16, // Adjusted fixed size
                          ),
                          filled: true,
                          fillColor: Colors.white, // Cleaner background
                          // Remove the generic border
                          // border: OutlineInputBorder(...)
                          enabledBorder: OutlineInputBorder(
                            // Border when not focused
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            // Border when focused
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            // Fixed padding
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                        ), // Use Fredoka font for input
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Material(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(30),
                      child: InkWell(
                        onTap: _sendMessage,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: EdgeInsets.all(screenSize.width * 0.035),
                          child: Icon(
                            Icons.send,
                            color: Colors.white,
                            size: screenSize.width * 0.05,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusTextColor() {
    switch (_petStatus) {
      case 'Happy':
        return Colors.green.shade700;
      case 'Sad':
        return Colors.red.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  Widget _buildActivityStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required BoxConstraints constraints,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: constraints.maxWidth * 0.06),
        SizedBox(height: constraints.maxHeight * 0.005),
        Text(
          value,
          style: GoogleFonts.fredoka(
            fontSize: constraints.maxWidth * 0.04,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: constraints.maxHeight * 0.002),
        Text(
          label,
          style: GoogleFonts.fredoka(
            fontSize: constraints.maxWidth * 0.03,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  // Enhanced mood detection for Gemini integration
  Map<String, dynamic> _detectMoodFromText(String text) {
    final result = {
      'mood': null as String?,
      'lonely': false,
      'anxious': false,
      'sad': false,
      'angry': false,
      'context': <String>[],
    };

    final lowerText = text.toLowerCase();

    // Check for emotions in the text
    final isLonely = lonelyWords.any((word) => lowerText.contains(word));
    final isSad = sadWords.any((word) => lowerText.contains(word));
    final isAnxious = anxiousWords.any((word) => lowerText.contains(word));
    final isAngry = angryWords.any((word) => lowerText.contains(word));
    final isHappy = happyWords.any((word) => lowerText.contains(word));

    // Update result based on detected emotions
    result['lonely'] = isLonely;
    result['sad'] = isSad;
    result['anxious'] = isAnxious;
    result['angry'] = isAngry;

    if (isLonely || isSad || isAnxious || isAngry) {
      result['mood'] = 'negative';
    } else if (isHappy) {
      result['mood'] = 'positive';
    }

    // Track consecutive negative messages for potential interventions
    if (isSad || isAnxious || isAngry || isLonely) {
      _consecutiveNegativeChats++;

      if (_consecutiveNegativeChats >= _negativeThreshold) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _showHelpSuggestion();
          }
        });
        _consecutiveNegativeChats = 0;
      }
    } else if (isHappy) {
      _consecutiveNegativeChats = 0;
    }

    return result;
  }

  Widget _buildFeatureButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    double size = 50,
    bool disabled = false,
    Duration? cooldownRemaining, // Add optional remaining duration
  }) {
    final effectiveColor = disabled ? Colors.grey : color;
    final bool showTimer =
        disabled &&
        cooldownRemaining != null &&
        cooldownRemaining > Duration.zero;

    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size, // Ensure container has size for the Text
            height: size,
            decoration: BoxDecoration(
              color: effectiveColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              // Center the icon or timer text
              child:
                  showTimer
                      ? Text(
                        '${cooldownRemaining.inSeconds}', // Display remaining seconds
                        style: GoogleFonts.fredoka(
                          fontSize:
                              size *
                              0.4, // Adjust font size relative to button size
                          fontWeight: FontWeight.bold,
                          color: effectiveColor,
                        ),
                      )
                      : IconButton(
                        // Use IconButton for standard behavior (tooltip, padding)
                        icon: Icon(icon, color: effectiveColor),
                        onPressed: onPressed,
                        iconSize: size * 0.6,
                        padding: EdgeInsets.zero, // Use Center for positioning
                        tooltip: disabled ? '$label (Resting)' : label,
                        splashRadius:
                            size * 0.7, // Adjust splash radius if needed
                      ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.fredoka(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Method to detect user distress and offer help resources
  void _checkUserDistress(String message, String mood) {
    // List of high-risk critical keywords that require immediate attention
    final criticalKeywords = [
      'suicide',
      'suicidal',
      'kill myself',
      'end my life',
      'want to die',
      'die',
      'death',
      'don\'t want to live',
      'end it all',
      'no reason to live',
      'better off dead',
      'can\'t go on',
      'giving up',
      'goodbye',
      'final goodbye',
    ];

    // List of distress keywords to check for in messages
    final distressKeywords = [
      'sad',
      'depressed',
      'depression',
      'anxiety',
      'anxious',
      'worried',
      'stress',
      'stressed',
      'overwhelmed',
      'lonely',
      'alone',
      'hopeless',
      'worthless',
      'desperate',
      'miserable',
      'unhappy',
      'suffering',
      'pain',
      'hurt',
      'crying',
      'tears',
      'broken',
      'empty',
      'numb',
      'tired of',
      'exhausted',
      'hate myself',
    ];

    // List of negative moods from daily check-ins to track
    final negativeMoods = ['Sad', 'Angry', 'Anxious'];

    // Convert message to lowercase for case-insensitive matching
    final lowerMessage = message.toLowerCase();

    // First check for critical high-risk keywords - these get immediate response
    final containsCriticalKeywords = criticalKeywords.any(
      (keyword) => lowerMessage.contains(keyword),
    );

    if (containsCriticalKeywords) {
      // Immediately show help suggestion for critical keywords
      _showHelpSuggestion(highPriority: true);
      return; // Exit early, no need to check other conditions
    }

    // Check for other distress keywords
    final containsDistressKeywords = distressKeywords.any(
      (keyword) => lowerMessage.contains(keyword),
    );

    // Check if current mood is negative
    final isNegativeMood = negativeMoods.contains(mood);

    // If we detect distress or consistently negative moods, show help suggestion
    if (containsDistressKeywords || isNegativeMood) {
      _showHelpSuggestion();
    }
  }

  // Update negative mood counter and check if we should suggest help
  void _updateMoodTracking(String mood) {
    final negativeMoods = ['Sad', 'Angry', 'Anxious'];

    if (negativeMoods.contains(mood)) {
      _consecutiveNegativeMoods++;

      // If user has had several negative moods in a row, suggest help
      if (_consecutiveNegativeMoods >= _negativeThreshold) {
        _showHelpSuggestion();
      }
    } else {
      // Reset counter if mood is positive
      _consecutiveNegativeMoods = 0;
    }
  }

  // Show a suggestion to visit help resources
  void _showHelpSuggestion({bool highPriority = false}) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible:
          !highPriority, // Cannot dismiss by tapping outside if high priority
      builder:
          (context) => AlertDialog(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Icon(
                    highPriority ? Icons.warning : Icons.pets,
                    color:
                        highPriority
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    highPriority
                        ? 'Important support message'
                        : 'A message from your pet',
                    style: GoogleFonts.fredoka(
                      fontWeight: FontWeight.bold,
                      color: highPriority ? Colors.red : null,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    highPriority
                        ? 'Your wellbeing matters. If you\'re thinking about harming yourself, please know that help is available and you are not alone. Let me show you some immediate support resources.'
                        : 'You seem like you\'re having a tough time. Sometimes talking to someone helps. Would you like me to show you some help resources?',
                    style: GoogleFonts.fredoka(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 100,
                    child: Image.asset(
                      highPriority
                          ? 'assets/animations/support_pet.gif'
                          : 'assets/animations/concerned_pet.gif',
                      errorBuilder:
                          (context, error, stackTrace) => Icon(
                            highPriority ? Icons.support : Icons.pets,
                            size: 60,
                            color:
                                highPriority
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              if (!highPriority) // Only show "Not now" for standard priority
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Not now', style: GoogleFonts.fredoka()),
                ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpSupportScreen(),
                    ),
                  );
                },
                style:
                    highPriority
                        ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
                        : null,
                child: Text(
                  highPriority ? 'Get help now' : 'Show resources',
                  style: GoogleFonts.fredoka(
                    color: highPriority ? Colors.white : null,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // Method to be called when processing chat messages
  void _processChatMessage(String message) {
    _checkUserDistress(message, '');
  }

  // Load happiness coins from AttendanceService
  Future<void> _loadHappinessCoins() async {
    try {
      if (!mounted) return;

      final attendanceService = AttendanceService();
      print("[MyHomePage] Loading coins from AttendanceService...");

      // Get current coins for comparison
      final int oldCoins = _totalHappinessCoins;

      final coins = await attendanceService.getTotalCoins();
      print("[MyHomePage] Loaded coins: $coins (previous: $oldCoins)");

      if (mounted) {
        // Only update state if the value has changed to avoid unnecessary rebuilds
        if (coins != oldCoins) {
          setState(() {
            _totalHappinessCoins = coins;
          });

          // Show a subtle message if coins increased
          if (coins > oldCoins) {
            final int earned = coins - oldCoins;
            print("[MyHomePage] Coins increased by $earned");
          }
        } else {
          print("[MyHomePage] Coin count unchanged");
        }
      }
    } catch (e) {
      print("[MyHomePage] Error loading coins: $e");
      // Don't change the current count on error
    }
  }

  // Method to be passed as callback
  void _refreshCoinDisplay() {
    print("[MyHomePage] Refreshing coin display...");
    _loadHappinessCoins();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Explicitly log when the main screen becomes active again
    print("[MyHomePage] didChangeDependencies called - screen is active");

    // Always check for the latest coins when returning to the main screen
    _refreshCoinsDirectlyFromFirestore();
  }

  // New method to force refresh coins directly from Firestore
  Future<void> _refreshCoinsDirectlyFromFirestore() async {
    try {
      final attendanceService = AttendanceService();
      final latestCoins = await attendanceService.getTotalCoins();

      print(
        "[MyHomePage] Directly fetched coins from Firestore: $latestCoins (current: $_totalHappinessCoins)",
      );

      if (mounted && latestCoins != _totalHappinessCoins) {
        setState(() {
          _totalHappinessCoins = latestCoins;
        });
        print("[MyHomePage] Updated coins display with latest value");
      }
    } catch (e) {
      print("[MyHomePage] Error refreshing coins directly: $e");
    }
  }

  // Navigation method
  void _navigateToTasks() {
    final attendanceService = AttendanceService();
    _petModel
        .loadPetData()
        .then((latestPetData) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => PetTasksScreen(
                    petModel: _petModel,
                    petData: latestPetData,
                    attendanceService: attendanceService,
                    onCoinsUpdated: _refreshCoinDisplay,
                  ),
            ),
          ).then((_) {
            // Refresh data when returning
            _initializePet(); // Reloads data and updates stats
            _loadHappinessCoins(); // Refresh coin display too
          });
        })
        .catchError((error) {
          print("Error loading pet data before navigating to tasks: $error");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not load tasks. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
  }

  // --- Cooldown Helper Methods ---

  Duration _getRemainingCooldown(String interactionType) {
    final lastInteraction = _petData['lastInteractionTimes']?[interactionType];
    if (lastInteraction is DateTime) {
      final now = DateTime.now();
      final timePassed = now.difference(lastInteraction);
      print(
        "Cooldown check for '$interactionType': Last interaction was $timePassed ago.",
      );
      return _interactionCooldown - timePassed;
    }
    return Duration.zero; // No cooldown remaining
  }

  void _updateCooldownTimer(String interactionType) {
    // Cancel existing timer for this type if any
    _cooldownTimers[interactionType]?.cancel();

    Duration remaining = _getRemainingCooldown(interactionType);
    if (remaining > Duration.zero) {
      if (mounted) {
        // Check if widget is still mounted
        setState(() {
          _remainingCooldowns[interactionType] = remaining;
        });
      }

      // Start a new timer
      _cooldownTimers[interactionType] = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          if (!mounted) {
            // Check again inside timer callback
            timer.cancel();
            _cooldownTimers.remove(interactionType);
            return;
          }
          final currentRemaining = _getRemainingCooldown(interactionType);
          setState(() {
            _remainingCooldowns[interactionType] = currentRemaining;
          });

          if (currentRemaining <= Duration.zero) {
            timer.cancel();
            _cooldownTimers.remove(interactionType);
            print("Cooldown finished for $interactionType");
            // Final update to ensure button enables
            if (mounted) setState(() {});
          }
        },
      );
    } else {
      // Ensure remaining time is cleared if cooldown ended before timer logic
      if (_remainingCooldowns.containsKey(interactionType)) {
        if (mounted) {
          setState(() {
            _remainingCooldowns.remove(interactionType);
          });
        }
      }
      _cooldownTimers.remove(interactionType); // Remove any stale timer entry
    }
  }

  // Helper to update all timers, useful after loading data
  void _updateAllCooldownTimers() {
    const interactionTypes = ['pet', 'feed', 'play', 'groom'];
    for (var type in interactionTypes) {
      _updateCooldownTimer(type);
    }
  }

  // Combined initialization
  Future<void> _initializePetAndLoadChat() async {
    print(
      '[_initializePetAndLoadChat] Initializing pet and loading today\'s chat...',
    );
    try {
      await _petModel.initializePet();
      print('[_initializePetAndLoadChat] _petModel.initializePet() completed.');
      _petData = await _petModel.loadPetData();
      print('[_initializePetAndLoadChat] _petModel.loadPetData() completed.');

      // --- Load Today's Chat ---
      await _loadTodaysChatHistory();
      // --- End Load Today's Chat ---

      _updatePetStatsFromData(); // Update state, UI, and calculate tasks
      _updateAllCooldownTimers(); // Start/update timers after loading
      print('[_initializePetAndLoadChat] Initial update complete.');
    } catch (e) {
      print('Failed to initialize pet or load chat: $e');
      if (mounted) {
        setState(() {
          _petStatus = 'Error';
          _petsTodayCount = 0;
          _mealsTodayCount = 0;
          _completedTasksCount = 0; // Reset task count on error
          _messages.clear(); // Clear messages on error
          _petData = {
            'happiness': 0,
            'lastInteractionTimes': {},
          }; // Ensure lastInteractionTimes exists
        });
      }
    }
  }

  // New method to load chat history for the current day
  Future<void> _loadTodaysChatHistory() async {
    if (_userId.isEmpty) return; // Don't load if no user
    print("[_loadTodaysChatHistory] Loading chat history for today...");
    final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final List<Map<String, dynamic>> historyData = await _petModel
          .loadChatHistoryForDate(todayString);
      final List<ChatMessage> todaysMessages =
          historyData.map((data) => ChatMessage.fromMap(data)).toList();

      // Sort messages by timestamp just in case they aren't stored perfectly ordered
      todaysMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (mounted) {
        setState(() {
          _messages.clear(); // Clear previous messages (if any)
          _messages.addAll(todaysMessages); // Add loaded messages
        });
        print(
          "[_loadTodaysChatHistory] Loaded ${_messages.length} messages for today.",
        );
      }
    } catch (e) {
      print("Error loading today's chat history: $e");
      if (mounted) {
        setState(() {
          _messages.clear();
        }); // Clear messages on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load today\'s chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Update the old _initializePet to call the new combined one
  Future<void> _initializePet() async {
    await _initializePetAndLoadChat();
  }

  // Add required method implementations for WidgetsBindingObserver
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print("[MyHomePage] App lifecycle state changed to: $state");

    if (state == AppLifecycleState.resumed) {
      print("[MyHomePage] App resumed, refreshing coins");
      _refreshCoinsDirectlyFromFirestore();
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  // Optional: Factory constructor to create from Firestore data
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'] as String? ?? '',
      isUser: map['isUser'] as bool? ?? false,
      // Convert Firestore Timestamp to DateTime, handle potential null
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Optional: Method to convert to a Map for Firestore saving
  // Note: We'll use FieldValue.serverTimestamp() directly when saving for accuracy
  Map<String, dynamic> toMapForSave() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': FieldValue.serverTimestamp(), // Use server time when saving
    };
  }
}

class BubbleTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.95)
          ..style = PaintingStyle.fill;

    final path =
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width / 2, size.height)
          ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
