import 'package:flutter/material.dart';
import '../models/practice_tip.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(categoryName)),
      body:
          tips.isEmpty
              ? const Center(child: Text('No tips available'))
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tips.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      title: Text(
                        tips[index].title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(tips[index].description),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
