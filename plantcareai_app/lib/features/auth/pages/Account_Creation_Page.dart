import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:plantcareai/core/services/auth_service.dart';
import 'package:plantcareai/core/services/firestore_service.dart';

class AccountCreationPage extends StatefulWidget {
  AccountCreationPage({super.key});

  @override
  _AccountCreationPageState createState() => _AccountCreationPageState();
}

class _AccountCreationPageState extends State<AccountCreationPage> {
  final TextEditingController _fNameController = TextEditingController();
  final TextEditingController _lNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordCofController = TextEditingController();
  bool _isLoading = false; // Loading state

  Future<bool> _createAccountAndStoreData(Map<String, String> data) async {
    try {
      // Await the signup process
      UserCredential userCredential = await signUpWithEmailAndPassword(
        data['email']!,
        data['password']!,
        data['fName']!,
      );

      // If signup successful, proceed to add user data
      String uid = userCredential.user!.uid;
      await addUserData({
        'uid': uid,
        'fName': data['fName']!,
        'lName': data['lName']!,
        'email': data['email']!,
      });
      return true; // Indicate success
    } on FirebaseAuthException {
      // Let the caller handle specific FirebaseAuthException messages
      rethrow;
    } catch (e) {
      // Handle other potential errors during Firestore write etc.
      debugPrint("Error during account creation/storage: $e");
      // Rethrow or return false based on desired handling
      rethrow; // Rethrowing allows the caller to show a generic error
    }
  }

  // Handles the button press logic including validation and async calls
  Future<void> _handleCreateAccount() async {
    if (!mounted) return;

    // --- Input Validation ---
    final fName = _fNameController.text.trim();
    final lName = _lNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text; // Don't trim password
    final confirmPassword = _passwordCofController.text;

    if (fName.isEmpty || lName.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in all fields.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Passwords do not match.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    // --- End Validation ---

    setState(() {
      _isLoading = true;
    });

    try {
      bool success = await _createAccountAndStoreData({
        'fName': fName,
        'lName': lName,
        'email': email,
        'password': password,
      });

      if (success && mounted) {
        // Navigate ONLY on success
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (Route<dynamic> route) => false, // Clear stack
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message ?? 'Signup failed.'),
              backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('An unexpected error occurred: $e'),
              backgroundColor: Colors.redAccent),
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

  @override
  void dispose() {
    _fNameController.dispose();
    _lNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordCofController.dispose();
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
          onPressed: _isLoading
              ? null
              : () {
                  // Disable while loading
                  Navigator.pop(context);
                },
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize:
              MainAxisSize.min, // Ensure Row takes minimum space needed
          children: const [
            Icon(FontAwesomeIcons.leaf,
                color: Colors.white), // Changed color to white for consistency
            SizedBox(width: 8),
            Text(
              'PlantCareAI',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... (Title remains the same) ...
              const SizedBox(height: 20),
              const Text(
                'Create Your Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // First Name Input
              TextField(
                controller: _fNameController,
                textCapitalization:
                    TextCapitalization.words, // Capitalize names
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'First Name',
                  hintText: 'Enter your first name',
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              // Last Name Input
              TextField(
                controller: _lNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  hintText: 'Enter your last name',
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              // Email Address Input
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'Enter your email',
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              // Password Input
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              // Confirm Password Input
              TextField(
                controller: _passwordCofController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Re-enter your password',
                  filled: true,
                ),
              ),
              const SizedBox(height: 30),
              // Create Account Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  // Disable button while loading, call _handleCreateAccount otherwise
                  onPressed: _isLoading ? null : _handleCreateAccount,
                  child: _isLoading
                      ? const SizedBox(
                          // Show progress indicator
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          // Show text
                          'Create Account',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20), // Add some padding at the bottom
            ],
          ),
        ),
      ),
    );
  }
}
