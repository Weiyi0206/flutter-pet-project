import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import '../models/practice_tip.dart';

class TipsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _logger = Logger('TipsService');

  Future<List<PracticeTip>> getTipsByCategory(String category) async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection('tips')
              .where('category', isEqualTo: category)
              .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      final doc = snapshot.docs.first;
      final List<dynamic> tipsData = doc['tips'] as List<dynamic>;

      return tipsData
          .map(
            (tipData) => PracticeTip.fromMap(tipData as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      _logger.severe('Error fetching tips for category $category:', e);
      return [];
    }
  }
}
