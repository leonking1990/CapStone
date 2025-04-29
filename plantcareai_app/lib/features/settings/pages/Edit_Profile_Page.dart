import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:plantcareai/core/services/firestore_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>(); // For input validation (optional)
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController =
      TextEditingController(); // For display only

  bool _isLoading = true;
  bool _isSaving = false;

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null) {
      // Handle case where user is somehow null (shouldn't happen if route is protected)
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Not logged in.')));
        Navigator.pop(context); // Go back if not logged in
      }
      return;
    }

    // Set email (read-only)
    _emailController.text = _currentUser!.email ?? 'No email found';

    // Fetch data from Firestore
    Map<String, dynamic>? firestoreData = await getUserData();

    if (mounted) {
      setState(() {
        // Populate controllers, prioritize Firestore data if available
        _firstNameController.text =
            firestoreData?['fName'] ?? _currentUser!.displayName ?? '';
        _lastNameController.text = firestoreData?['lName'] ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSaveChanges() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentUser == null) return; // Should not happen

    setState(() {
      _isSaving = true;
    });

    String newFirstName = _firstNameController.text.trim();
    String newLastName = _lastNameController.text.trim();

    try {
      // 1. Update Firestore Data
      await updateUserData(fName: newFirstName, lName: newLastName);

      // 2. Update Firebase Auth Display Name
      // Check if display name needs update (if it differs from new first name)
      if (_currentUser!.displayName != newFirstName) {
        await _currentUser!.updateDisplayName(newFirstName);
        // You might need to refresh the user object or notify other parts of the app
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back after saving
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to update profile: ${e.toString()}'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          // Avoid overflow by making title flexible if needed, or keep minimal
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Edit Profile",
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color)),
            const SizedBox(width: 5),
            Icon(FontAwesomeIcons.leaf,
                color: Theme.of(context).appBarTheme.iconTheme?.color),
          ],
        ),
        leading: IconButton(
          // Add back button
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).appBarTheme.iconTheme?.color),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        centerTitle: true, // Center the title Row
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              // Allow scrolling
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch, // Make button stretch
                  children: [
                    const SizedBox(height: 20),
                    // Email (Read-only)
                    TextField(
                      controller: _emailController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: labelColor),
                        filled: true,
                        fillColor: inputFillColor?.withOpacity(
                            0.5), // Slightly different fill for read-only
                      ),
                    ),
                    const SizedBox(height: 20),

                    // First Name
                    TextFormField(
                      // Use TextFormField for validation later if needed
                      controller: _firstNameController,
                      style: TextStyle(color: valueColor),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        labelStyle: TextStyle(color: labelColor),
                      ),
                      // validator: (value) { // Example validation
                      //   if (value == null || value.trim().isEmpty) {
                      //     return 'Please enter your first name';
                      //   }
                      //   return null;
                      // },
                    ),
                    const SizedBox(height: 20),

                    // Last Name
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Save Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        // Use theme primary color
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      // Disable button while saving
                      onPressed: _isSaving ? null : _handleSaveChanges,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Changes',
                              style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
