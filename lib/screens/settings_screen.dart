import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';
  int _appUsageCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _selectedLanguage = prefs.getString('selectedLanguage') ?? 'English';
      _appUsageCount = prefs.getInt('appUsageCount') ?? 0;
    });
  }

  void _navigateToAccountSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AccountSettingsScreen()),
    );
  }

  void _changePassword(BuildContext context) async {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
                obscureText: true,
              ),
              TextField(
                controller: newPasswordController,
                decoration: const InputDecoration(labelText: 'New Password'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  try {
                    // Re-authenticate the user
                    final cred = EmailAuthProvider.credential(
                      email: user.email!,
                      password: currentPasswordController.text,
                    );
                    await user.reauthenticateWithCredential(cred);

                    // Update the password
                    await user.updatePassword(newPasswordController.text);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password changed successfully!'),
                      ),
                    );
                  } on FirebaseAuthException catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.message}')),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('An unexpected error occurred: $e'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Change'),
            ),
          ],
        );
      },
    );
  }

  void _deleteAccount(BuildContext context) async {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: TextField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: 'Current Password'),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  try {
                    // Re-authenticate the user
                    final cred = EmailAuthProvider.credential(
                      email: user.email!,
                      password: passwordController.text,
                    );
                    await user.reauthenticateWithCredential(cred);

                    // Delete the account
                    await user.delete();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account deleted successfully!'),
                      ),
                    );
                  } on FirebaseAuthException catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.message}')),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notifications ${value ? 'enabled' : 'disabled'}'),
      ),
    );
  }

  void _changeLanguage(String? newValue) async {
    if (newValue != null) {
      setState(() {
        _selectedLanguage = newValue;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedLanguage', newValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Language changed to $_selectedLanguage')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [

          // Account Section
          ListTile(
            title: const Text('Account'),
            subtitle: const Text('Manage your account settings'),
            leading: const Icon(Icons.account_circle),
            onTap: _navigateToAccountSettings,
          ),
          ListTile(
            title: const Text('Change Password'),
            leading: const Icon(Icons.lock),
            onTap: () => _changePassword(context),
          ),
          ListTile(
            title: const Text('Delete Account'),
            leading: const Icon(Icons.delete),
            onTap: () => _deleteAccount(context),
          ),
          const Divider(),

          // Time Management
          ListTile(
            title: const Text('Time Management'),
            subtitle: Text('You’ve spent time with your pet $_appUsageCount times 💖'),
            leading: const Icon(Icons.timer),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tracking your self-care progress 💪')),
              );
            },
          ),

          const Divider(),

          // Notifications
          SwitchListTile(
            title: const Text('Notifications'),
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
            secondary: const Icon(Icons.notifications),
          ),
          const Divider(),

          // App Language
          ListTile(
            title: const Text('App Language'),
            leading: const Icon(Icons.language),
            trailing: DropdownButton<String>(
              value: _selectedLanguage,
              onChanged: _changeLanguage,
              items:
                  <String>[
                    'English',
                    'Malay',
                    'Mandarin',
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: user == null
          ? const Center(child: Text('No user is currently logged in.'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Account Info',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  _infoTile('Display Name', user.displayName ?? 'Not set'),
                  _infoTile('Email', user.email ?? 'Not set'),
                  _infoTile('Password', '•••••••• (hidden)'),

                  const SizedBox(height: 30),

                  ElevatedButton.icon(
                    onPressed: () async {
                      if (user.email != null) {
                        await FirebaseAuth.instance
                            .sendPasswordResetEmail(email: user.email!);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password reset email sent!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('Reset Password'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
