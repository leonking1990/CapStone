import 'package:flutter/material.dart';

// I left a ton of comments in this file to help you understand the code better (I beraly remember it myself)
// Define a class to hold the app's theme data
// This class can be used to manage both light and dark themes in the app
// It can be extended in the future to include more themes or styles
// The class is static to avoid instantiation and to provide a single point of access
// to the theme data throughout the app


class AppThemes {
  // Define common border radius
  static final _inputBorderRadius = BorderRadius.circular(12.0);

  // Define common border shape
  static final _inputBorder = OutlineInputBorder(
    borderRadius: _inputBorderRadius,
    borderSide: BorderSide.none, // No visible border line
  );

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.blue, // Example primary color
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[850], // Keep original AppBar style
      iconTheme: const IconThemeData(color: Colors.green),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), // Ensure title text is styled
    ),
    colorScheme: ColorScheme.fromSeed( // Use ColorScheme for more modern theming
        seedColor: Colors.green, // Base color for the scheme
        brightness: Brightness.light,
        // Define primary/secondary if needed, otherwise they derive from seed
        // primary: Colors.green,
        // secondary: Colors.redAccent,
    ),
    textTheme: const TextTheme(
      // Define text styles if needed, otherwise defaults are used
      bodyLarge: TextStyle(color: Colors.black), // Default text
      bodyMedium: TextStyle(color: Colors.black54), // Subdued text
      titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold), // Headlines
      titleMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: Colors.black),
      // AppBar title uses bodySmall in some places, ensure it's defined if needed
      bodySmall: TextStyle(color: Colors.white), // Used for text on dark AppBar
      labelLarge: TextStyle(color: Colors.white), // Default button text color if using theme buttons
    ),
    // --- Add InputDecorationTheme ---
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[200], // Lighter grey for light mode fill
      border: _inputBorder, // Use the defined border shape
      enabledBorder: _inputBorder, // Keep same border look always
      focusedBorder: _inputBorder, // Keep same border look always
      disabledBorder: _inputBorder, // Border for disabled state (e.g., read-only email)
      labelStyle: TextStyle(color: Colors.grey[700]), // Label color for light mode
      hintStyle: TextStyle(color: Colors.grey[500]), // Hint color for light mode
      prefixIconColor: Colors.grey[700], // Default prefix icon color
      suffixIconColor: Colors.grey[700], // Default suffix icon color
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0), // Consistent padding
    ),
     // Optional: Define ElevatedButtonTheme
     elevatedButtonTheme: ElevatedButtonThemeData(
       style: ElevatedButton.styleFrom(
          // Default button colors using ColorScheme
          backgroundColor: Colors.green, // Use ColorScheme's primary
          foregroundColor: Colors.white, // Use ColorScheme's onPrimary
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: _inputBorderRadius), // Match input radius
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
       ),
     ),
     // Optional: Define TextButtonTheme
     textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: Colors.green, // Use ColorScheme's primary
        ),
     ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFFBB86FC), // Example primary color
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[850], // Keep original AppBar style
      iconTheme: const IconThemeData(color: Colors.green),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), // Ensure title text is styled
    ),
     colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green, // Base color
        brightness: Brightness.dark,
        // Define primary/secondary mite need to be adjusted for dark mode
        // primary: Colors.green[700],
        // secondary: Colors.redAccent[100],
     ),
    textTheme: const TextTheme(
      // Define text styles
      bodyLarge: TextStyle(color: Color(0xFFE0E0E0)), // Default text
      bodyMedium: TextStyle(color: Colors.white70), // Subdued text
      titleLarge: TextStyle(color: Color(0xFFE0E0E0), fontWeight: FontWeight.bold), // Headlines
      titleMedium: TextStyle(color: Color(0xFFE0E0E0), fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: Color(0xFFE0E0E0)),
       // AppBar title uses bodySmall in some places, ensure it's defined if needed
      bodySmall: TextStyle(color: Colors.white), // Used for text on dark AppBar
      labelLarge: TextStyle(color: Colors.white), // Default button text color if using theme buttons
    ),
    // --- Add InputDecorationTheme ---
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[800], // Darker grey for dark mode fill
      border: _inputBorder, // Use the defined border shape
      enabledBorder: _inputBorder,
      focusedBorder: _inputBorder,
      disabledBorder: _inputBorder,
      labelStyle: TextStyle(color: Colors.white70), // Label color for dark mode
      hintStyle: TextStyle(color: Colors.white54), // Hint color for dark mode
      prefixIconColor: Colors.white70, // Default prefix icon color
      suffixIconColor: Colors.white70, // Default suffix icon color
       contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0), // Consistent padding
    ),
     // Optional: Define ElevatedButtonTheme
     elevatedButtonTheme: ElevatedButtonThemeData(
       style: ElevatedButton.styleFrom(
          // Use theme colors
          backgroundColor: Colors.green[700], // Darker green for primary
          foregroundColor: Colors.white, // Use ColorScheme's onPrimary
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: _inputBorderRadius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
       ),
     ),
     // Optional: Define TextButtonTheme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: Colors.greenAccent, // Lighter green for primary
        ),
     ),
  );
}