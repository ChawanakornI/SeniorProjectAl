import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';


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

  final String correctUsername = "user"; // example
  final String correctPassword = "123456"; // example

  void _onLoginPressed() async {
    setState(() => _errorText = null);

    final usernameEmpty = usernameController.text.isEmpty;
    final passwordEmpty = passwordController.text.isEmpty;

    if (usernameEmpty && passwordEmpty) {
      setState(() => _errorText = 'Please enter Username and Password');
      return;
    } else if (usernameEmpty) {
      setState(() => _errorText = 'Please enter Username');
      return;
    } else if (passwordEmpty) {
      setState(() => _errorText = 'Please enter Password');
      return;
    }

    // Check credentials
    if (usernameController.text != correctUsername ||
        passwordController.text != correctPassword) {
      setState(() => _errorText = 'Invalid Username or Password');
      return;
    }

    // Credentials correct, simulate login
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isLoading = false;
      _errorText = null;
    });

    // Optional: show snackbar on success
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Login successful! 🎉 Welcome ${usernameController.text}')),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFF686868),
      ),
      border: InputBorder.none,
      prefixIcon: Icon(prefixIcon, color: Colors.grey.shade600),
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 0),
    );
  }

  Widget _buildNeumorphicField({required Widget child}) {
    return SizedBox(
      width: 300,
      height: 40,
      child: Neumorphic(
        style: NeumorphicStyle(
          shape: NeumorphicShape.concave,
          depth: -2.5,
          intensity: 0.7,
          lightSource: LightSource.topLeft,
          color: Colors.white,
          border: NeumorphicBorder(
            color: Colors.grey.shade300,
            width: 0.5,
          ),
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(8)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 5),
              const Text(
                "Sign In",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                
              ),
              const SizedBox(height: 4),
              const Text(
                "Login into your account to continue",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
                
              ),
              const SizedBox(height: 15),

              // Username Field
              _buildNeumorphicField(
                child: TextFormField(
                  controller: usernameController,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF686868),
                  ),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: _buildInputDecoration(
                    hintText: 'Username',
                    prefixIcon: Icons.person_outline,
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Password Field
              _buildNeumorphicField(
                child: TextFormField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF686868),
                  ),
                  decoration: _buildInputDecoration(
                    hintText: 'Password',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 0),

              // Remember Me and Forgot Password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (bool? newValue) {
                            setState(() {
                              _rememberMe = newValue ?? false;
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          side: const BorderSide(
                              color: Colors.black54, width: 1),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          fillColor: MaterialStateProperty.resolveWith<Color>(
                              (states) {
                            if (states.contains(MaterialState.selected)) {
                              return const Color.fromARGB(255, 26, 68, 160);
                            }
                            return Colors.white;
                          }),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Remember me',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Sign In Button 
              Container(
                width: 300,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onLoginPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF282828),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0, // prevent double shadow
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // OR Divider
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Colors.grey.shade400,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Colors.grey.shade400,
                      thickness: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Sign in with Google Button
              SizedBox(
  width: 300,
  height: 40,
  child: Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8), // Consistent radius
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          blurRadius: 4,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    // The OutlinedButton should be the child of the Container
    child: OutlinedButton.icon(
      onPressed: () {
        // TODO: Implement Google Sign-In logic
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white, // Ensure it has a background
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Consistent radius
        ),
        side: const BorderSide(color: Colors.grey, width: 0.5),
      ),
      icon: Image.asset(
        'assets/images/google_logo.png', // Make sure this asset exists
        height: 20.0,
      ),
      label: const Text(
        'Sign in with Google',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    ),
  ),
),
const SizedBox(height: 10),

              // ERROR TEXT BELOW
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
