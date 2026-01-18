import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../routes.dart';
import '../../../app_state.dart';
import '../../../services/auth_service.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _errorText;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadRemembered();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getBool('remember_me') ?? false;
    final savedUser = prefs.getString('remembered_username') ?? '';
    setState(() {
      _rememberMe = remembered;
      if (remembered && savedUser.isNotEmpty) {
        usernameController.text = savedUser;
      }
    });
  }

  void _onLoginPressed() async {
    setState(() => _errorText = null);

    if (usernameController.text.isEmpty || passwordController.text.isEmpty) {
      setState(() => _errorText = 'Please enter Username and Password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Authenticate with backend
      final response = await _authService.login(
        usernameController.text,
        passwordController.text,
      );

      // Save remember me preference
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('remember_me', true);
        await prefs.setString('remembered_username', usernameController.text);
      } else {
        await prefs.remove('remember_me');
        await prefs.remove('remembered_username');
      }

      // Clear previous user session before loading new user
      appState.clearUserSession();

      // Set user data from login response
      appState.setUserId(response.user.userId);
      appState.setFirstName(response.user.firstName);
      appState.setLastName(response.user.lastName);
      appState.setUserRole(response.user.role);
      appState.setAccessToken(response.accessToken);

      // Load user-specific persisted data (profile image, custom names)
      await appState.loadUserData();

      if (!mounted) return;
      // Route based on user role
      String routeName;
      if (response.user.role == 'gp') {
        routeName = Routes.gpHome;
      } else if (response.user.role == 'admin') {
        routeName = Routes.admin;
      } else {
        // Default to doctor home page
        routeName = Routes.home;
      }
      Navigator.of(context).pushReplacementNamed(routeName);
    } on SocketException {
      setState(() => _errorText = 'Cannot connect to server. Please check your network.');
    } catch (e) {
      String message = e.toString();
      if (message.contains('Invalid username or password')) {
        message = 'Invalid Username or Password';
      } else if (message.contains('Connection refused')) {
        message = 'Cannot connect to server';
      } else {
        message = 'Login failed. Please try again.';
      }
      setState(() => _errorText = message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onGoogleSignIn() {
    setState(() {
      _errorText =
          'Google sign-in is temporarily disabled until OAuth setup is completed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: usernameController,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w300,
            ),
            decoration: const InputDecoration(
              hintText: 'Enter Your Username',
              hintStyle: TextStyle(color: Colors.white, fontSize: 16),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),

          const SizedBox(height: 20),

          TextFormField(
            controller: passwordController,
            obscureText: _obscurePassword,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w300,
            ),
            decoration: InputDecoration(
              hintText: 'Enter Your Password',
              hintStyle: const TextStyle(color: Colors.white, fontSize: 16),

              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                  size: 18,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
          ),

          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Transform.scale(
                      scale: 1.1,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged:
                            (v) => setState(() => _rememberMe = v ?? false),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        side: const BorderSide(
                          color: Colors.white70,
                          width: 1.2,
                        ),
                        activeColor: Colors.white,
                        checkColor: Colors.black,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Remember me',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    Navigator.of(context).pushNamed(Routes.forgotPassword);
                  },
                  child: Text(
                    'Forgot Password?',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onLoginPressed,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color.fromARGB(
                    255,
                    255,
                    255,
                    255,
                  ).withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: const BorderSide(color: Colors.white, width: 1),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Text(
                          'SIGN IN',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1,
                          ),
                        ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: const [
              Expanded(
                child: Divider(color: Color.fromARGB(255, 255, 255, 255)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'OR',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              Expanded(
                child: Divider(color: Color.fromARGB(255, 255, 255, 255)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _onGoogleSignIn,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: Image.asset('assets/Icons/google_logo.png', height: 30),
                label: const Text(
                  'Sign in with Google',
                  style: TextStyle(color: Color(0xFF686868)),
                ),
              ),
            ),
          ),

          if (_errorText != null) ...[
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
