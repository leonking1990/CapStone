import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isChanging = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    // Validate the form first
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isChanging = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    final String currentPassword = _currentPasswordController.text;
    final String newPassword = _newPasswordController.text;

    if (user == null || user.email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error: User not found or email missing.'),
              backgroundColor: Colors.redAccent),
        );
        setState(() {
          _isChanging = false;
        });
      }
      return;
    }

    try {
      // 1. Re-authenticate the user with their current password
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. If re-authentication is successful, update the password
      await user.updatePassword(newPassword);

      // 3. Success: Show message and pop
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Password updated successfully! Please log in again if needed.'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back to settings page
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'An error occurred.';
        if (e.code == 'wrong-password') {
          errorMessage = 'Incorrect current password. Please try again.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'The new password is too weak.';
        } else if (e.code == 'requires-recent-login') {
          errorMessage =
              'This operation requires a recent login. Please log out and log back in.';
        } else {
          errorMessage = e.message ?? errorMessage;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('An unexpected error occurred: ${e.toString()}'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChanging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use theme colors
    final Color? labelColor = Theme.of(context).textTheme.bodyMedium?.color;
    final Color? valueColor = Theme.of(context).textTheme.bodyLarge?.color;
    final Color? inputFillColor =
        Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[200];
    final Color iconColor = Theme.of(context).iconTheme.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white70
            : Colors.black54);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Change Password",
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color)),
            const SizedBox(width: 5),
            Icon(FontAwesomeIcons.leaf,
                color: Theme.of(context).appBarTheme.iconTheme?.color),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).appBarTheme.iconTheme?.color),
          onPressed: _isChanging ? null : () => Navigator.pop(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Current Password
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                style: TextStyle(color: valueColor),
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: TextStyle(color: labelColor),
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  prefixIcon: Icon(Icons.lock_outline, color: iconColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: iconColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // New Password
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                style: TextStyle(color: valueColor),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: labelColor),
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  prefixIcon: Icon(Icons.lock_outline, color: iconColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: iconColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  // Add complexity rules if desired (e.g., length)
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Confirm New Password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                style: TextStyle(color: valueColor),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: TextStyle(color: labelColor),
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  prefixIcon: Icon(Icons.lock_outline, color: iconColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: iconColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // Change Password Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isChanging ? null : _handleChangePassword,
                child: _isChanging
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Change Password',
                        style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
