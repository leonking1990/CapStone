import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'theme.dart'; // Import light & dark themes

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
  
  /* 
  In the code snippet above, we have created a  ThemeProvider  class that extends  ChangeNotifier . This class has a  ThemeData  property called  _currentTheme  that is initialized with the  lightTheme  from the  AppThemes  class. 
  The  isDarkMode  getter returns a boolean value that indicates whether the current theme is dark or not. The  theme  getter returns the current theme. 
  The  toggleTheme  method changes the current theme to the opposite of the current theme. If the current theme is dark, it changes to light, and vice versa. 
  The  notifyListeners  method is called to notify listeners to rebuild the UI. 
  Step 3: Create a ThemeProvider instance 
  Next, we will create an instance of the  ThemeProvider  class in the  main.dart  file. */
  