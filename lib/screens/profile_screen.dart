import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No changes detected.')));
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
        title: Text('Profile', style: GoogleFonts.fredoka()),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      child: ClipOval(
                        child:
                            _currentUser?.photoURL != null
                                ? Image.network(
                                  _currentUser!.photoURL!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      size: 50,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSecondaryContainer,
                                    );
                                  },
                                )
                                : Icon(
                                  Icons.person,
                                  size: 50,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSecondaryContainer,
                                ),
                      ),
                    ),
                  ),
                ],
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
              child:
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                        onPressed: _saveChanges,
                        icon: const Icon(Icons.save),
                        label: Text(
                          'Save Changes',
                          style: GoogleFonts.fredoka(),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final File imageFile = File(pickedFile.path);

      // Define Firebase Storage reference (e.g., profile_pics/user_uid.jpg)
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pics')
          .child('${_currentUser!.uid}.jpg');

      // Upload the file
      await storageRef.putFile(imageFile);

      // Get the download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firebase Auth profile photoURL
      //await _currentUser!.updatePhotoURL(downloadUrl);
      await FirebaseAuth.instance.currentUser!.updatePhotoURL(downloadUrl);

      // Refresh UI
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
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
}