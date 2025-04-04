class PracticeTip {
  final String category;
  final String title;
  final String description;
  final String place;
  final String benefit;
  final List<String> steps;
  final String videoUrl;
  final String imageUrl;
  final String articleUrl;

  const PracticeTip({
    required this.category,
    required this.title,
    required this.description,
    this.place = '', // Made place optional with empty default
    required this.benefit,
    this.steps = const [],
    this.videoUrl = '',
    this.imageUrl = '',
    this.articleUrl = '',
  });

  factory PracticeTip.fromMap(Map<String, dynamic> map) {
    return PracticeTip(
      category: map['category'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      place: map['place'] as String? ?? '', // Handle missing place field
      benefit: map['benefit'] as String,
      steps:
          map['steps'] != null
              ? List<String>.from(map['steps'] as List)
              : (map['Steps'] != null
                  ? List<String>.from(map['Steps'] as List)
                  : []),
      videoUrl: map['videoUrl'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      articleUrl: map['articleUrl'] as String? ?? '',
    );
  }
}
