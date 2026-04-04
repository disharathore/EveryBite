import 'package:everybite/homepage.dart';
import 'package:everybite/signuppage.dart';
import 'package:everybite/services/mongo_user_service.dart';
import 'package:everybite/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool passwordVisible = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = ''; // Variable to hold error message

  Future<void> _loginWithEmail() async {
    setState(() {
      _errorMessage = ''; // Clear any previous error messages
    });

    try {
      final user = await MongoUserService.instance.loginWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (user != null) {
        SessionService.currentUserId = user['user_id'] as String?;
        // If login is successful, navigate to the home page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Homepage()),
        );
      } else {
        Fluttertoast.showToast(
          msg: 'Login failed. Please try again later.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      if (errorText.contains('missing in .env')) {
        Fluttertoast.showToast(
          msg: 'Server setup missing. Please configure MongoDB in .env.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        Fluttertoast.showToast(
          msg: 'Incorrect email or password. Please try again.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
      print("Login Error: $e");
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.isNotEmpty) {
      try {
        final exists = await MongoUserService.instance
            .userExistsByEmail(_emailController.text);
        setState(() {
          _errorMessage = exists
              ? 'Password reset requested. Please contact support.'
              : 'No user found for this email.';
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Error checking account for password reset.';
        });
        print("Reset Error: $e");
      }
    } else {
      setState(() {
        _errorMessage = 'Please enter your email.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    void navigateToSignup() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SignUp()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/image/1.png', // Replace with your image path
              fit: BoxFit.cover, // Makes the image cover the entire background
            ),
          ),
          // Semi-transparent Overlay (optional, for readability)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4), // Dark overlay
            ),
          ),
          // Content
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Login Heading
                  Text(
                    'Login',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40), // Space below heading
                  // Email TextField
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        labelText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        prefixIcon: const Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(height: 20), // Space between fields
                  // Password TextField
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: TextField(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        labelText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        prefixIcon: const Icon(Icons.lock),
                      ),
                      controller: _passwordController,
                      obscureText: !passwordVisible,
                    ),
                  ),

                  TextButton(
                    onPressed: _forgotPassword,
                    child: const Text(
                      "Forgot Password?",
                      style:
                          TextStyle(color: Color.fromARGB(255, 254, 254, 254)),
                    ),
                  ),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                      ),
                    ), // Space before login button
                  // Login Button
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loginWithEmail,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      backgroundColor: Color(0xFFA7FF4F), // Custom button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                          fontSize: 18, color: Color.fromARGB(255, 0, 0, 0)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: GestureDetector(
                      onTap: navigateToSignup,
                      child: const Text(
                        "Create a new account",
                        style: TextStyle(
                          fontSize: 18,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
