import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart'; // Import light & dark themes

class ThemeProvider extends ChangeNotifier {
  ThemeData _currentTheme = AppThemes.lightTheme; // Default to Light Mode

  ThemeData get theme => _currentTheme;

  bool get isDarkMode => _currentTheme == AppThemes.darkTheme;

  void toggleTheme() {
    if (isDarkMode) {
      _currentTheme = AppThemes.lightTheme;
    } else {
      _currentTheme = AppThemes.darkTheme;
    }
    debugPrint("🔄 Theme switched: ${isDarkMode ? "Dark Mode" : "Light Mode"}");
    notifyListeners();
  }
}
 
  