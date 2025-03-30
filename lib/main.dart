import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/chat_history_screen.dart';
import 'screens/help_support_screen.dart';
import 'dart:math';
import 'services/gemini_service.dart';
import 'package:logging/logging.dart';
import 'screens/daily_tips_screen.dart';
import 'dart:async';

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

  Timer? _tipTimer;
  final Random _random = Random();
  final List<String> _dailyTips = [
    "Hey, shall we try a quick breathing exercise together? Just breathe in for 4, hold for 4, out for 4! 🧘‍♂️",
    "Don't forget to drink some water today! Staying hydrated helps your mind stay clear. 💧",
    "How about a 2-minute stretch break? Your body will thank you! 🤸‍♂️",
    "Remember to take a moment to appreciate something good today. What made you smile? 😊",
    "Maybe we could practice mindfulness together? Just focus on this moment for a minute. 🌟",
    "Time for a quick screen break! Look at something 20 feet away for 20 seconds. 👀",
    "Let's do a quick gratitude check - what are you thankful for today? 🙏",
    "How about a short walk? Even a few minutes of movement can boost your mood! 🚶‍♂️",
  ];

  List<String> _unusedTips = [];

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
      _currentResponse = tip;
      _messages.add(
        ChatMessage(text: tip, isUser: false, timestamp: timeString),
      );
    });

    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _currentResponse == tip) {
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

    setState(() {
      _messages.add(
        ChatMessage(text: userMessage, isUser: true, timestamp: timeString),
      );
      _chatController.clear();
    });

    final response = await _geminiService.getChatResponse(
      userMessage,
      _happiness,
      _petStatus,
    );

    setState(() {
      _messages.add(
        ChatMessage(text: response, isUser: false, timestamp: timeString),
      );
      _currentResponse = response;
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _currentResponse = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
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
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Virtual Pet Display and Help Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 200,
                              height: 200,
                              child: CustomPaint(
                                painter: PetPainter(
                                  color:
                                      _petStatus == 'Happy'
                                          ? Colors.green
                                          : _petStatus == 'Normal'
                                          ? Colors.blue
                                          : Colors.red,
                                ),
                              ),
                            ),
                            if (_currentResponse != null)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  _currentResponse!,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            Text(
                              'Happiness: $_happiness%',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              'Status: $_petStatus',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _petThePet,
                                  icon: const Icon(Icons.pets),
                                  label: const Text('Pet'),
                                ),
                                const SizedBox(width: 20),
                                ElevatedButton.icon(
                                  onPressed: _feedThePet,
                                  icon: const Icon(Icons.restaurant),
                                  label: const Text('Feed'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 16,
                      ), // Spacing between pet and help button
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              iconSize: 32,
                              icon: const Icon(Icons.support_agent),
                              color: Colors.red,
                              tooltip: 'Get Help & Support',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => const HelpSupportScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Help',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(
                      hintText: 'Talk to your pet...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
