import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _isLoadingPreference = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference(); // Load the preference when the page loads
  }

  // Function to load the saved preference
  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    // Read the value, defaulting to true if it doesn't exist yet
    final bool savedValue = prefs.getBool('notifications_enabled') ?? true;

    // Check if the widget is still mounted before calling setState
    if (mounted) {
      setState(() {
        _notificationsEnabled = savedValue;
        _isLoadingPreference = false; // Loading finished
      });
    }
  }

  // Function to save the preference
  Future<void> _saveNotificationPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    debugPrint(
        "🔄 SettingsPage Rebuilt: ${themeProvider.isDarkMode ? "Dark Mode" : "Light Mode"}");
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 5),
            Icon(FontAwesomeIcons.leaf,
                color: Theme.of(context).appBarTheme.iconTheme?.color),
          ],
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).appBarTheme.iconTheme?.color),
          onPressed: () {
            Navigator.pop(context); // Navigate back to the previous page
          },
        ),
      ),
      body: Container(
        color: Theme.of(context)
            .scaffoldBackgroundColor, // Dynamic background color
        child: ListView(
          children: [
            const SizedBox(height: 10),
            _buildSectionTitle('Account', context),
            _buildAccountSettings(context),
            const SizedBox(height: 20),
            _buildSectionTitle('Preferences', context),
            _buildNotificationToggle(context),
            _buildThemeToggle(context, themeProvider),
            const SizedBox(height: 20),
            _buildSectionTitle('Other', context),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAccountSettings(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.person, color: Theme.of(context).iconTheme.color),
          title: Text('Edit Profile',
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color)),
          onTap: () {
            Navigator.pushNamed(context, '/editProfile');
          },
        ),
        Divider(color: Theme.of(context).dividerColor),
        ListTile(
          leading: Icon(Icons.lock, color: Theme.of(context).iconTheme.color),
          title: Text('Change Password',
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color)),
          onTap: () {
            Navigator.pushNamed(context, '/changePassword');
          },
        ),
        Divider(color: Theme.of(context).dividerColor),
      ],
    );
  }

  Widget _buildNotificationToggle(BuildContext context) {
    if (_isLoadingPreference) {
      return const ListTile(
        title: Text('Enable Notifications'), // Show label even while loading
        trailing: SizedBox(
          // Show a small loading indicator
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Show the actual switch once loading is complete
    return SwitchListTile(
      title: Text('Enable Notifications',
          style:
              TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
      value: _notificationsEnabled, // Use the state variable
      activeColor: Colors.red, // Or use Theme.of(context).colorScheme.primary
      onChanged: (bool value) {
        // Update the UI state immediately
        setState(() {
          _notificationsEnabled = value;
        });
        // Save the new value asynchronously
        _saveNotificationPreference(value);
      },
    );
  }

  Widget _buildThemeToggle(BuildContext context, ThemeProvider themeProvider) {
    return SwitchListTile(
      title: Text(
        'Dark Mode',
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      value: themeProvider.isDarkMode,
      activeColor: Colors.red,
      onChanged: (bool value) {
        themeProvider.toggleTheme(); // Toggle theme dynamically
      },
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.logout, color: Theme.of(context).iconTheme.color),
      title: Text('Logout',
          style:
              TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
      onTap: () async {
        await FirebaseAuth.instance.signOut();
        Navigator.pushNamed(context, '/');
      },
    );
  }
}
