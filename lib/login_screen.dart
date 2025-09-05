// login_screen.dart
import 'package:flutter/material.dart';
import 'package:student_attendance/home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Login')),
      body: Center(
        child: ElevatedButton(
          child: const Text("Login as Teacher"),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          },
        ),
      ),
    );
  }
}