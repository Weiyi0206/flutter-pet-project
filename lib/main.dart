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
import 'widgets/animated_chat_bubble.dart';
import 'widgets/happiness_meter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'screens/tests_list_screen.dart'; // Add this import
import 'services/attendance_service.dart';

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
  final TextEditingController _chatController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final List<ChatMessage> _messages = [];
  String? _currentResponse;
  String? _lastUserMessage;

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
  final ScrollController _scrollController = ScrollController();

  bool _hasCheckedInToday = false;
  DateTime? _lastCheckInDate;
  String? _currentMood;
  final List<String> _moodOptions = [
    '😊 Happy',
    '😐 Neutral',
    '😔 Sad',
    '😰 Anxious',
    '😴 Tired',
    '🤔 Confused',
  ];

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
  bool _hasCompletedActivityToday = false;
  int _achievementPoints = 0;

  bool _isVisualizationActive = false;

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

  bool _showInteractionsPanel = false;

  void _toggleInteractionsPanel() {
    setState(() {
      _showInteractionsPanel = !_showInteractionsPanel;
    });
  }

  @override
  void initState() {
    super.initState();

    void _showInitialCheckIn() async {
      final attendanceService = AttendanceService();

      if (await attendanceService.shouldShowCheckInPrompt()) {
        if (!mounted) return;

        _showMoodTracker(); // This uses your existing mood tracker dialog
      }
    }

    // Show check-in prompt after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInitialCheckIn();
    });

    // Initialize pet status
    _updatePetStatus();

    // Check connection to AI service
    _checkAIConnection();

    // Start tip timer
    _startTipTimer();

    // Schedule routine check
    Timer.periodic(const Duration(hours: 3), (timer) {
      if (mounted) {
        _checkRoutineProgress();
      }
    });

    // Schedule random wellness prompts
    Timer.periodic(const Duration(minutes: 45), (timer) {
      if (mounted && _currentResponse == null) {
        // Choose a random support feature based on time of day and randomness
        final now = DateTime.now();
        final rand = _random.nextDouble();

        if (now.hour < 10 && rand < 0.3) {
          // Morning: Routine reminder
          _showRoutineTracker();
        } else if (now.hour >= 10 && now.hour < 14 && rand < 0.3) {
          // Mid-day: Stress relief
          _showQuickStressRelief();
        } else if (now.hour >= 14 && now.hour < 18 && rand < 0.3) {
          // Afternoon: Small activity
          _showSmallActivityPrompt();
        } else if (now.hour >= 18 && rand < 0.3) {
          // Evening: Affirmation or breathing
          if (_random.nextBool()) {
            _showAffirmation();
          } else {
            _startBreathingExercise();
          }
        } else if (rand < 0.2) {
          // Random companionship prompt
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
    _isVisualizationActive = false;
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

    // Detect mood from the message
    final moodResult = _detectMoodFromText(userMessage);
    final mightBeLonely = moodResult['lonely'] ?? false;
    final detectedMood = moodResult['mood'];

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
      // Get response from AI service
      final response = await _geminiService.getChatResponse(
        userMessage,
        _happiness,
        _petStatus,
        mightBeLonely,
      );

      // Store the response in history and show it
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(text: response, isUser: false, timestamp: timeString),
          );
          _currentResponse = response;

          // Adjust happiness based on detected mood
          if (mightBeLonely) {
            _happiness = min(
              _happiness + 5,
              100,
            ); // Small happiness boost for sharing
          }

          // Additional happiness adjustments based on detected mood
          if (detectedMood != null) {
            if (detectedMood == 'positive') {
              _happiness = min(_happiness + 3, 100);
            } else if (detectedMood == 'negative') {
              _happiness = max(_happiness - 2, 0);
            }
          }

          _updatePetStatus();
        });

        // Remove pet response after 15 seconds
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
                  decoration: InputDecoration(
                    hintText: 'Share your mood...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      Navigator.pop(context);

                      // Update routine item
                      setState(() {
                        _dailyRoutineItems["Morning check-in"] = true;
                      });

                      // Get AI response to check-in
                      _geminiService.getCheckInResponse(value).then((response) {
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
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Maybe Later', style: GoogleFonts.fredoka()),
              ),
            ],
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

  void _startBreathingExercise() {
    setState(() {
      _isBreathingExerciseActive = true;
      _breathingStep = 0;
      _breathingCount = 0;
      _currentResponse =
          "Let's take a few deep breaths together. Follow my lead...";
    });

    // Start the breathing cycle
    _runBreathingCycle();
  }

  void _runBreathingCycle() {
    if (!_isBreathingExerciseActive || !mounted) return;

    // Update the breathing instruction
    setState(() {
      switch (_breathingStep) {
        case 0: // Inhale
          _currentResponse = "Breathe in slowly... 1... 2... 3... 4...";
          break;
        case 1: // Hold
          _currentResponse = "Hold... 1... 2... 3... 4...";
          break;
        case 2: // Exhale
          _currentResponse = "Breathe out slowly... 1... 2... 3... 4...";
          break;
      }
    });

    // Move to next step after delay
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted || !_isBreathingExerciseActive) return;

      setState(() {
        _breathingStep = (_breathingStep + 1) % 3;

        // If we completed a full cycle
        if (_breathingStep == 0) {
          _breathingCount++;

          // End after 3 cycles
          if (_breathingCount >= 3) {
            _isBreathingExerciseActive = false;
            _currentResponse =
                "Great job! How do you feel now? Remember you can do this anytime you feel anxious.";

            // Clear message after delay
            Future.delayed(const Duration(seconds: 10), () {
              if (mounted && _currentResponse?.contains("Great job") == true) {
                setState(() {
                  _currentResponse = null;
                });
              }
            });
            return;
          }
        }

        // Continue the cycle
        _runBreathingCycle();
      });
    });
  }

  void _startGroundingExercise() {
    final groundingSteps = [
      "Let's try a quick grounding exercise. Look around and find 5 things you can see.",
      "Now, notice 4 things you can touch or feel.",
      "Listen for 3 things you can hear right now.",
      "Try to identify 2 things you can smell.",
      "Finally, notice 1 thing you can taste.",
      "Great job! This 5-4-3-2-1 technique can help you feel more present when anxious.",
    ];

    _runSequentialMessages(groundingSteps, const Duration(seconds: 8));
  }

  void _runSequentialMessages(
    List<String> messages,
    Duration delay, [
    int index = 0,
  ]) {
    if (index >= messages.length || !mounted) return;

    setState(() {
      _currentResponse = messages[index];
    });

    Future.delayed(delay, () {
      _runSequentialMessages(messages, delay, index + 1);
    });
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

  void _showMentalHealthTools() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                Text(
                  'Wellness Tools',
                  style: GoogleFonts.fredoka(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  'Tools to support your mental wellbeing',
                  style: GoogleFonts.fredoka(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Categories
                Row(
                  children: [
                    _buildCategoryTab(
                      icon: Icons.sentiment_satisfied_alt,
                      label: 'Mood',
                      color: Colors.blue,
                    ),
                    _buildCategoryTab(
                      icon: Icons.spa,
                      label: 'Calm',
                      color: Colors.green,
                    ),
                    _buildCategoryTab(
                      icon: Icons.psychology,
                      label: 'Mind',
                      color: Colors.purple,
                    ),
                    _buildCategoryTab(
                      icon: Icons.favorite,
                      label: 'Self',
                      color: Colors.red,
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    children: [
                      _buildToolButton(
                        icon: Icons.air,
                        label: 'Breathing',
                        color: Colors.blue,
                        onPressed: () {
                          Navigator.pop(context);
                          _startBreathingExercise();
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.spa,
                        label: 'Grounding',
                        color: Colors.green,
                        onPressed: () {
                          Navigator.pop(context);
                          _startGroundingExercise();
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.psychology,
                        label: 'Small Win',
                        color: Colors.purple,
                        onPressed: () {
                          Navigator.pop(context);
                          _showSmallActivityPrompt();
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.beach_access,
                        label: 'Visualize',
                        color: Colors.orange,
                        onPressed: () {
                          Navigator.pop(context);
                          _startVisualizationExercise();
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.schedule,
                        label: 'Routine',
                        color: Colors.indigo,
                        onPressed: () {
                          Navigator.pop(context);
                          _showRoutineTracker();
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.favorite,
                        label: 'Affirmation',
                        color: Colors.red,
                        onPressed: () {
                          Navigator.pop(context);
                          _showAffirmation();
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.fitness_center,
                        label: 'Stress Relief',
                        color: Colors.teal,
                        onPressed: () {
                          Navigator.pop(context);
                          _showStressReliefOptions();
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.star,
                        label: 'Strengths',
                        color: Colors.amber,
                        onPressed: () {
                          Navigator.pop(context);
                          _showSelfEsteemBuilder();
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.emoji_events,
                        label: 'Achievements',
                        color: Colors.deepOrange,
                        onPressed: () {
                          Navigator.pop(context);
                          _showAchievements();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildCategoryTab({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.fredoka(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        child: TextButton(
          onPressed: onPressed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.fredoka(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AttendanceScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DailyTipsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
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
                                // Top row of feature buttons
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildFeatureButton(
                                      icon: Icons.check_box,
                                      label: 'Check-In',
                                      onPressed: _showMoodTracker,
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
                                      icon: Icons.spa,
                                      label: 'Wellness',
                                      onPressed: _showStressReliefOptions,
                                      color: Colors.green,
                                      size: isSmallScreen ? 40 : 50,
                                    ),
                                    SizedBox(
                                      width: constraints.maxWidth * 0.05,
                                    ),
                                    _buildFeatureButton(
                                      icon: Icons.pets,
                                      label: 'Interact',
                                      onPressed: _toggleInteractionsPanel,
                                      color: Colors.purple,
                                      size: isSmallScreen ? 40 : 50,
                                    ),
                                    SizedBox(
                                      width: constraints.maxWidth * 0.05,
                                    ),
                                    _buildFeatureButton(
                                      onPressed: () {
                                        _showCompanionshipPrompt();
                                      },
                                      icon: Icons.chat_bubble_outline,
                                      label: 'Talk to Me',
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

                        // Interactions panel
                        if (_showInteractionsPanel)
                          Positioned(
                            bottom: constraints.maxHeight * 0.05,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  HappinessMeter(
                                    happiness: _happiness,
                                    status: _petStatus,
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildActionButton(
                                        onPressed: _petThePet,
                                        icon: Icons.pets,
                                        label: 'Pet',
                                        color: Colors.purple,
                                        size: screenSize.width * 0.1,
                                      ),
                                      _buildActionButton(
                                        onPressed: _feedThePet,
                                        icon: Icons.restaurant,
                                        label: 'Feed',
                                        color: Colors.orange,
                                        size: screenSize.width * 0.1,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 300.ms),
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

  // Add this helper method to detect mood from text
  Map<String, dynamic> _detectMoodFromText(String text) {
    final result = {
      'mood': null as String?, // Explicitly type as String? instead of bool?
      'lonely': false,
      'anxious': false,
      'sad': false,
      'angry': false,
    };

    final lowerText = text.toLowerCase();

    // Detect loneliness
    final lonelyKeywords = [
      'lonely',
      'alone',
      'no one',
      'by myself',
      'no friends',
      'isolated',
      'abandoned',
      'nobody',
      'miss',
      'missing',
    ];

    // Detect anxiety
    final anxiousKeywords = [
      'anxious',
      'nervous',
      'worry',
      'worried',
      'stress',
      'stressed',
      'panic',
      'fear',
      'afraid',
      'scared',
    ];

    // Detect sadness
    final sadKeywords = [
      'sad',
      'unhappy',
      'depressed',
      'down',
      'blue',
      'miserable',
      'heartbroken',
      'upset',
      'cry',
      'crying',
    ];

    // Detect anger
    final angryKeywords = [
      'angry',
      'mad',
      'furious',
      'rage',
      'hate',
      'annoyed',
      'irritated',
      'frustrated',
      'upset',
    ];

    // Detect positive emotions
    final positiveKeywords = [
      'happy',
      'joy',
      'excited',
      'great',
      'good',
      'wonderful',
      'fantastic',
      'amazing',
      'love',
      'glad',
    ];

    // Check for each emotion type
    for (final keyword in lonelyKeywords) {
      if (lowerText.contains(keyword)) {
        result['lonely'] = true;
        break;
      }
    }

    for (final keyword in anxiousKeywords) {
      if (lowerText.contains(keyword)) {
        result['anxious'] = true;
        break;
      }
    }

    for (final keyword in sadKeywords) {
      if (lowerText.contains(keyword)) {
        result['sad'] = true;
        break;
      }
    }

    for (final keyword in angryKeywords) {
      if (lowerText.contains(keyword)) {
        result['angry'] = true;
        break;
      }
    }

    // Determine overall mood
    if (result['lonely'] == true ||
        result['anxious'] == true ||
        result['sad'] == true ||
        result['angry'] == true) {
      result['mood'] = 'negative';
    } else {
      // Check for positive emotions
      for (final keyword in positiveKeywords) {
        if (lowerText.contains(keyword)) {
          result['mood'] = 'positive';
          break;
        }
      }
    }

    return result;
  }

  void _showAchievements() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Your Achievements',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Achievement Points: $_achievementPoints',
                    style: GoogleFonts.fredoka(
                      fontSize: 18,
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (_achievements.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'Complete wellness activities to earn achievements!',
                        style: GoogleFonts.fredoka(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _achievements.length,
                        itemBuilder: (context, index) {
                          final achievement = _achievements[index];
                          return ListTile(
                            leading: Icon(
                              achievement['icon'] as IconData,
                              color: achievement['color'] as Color,
                            ),
                            title: Text(
                              achievement['title'] as String,
                              style: GoogleFonts.fredoka(),
                            ),
                            subtitle: Text(
                              achievement['date'] as String,
                              style: GoogleFonts.fredoka(fontSize: 12),
                            ),
                            trailing: Text(
                              '+${achievement['points']}',
                              style: GoogleFonts.fredoka(
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: GoogleFonts.fredoka()),
              ),
            ],
          ),
    );
  }

  // Add this method for quick stress relief
  void _showStressReliefOptions() {
    final reliefOptions = [
      {
        "title": "Box Breathing",
        "description":
            "Breathe in for 4 counts, hold for 4, exhale for 4, hold for 4. Repeat 3 times.",
        "icon": Icons.air,
        "color": Colors.blue,
      },
      {
        "title": "Progressive Relaxation",
        "description":
            "Tense and then relax each muscle group, starting from your toes and moving up.",
        "icon": Icons.spa,
        "color": Colors.green,
      },
      {
        "title": "5-4-3-2-1 Grounding",
        "description":
            "Notice 5 things you see, 4 things you feel, 3 things you hear, 2 things you smell, 1 thing you taste.",
        "icon": Icons.nature,
        "color": Colors.teal,
      },
      {
        "title": "Quick Visualization",
        "description":
            "Close your eyes and imagine a peaceful place for 30 seconds. Notice the details.",
        "icon": Icons.cloud,
        "color": Colors.purple,
      },
    ];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Stress Relief Techniques',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Choose a quick technique:',
                    style: GoogleFonts.fredoka(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: reliefOptions.length,
                      itemBuilder: (context, index) {
                        final option = reliefOptions[index];
                        return ListTile(
                          leading: Icon(
                            option["icon"] as IconData,
                            color: option["color"] as Color,
                          ),
                          title: Text(
                            option["title"] as String,
                            style: GoogleFonts.fredoka(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            option["description"] as String,
                            style: GoogleFonts.fredoka(fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _addAchievement(
                              "Used ${option["title"]} technique",
                              icon: option["icon"] as IconData,
                              color: option["color"] as Color,
                            );

                            // Show confirmation
                            setState(() {
                              _currentResponse =
                                  "Great job using the ${option["title"]} technique! How do you feel now?";
                            });

                            // Clear message after delay
                            Future.delayed(const Duration(seconds: 10), () {
                              if (mounted &&
                                  _currentResponse?.contains(
                                        option["title"] as String,
                                      ) ==
                                      true) {
                                setState(() {
                                  _currentResponse = null;
                                });
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
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

  // Add this method for self-esteem building
  void _showSelfEsteemBuilder() {
    final prompts = [
      "What's one small thing you like about yourself?",
      "What's something you did well recently, no matter how small?",
      "What's a challenge you've overcome in the past?",
      "What's a quality your friends might appreciate about you?",
      "What's a small act of kindness you've done recently?",
    ];

    final prompt = prompts[_random.nextInt(prompts.length)];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Positive Reflection',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  prompt,
                  style: GoogleFonts.fredoka(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Your thoughts...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      Navigator.pop(context);
                      _addAchievement(
                        "Completed a positive reflection",
                        icon: Icons.favorite,
                        color: Colors.red,
                        points: 10,
                      );

                      // Pet responds with encouragement
                      setState(() {
                        _currentResponse =
                            "That's wonderful! Thank you for sharing that with me. You should be proud of yourself!";
                      });

                      // Clear message after delay
                      Future.delayed(const Duration(seconds: 10), () {
                        if (mounted &&
                            _currentResponse?.contains("That's wonderful") ==
                                true) {
                          setState(() {
                            _currentResponse = null;
                          });
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Recognizing your positive qualities builds self-esteem!',
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

  Widget _buildFeatureButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required double size,
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

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required double size,
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
                            }
                          },
                          // onTap:
                          // () {
                          //   // Record the selected mood
                          //   _recordMood(mood['label'] as String);
                          //   Navigator.pop(context);
                          // };
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
    setState(() {
      // Update pet response based on mood
      if (mood == "Happy" || mood == "Calm") {
        _currentResponse =
            "I'm glad you're feeling $mood today! That's wonderful!";
      } else if (mood == "Sad" || mood == "Angry" || mood == "Anxious") {
        _currentResponse =
            "I see you're feeling $mood. Remember I'm here for you. Would you like to try a quick wellness activity?";
        // Optionally suggest relevant wellness activities
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _currentResponse?.contains(mood) == true) {
            _showRelevantWellnessOptions(mood);
          }
        });
      } else {
        _currentResponse = "Thanks for sharing how you're feeling today!";
      }

      // Add achievement for tracking mood
      _addAchievement(
        "Tracked daily mood",
        icon: Icons.mood,
        color: Colors.blue,
        points: 3,
      );

      // Store mood in history
      // You would implement this based on your data storage approach
    });
  }

  void _recordMoodDetails(String details) {
    // Store additional mood details
    // You would implement this based on your data storage approach

    // Pet responds to details
    _geminiService.getCheckInResponse(details).then((response) {
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

  void _showRelevantWellnessOptions(String mood) {
    // Show relevant wellness activities based on mood
    if (mood == "Anxious") {
      _showStressReliefOptions();
    } else if (mood == "Sad") {
      _showSelfEsteemBuilder();
    } else if (mood == "Angry") {
      _startBreathingExercise();
    }
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

class PetPainter extends CustomPainter {
  final Color color;

  PetPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final pixelSize = size.width / 8;
    final pixels = [
      [0, 0, 1, 1, 1, 1, 0, 0],
      [0, 1, 1, 1, 1, 1, 1, 0],
      [1, 1, 0, 1, 1, 0, 1, 1],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [0, 1, 1, 1, 1, 1, 1, 0],
      [0, 0, 1, 0, 0, 1, 0, 0],
      [0, 0, 1, 1, 1, 1, 0, 0],
    ];

    for (var y = 0; y < pixels.length; y++) {
      for (var x = 0; x < pixels[y].length; x++) {
        if (pixels[y][x] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(x * pixelSize, y * pixelSize, pixelSize, pixelSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
