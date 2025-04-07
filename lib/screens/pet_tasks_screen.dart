import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pet_model.dart';

class PetTasksScreen extends StatefulWidget {
  final PetModel petModel;
  final Map<String, dynamic> petData;

  const PetTasksScreen({
    Key? key,
    required this.petModel,
    required this.petData,
  }) : super(key: key);

  @override
  State<PetTasksScreen> createState() => _PetTasksScreenState();
}

class _PetTasksScreenState extends State<PetTasksScreen> {
  late Map<String, dynamic> _petData;

  @override
  void initState() {
    super.initState();
    _petData = widget.petData;
  }

  @override
  Widget build(BuildContext context) {
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
                _buildTaskSection(),
                const SizedBox(height: 24),
                Text(
                  'Pet Stats',
                  style: GoogleFonts.fredoka(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatsSection(),
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

  Widget _buildTaskSection() {
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
                'Completed today: 2/4',
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

  Widget _buildStatsSection() {
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
        children: [
          _buildStatBar(
            'Experience',
            _petData['experience'] ?? 0,
            100,
            Colors.amber,
            Icons.star,
          ),
          const SizedBox(height: 16),
          _buildStatBar(
            'Happiness',
            _petData['happiness'] ?? 0,
            100,
            Colors.pink,
            Icons.favorite,
          ),
        ],
      ),
    );
  }

  Widget _buildStatBar(
    String label,
    int value,
    int maxValue,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.fredoka(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    '$value/$maxValue',
                    style: GoogleFonts.fredoka(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: value / maxValue,
                  backgroundColor: color.withOpacity(0.1),
                  color: color,
                  minHeight: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskList() {
    final tasks = [
      {
        'name': 'Pet your companion',
        'description': 'Show some affection by petting',
        'icon': Icons.pets,
        'color': Colors.purple,
        'reward': '+10 Happiness',
      },
      {
        'name': 'Play with your pet',
        'description': 'Spend some time playing',
        'icon': Icons.sports_esports,
        'color': Colors.blue,
        'reward': '+15 XP, +5 Happiness',
      },
      {
        'name': 'Take a nap',
        'description': 'Let your pet rest to gain happiness',
        'icon': Icons.bedtime,
        'color': Colors.indigo,
        'reward': '+15 Happiness',
      },
      {
        'name': 'Training session',
        'description': 'Teach your pet new tricks',
        'icon': Icons.school,
        'color': Colors.teal,
        'reward': '+20 XP',
      },
    ];

    return ListView.separated(
      itemCount: tasks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Container(
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
              backgroundColor: (task['color'] as Color).withOpacity(0.2),
              child: Icon(task['icon'] as IconData, color: task['color'] as Color),
            ),
            title: Text(
              task['name'] as String,
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
                  task['description'] as String,
                  style: GoogleFonts.fredoka(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Reward: ${task['reward']}',
                    style: GoogleFonts.fredoka(
                      fontSize: 12,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: task['color'] as Color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Do Task',
                style: GoogleFonts.fredoka(fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }
} 