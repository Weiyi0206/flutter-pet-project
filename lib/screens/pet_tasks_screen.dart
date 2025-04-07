import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pet_model.dart';
import '../services/attendance_service.dart';

// Define a Task class for better structure
class PetTask {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int requiredCount;
  final String currentCountKey; // Key in petData for current progress (e.g., 'petsToday')
  final int coinReward;
  // Add other potential rewards like XP if needed
  // final int xpReward;

  PetTask({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.requiredCount,
    required this.currentCountKey,
    required this.coinReward,
    // this.xpReward = 0,
  });
}

class PetTasksScreen extends StatefulWidget {
  final PetModel petModel;
  final Map<String, dynamic> petData;
  final AttendanceService attendanceService;
  final VoidCallback onCoinsUpdated;

  const PetTasksScreen({
    Key? key,
    required this.petModel,
    required this.petData,
    required this.attendanceService,
    required this.onCoinsUpdated,
  }) : super(key: key);

  @override
  State<PetTasksScreen> createState() => _PetTasksScreenState();
}

class _PetTasksScreenState extends State<PetTasksScreen> {
  late Map<String, dynamic> _petData;
  late Map<String, bool> _taskStatus;

  // Define the list of tasks
  final List<PetTask> _tasks = [
    PetTask(
      id: 'pet_3_times',
      name: 'Show Affection',
      description: 'Pet your companion 3 times today',
      icon: Icons.pets,
      color: Colors.purple,
      requiredCount: 3,
      currentCountKey: 'petsToday',
      coinReward: 2,
    ),
    PetTask(
      id: 'feed_1_time',
      name: 'Meal Time',
      description: 'Feed your pet at least once today',
      icon: Icons.restaurant,
      color: Colors.orange,
      requiredCount: 1,
      currentCountKey: 'mealsToday',
      coinReward: 1,
    ),
    PetTask(
      id: 'play_2_times',
      name: 'Play Session',
      description: 'Play with your pet 2 times',
      icon: Icons.sports_esports,
      color: Colors.blue,
      requiredCount: 2,
      currentCountKey: 'playsToday',
      coinReward: 2,
    ),
    PetTask(
      id: 'groom_1_time',
      name: 'Grooming',
      description: 'Groom your pet once',
      icon: Icons.cleaning_services,
      color: Colors.green,
      requiredCount: 1,
      currentCountKey: 'groomsToday',
      coinReward: 1,
    ),
    PetTask(
      id: 'chat_5_times',
      name: 'Friendly Chat',
      description: 'Send 5 messages to your pet today',
      icon: Icons.chat_bubble_outline,
      color: Colors.pink,
      requiredCount: 5,
      currentCountKey: 'chatsToday',
      coinReward: 3,
    ),
    PetTask(
      id: 'write_diary_entry',
      name: 'Dear Diary',
      description: 'Write at least one diary entry today',
      icon: Icons.book_outlined,
      color: Colors.teal,
      requiredCount: 1,
      currentCountKey: 'diaryEntriesToday',
      coinReward: 2,
    ),
    PetTask(
      id: 'view_daily_tip',
      name: 'Daily Wisdom',
      description: 'Check out the daily tips screen',
      icon: Icons.lightbulb_outline,
      color: Colors.amber,
      requiredCount: 1,
      currentCountKey: 'viewedTipsToday',
      coinReward: 1,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _petData = widget.petData;
    _taskStatus = Map<String, bool>.from(_petData['dailyTaskStatus'] ?? {});
    print("[PetTasksScreen] Initial task status loaded: $_taskStatus");
  }

  Future<void> _claimReward(PetTask task) async {
    print("[PetTasksScreen] Attempting to claim reward for task: ${task.id}");
    int currentCount = _petData[task.currentCountKey] ?? 0;
    bool isCompleted = currentCount >= task.requiredCount;
    bool alreadyClaimed = _taskStatus[task.id] ?? false;

    if (isCompleted && !alreadyClaimed) {
      try {
        await widget.attendanceService.addCoins(task.coinReward);
        print("[PetTasksScreen] Coins awarded: ${task.coinReward}");

        _taskStatus[task.id] = true;
        await widget.petModel.updateTaskStatus(_taskStatus);
        print("[PetTasksScreen] Task status updated in Firestore.");

        widget.onCoinsUpdated();
        print("[PetTasksScreen] Coin refresh callback triggered.");

        if (mounted) {
          _petData = await widget.petModel.loadPetData();
          _taskStatus = Map<String, bool>.from(_petData['dailyTaskStatus'] ?? {});
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reward Claimed: ${task.coinReward} Coins!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print("[PetTasksScreen] Error claiming reward: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error claiming reward: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      print("[PetTasksScreen] Cannot claim reward. Completed: $isCompleted, Claimed: $alreadyClaimed");
    }
  }

  @override
  Widget build(BuildContext context) {
    _taskStatus = Map<String, bool>.from(_petData['dailyTaskStatus'] ?? {});

    int completedTasks = 0;
    for (var task in _tasks) {
      int currentCount = _petData[task.currentCountKey] as int? ?? 0;
      if (currentCount >= task.requiredCount) {
        completedTasks++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pet Tasks',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Tasks',
                  style: GoogleFonts.fredoka(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTaskProgressSection(completedTasks, _tasks.length),
                const SizedBox(height: 24),
                Text(
                  'Tasks to Complete',
                  style: GoogleFonts.fredoka(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildTaskList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskProgressSection(int completed, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your pet needs attention!',
            style: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete these daily tasks to keep your pet happy and energetic.',
            style: GoogleFonts.fredoka(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text(
                'Completed today: $completed/$total',
                style: GoogleFonts.fredoka(
                  fontSize: 16,
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.separated(
        itemCount: _tasks.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final task = _tasks[index];
          final int currentCount = _petData[task.currentCountKey] as int? ?? 0;
          final bool isCompleted = currentCount >= task.requiredCount;
          final bool isClaimed = _taskStatus[task.id] ?? false;

          final String progressText = _petData.containsKey(task.currentCountKey)
              ? '$currentCount/${task.requiredCount}'
              : '0/${task.requiredCount} (Tracking Needed)';

          return Opacity(
            opacity: isClaimed ? 0.6 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: task.color.withOpacity(0.2),
                  child: Icon(task.icon, color: task.color, size: 26),
                ),
                title: Text(
                  task.name,
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      task.description,
                      style: GoogleFonts.fredoka(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Progress: $progressText',
                          style: GoogleFonts.fredoka(
                            fontSize: 12,
                            color: !_petData.containsKey(task.currentCountKey)
                                ? Colors.red.shade400
                                : (isCompleted ? Colors.green.shade700 : Colors.orange.shade700),
                            fontWeight: FontWeight.w500
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.monetization_on, size: 14, color: Colors.amber.shade700),
                              const SizedBox(width: 3),
                              Text(
                                '${task.coinReward}',
                                style: GoogleFonts.fredoka(
                                  fontSize: 12,
                                  color: Colors.amber.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: (isCompleted && !isClaimed) ? () => _claimReward(task) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isClaimed ? Colors.grey.shade500 : (isCompleted ? Colors.green.shade600 : task.color),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isClaimed ? Colors.grey.shade400 : task.color.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    isClaimed ? 'Claimed' : (isCompleted ? 'Claim' : 'Do Task'),
                    style: GoogleFonts.fredoka(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 