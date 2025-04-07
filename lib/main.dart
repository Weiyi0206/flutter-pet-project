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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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

class _MyHomePageState extends State<MyHomePage> {
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

  int _happiness = 50; // Keep happiness for fallback mood calculation
  String _petStatus = 'Normal';
  String? _currentResponse;
  String? _lastUserMessage;
  int _consecutiveNegativeChats = 0;
  final int _negativeThreshold = 3;
  int _consecutiveNegativeMoods = 0;

  // Emotion detection keywords
  final List<String> lonelyWords = ['lonely', 'alone', 'no one', 'by myself', 'no friends', 'isolated'];
  final List<String> sadWords = ['sad', 'unhappy', 'depressed', 'down', 'blue', 'miserable'];
  final List<String> anxiousWords = ['anxious', 'nervous', 'worry', 'worried', 'stress', 'stressed'];
  final List<String> angryWords = ['angry', 'mad', 'furious', 'rage', 'hate', 'annoyed'];
  final List<String> happyWords = ['happy', 'joy', 'excited', 'great', 'good', 'wonderful'];

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
  static const Duration _interactionCooldown = Duration(minutes: 1); // Example: 1 minute cooldown

  // --- Cooldown State ---
  final Map<String, Timer> _cooldownTimers = {}; // Store active timers
  final Map<String, Duration> _remainingCooldowns = {}; // Store remaining durations for display

  @override
  void initState() {
    super.initState();

    void showInitialCheckIn() async {
      final attendanceService = AttendanceService();

      if (await attendanceService.shouldShowCheckInPrompt()) {
        if (!mounted) return;

        // Navigate to the attendance screen instead of showing mood tracker
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AttendanceScreen()),
        );
      }
    }

    // Load happiness coins
    _loadHappinessCoins();

    // Show check-in prompt after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showInitialCheckIn();
    });

    // Initialize pet data and status/stats
    _initializePet();

    // Check connection to AI service
    _checkAIConnection();

    // Schedule companionship prompts
    Timer.periodic(const Duration(minutes: 60), (timer) {
      if (mounted && _currentResponse == null) {
        final rand = _random.nextDouble();
        if (rand < 0.4) {  // 40% chance each hour
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
      print('[_updatePetStatsFromData] Updated state: _petsTodayCount=$_petsTodayCount, _mealsTodayCount=$_mealsTodayCount');

      // Update mood status based on petData first, then fallback to happiness
      if (_petData.isNotEmpty && _petData.containsKey('mood')) {
        _petStatus = _petData['mood'] as String? ?? 'Normal';
        // --- Add log ---
        print('[_updatePetStatsFromData] Updated state: _petStatus=$_petStatus (from _petData)');
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
        print('[_updatePetStatsFromData] Updated state: _petStatus=$_petStatus (from fallback)');
      }
      // Note: _happiness itself might need to be loaded from _petData too
      // _happiness = _petData['happiness'] as int? ?? 50;
    });
  }

  // --- Helper to check cooldown ---
  bool _isOnCooldown(String interactionType) {
    final lastInteraction = _petData['lastInteractionTimes']?[interactionType];
    if (lastInteraction is DateTime) { // Check if it's a DateTime object
      final now = DateTime.now();
      final difference = now.difference(lastInteraction);
      print("Cooldown check for '$interactionType': Last interaction was $difference ago.");
      return difference < _interactionCooldown;
    }
    return false; // Not on cooldown if no last interaction time found
  }

  // --- Helper to show cooldown message ---
  void _showCooldownMessage(String actionName) {
     if (!mounted) return;
     final lastInteraction = _petData['lastInteractionTimes']?[actionName.toLowerCase()];
     String message = '$actionName is on cooldown.';
     if (lastInteraction is DateTime) {
        final timeRemaining = _interactionCooldown - DateTime.now().difference(lastInteraction);
        if (timeRemaining.inSeconds > 0) {
           message = '$actionName is resting. Try again in ${timeRemaining.inSeconds} seconds.';
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
    // Cooldown check already handled by button state, but keep for safety
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
      _updatePetStatsFromData();
      _updateCooldownTimer('pet'); // Update timer after action
    } catch (e) {
      print('Error petting pet: $e');
      if (mounted) { // Show error to user
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error petting pet: $e'), backgroundColor: Colors.red),
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
      _updatePetStatsFromData();
      _updateCooldownTimer('feed'); // Update timer after action
    } catch (e) {
      print('Error feeding pet: $e');
       if (mounted) { // Show error to user
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error feeding pet: $e'), backgroundColor: Colors.red),
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
      _updatePetStatsFromData();
      _updateCooldownTimer('play'); // Update timer after action
    } catch (e) {
      print('Error playing with pet: $e');
       if (mounted) { // Show error to user
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error playing with pet: $e'), backgroundColor: Colors.red),
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
      _updatePetStatsFromData();
      _updateCooldownTimer('groom'); // Update timer after action
    } catch (e) {
      print('Error grooming pet: $e');
       if (mounted) { // Show error to user
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error grooming pet: $e'), backgroundColor: Colors.red),
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

    final userMessage = _chatController.text;
    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Enhanced mood detection from the message
    final moodResult = _detectMoodFromText(userMessage);
    final hasEmotionalContent = moodResult['lonely'] == true || 
                               moodResult['anxious'] == true || 
                               moodResult['sad'] == true || 
                               moodResult['angry'] == true;
    final detectedMood = moodResult['mood'];

    // Check for signs of distress in the message
    _processChatMessage(userMessage);

    // Store the message in history
    setState(() {
      _messages.add(
        ChatMessage(text: userMessage, isUser: true, timestamp: timeString),
      );
      _lastUserMessage = userMessage;
      _chatController.clear();

      // Clear any previous response while waiting for new one
      _currentResponse = null;
    });

    try {
      String response;
      
      // Use the enhanced mental health response if emotional content is detected
      if (hasEmotionalContent) {
        response = await _geminiService.getMentalHealthResponse(userMessage, moodResult);
      } else {
        // Otherwise use the standard chat response
        response = await _geminiService.getChatResponse(
          userMessage,
          _happiness,
          _petStatus,
          moodResult['lonely'] ?? false,
        );
      }

      // Store the response in history and show it
      if (mounted) {
        // Reload pet data after interaction (optional, depends if chat affects stats)
        // _petData = await _petModel.loadPetData();

        setState(() { // Keep setState for message list updates
          _messages.add(
            ChatMessage(text: response, isUser: false, timestamp: timeString),
          );
          _currentResponse = response;

          // Adjust happiness based on detected mood - reward the user for sharing
          if (hasEmotionalContent) {
            _happiness = min(_happiness + 5, 100); // Happiness boost for emotional sharing
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

        // Update pet stats/status based on potentially changed happiness/data
        _updatePetStatsFromData(); // Call this AFTER state updates potentially affecting mood

        // Remove pet response after a delay
        Future.delayed(const Duration(seconds: 15), () {
          if (mounted && _currentResponse == response) {
            setState(() {
              _currentResponse = null;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
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
    final Duration petCooldownRemaining = _remainingCooldowns['pet'] ?? _getRemainingCooldown('pet');
    final Duration feedCooldownRemaining = _remainingCooldowns['feed'] ?? _getRemainingCooldown('feed');
    final Duration playCooldownRemaining = _remainingCooldowns['play'] ?? _getRemainingCooldown('play');
    final Duration groomCooldownRemaining = _remainingCooldowns['groom'] ?? _getRemainingCooldown('groom');

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
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Daily Attendance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AttendanceScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            tooltip: 'Tips',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DailyTipsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Chat History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatHistoryScreen(messages: _messages),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
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
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => AttendanceScreen()),
                                        );
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
                                            builder: (context) => const DiaryScreen(),
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
                                      onPressed: isPettingOnCooldown ? null : _petThePet,
                                      color: Colors.purple,
                                      size: isSmallScreen ? 40 : 50,
                                      disabled: isPettingOnCooldown,
                                      cooldownRemaining: petCooldownRemaining, // Pass remaining time
                                    ),
                                    SizedBox(
                                      width: constraints.maxWidth * 0.05,
                                    ),
                                    _buildFeatureButton(
                                      icon: Icons.sports_esports,
                                      label: 'Play',
                                      onPressed: (isPlayingOnCooldown || _petData.isEmpty) ? null : _playWithPet,
                                      color: Colors.blue,
                                      size: isSmallScreen ? 40 : 50,
                                      disabled: isPlayingOnCooldown,
                                      cooldownRemaining: playCooldownRemaining, // Pass remaining time
                                    ),
                                    SizedBox(
                                      width: constraints.maxWidth * 0.05,
                                    ),
                                    _buildFeatureButton(
                                      icon: Icons.restaurant,
                                      label: 'Feed',
                                      onPressed: isFeedingOnCooldown ? null : _feedThePet,
                                      color: Colors.orange,
                                      size: isSmallScreen ? 40 : 50,
                                      disabled: isFeedingOnCooldown,
                                      cooldownRemaining: feedCooldownRemaining, // Pass remaining time
                                    ),
                                    SizedBox(
                                      width: constraints.maxWidth * 0.05,
                                    ),
                                    _buildFeatureButton(
                                      icon: Icons.cleaning_services,
                                      label: 'Groom',
                                      onPressed: (isGroomingOnCooldown || _petData.isEmpty) ? null : _groomPet,
                                      color: Colors.green,
                                      size: isSmallScreen ? 40 : 50,
                                      disabled: isGroomingOnCooldown,
                                      cooldownRemaining: groomCooldownRemaining, // Pass remaining time
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
                                            value: '$_mealsTodayCount/$_maxMealsPerDay',
                                            color: Colors.orange,
                                            constraints: constraints,
                                          ),
                                          _buildActivityStat(
                                            icon: Icons.favorite,
                                            label: 'Mood',
                                            // --- Remains the same ---
                                            value: _petStatus,
                                            color: _getStatusTextColor(),
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
                                          color: _getStatusTextColor().withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: _getStatusTextColor().withOpacity(0.5)
                                          )
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              // Choose an icon for happiness
                                              Icons.favorite,
                                              color: _getStatusTextColor(), // Use mood color
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
                                                color: _getStatusTextColor().withOpacity(0.9),
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
                          hintStyle: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: screenSize.width * 0.04,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: screenSize.width * 0.05,
                            vertical: screenSize.height * 0.015,
                          ),
                        ),
                        style: TextStyle(fontSize: screenSize.width * 0.04),
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
    final bool showTimer = disabled && cooldownRemaining != null && cooldownRemaining > Duration.zero;

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
            child: Center( // Center the icon or timer text
              child: showTimer
                  ? Text(
                      '${cooldownRemaining.inSeconds}', // Display remaining seconds
                      style: GoogleFonts.fredoka(
                        fontSize: size * 0.4, // Adjust font size relative to button size
                        fontWeight: FontWeight.bold,
                        color: effectiveColor,
                      ),
                    )
                  : IconButton( // Use IconButton for standard behavior (tooltip, padding)
                      icon: Icon(icon, color: effectiveColor),
                      onPressed: onPressed,
                      iconSize: size * 0.6,
                      padding: EdgeInsets.zero, // Use Center for positioning
                      tooltip: disabled ? '$label (Resting)' : label,
                      splashRadius: size * 0.7, // Adjust splash radius if needed
                    ),
            )
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.fredoka(fontSize: 12, color: Colors.grey.shade700),
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
    final attendanceService = AttendanceService();
    final coins = await attendanceService.getTotalCoins();
    if (mounted) {
      print("[MyHomePage] Reloaded coins: $coins");
      setState(() {
        _totalHappinessCoins = coins;
      });
    }
  }

  // Method to be passed as callback
  void _refreshCoinDisplay() {
     _loadHappinessCoins();
  }

  // Navigation method
  void _navigateToTasks() {
     final attendanceService = AttendanceService();
     _petModel.loadPetData().then((latestPetData) {
        if (!mounted) return;
        Navigator.push(
           context,
           MaterialPageRoute(
              builder: (context) => PetTasksScreen(
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
     }).catchError((error) {
        print("Error loading pet data before navigating to tasks: $error");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not load tasks. Please try again.'), backgroundColor: Colors.red),
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
      if (timePassed < _interactionCooldown) {
        return _interactionCooldown - timePassed;
      }
    }
    return Duration.zero; // No cooldown remaining
  }

  void _updateCooldownTimer(String interactionType) {
    // Cancel existing timer for this type if any
    _cooldownTimers[interactionType]?.cancel();

    Duration remaining = _getRemainingCooldown(interactionType);
    if (remaining > Duration.zero) {
      if (mounted) { // Check if widget is still mounted
         setState(() {
             _remainingCooldowns[interactionType] = remaining;
         });
      }

      // Start a new timer
      _cooldownTimers[interactionType] = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) { // Check again inside timer callback
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
      });
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

  // Override _initializePet and interaction methods to update timers after loading data
  Future<void> _initializePet() async {
    print('[_initializePet] Initializing pet...');
    try {
      await _petModel.initializePet();
      print('[_initializePet] _petModel.initializePet() completed.');
      _petData = await _petModel.loadPetData();
      print('[_initializePet] _petModel.loadPetData() completed.');
      _updatePetStatsFromData(); // Update state and UI
      _updateAllCooldownTimers(); // Start/update timers after loading
      print('[_initializePet] Initial update complete.');
    } catch (e) {
      print('Failed to initialize pet: $e');
      if (mounted) {
          setState(() {
             _petStatus = 'Error';
             _petsTodayCount = 0;
             _mealsTodayCount = 0;
             // Initialize _petData to avoid null errors in build
             _petData = {'happiness': 0, 'lastInteractionTimes': {}}; // Ensure lastInteractionTimes exists
          });
      }
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
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
