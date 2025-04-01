import 'package:flutter/material.dart';
import 'package:helloworld/services/attendance_service.dart';
import 'package:helloworld/widgets/attendance_calendar.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  final AttendanceService _attendanceService = AttendanceService();
  List<DateTime> _attendanceDates = [];
  DateTime? _selectedDate;
  bool _isLoading = true;
  int _streak = 0;
  bool _checkedInToday = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  AttendanceReward? _lastReward;
  bool _showRewardAnimation = false;

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
      final dates = await _attendanceService.getAttendanceDates();
      final streak = await _attendanceService.getStreak();
      final checkedIn = await _attendanceService.hasCheckedInToday();

      setState(() {
        _attendanceDates = dates;
        _streak = streak;
        _checkedInToday = checkedIn;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading attendance data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCheckIn() async {
    final result = await _attendanceService.markAttendance();

    if (result.success) {
      setState(() {
        _lastReward = result.reward;
        _showRewardAnimation = true;
        _streak = result.streak;
        _checkedInToday = true;
      });

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
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
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
                                    markedDates: _attendanceDates,
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
              Text(
                '+${_lastReward!.happinessBoost} Happiness',
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
