import 'package:flutter/material.dart';
import 'package:helloworld/services/attendance_service.dart';
import 'package:helloworld/widgets/attendance_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

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

    // Ensure data loads by using a post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAttendanceData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload data when dependencies change (like coming back to this screen)
    _loadAttendanceData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceData() async {
    // Remove the condition that prevents loading
    print('DEBUG: Starting to load attendance data...');
    setState(() {
      _isLoading = true;
    });

    try {
      print('DEBUG: Loading attendance data for current user');
      final datesWithMoods =
          await _attendanceService.getAttendanceDatesWithMoods();
      print('DEBUG: Loaded ${datesWithMoods.length} attendance dates');

      final streak = await _attendanceService.getStreak();
      print('DEBUG: Current streak: $streak');

      final checkedIn = await _attendanceService.hasCheckedInToday();
      print('DEBUG: Has checked in today: $checkedIn');

      final totalCoins = await _attendanceService.getTotalCoins();
      print('DEBUG: Total coins: $totalCoins');

      if (mounted) {
        setState(() {
          _attendanceDatesWithMoods = datesWithMoods;
          _streak = streak;
          _checkedInToday = checkedIn;
          _totalCoins = totalCoins;
          _isLoading = false;
        });
        print('DEBUG: Successfully updated state with attendance data');
      }
    } catch (e) {
      print('ERROR loading attendance data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading data: ${e.toString().substring(0, math.min(e.toString().length, 50))}...',
            ),
          ),
        );
      }
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

  // Show a SnackBar with coins earned message
  void _showCoinsEarnedMessage(int earned) {
    if (earned > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Congratulations! You earned $earned coins!'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleCheckIn() async {
    final selectedMood = await _showMoodSelectionDialog();
    if (selectedMood == null) return;

    // Show loading indicator while checking in
    setState(() {
      _isLoading = true;
    });

    try {
      final int prevCoins = await _attendanceService.getTotalCoins();
      print('DEBUG: Coins before check-in: $prevCoins');

      final result = await _attendanceService.markAttendanceWithMood(
        selectedMood,
      );

      if (result.success) {
        // Fetch the latest coins directly to ensure accuracy
        final int newCoins = await _attendanceService.getTotalCoins();
        print('DEBUG: Coins after check-in: $newCoins');
        final int earned = newCoins - prevCoins;
        print('DEBUG: Earned coins: $earned');

        // Refresh attendance data to get updated calendar info
        final datesWithMoods =
            await _attendanceService.getAttendanceDatesWithMoods();
        print(
          'DEBUG: Fetched ${datesWithMoods.length} dates with moods for calendar',
        );

        if (mounted) {
          setState(() {
            _lastReward = result.reward;
            _showRewardAnimation = true;
            _streak = result.streak;
            _checkedInToday = true;
            _totalCoins = newCoins;
            _earnedCoins = earned;
            _attendanceDatesWithMoods = datesWithMoods;
            _isLoading = false;
          });

          _animationController.reset();
          _animationController.forward();

          // Show coins earned message
          _showCoinsEarnedMessage(earned);

          // Auto return to main screen with result after a timeout if user doesn't interact
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && _showRewardAnimation) {
              setState(() {
                _showRewardAnimation = false;
              });

              // Return the earned coins data to the main screen
              Navigator.of(
                context,
              ).pop({'earnedCoins': _earnedCoins, 'totalCoins': _totalCoins});
            }
          });
        }
      } else {
        // In case of an error, still update the UI with the latest data
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result.message)));

          // Reload data to ensure UI is synced
          _loadAttendanceData();
        }
      }
    } catch (e) {
      print('ERROR during check-in: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error during check-in: ${e.toString().substring(0, math.min(e.toString().length, 50))}...',
            ),
          ),
        );

        // Try to reload data even after error
        _loadAttendanceData();
      }
    }
  }

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
    return PopScope(
      onPopInvoked: (didPop) {
        // If user earned coins but is going back without using the "Collect" button,
        // we need to send the result back manually
        if (didPop && _earnedCoins > 0) {
          print('DEBUG: User navigating back with earned coins: $_earnedCoins');

          // Note: With onPopInvoked we don't need to explicitly call pop again,
          // we just need to ensure that on the main screen they check for the result
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Daily Attendance',
            style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // When user manually presses back button, send back coins data
              Navigator.of(
                context,
              ).pop({'earnedCoins': _earnedCoins, 'totalCoins': _totalCoins});
            },
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
                                  ],
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
              icon: const Icon(Icons.refresh, color: Colors.black54),
              onPressed: () async {
                await _loadAttendanceData();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Data refreshed')));
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
              'Pet Treat (+10 Coins)',
              Icons.pets,
              Colors.amber,
            ),
            const Divider(),
            _buildRewardItem(
              '7-Day Streak',
              'Special Treat (+20 Coins)',
              Icons.card_giftcard,
              Colors.orange,
            ),
            const Divider(),
            _buildRewardItem(
              '30-Day Streak',
              'Super Toy (+50 Coins)',
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Hide the reward animation
                  setState(() {
                    _showRewardAnimation = false;
                  });

                  // Return to main screen with result
                  Navigator.of(context).pop({
                    'earnedCoins': _earnedCoins,
                    'totalCoins': _totalCoins,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text('Collect', style: GoogleFonts.fredoka()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
