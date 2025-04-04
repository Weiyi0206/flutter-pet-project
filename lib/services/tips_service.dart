import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import '../models/practice_tip.dart';

class TipsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _logger = Logger('TipsService');

  Future<List<PracticeTip>> getTipsByCategory(String category) async {
    try {
      print('Fetching tips for category: ${category.toLowerCase()}');

      // Query for exact category match
      final QuerySnapshot snapshot =
          await _firestore
              .collection('tips')
              .where('category', isEqualTo: category.toLowerCase())
              .get();

      print('Found ${snapshot.docs.length} tips for $category');

      if (snapshot.docs.isEmpty) {
        print('No tips found for category: $category');
        return [];
      }

      final tips =
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            print(
              'Processing tip: ${data['title']} with category ${data['category']}',
            );
            return PracticeTip.fromMap(data);
          }).toList();

      return tips;
    } catch (e) {
      print('Error fetching tips: $e');
      return [];
    }
  }
}
