import 'package:cloud_firestore/cloud_firestore.dart';

class HelpDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get helplines from Firestore
  Future<List<Map<String, String>>> getHelplines() async {
    try {
      print("Trying to fetch helplines from Firestore");
      final snapshot = await _firestore.collection('helplines').get();
      print("Helplines snapshot: ${snapshot.docs.length} documents found");

      if (snapshot.docs.isEmpty) {
        print("No helpline documents found in Firestore");
        return [];
      }

      // Debug first document
      if (snapshot.docs.isNotEmpty) {
        print("First helpline doc data: ${snapshot.docs.first.data()}");
        print(
          "First helpline fields: ${snapshot.docs.first.data().keys.join(', ')}",
        );
      }

      final helplinesList = <Map<String, String>>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          helplinesList.add({
            'name': data['name']?.toString() ?? '',
            'number': data['number']?.toString() ?? '',
            'whatsapp': data['whatsapp']?.toString() ?? '',
            'website': data['website']?.toString() ?? '',
            'description': data['description']?.toString() ?? '',
            'email': data['email']?.toString() ?? '',
            'working_hours': data['working_hours']?.toString() ?? '',
          });
        } catch (e) {
          print('Error processing helpline document: $e');
          // Continue to next document instead of failing completely
        }
      }

      return helplinesList;
    } catch (e) {
      print('Error fetching helplines: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get counseling centers from Firestore
  Future<List<Map<String, String>>> getCounselingCenters() async {
    try {
      print("Trying to fetch counseling centers from Firestore");
      final snapshot = await _firestore.collection('counseling_centers').get();
      print(
        "Counseling centers snapshot: ${snapshot.docs.length} documents found",
      );

      if (snapshot.docs.isEmpty) {
        print("No counseling center documents found in Firestore");
        return [];
      }

      // Debug first document
      if (snapshot.docs.isNotEmpty) {
        print(
          "First counseling center doc data: ${snapshot.docs.first.data()}",
        );
        print(
          "First counseling center fields: ${snapshot.docs.first.data().keys.join(', ')}",
        );
      }

      final centersList = <Map<String, String>>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          centersList.add({
            'name': data['name']?.toString() ?? '',
            'description':
                data['description']?.toString() ??
                data['address']?.toString() ??
                '',
            'phone':
                data['phone']?.toString() ?? data['number']?.toString() ?? '',
            'whatsapp': data['whatsapp']?.toString() ?? '',
            'website': data['website']?.toString() ?? '',
            'email': data['email']?.toString() ?? '',
            'address': data['address']?.toString() ?? '',
          });
        } catch (e) {
          print('Error processing counseling center document: $e');
          // Continue to next document instead of failing completely
        }
      }

      return centersList;
    } catch (e) {
      print('Error fetching counseling centers: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Add a new helpline (admin feature)
  Future<void> addHelpline(
    String name,
    String number,
    String whatsapp,
    String website,
    String description,
    String email,
    String workingHours,
  ) async {
    await _firestore.collection('helplines').add({
      'name': name,
      'number': number,
      'whatsapp': whatsapp,
      'website': website,
      'description': description,
      'email': email,
      'working_hours': workingHours,
    });
  }

  // Add a new counseling center (admin feature)
  Future<void> addCounselingCenter(
    String name,
    String address,
    String phone,
    String whatsapp,
    String website,
    String description,
    String email,
  ) async {
    await _firestore.collection('counseling_centers').add({
      'name': name,
      'address': address,
      'phone': phone,
      'whatsapp': whatsapp,
      'website': website,
      'description': description,
      'email': email,
    });
  }
}
