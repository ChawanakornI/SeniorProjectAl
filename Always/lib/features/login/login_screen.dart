import 'package:flutter/material.dart';
import 'widget/login_form.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/LoginBGJPEG.jpg', fit: BoxFit.cover),
          ),

          Positioned(
            top: 60,
            left: 35,
            child: SafeArea(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset('assets/images/LogoVector.svg', height: 40),
                  const SizedBox(width: 20),

                  SvgPicture.asset(
                    'assets/images/AllcareTextVector.svg',
                    height: 20,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 165, 32, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detect skin cancer early with AI',
                      style: GoogleFonts.inter(
                        fontSize: 37,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Capture or upload a skin photo to get an instant\n'
                      'AI-based skin analysis and insights for early detection.',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w300,
                        height: 1.25,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 28),

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
