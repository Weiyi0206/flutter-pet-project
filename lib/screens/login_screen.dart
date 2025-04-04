import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/attendance_service.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onRegisterPress;
  const LoginScreen({super.key, required this.onRegisterPress});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  Future<void> _signIn() async {
    try {
      await _authService.signInWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
      );
      //if (!mounted) return;
      // Call check-in prompt after successful login
      //await _onLoginSuccess();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()))
      );
    }
  }

  // Future<void> _onLoginSuccess() async {
  //   final attendanceService = AttendanceService();
    
  //   if (await attendanceService.shouldShowCheckInPrompt()) {
  //     if (!mounted) return;
      
  //     // Show check-in dialog
  //     await showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (BuildContext context) {
  //         return AlertDialog(
  //           title: const Text('Welcome Back!'),
  //           content: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               const Text('Would you like to check in for today?'),
  //               const SizedBox(height: 10),
  //               const Text(
  //                 'Daily check-ins help keep your pet happy!',
  //                 style: TextStyle(fontSize: 12, color: Colors.grey)
  //               ),
  //             ],
  //           ),
  //           actions: [
  //             TextButton(
  //               child: const Text('Later', style: TextStyle(color: Colors.grey)),
  //               onPressed: () {
  //                 Navigator.of(context).pop();
  //                 _navigateToHome();
  //               },
  //             ),
  //             ElevatedButton(
  //               child: const Text('Check In'),
  //               onPressed: () async {
  //                 try {
  //                   final result = await attendanceService.markAttendanceWithMood(mood['label'] as String);
  //                   if (!mounted) return;
  //                   Navigator.of(context).pop();
                    
  //                   ScaffoldMessenger.of(context).showSnackBar(
  //                     SnackBar(
  //                       content: Text(result.message),
  //                       duration: const Duration(seconds: 2),
  //                       backgroundColor: result.success ? Colors.green : Colors.red,
  //                     ),
  //                   );
                    
  //                   if (result.success && result.reward != null) {
  //                     if (!mounted) return;
  //                     await showDialog(
  //                       context: context,
  //                       builder: (BuildContext context) {
  //                         return AlertDialog(
  //                           title: const Text('🎉 Reward!'),
  //                           content: Column(
  //                             mainAxisSize: MainAxisSize.min,
  //                             children: [
  //                               if (result.reward!.imageUrl != null)
  //                                 Image.asset(
  //                                   result.reward!.imageUrl!,
  //                                   height: 100,
  //                                   width: 100,
  //                                 ),
  //                               const SizedBox(height: 10),
  //                               Text('You earned: ${result.reward!.name}'),
  //                               Text(
  //                                 'Happiness boost: +${result.reward!.happinessBoost}',
  //                                 style: const TextStyle(
  //                                   color: Colors.green,
  //                                   fontWeight: FontWeight.bold
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                           actions: [
  //                             ElevatedButton(
  //                               child: const Text('Awesome!'),
  //                               onPressed: () {
  //                                 Navigator.of(context).pop();
  //                                 _navigateToHome();
  //                               },
  //                             ),
  //                           ],
  //                         );
  //                       },
  //                     );
  //                   } else {
  //                     _navigateToHome();
  //                   }
  //                 } catch (e) {
  //                   ScaffoldMessenger.of(context).showSnackBar(
  //                     const SnackBar(
  //                       content: Text('Failed to check in. Please try again.'),
  //                       backgroundColor: Colors.red,
  //                     ),
  //                   );
  //                   _navigateToHome();
  //                 }
  //               },
  //             ),
  //           ],
  //         );
  //       },
  //     );
  //   } else {
  //     _navigateToHome();
  //   }
  // }

  void _navigateToHome() {
  Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MyHomePage(
            title: 'Virtual Pet Companion',
          ),
        ),
      );
  } 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signIn,
              child: const Text('Sign In')
            ),
            TextButton(
              onPressed: widget.onRegisterPress,
              child: const Text('Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}