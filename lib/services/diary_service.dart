import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/diary_entry.dart';
import 'package:uuid/uuid.dart';

class DiaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  // Get the current user ID or return null if not logged in
  String? get _userId => _auth.currentUser?.uid;

  // Get all diary entries for the current user
  Future<List<DiaryEntry>> getDiaryEntries() async {
    if (_userId == null) return [];

    try {
      final snapshot =
          await _firestore
              .collection('diaries')
              .doc(_userId)
              .collection('entries')
              .orderBy('date', descending: true)
              .get();

      return snapshot.docs
          .map((doc) => DiaryEntry.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching diary entries: $e');
      return [];
    }
  }

  // Get a single diary entry by ID
  Future<DiaryEntry?> getDiaryEntry(String entryId) async {
    if (_userId == null) return null;

    try {
      final doc =
          await _firestore
              .collection('diaries')
              .doc(_userId)
              .collection('entries')
              .doc(entryId)
              .get();

      if (!doc.exists) return null;
      return DiaryEntry.fromMap(doc.data()!);
    } catch (e) {
      print('Error fetching diary entry: $e');
      return null;
    }
  }

  // Add a new diary entry
  Future<DiaryEntry?> addDiaryEntry(
    String title,
    String content,
    String mood,
  ) async {
    if (_userId == null) return null;

    try {
      final entryId = _uuid.v4();
      final entry = DiaryEntry(
        id: entryId,
        title: title,
        content: content,
        mood: mood,
        date: DateTime.now(),
        userId: _userId!,
      );

      await _firestore
          .collection('diaries')
          .doc(_userId)
          .collection('entries')
          .doc(entryId)
          .set(entry.toMap());

      return entry;
    } catch (e) {
      print('Error adding diary entry: $e');
      return null;
    }
  }

  // Update an existing diary entry
  Future<bool> updateDiaryEntry(DiaryEntry entry) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('diaries')
          .doc(_userId)
          .collection('entries')
          .doc(entry.id)
          .update(entry.toMap());
      return true;
    } catch (e) {
      print('Error updating diary entry: $e');
      return false;
    }
  }

  // Delete a diary entry
  Future<bool> deleteDiaryEntry(String entryId) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('diaries')
          .doc(_userId)
          .collection('entries')
          .doc(entryId)
          .delete();
      return true;
    } catch (e) {
      print('Error deleting diary entry: $e');
      return false;
    }
  }
}
