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
    // Add more tasks here (e.g., play, groom, etc.)
    PetTask(
      id: 'play_2_times',
      name: 'Play Session',
      description: 'Play with your pet 2 times',
      icon: Icons.sports_esports,
      color: Colors.blue,
      requiredCount: 2, // Needs PetModel to track 'playsToday'
      currentCountKey: 'playsToday', // <<< IMPORTANT: PetModel needs to track this!
      coinReward: 2,
    ),
    PetTask(
      id: 'groom_1_time',
      name: 'Grooming',
      description: 'Groom your pet once',
      icon: Icons.cleaning_services,
      color: Colors.green,
      requiredCount: 1, // Needs PetModel to track 'groomsToday'
      currentCountKey: 'groomsToday', // <<< IMPORTANT: PetModel needs to track this!
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
    _petData = widget.petData;
    _taskStatus = Map<String, bool>.from(_petData['dailyTaskStatus'] ?? {});

    int completedTasks = 0;
    _tasks.forEach((task) {
      int currentCount = _petData[task.currentCountKey] as int? ?? 0;
      if (currentCount >= task.requiredCount) {
        completedTasks++;
      }
    });

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
                    fontSize: 24,
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    return ListView.separated(
      itemCount: _tasks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final task = _tasks[index];
        final int currentCount = _petData[task.currentCountKey] as int? ?? 0;
        final bool isCompleted = currentCount >= task.requiredCount;
        final bool isClaimed = _taskStatus[task.id] ?? false;

        final String progressText = '${task.currentCountKey.contains("Today") ? currentCount : "?"}/${task.requiredCount}';

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
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                backgroundColor: task.color.withOpacity(0.2),
                child: Icon(task.icon, color: task.color),
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
                  const SizedBox(height: 4),
                  Text(
                    'Progress: $progressText',
                    style: GoogleFonts.fredoka(
                      fontSize: 12,
                      color: isCompleted ? Colors.green.shade700 : Colors.orange.shade700,
                      fontWeight: FontWeight.w500
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      'Reward: ${task.coinReward} Coins',
                      style: GoogleFonts.fredoka(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: (isCompleted && !isClaimed) ? () => _claimReward(task) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClaimed ? Colors.grey : (isCompleted ? Colors.green : task.color),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isClaimed ? Colors.grey.shade400 : task.color.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  isClaimed ? 'Claimed' : (isCompleted ? 'Claim' : 'Do Task'),
                  style: GoogleFonts.fredoka(fontSize: 12),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
} 