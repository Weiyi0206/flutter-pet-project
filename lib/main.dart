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

  @override
  void initState() {
    super.initState();
    _checkApiConnection();
    _unusedTips = List.from(_dailyTips);
    _startTipTimer();
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _checkApiConnection() async {
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

    // Keep user message visible for 15 seconds
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          _lastUserMessage = null;
        });
      }
    });

    try {
      final response = await _geminiService.getChatResponse(
        userMessage,
        _happiness,
        _petStatus,
      );

      // Store the response in history and show it
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(text: response, isUser: false, timestamp: timeString),
          );
          _currentResponse = response;
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
        setState(() {
          final errorMessage = "Sorry, I couldn't process that. Let's try again!";
          _messages.add(
            ChatMessage(
              text: errorMessage,
              isUser: false,
              timestamp: timeString,
            ),
          );
          _currentResponse = errorMessage;
        });
      }
      print("Error in chat response: $e");
    }
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
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DailyTipsScreen(),
                ),
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
            colors: [
              Colors.purple.shade50,
              Colors.blue.shade50,
            ],
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
                          top: constraints.maxHeight * 0.1,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: AnimatedPet(
                              status: _petStatus,
                              onPet: _petThePet,
                              onFeed: _feedThePet,
                              size: constraints.maxWidth * 0.6, // Responsive size
                            ),
                          ),
                        ),
                        
                        // Feature buttons - positioned on left side
                        Positioned(
                          top: constraints.maxHeight * 0.15,
                          left: isSmallScreen ? 5 : 15,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildFeatureButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AttendanceScreen(),
                                    ),
                                  );
                                },
                                icon: Icons.calendar_today,
                                label: 'Check-in',
                                color: Colors.amber,
                                size: isSmallScreen ? 40 : 50,
                              ),
                              SizedBox(height: constraints.maxHeight * 0.03),
                              _buildFeatureButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const HelpSupportScreen(),
                                    ),
                                  );
                                },
                                icon: Icons.support_agent,
                                label: 'Help',
                                color: Colors.red,
                                size: isSmallScreen ? 40 : 50,
                              ),
                              SizedBox(height: constraints.maxHeight * 0.03),
                              _buildFeatureButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DailyTipsScreen(),
                                    ),
                                  );
                                },
                                icon: Icons.tips_and_updates,
                                label: 'Tips',
                                color: Colors.green,
                                size: isSmallScreen ? 40 : 50,
                              ),
                            ],
                          ),
                        ),
                        
                        // Pet speech bubble (only shown when there's a response)
                        if (_currentResponse != null)
                          Positioned(
                            top: constraints.maxHeight * 0.05,
                            right: constraints.maxWidth * 0.1,
                            left: constraints.maxWidth * 0.3,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Main bubble
                                Container(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth * 0.6,
                                    maxHeight: constraints.maxHeight * 0.2,
                                  ),
                                  padding: EdgeInsets.all(constraints.maxWidth * 0.03),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Flexible(
                                        child: SingleChildScrollView(
                                          child: AnimatedTextKit(
                                            animatedTexts: [
                                              TypewriterAnimatedText(
                                                _currentResponse!,
                                                speed: const Duration(milliseconds: 50),
                                                textStyle: TextStyle(
                                                  fontSize: constraints.maxWidth * 0.035,
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
                                  left: constraints.maxWidth * 0.15,
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
                          bottom: constraints.maxHeight * 0.22, // Position it above status bar
                          left: 0,
                          right: 0,
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.05),
                            child: Column(
                              children: [
                                // Pet mood and activities
                                Container(
                                  padding: EdgeInsets.all(constraints.maxWidth * 0.03),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getStatusTextColor().withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Today's activities
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                                            value: '${_random.nextInt(3) + 1}/3',
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
                                      
                                      SizedBox(height: constraints.maxHeight * 0.015),
                                      
                                      // Daily streak
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: constraints.maxHeight * 0.01,
                                          horizontal: constraints.maxWidth * 0.03,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.local_fire_department,
                                              color: Colors.orange,
                                              size: constraints.maxWidth * 0.05,
                                            ),
                                            SizedBox(width: constraints.maxWidth * 0.02),
                                            Text(
                                              'Daily streak: ${_random.nextInt(30) + 1} days',
                                              style: GoogleFonts.fredoka(
                                                fontSize: constraints.maxWidth * 0.035,
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
                        
                        // Status indicator
                        Positioned(
                          bottom: constraints.maxHeight * 0.05,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              Text(
                                'Status: $_petStatus',
                                style: GoogleFonts.fredoka(
                                  fontSize: constraints.maxWidth * 0.04,
                                  color: _getStatusTextColor(),
                                ),
                              ),
                              SizedBox(height: 8),
                              Center(
                                child: Container(
                                  width: constraints.maxWidth * 0.6,
                                  height: 15,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Stack(
                                    children: [
                                      FractionallySizedBox(
                                        widthFactor: _happiness / 100,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: _getStatusTextColor(),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '$_happiness%',
                                style: GoogleFonts.fredoka(
                                  fontSize: constraints.maxWidth * 0.035,
                                  color: _getStatusTextColor(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // User's last message (only shown when there's a message)
                        if (_lastUserMessage != null)
                          Positioned(
                            bottom: constraints.maxHeight * 0.15, // Position it above the status
                            right: 0,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.7,
                                maxHeight: constraints.maxHeight * 0.1,
                              ),
                              margin: EdgeInsets.only(right: constraints.maxWidth * 0.05),
                              padding: EdgeInsets.all(constraints.maxWidth * 0.025),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100.withOpacity(0.9),
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
                                  SizedBox(width: constraints.maxWidth * 0.02),
                                  Flexible(
                                    child: Text(
                                      _lastUserMessage!,
                                      style: TextStyle(
                                        fontSize: constraints.maxWidth * 0.035,
                                        color: Colors.purple.shade800,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 300.ms).slideX(
                              begin: 0.5,
                              end: 0,
                              duration: 300.ms,
                            ),
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
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: EdgeInsets.all(size * 0.25),
                child: Icon(
                  icon,
                  size: size * 0.5,
                  color: color,
                ),
              ),
            ),
          ),
        ).animate().scale(
              duration: 200.ms,
              curve: Curves.easeOut,
              delay: 100.ms,
            ),
        SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.fredoka(
            color: color,
            fontSize: size * 0.28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
        Icon(
          icon,
          color: color,
          size: constraints.maxWidth * 0.06,
        ),
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
}

class BubbleTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.95)
      ..style = PaintingStyle.fill;

    final path = Path()
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
