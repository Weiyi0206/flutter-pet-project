import 'package:firebase_auth/firebase_auth.dart';
import 'package:helloworld/services/attendance_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AttendanceService _attendanceService = AttendanceService();

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Clear attendance and other user-specific data from SharedPreferences before signing out
      await _attendanceService.clearAttendanceData();
      print('Successfully cleared attendance data before sign out');

      // Then sign out from Firebase Auth
      await _auth.signOut();
    } catch (e) {
      print('Error during sign out: $e');
      // Still attempt to sign out even if clearing data failed
      await _auth.signOut();
      rethrow;
    }
  }
}
