import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import '../models/practice_tip.dart';

class TipsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _logger = Logger('TipsService');

  Future<List<PracticeTip>> getTipsByCategory(String category) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('tips')
          .where('category', isEqualTo: category)
          .get()
          .then((snapshot) => snapshot.docs.first);

      final List<dynamic> tipsData = doc['tips'] as List<dynamic>;
      return tipsData
          .map(
            (tipData) => PracticeTip(
              title: tipData['title'],
              description: tipData['description'],
            ),
          )
          .toList();
    } catch (e) {
      _logger.severe('Error fetching tips for category $category:', e);
      return [];
    }
  }
}
