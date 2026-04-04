import 'package:everybite/homepage.dart';
import 'package:everybite/loginpage.dart';
import 'package:everybite/services/mongo_user_service.dart';
import 'package:everybite/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = false;
  String? _selectedGender;
  String? _selectedDietaryPreference;
  String? _pregnancyStatus;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = await MongoUserService.instance.createUser(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        age: _ageController.text.trim(),
        gender: _selectedGender,
        dietaryPreference: _selectedDietaryPreference,
        allergies: _allergiesController.text.trim(),
        pregnancyStatus: _pregnancyStatus,
      );
      SessionService.currentUserId = userId;

      Fluttertoast.showToast(
        msg: "Account created successfully!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const Homepage(),
        ),
      );
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      final alreadyRegistered = errorText.contains('email-already-in-use');
      final message = alreadyRegistered
          ? 'This email is already registered. Please login.'
          : 'Sign up failed: $e';
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      if (alreadyRegistered && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Account Already Exists'),
            content: const Text('This email is already registered. Please login instead.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                child: const Text('Go To Login'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _askPregnancyStatus() {
    if (_selectedGender == 'Female') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Pregnancy Status"),
          content: const Text("Are you pregnant?"),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _pregnancyStatus = 'No';
                });
                Navigator.of(context).pop();
              },
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _pregnancyStatus = 'Yes';
                });
                Navigator.of(context).pop();
              },
              child: const Text("Yes"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/image/1.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
                color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.6)),
          ),
          Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        "Create a new account",
                        style: GoogleFonts.ebGaramond(
                          color: const Color.fromARGB(255, 182, 225, 192),
                          fontSize: 25,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      width: 360,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(18),
                                  right: Radius.circular(18),
                                ),
                              ),
                              labelStyle: TextStyle(color: Colors.white),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 17),
                          DropdownButtonFormField<String>(
                            style: const TextStyle(color: Colors.white),
                            dropdownColor: Colors.black,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              prefixIcon: Icon(Icons.people_alt_sharp),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(18),
                                  right: Radius.circular(18),
                                ),
                              ),
                              labelStyle: TextStyle(color: Colors.white),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Male',
                                child: Text('Male'),
                              ),
                              DropdownMenuItem(
                                value: 'Female',
                                child: Text('Female'),
                              ),
                              DropdownMenuItem(
                                value: 'Other',
                                child: Text('Other'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedGender = value;
                              });
                              _askPregnancyStatus(); // Check pregnancy status if female
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your gender';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 17),
                          TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Age',
                              prefixIcon: Icon(Icons.cake),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(18),
                                  right: Radius.circular(18),
                                ),
                              ),
                              labelStyle: TextStyle(color: Colors.white),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty ||
                                  int.tryParse(value) == null) {
                                return 'Please enter a valid age';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 17),
                          DropdownButtonFormField<String>(
                            style: const TextStyle(color: Colors.white),
                            dropdownColor: Colors.black,
                            decoration: const InputDecoration(
                              labelText: 'Dietary Preference',
                              prefixIcon: Icon(Icons.local_hospital),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(18),
                                  right: Radius.circular(18),
                                ),
                              ),
                              labelStyle: TextStyle(color: Colors.white),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Vegetarian',
                                child: Text('Vegetarian'),
                              ),
                              DropdownMenuItem(
                                value: 'Non-Vegetarian',
                                child: Text('Non-Vegetarian'),
                              ),
                              DropdownMenuItem(
                                value: 'Vegan',
                                child: Text('Vegan'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedDietaryPreference = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your dietary preference';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 17),
                          TextFormField(
                            controller: _allergiesController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Allergies (if any)',
                              prefixIcon: Icon(Icons.health_and_safety),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(18),
                                  right: Radius.circular(18),
                                ),
                              ),
                              labelStyle: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 17),
                          TextFormField(
                            controller: _emailController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(18),
                                  right: Radius.circular(18),
                                ),
                              ),
                              labelStyle: TextStyle(color: Colors.white),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              } else if (!RegExp(
                                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                                  .hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 17),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_passwordVisible,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(_passwordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () {
                                  setState(() {
                                    _passwordVisible = !_passwordVisible;
                                  });
                                },
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(18),
                                  right: Radius.circular(18),
                                ),
                              ),
                              labelStyle: const TextStyle(color: Colors.white),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 17),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_confirmPasswordVisible,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(_confirmPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () {
                                  setState(() {
                                    _confirmPasswordVisible =
                                        !_confirmPasswordVisible;
                                  });
                                },
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(18),
                                  right: Radius.circular(18),
                                ),
                              ),
                              labelStyle: const TextStyle(color: Colors.white),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              } else if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _signUpWithEmail,
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : const Text('Sign Up'),
                          ),
                        ],
                      ),
                    ),
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
