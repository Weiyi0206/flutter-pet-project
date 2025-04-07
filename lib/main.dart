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
import 'widgets/happiness_meter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'screens/tests_list_screen.dart'; 
import 'services/attendance_service.dart';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'services/gemini_service.dart';
import 'screens/chat_history_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/diary_screen.dart'; // Add this import
import 'services/emotion_service.dart';


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
  int _happiness = 50;
  String _petStatus = 'Normal';
  String? _currentMood;
  final TextEditingController _chatController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final List<ChatMessage> _messages = [];
  String? _currentResponse;
  String? _lastUserMessage;
  bool _isVisualizationActive = false;
  bool _hasCompletedActivityToday = false;
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
  final List<Map<String, String>> _dailyTips = [
    {
      'text': '''Quick Breath! 🧘‍♂️
• In (4s)
• Hold (4s)
• Out (4s)
Let's do it!''',
      'category': 'breathing',
    },
    {
      'text': '''Self-Care Check 💧
• Water?
• Stretch?
• Break?
Take care!''',
      'category': 'self-care',
    },
    {
      'text': '''Quick Move! 🤸‍♂️
Choose:
• 10 stretches
• 30s march
• Short walk''',
      'category': 'exercise',
    },
    {
      'text': '''Mindful Moment 😊
Notice:
• 3 sights
• 2 touches
• 1 sound''',
      'category': 'mindfulness',
    },
    {
      'text': '''Present Time 🌟
• Deep breath
• Feel body
• Let thoughts go''',
      'category': 'mindfulness',
    },
    {
      'text': '''Eye Break! 👀
20-20-20:
• Look away
• 20 feet far
• 20 seconds''',
      'category': 'self-care',
    },
    {
      'text': '''Gratitude 🙏
Think of:
• A friend
• A win
• A joy''',
      'category': 'mindfulness',
    },
    {
      'text': '''Move Time! 🚶‍♂️
Pick one:
• Quick walk
• Stretches
• Desk moves''',
      'category': 'exercise',
    },
  ];

  List<Map<String, String>> _unusedTips = [];

  final List<String> _companionshipPrompts = [
    "How was your day? I'd love to hear about it!",
    "Want to tell me something interesting you learned today?",
    "I've been waiting to chat with you! What's on your mind?",
    "I missed you! Want to play a game or just chat?",
    "I'm here for you. Want to talk about anything?",
    "Sometimes just sharing your thoughts can help. What's going on in your world?",
  ];

  int _connectionStreak = 0;
  DateTime? _lastConnectionDate;

  bool _isBreathingExerciseActive = false;
  int _breathingStep = 0;
  int _breathingCount = 0;

  List<Map<String, dynamic>> _achievements = [];
  int _achievementPoints = 0;
  int _totalHappinessCoins = 0; // Add this line to track happiness coins

  final Map<String, bool> _dailyRoutineItems = {
    "Morning check-in": false,
    "Hydration reminder": false,
    "Movement break": false,
    "Evening reflection": false,
  };

  final List<String> _affirmations = [
    "You are enough just as you are.",
    "You're doing better than you think.",
    "Small steps forward are still progress.",
    "Your worth isn't measured by productivity.",
    "It's okay to be a work in progress.",
    "You deserve kindness, especially from yourself.",
    "Your feelings are valid and important.",
    "You have unique strengths that matter.",
  ];

  final EmotionService _emotionService = EmotionService();


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

    // Initialize pet status
    _updatePetStatus();

    // Check connection to AI service
    _checkAIConnection();

    // Optional: Keep basic tips for pet care
    _startTipTimer();

    // Schedule companionship prompts
    Timer.periodic(const Duration(minutes: 60), (timer) {
      if (mounted && _currentResponse == null) {
        final rand = _random.nextDouble();
        if (rand < 0.4) {  // 40% chance each hour
          _showCompanionshipPrompt();
        }
      }
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _chatController.dispose();
    // Cancel any active exercises
    _isBreathingExerciseActive = false;
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

  void _startTipTimer() {
    Future.delayed(const Duration(seconds: 10), () {
      _showRandomTip();
    });

    _tipTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _showRandomTip();
    });
  }

  void _showRandomTip() {
    if (!mounted) return;

    if (_unusedTips.isEmpty) {
      _unusedTips = List.from(_dailyTips);
    }

    final randomIndex = _random.nextInt(_unusedTips.length);
    final tip = _unusedTips[randomIndex];
    _unusedTips.removeAt(randomIndex);

    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _currentResponse = tip['text'];
      _messages.add(
        ChatMessage(text: tip['text']!, isUser: false, timestamp: timeString),
      );
    });

    Future.delayed(const Duration(seconds: 20), () {
      if (mounted && _currentResponse == tip['text']) {
        setState(() {
          _currentResponse = null;
        });
      }
    });
  }

  void _petThePet() {
    setState(() {
      _happiness = min(_happiness + 10, 100);
      _updatePetStatus();
    });
  }

  void _feedThePet() {
    setState(() {
      _happiness = min(_happiness + 15, 100);
      _updatePetStatus();
    });
  }

  void _updatePetStatus() {
    if (_happiness >= 80) {
      _petStatus = 'Happy';
    } else if (_happiness >= 40) {
      _petStatus = 'Normal';
    } else {
      _petStatus = 'Sad';
    }
  }

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
        setState(() {
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
              // No negative adjustment - don't penalize negative emotions
              // Instead give a small boost for sharing
              _happiness = min(_happiness + 1, 100);
            }
          }

          _updatePetStatus();
        });

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

  void _updateConnectionStreak() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastConnectionDate != null) {
      final yesterday = today.subtract(const Duration(days: 1));
      final lastDate = DateTime(
        _lastConnectionDate!.year,
        _lastConnectionDate!.month,
        _lastConnectionDate!.day,
      );

      if (lastDate.isAtSameMomentAs(yesterday)) {
        // User connected yesterday, increment streak
        _connectionStreak++;
      } else if (lastDate.isBefore(yesterday)) {
        // User missed a day, reset streak
        _connectionStreak = 1;
      }
      // If they already connected today, do nothing
    } else {
      // First time connecting
      _connectionStreak = 1;
    }

    _lastConnectionDate = now;

    // Save to persistent storage (implement this later)
  }

  void _addAchievement(
    String title, {
    IconData icon = Icons.star,
    Color color = Colors.amber,
    int points = 5,
  }) {
    final now = DateTime.now();
    final dateString = '${now.day}/${now.month}/${now.year}';

    setState(() {
      _achievements.add({
        'title': title,
        'icon': icon,
        'color': color,
        'date': dateString,
        'points': points,
      });

      _achievementPoints += points;
      _happiness = min(_happiness + points, 100);
      _updatePetStatus();

      // Show celebration
      _currentResponse = "Achievement unlocked: $title (+$points points)! 🎉";
    });

    // Update happiness coins from achievements
    _updateAchievementCoins(points);

    // Clear message after delay
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted &&
          _currentResponse?.contains("Achievement unlocked") == true) {
        setState(() {
          _currentResponse = null;
        });
      }
    });
  }
  // Update happiness coins from achievements
  Future<void> _updateAchievementCoins(int points) async {
    final attendanceService = AttendanceService();

    // First refresh the current coin count
    await _loadHappinessCoins();

    // We don't actually need to update coins here since achievements
    // don't directly add to the happiness coins, but we refresh the display
    // in case other activities have affected the coins
  }

  void _showSmallActivityPrompt() {
    final activities = [
      "Could you drink a glass of water? Even small self-care steps matter!",
      "How about opening a window for some fresh air? It might feel nice.",
      "Maybe stretch your arms up high for just 10 seconds?",
      "Could you name one tiny thing you're grateful for today?",
      "How about sending a quick message to someone you care about?",
    ];

    final activity = activities[_random.nextInt(activities.length)];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Small Step Forward',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  activity,
                  style: GoogleFonts.fredoka(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Maybe Later',
                        style: GoogleFonts.fredoka(color: Colors.grey),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _addAchievement("Completed a small activity");
                        setState(() {
                          _hasCompletedActivityToday = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: Text(
                        'I Did It!',
                        style: GoogleFonts.fredoka(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  void _startVisualizationExercise() {
    _isVisualizationActive = true;

    final visualizationSteps = [
      "Let's take a moment to relax. Close your eyes if you'd like.",
      "Imagine you're in a peaceful place. Maybe a beach, forest, or anywhere you feel calm.",
      "Notice the colors around you in this peaceful place.",
      "Feel the temperature. Is it warm or cool?",
      "Listen to the sounds in your peaceful place.",
      "Take a deep breath and enjoy this moment of calm.",
      "When you're ready, gently bring your awareness back to the present.",
      "You can return to this peaceful place anytime you need a moment of calm.",
    ];

    _runSequentialMessages(visualizationSteps, const Duration(seconds: 10));

    // End visualization after all steps
    Future.delayed(Duration(seconds: 10 * visualizationSteps.length), () {
      if (mounted) {
        setState(() {
          _isVisualizationActive = false;
          _currentResponse = null;
        });
      }
    });
  }

  void _showQuickStressRelief() {
    final reliefOptions = [
      {
        "title": "Shoulder Roll",
        "description":
            "Roll your shoulders forward 5 times, then backward 5 times to release tension.",
      },
      {
        "title": "Hand Massage",
        "description":
            "Gently massage your hand for 30 seconds, focusing on any tense areas.",
      },
      {
        "title": "Jaw Release",
        "description":
            "Let your jaw relax completely for 10 seconds. Notice any tension you're holding there.",
      },
      {
        "title": "Quick Stretch",
        "description":
            "Reach your arms up high, then slowly lower them while taking a deep breath.",
      },
    ];

    final option = reliefOptions[_random.nextInt(reliefOptions.length)];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              option["title"]!,
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  option["description"]!,
                  style: GoogleFonts.fredoka(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _addAchievement("Used a stress relief technique");
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: Text(
                    'I Feel Better',
                    style: GoogleFonts.fredoka(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showRoutineTracker() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(
                    'Daily Routine',
                    style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ..._dailyRoutineItems.entries.map(
                        (entry) => CheckboxListTile(
                          title: Text(entry.key, style: GoogleFonts.fredoka()),
                          value: entry.value,
                          activeColor: Colors.green,
                          onChanged: (bool? value) {
                            setState(() {
                              _dailyRoutineItems[entry.key] = value ?? false;
                            });

                            // Update in parent state too
                            this.setState(() {});

                            // If completed all items
                            if (!_dailyRoutineItems.values.contains(false)) {
                              Future.delayed(
                                const Duration(milliseconds: 500),
                                () {
                                  Navigator.pop(context);
                                  _addAchievement("Completed daily routine");
                                },
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Completing your routine helps your pet stay happy!',
                        style: GoogleFonts.fredoka(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close', style: GoogleFonts.fredoka()),
                    ),
                  ],
                ),
          ),
    );
  }

  void _checkRoutineProgress() {
    // Count completed items
    final completedCount = _dailyRoutineItems.values.where((v) => v).length;
    final totalCount = _dailyRoutineItems.length;

    // If less than half completed and it's afternoon
    final now = DateTime.now();
    if (completedCount < totalCount / 2 && now.hour >= 14 && now.hour <= 20) {
      setState(() {
        _currentResponse =
            "Don't forget about your daily routine! It helps both of us stay happy and healthy.";
      });

      // Clear message after delay
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _currentResponse?.contains("routine") == true) {
          setState(() {
            _currentResponse = null;
          });
        }
      });
    }
  }

  void _showAffirmation() {
    final affirmation = _affirmations[_random.nextInt(_affirmations.length)];

    setState(() {
      _currentResponse = "Remember: $affirmation";
    });

    // Clear message after delay
    Future.delayed(const Duration(seconds: 12), () {
      if (mounted && _currentResponse?.contains("Remember:") == true) {
        setState(() {
          _currentResponse = null;
        });
      }
    });
  }

  void _promptStrengthRecognition() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Your Strengths',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'What\'s one small thing you did well today?',
                  style: GoogleFonts.fredoka(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'I did well at...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      Navigator.pop(context);
                      _addAchievement("Recognized a personal strength");

                      // Pet responds with encouragement
                      _geminiService.getStrengthResponse(value).then((
                        response,
                      ) {
                        setState(() {
                          _currentResponse = response;
                        });

                        // Clear message after delay
                        Future.delayed(const Duration(seconds: 15), () {
                          if (mounted && _currentResponse == response) {
                            setState(() {
                              _currentResponse = null;
                            });
                          }
                        });
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Recognizing your strengths builds confidence!',
                  style: GoogleFonts.fredoka(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Maybe Later', style: GoogleFonts.fredoka()),
              ),
            ],
          ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

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
                                      icon: Icons.lightbulb,
                                      label: 'Tips',
                                      onPressed:
                                          () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      const DailyTipsScreen(),
                                            ),
                                          ),
                                      color: Colors.amber,
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
                                  ],
                                ),
                                SizedBox(height: constraints.maxHeight * 0.02),
                                // Bottom row with remaining buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildFeatureButton(
                                      icon: Icons.pets,
                                      label: 'Pet',
                                      onPressed: _petThePet,
                                      color: Colors.purple,
                                      size: isSmallScreen ? 40 : 50,
                                    ),
                                    SizedBox(
                                      width: constraints.maxWidth * 0.05,
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
                                      color: Colors.indigo,
                                      size: isSmallScreen ? 40 : 50,
                                    ),                                  
                                    SizedBox(
                                      width: constraints.maxWidth * 0.05,
                                    ),
                                    _buildFeatureButton(
                                      icon: Icons.restaurant,
                                      label: 'Feed',
                                      onPressed: _feedThePet,
                                      color: Colors.orange,
                                      size: isSmallScreen ? 40 : 50,
                                    ),
                                    SizedBox(
                                      width: constraints.maxWidth * 0.05,
                                    ),
                                    _buildFeatureButton(
                                      icon: Icons.chat_bubble_outline,
                                      label: 'Talk to Me',
                                      onPressed: _showCompanionshipPrompt,
                                      color: Colors.blue,
                                      size: isSmallScreen ? 40 : 50,
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
                                      // Today's activities
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildActivityStat(
                                            icon: Icons.pets,
                                            label: 'Pets today',
                                            value: '${_random.nextInt(10) + 5}',
                                            color: Colors.purple,
                                            constraints: constraints,
                                          ),
                                          _buildActivityStat(
                                            icon: Icons.restaurant,
                                            label: 'Meals',
                                            value:
                                                '${_random.nextInt(3) + 1}/3',
                                            color: Colors.orange,
                                            constraints: constraints,
                                          ),
                                          _buildActivityStat(
                                            icon: Icons.favorite,
                                            label: 'Mood',
                                            value: _petStatus,
                                            color: _getStatusTextColor(),
                                            constraints: constraints,
                                          ),
                                        ],
                                      ),

                                      SizedBox(
                                        height: constraints.maxHeight * 0.015,
                                      ),

                                      // Daily streak
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical:
                                              constraints.maxHeight * 0.01,
                                          horizontal:
                                              constraints.maxWidth * 0.03,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.local_fire_department,
                                              color: Colors.orange,
                                              size: constraints.maxWidth * 0.05,
                                            ),
                                            SizedBox(
                                              width:
                                                  constraints.maxWidth * 0.02,
                                            ),
                                            Text(
                                              'Connection streak: $_connectionStreak days',
                                              style: GoogleFonts.fredoka(
                                                fontSize:
                                                    constraints.maxWidth *
                                                    0.035,
                                                color: Colors.orange.shade800,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
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
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    double size = 50,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: color),
            onPressed: onPressed,
            iconSize: size * 0.6,
            padding: EdgeInsets.all(size * 0.2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.fredoka(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  void _showMoodTracker() {
    final moodOptions = [
      {'emoji': '😊', 'label': 'Happy', 'color': Colors.yellow},
      {'emoji': '😌', 'label': 'Calm', 'color': Colors.blue.shade300},
      {'emoji': '😐', 'label': 'Neutral', 'color': Colors.grey.shade400},
      {'emoji': '😔', 'label': 'Sad', 'color': Colors.indigo.shade300},
      {'emoji': '😡', 'label': 'Angry', 'color': Colors.red.shade400},
      {'emoji': '😰', 'label': 'Anxious', 'color': Colors.purple.shade300},
    ];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'How are you feeling today?',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                // Emoji mood selector
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 15,
                  children:
                      moodOptions.map((mood) {
                        return InkWell(
                          onTap: () async {
                            // Make async
                            final attendanceService = AttendanceService();

                            // Mark attendance with mood
                            final result = await attendanceService
                                .markAttendanceWithMood(
                                  mood['label'] as String,
                                );

                            if (!mounted) return;
                            Navigator.pop(context);

                            // Record mood and show pet response
                            _recordMood(mood['label'] as String);

                            if (result.success) {
                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result.message),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // If there's a reward, show reward dialog
                              if (result.reward != null) {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('🎉 Reward!'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'You earned: ${result.reward!.name}',
                                          ),
                                          Text(
                                            'Happiness boost: +${result.reward!.happinessBoost}',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          child: Text(
                                            'Great!',
                                            style: GoogleFonts.fredoka(),
                                          ),
                                          onPressed:
                                              () => Navigator.pop(context),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }

                              // Update happiness coins count
                              _loadHappinessCoins();
                            }
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (mood['color'] as Color).withOpacity(
                                    0.2,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  mood['emoji'] as String,
                                  style: const TextStyle(fontSize: 30),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                mood['label'] as String,
                                style: GoogleFonts.fredoka(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Maybe Later', style: GoogleFonts.fredoka()),
              ),
            ],
          ),
    );
  }

  void _recordMood(String mood) {
    print('DEBUG: _recordMood called with mood: $mood');
    
    // Update local state
    _currentMood = mood;
      
    // Generate response based on mood
    String response;
    if (mood == "Happy" || mood == "Calm") {
      response = "I'm glad you're feeling $mood today! That's wonderful!";
      _happiness = min(_happiness + 5, 100);
    } else if (mood == "Sad" || mood == "Angry" || mood == "Anxious") {
      response = "I see you're feeling $mood. Remember I'm here for you.";
      // Give a smaller happiness boost for sharing difficult emotions
      _happiness = min(_happiness + 2, 100);
    } else {
      response = "Thanks for sharing how you're feeling today!";
      _happiness = min(_happiness + 3, 100);
    }
    
    // Update UI with response
    setState(() {
      _currentResponse = response;
      _updatePetStatus();
    });
    
    // Send mood to Gemini service for contextual awareness in future interactions
    _geminiService.getCheckInResponse(mood).then((aiResponse) {
      // Update the response after a small delay to show the initial acknowledgment first
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _currentResponse = aiResponse;
            
            // Clear message after delay
            Future.delayed(const Duration(seconds: 12), () {
              if (mounted && _currentResponse == aiResponse) {
                setState(() {
                  _currentResponse = null;
                });
              }
            });
          });
        }
      });
    });
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
      setState(() {
        _totalHappinessCoins = coins;
      });
    }
  }

  void _startBreathingExercise() {
    // Implementation for breathing exercise
  }

  void _startGroundingExercise() {
    // Implementation for grounding exercise
  }

  void _showStressReliefOptions() {
    // Implementation for stress relief options
  }

  void _showSelfEsteemBuilder() {
    // Implementation for self esteem builder
  }

  void _toggleInteractionsPanel() {
    // Implementation for toggling interactions panel
  }

  void _runSequentialMessages(List<String> messages, Duration delay) {
    // Implementation for running sequential messages
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
