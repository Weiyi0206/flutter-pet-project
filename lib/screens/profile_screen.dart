import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  late TextEditingController _displayNameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: _currentUser?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_currentUser == null) return;

    final newDisplayName = _displayNameController.text.trim();
    if (newDisplayName == _currentUser?.displayName) {
      // No changes made
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes detected.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _currentUser!.updateDisplayName(newDisplayName);
      // Optional: Update Firestore user document if you store display name there too

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display name updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      // Refresh user data locally if needed, though FirebaseAuth instance updates
      // You might call setState here if other parts of the UI depend on _currentUser.displayName
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating display name: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.fredoka(),
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                child: Icon(
                  Icons.person,
                  size: 50,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Email:',
              style: GoogleFonts.fredoka(
                fontSize: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _currentUser?.email ?? 'N/A',
              style: GoogleFonts.fredoka(fontSize: 18),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: GoogleFonts.fredoka(),
                hintText: 'Enter your display name',
                hintStyle: GoogleFonts.fredoka(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: GoogleFonts.fredoka(fontSize: 16),
            ),
            const SizedBox(height: 30),
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _saveChanges,
                      icon: const Icon(Icons.save),
                      label: Text('Save Changes', style: GoogleFonts.fredoka()),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        textStyle: GoogleFonts.fredoka(fontSize: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
} 