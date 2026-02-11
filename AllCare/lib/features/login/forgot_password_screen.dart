import 'dart:ui';

import 'package:allcare/theme/glass.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password reset link sent (mock).'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFF2563EB);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Forgot Password',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/LoginBGJPEG.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: isDark ? 0.55 : 0.2),
                    Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          _glowBlob(
            alignment: Alignment.topRight,
            color: const Color(0xFF60A5FA).withValues(alpha: 0.32),
            size: 220,
          ),
          _glowBlob(
            alignment: Alignment.bottomLeft,
            color: const Color(0xFF22D3EE).withValues(alpha: 0.28),
            size: 240,
            blur: 42,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: glassBox(isDark, radius: 24, highlight: true),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reset your password',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'We will send you a secure link to restore access.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black.withValues(alpha: 0.65),
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'name@example.com',
                                  prefixIcon: Icon(
                                    Icons.alternate_email,
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : Colors.grey.shade700,
                                  ),
                                  filled: true,
                                  fillColor:
                                      isDark
                                          ? Colors.white.withValues(alpha: 0.04)
                                          : Colors.white.withValues(alpha: 0.75),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.24),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(alpha: 
                                        isDark ? 0.18 : 0.12,
                                      ),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: accent,
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Email is required';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _submit,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    backgroundColor: accent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Send Reset Link',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowBlob({
    required Alignment alignment,
    required Color color,
    double size = 200,
    double blur = 32,
  }) {
    return Align(
      alignment: alignment,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }
}
