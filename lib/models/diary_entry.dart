import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final String mood;
  final DateTime date;
  final String userId;

  DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.mood,
    required this.date,
    required this.userId,
  });

  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      mood: map['mood'] as String,
      date: (map['date'] as Timestamp).toDate(),
      userId: map['userId'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'mood': mood,
      'date': Timestamp.fromDate(date),
      'userId': userId,
    };
  }
}
