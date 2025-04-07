import 'package:flutter/material.dart';
import 'package:helloworld/services/attendance_service.dart';
import 'package:helloworld/widgets/attendance_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../services/emotion_service.dart';
import '../main.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  final AttendanceService _attendanceService = AttendanceService();

  List<Map<String, dynamic>> _attendanceDatesWithMoods = [];

  DateTime? _selectedDate;
  bool _isLoading = true;
  int _streak = 0;
  int _totalCoins = 0;
  bool _checkedInToday = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  AttendanceReward? _lastReward;
  bool _showRewardAnimation = false;

  int _earnedCoins = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _loadAttendanceData();
    _loadEmotionHistory();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final datesWithMoods =
          await _attendanceService.getAttendanceDatesWithMoods();
      final streak = await _attendanceService.getStreak();
      final checkedIn = await _attendanceService.hasCheckedInToday();
      final totalCoins = await _attendanceService.getTotalCoins();

      setState(() {
        _attendanceDatesWithMoods = datesWithMoods;
        _streak = streak;
        _checkedInToday = checkedIn;
        _totalCoins = totalCoins;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading attendance data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  final moodOptions = [
    {'emoji': '😊', 'label': 'Happy', 'color': Colors.yellow},
    {'emoji': '😌', 'label': 'Calm', 'color': Colors.blue.shade300},
    {'emoji': '😐', 'label': 'Neutral', 'color': Colors.grey.shade400},
    {'emoji': '😔', 'label': 'Sad', 'color': Colors.indigo.shade300},
    {'emoji': '😡', 'label': 'Angry', 'color': Colors.red.shade400},
    {'emoji': '😰', 'label': 'Anxious', 'color': Colors.purple.shade300},
  ];

  Future<void> _handleCheckIn() async {
    // Show mood selection dialog
    final selectedMood = await _showMoodSelectionDialog();
    if (selectedMood == null) return; // User cancelled

    final result = await _attendanceService.markAttendanceWithMood(
      selectedMood,
    );

    if (result.success) {
      // Calculate earned coins in this check-in
      final int prevCoins = _totalCoins;
      final int newCoins = result.totalCoins;
      final int earned = newCoins - prevCoins;

      setState(() {
        _lastReward = result.reward;
        _showRewardAnimation = true;
        _streak = result.streak;
        _checkedInToday = true;
        _totalCoins = result.totalCoins;
        _earnedCoins = earned;
      });

      // Reload data to get the updated mood data
      _loadAttendanceData();


        // Add today to attendance dates
        final today = DateTime.now();
        setState(() {
          _attendanceDates.add(DateTime(today.year, today.month, today.day));
        });

        // Play animation
        _animationController.reset();
        _animationController.forward();

        // Hide animation after a few seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showRewardAnimation = false;
            });
          }
        });
        
        // Reload emotion history to show the new entry
        _loadEmotionHistory();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(checkInResult.message), backgroundColor: Colors.green)
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(checkInResult.message))
        );
      }
    }
  }

  // Show dialog to select mood
  Future<String?> _showMoodSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'How are you feeling today?',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select your mood:', style: GoogleFonts.fredoka()),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children:
                        moodOptions.map((option) {
                          return InkWell(
                            onTap:
                                () => Navigator.of(
                                  context,
                                ).pop(option['label'] as String),
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: (option['color'] as Color)
                                        .withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    option['emoji'] as String,
                                    style: const TextStyle(fontSize: 30),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  option['label'] as String,
                                  style: GoogleFonts.fredoka(),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel', style: GoogleFonts.fredoka()),
              ),
            ],
          ),
    );
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Daily Attendance',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCoinCounter(),
                          const SizedBox(height: 16),
                          _buildStreakInfo(),
                          const SizedBox(height: 16),
                          Card(
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                    'Attendance Calendar',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  AttendanceCalendar(
                                    markedDatesWithMoods:
                                        _attendanceDatesWithMoods,
                                    selectedDate: _selectedDate,
                                    onDaySelected: _onDateSelected,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildCheckInButton(),
                              const SizedBox(height: 24),
                              _buildRewardsInfo(),
                            ],
                          ),
                        ),
                      ),
                      if (_showRewardAnimation) _buildRewardAnimation(),
                    ],
                  ),
                  
                  // Mood History Tab
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'Week', label: Text('Week')),
                            ButtonSegment(value: 'Month', label: Text('Month')),
                            ButtonSegment(value: 'Year', label: Text('Year')),
                          ],
                          selected: {_timeRange},
                          onSelectionChanged: (Set<String> selection) {
                            setState(() {
                              _timeRange = selection.first;
                            });
                            _loadEmotionHistory();
                          },
                        ),
                      ),
                      
                      // Emotion chart
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildEmotionChart(),
                        ),
                      ),
                      
                      // Emotion history list
                      Expanded(
                        flex: 3,
                        child: _buildEmotionHistoryList(),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCoinCounter() {
    return Card(
      color: Colors.amber.shade300,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monetization_on,
                  color: Colors.amber.shade800,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Happiness Coins',
                      style: GoogleFonts.fredoka(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '$_totalCoins coins',
                      style: GoogleFonts.fredoka(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.black54),
              onPressed: () {
                _showCoinInfoDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCoinInfoDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.amber.shade600),
                const SizedBox(width: 8),
                Text('Happiness Coins', style: GoogleFonts.fredoka()),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Happiness Coins are earned through daily check-ins:',
                  style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildCoinInfoItem('Daily Check-in', '+10 coins'),
                _buildCoinInfoItem('Weekly Streak (7 days)', '+20 coins'),
                _buildCoinInfoItem('Monthly Streak (30 days)', '+50 coins'),
                const SizedBox(height: 12),
                Text(
                  'These coins reflect your pet\'s happiness level and can be used to unlock special features in the future!',
                  style: GoogleFonts.fredoka(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Got it', style: GoogleFonts.fredoka()),
              ),
            ],
          ),
    );
  }

  Widget _buildCoinInfoItem(String title, String reward) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.fredoka()),
          Text(
            reward,
            style: GoogleFonts.fredoka(
              color: Colors.amber.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakInfo() {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Streak',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: theme.textTheme.titleLarge?.fontSize,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$_streak days',
              style: GoogleFonts.fredoka(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: theme.textTheme.headlineMedium?.fontSize,
              ),
            ),
            if (_streak > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _streak == 1
                      ? 'Keep going!'
                      : _streak >= 7
                      ? 'Amazing dedication!'
                      : 'Great job!',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: theme.textTheme.bodyLarge?.fontSize,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInButton() {
    return ElevatedButton.icon(
      onPressed: _checkedInToday ? null : _handleCheckIn,
      icon: Icon(_checkedInToday ? Icons.check_circle : Icons.pets),
      label: Text(
        _checkedInToday ? 'Already Checked In Today' : 'Check In Now',
        style: GoogleFonts.fredoka(fontSize: 16),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildRewardsInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Rewards',
              style: GoogleFonts.fredoka(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildRewardItem(
              'Daily Check-in',
              'Pet Treat (+10 happiness)',
              Icons.pets,
              Colors.amber,
            ),
            const Divider(),
            _buildRewardItem(
              '7-Day Streak',
              'Special Treat (+20 happiness)',
              Icons.card_giftcard,
              Colors.orange,
            ),
            const Divider(),
            _buildRewardItem(
              '30-Day Streak',
              'Super Toy (+50 happiness)',
              Icons.star,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardItem(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.fredoka(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.fredoka(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardAnimation() {
    if (_lastReward == null) return const SizedBox.shrink();

    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reward Earned!',
                style: GoogleFonts.fredoka(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _lastReward!.name,
                style: GoogleFonts.fredoka(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on, color: Colors.amber.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '+$_earnedCoins coins',
                    style: GoogleFonts.fredoka(
                      fontSize: 18,
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '+${_lastReward!.happinessBoost} happiness',
                style: GoogleFonts.fredoka(
                  fontSize: 16,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Emotion History Widget Methods
  Widget _buildEmotionChart() {
    if (_emotionHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No emotion data available for this period.',
              style: GoogleFonts.fredoka(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Check in with your mood to see your emotion history!',
              style: GoogleFonts.fredoka(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group emotions by type
    final Map<String, int> emotionCounts = {
      'Happy': 0,
      'Calm': 0,
      'Neutral': 0,
      'Sad': 0,
      'Angry': 0,
      'Anxious': 0,
    };

    for (final entry in _emotionHistory) {
      final emotion = entry['emotion'] as String;
      emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
    }

    // Create chart data
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emotion Summary',
              style: GoogleFonts.fredoka(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: emotionCounts.entries.map((entry) {
                  // Skip emotions with zero count
                  if (entry.value == 0) return const SizedBox();
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getEmotionEmoji(entry.key),
                        style: const TextStyle(fontSize: 30),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.value.toString(),
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getEmotionColor(entry.key),
                        ),
                      ),
                      Text(
                        entry.key,
                        style: GoogleFonts.fredoka(fontSize: 12),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionHistoryList() {
    if (_emotionHistory.isEmpty) {
      return Center(
        child: Text(
          'No emotion data recorded yet.',
          style: GoogleFonts.fredoka(color: Colors.grey.shade600),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _emotionHistory.length,
        itemBuilder: (context, index) {
          final item = _emotionHistory[index];
          final dateStr = item['date'] as String;
          final timeStr = (item['time'] as String?) ?? '12:00:00';
          final emotion = item['emotion'] as String;
          final note = item['note'] as String?;
          
          final dateTime = DateTime.parse('$dateStr $timeStr');
          final formattedDate = DateFormat('MMM d, yyyy').format(dateTime);
          final formattedTime = DateFormat('h:mm a').format(dateTime);
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getEmotionColor(emotion).withOpacity(0.2),
              child: Text(
                _getEmotionEmoji(emotion),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            title: Text(
              emotion,
              style: GoogleFonts.fredoka(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$formattedDate at $formattedTime',
                  style: GoogleFonts.fredoka(fontSize: 12),
                ),
                if (note != null && note.isNotEmpty)
                  Text(
                    note,
                    style: GoogleFonts.fredoka(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            trailing: _buildEmotionIndicator(emotion),
          );
        },
      ),
    );
  }

  Widget _buildEmotionIndicator(String emotion) {
    final score = _getEmotionScore(emotion);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          return Icon(
            index < score ? Icons.star : Icons.star_border,
            color: index < score ? _getEmotionColor(emotion) : Colors.grey.shade300,
            size: 16,
          );
        }),
      ],
    );
  }

  int _getEmotionScore(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return 5;
      case 'calm':
        return 4;
      case 'neutral':
        return 3;
      case 'anxious':
        return 2;
      case 'sad':
      case 'angry':
        return 1;
      default:
        return 3; // Neutral as default
    }
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'calm':
        return '😌';
      case 'neutral':
        return '😐';
      case 'sad':
        return '😔';
      case 'angry':
        return '😡';
      case 'anxious':
        return '😰';
      default:
        return '😐'; // Neutral
    }
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Colors.yellow;
      case 'calm':
        return Colors.blue.shade300;
      case 'neutral':
        return Colors.grey.shade400;
      case 'sad':
        return Colors.indigo.shade300;
      case 'angry':
        return Colors.red.shade400;
      case 'anxious':
        return Colors.purple.shade300;
      default:
        return Colors.grey.shade400; // Neutral
    }
  }
}
