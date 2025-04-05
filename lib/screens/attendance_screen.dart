import 'package:flutter/material.dart';
import 'package:helloworld/services/attendance_service.dart';
import 'package:helloworld/widgets/attendance_calendar.dart';
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
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  // Show dialog to select mood
  Future<String?> _showMoodSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'How are you feeling today?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select your mood:'),
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
                                Text(option['label'] as String),
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
                child: const Text('Cancel'),
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
      appBar: AppBar(title: const Text('Daily Attendance')),
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
                                  const Text(
                                    'Attendance Calendar',
                                    style: TextStyle(
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
                    const Text(
                      'Happiness Coins',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '$_totalCoins coins',
                      style: TextStyle(
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
                const Text('Happiness Coins'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Happiness Coins are earned through daily check-ins:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildCoinInfoItem('Daily Check-in', '+10 coins'),
                _buildCoinInfoItem('Happy Mood Bonus', '+5 coins'),
                _buildCoinInfoItem('Calm Mood Bonus', '+3 coins'),
                _buildCoinInfoItem('Weekly Streak (7 days)', '+20 coins'),
                _buildCoinInfoItem('Monthly Streak (30 days)', '+50 coins'),
                const SizedBox(height: 12),
                const Text(
                  'These coins reflect your pet\'s happiness level and can be used to unlock special features in the future!',
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
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
          Text(title),
          Text(
            reward,
            style: TextStyle(
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
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$_streak days',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
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
        style: const TextStyle(fontSize: 16),
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
            const Text(
              'Attendance Rewards',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(description, style: TextStyle(color: Colors.grey[600])),
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
              const Text(
                'Reward Earned!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _lastReward!.name,
                style: const TextStyle(
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
                    style: TextStyle(
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
                style: const TextStyle(
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
}
