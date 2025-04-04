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
      {
        'name': 'Mindfulness',
        'icon': Icons.self_improvement,
        'description':
            'Basic human ability to be fully present, aware of where we are and what we’re doing, and not overly reactive or overwhelmed by what’s going on around us.',
      },
      {
        'name': 'Breathing',
        'icon': Icons.air,
        'description':
            'Natural process of taking in air and releasing it. Use breathing techniques to reduce stress.',
      },
      {
        'name': 'Self-Care',
        'icon': Icons.favorite,
        'description':
            'Practice of taking care of physical, mental, emotional, and spiritual aspects of your life to promote health and wellness.',
      },
      {
        'name': 'Exercises',
        'icon': Icons.fitness_center,
        'description':
            'Physical activity that enhances or maintains fitness and overall health.',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daily Practice Tips',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final categoryName = category['name'] as String;

            return GestureDetector(
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
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                color: Colors.white,
                child: Stack(
                  children: [
                    // Center the main content
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF6A9BF5),
                            child: Icon(
                              category['icon'] as IconData,
                              size: 35,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              categoryName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Keep the info button in the corner
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Color(0xFF6A9BF5),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(
                                  categoryName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6A9BF5),
                                  ),
                                ),
                                content: Text(
                                  category['description'] as String,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
