import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/practice_tip.dart';
import 'tip_detail_screen.dart';

class CategoryTipsScreen extends StatelessWidget {
  final String categoryName;
  final List<PracticeTip> tips;

  const CategoryTipsScreen({
    super.key,
    required this.categoryName,
    required this.tips,
  });

  @override
  Widget build(BuildContext context) {
    print('Building CategoryTipsScreen');
    print('Category name: $categoryName');
    print('Number of tips: ${tips.length}');
    if (tips.isEmpty) {
      print('Tips list is empty!');
    } else {
      tips.forEach((tip) {
        print('Tip title: ${tip.title}');
      });
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          categoryName,
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6A9BF5),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF6A9BF5)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body:
          tips.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'No tips available for this category',
                      style: GoogleFonts.fredoka(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Category: $categoryName',
                      style: GoogleFonts.fredoka(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tips.length,
                itemBuilder: (context, index) {
                  final tip = tips[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.white,
                    elevation: 2,
                    child: ExpansionTile(
                      initiallyExpanded:
                          true, // Add this line to expand by default
                      maintainState:
                          true, // Add this to maintain the expanded state
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6A9BF5).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getTipIcon(
                            tip.category,
                          ), // Changed from tip.title to tip.category
                          size: 24,
                          color: const Color(0xFF6A9BF5),
                        ),
                      ),
                      title: Text(
                        tip.title,
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        tip.benefit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fredoka(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TipDetailScreen(tip: tip),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tip.description,
                                  style: GoogleFonts.fredoka(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                TipDetailScreen(tip: tip),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6A9BF5),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(
                                      double.infinity,
                                      45,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'View Details',
                                    style: GoogleFonts.fredoka(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }

  IconData _getTipIcon(String category) {
    // Convert category to lowercase for case-insensitive comparison
    final lowerCategory = category.toLowerCase();

    switch (lowerCategory) {
      case 'breathing':
        return Icons.air;
      case 'mindfulness':
        return Icons.self_improvement;
      case 'exercise':
      case 'exercises':
        return Icons.fitness_center;
      case 'self-care':
      case 'selfcare':
        return Icons.favorite;
      default:
        return Icons.tips_and_updates;
    }
  }
}
