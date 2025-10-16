import 'package:flutter/material.dart';
import '../widgets/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🖼️ Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // 🧱 Foreground content
          // ✨ DEBUGGING TEST: Using Align with topCenter to force it to the top.
          Align(
            alignment: Alignment.topCenter, // This is a very obvious change
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 90), // Added vertical padding
                child: Column(
                  mainAxisSize: MainAxisSize.min, // This is very important!
                  children: [
                    // 🚀 LOGO WIDGET
                    Image.asset(
                      'assets/images/Allcarelogo.png',
                      height: 60,
                    ),

                    // 📏 SPACER
                    const SizedBox(height: 80),

                    // 📄 LoginForm widget
                    const LoginForm(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}