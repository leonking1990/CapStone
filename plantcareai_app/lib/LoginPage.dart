import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fireBaseAuth.dart';

class LoginPage extends StatefulWidget {
  LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for email and password input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false; // State variable for loading indicator

  final Duration _keyboardDismissDelay =
      const Duration(milliseconds: 200); // Delay for keyboard dismissal

  // Method to handle the sign-in logic
  Future<void> _handleSignIn() async {
    if (!mounted) return; // Check if the widget is still in the tree
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      // Await the sign-in function and pass controller text directly
      await signInWithEmailAndPassword(
        _emailController.text.trim(), // Trim whitespace
        _passwordController.text.trim(), // Trim whitespace
      );

      // Navigate ONLY on success
      if (mounted) {
        // Check again if widget is mounted after async operation
        // Clear navigation stack and go to home
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (Route<dynamic> route) => false, // Remove all previous routes
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        // Check if widget is mounted before showing SnackBar
        // Show error message to the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'An unknown error occurred.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Handle any other unexpected errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Hide loading indicator regardless of outcome
        });
      }
    }
  }

  @override
  void dispose() {
    // Dispose controllers when the widget is removed
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            if (!_isLoading) {
              FocusScope.of(context).unfocus(); // Dismiss keyboard
              // Navigate back to the previous screen
              await Future.delayed(_keyboardDismissDelay);
              if (mounted) {
                // Use maybePop to respect WillPopScope
                Navigator.maybePop(context);
              }
            }
          },
        ),
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Image section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.asset(
                  'assets/login_image.png',
                  height: 200, // Adjust height as needed
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Text(
                'PlantCareAI',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              // Email Input Field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                ),
              ),
              const SizedBox(height: 16),
              // Password Input Field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                ),
              ),
              const SizedBox(height: 10),
              // Forgot Password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          // Disable while loading
                          // Handle forgot password
                        },
                  child: const Text(
                    'Forgot your password?',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Sign In Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Red button color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isLoading ? null : _handleSignIn,
                  child: _isLoading
                      ? const SizedBox(
                          // Show progress indicator when loading
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          // Show text otherwise
                          'Sign In',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
