class PracticeTip {
  final String title;
  final String description;

  PracticeTip({required this.title, required this.description});

  factory PracticeTip.fromMap(Map<String, dynamic> map) {
    return PracticeTip(
      title: map['title'] as String,
      description: map['description'] as String,
    );
  }
}
