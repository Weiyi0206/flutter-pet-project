import 'package:flutter/material.dart';
import '../services/tips_service.dart';
import 'category_tips_screen.dart';

class DailyTipsScreen extends StatefulWidget {
  const DailyTipsScreen({super.key});

  @override
  State<DailyTipsScreen> createState() => _DailyTipsScreenState();
}

class _DailyTipsScreenState extends State<DailyTipsScreen> {
  final TipsService _tipsService = TipsService();

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'name': 'Mindfulness', 'icon': Icons.self_improvement},
      {'name': 'Breathing', 'icon': Icons.air},
      {'name': 'Self-Care', 'icon': Icons.favorite},
      {'name': 'Exercises', 'icon': Icons.fitness_center},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Practice Tips')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final categoryName = categories[index]['name'] as String;
          return Card(
            elevation: 4,
            child: InkWell(
              onTap: () async {
                final tips = await _tipsService.getTipsByCategory(categoryName);
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => CategoryTipsScreen(
                            categoryName: categoryName,
                            tips: tips,
                          ),
                    ),
                  );
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(categories[index]['icon'] as IconData, size: 48),
                  const SizedBox(height: 8),
                  Text(categoryName, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
