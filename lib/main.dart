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
import 'screens/pet_interactions_screen.dart';


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

  int _happiness = 50;
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

  int _connectionStreak = 0;
  DateTime? _lastConnectionDate;

  int _totalHappinessCoins = 0; // Add this line to track happiness coins

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

    // Initialize pet data and status
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
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _chatController.dispose();
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

  void _petThePet() async {
    try {
      await _petModel.petPet();
      _petData = await _petModel.loadPetData();
      setState(() {
        _updatePetStatus();
      });
    } catch (e) {
      print('Error petting pet: $e');
    }
  }

  void _feedThePet() async {
    try {
      await _petModel.feedPet();
      _petData = await _petModel.loadPetData();
      setState(() {
        _updatePetStatus();
      });
    } catch (e) {
      print('Error feeding pet: $e');
    }
  }

  void _updatePetStatus() {
    // Use mood from pet data if available, otherwise use happiness level
    if (_petData.isNotEmpty && _petData.containsKey('mood')) {
      _petStatus = _petData['mood'];
    } else {
      if (_happiness >= 80) {
        _petStatus = 'Happy';
      } else if (_happiness >= 40) {
        _petStatus = 'Content';
      } else {
        _petStatus = 'Sad';
      }
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
                                      icon: Icons.pets,
                                      label: 'Pet Care',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PetInteractionsScreen(
                                              petModel: _petModel,
                                              petData: _petData,
                                              onPetDataUpdate: (updatedData) {
                                                setState(() {
                                                  _petData = updatedData;
                                                  _updatePetStatus();
                                                });
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                      color: Colors.purple,
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
                                      icon: Icons.sports_esports,
                                      label: 'Play',
                                      onPressed: () {
                                        if (_petData.isNotEmpty) {
                                          _playWithPet();
                                        }
                                      },
                                      color: Colors.blue,
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
                                      icon: Icons.cleaning_services,
                                      label: 'Groom',
                                      onPressed: () {
                                        if (_petData.isNotEmpty) {
                                          _groomPet();
                                        }
                                      },
                                      color: Colors.green,
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

  // Add method to initialize pet
  Future<void> _initializePet() async {
    try {
      await _petModel.initializePet();
      _petData = await _petModel.loadPetData();
      setState(() {
        _updatePetStatus();
      });
    } catch (e) {
      print('Failed to initialize pet: $e');
    }
  }

  // Add methods for play and groom
  void _playWithPet() async {
    try {
      await _petModel.playWithPet();
      _petData = await _petModel.loadPetData();
      setState(() {
        _updatePetStatus();
      });
    } catch (e) {
      print('Error playing with pet: $e');
    }
  }

  void _groomPet() async {
    try {
      await _petModel.groomPet();
      _petData = await _petModel.loadPetData();
      setState(() {
        _updatePetStatus();
      });
    } catch (e) {
      print('Error grooming pet: $e');
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
