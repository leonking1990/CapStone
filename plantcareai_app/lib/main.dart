import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'plant_provider.dart';
import 'MyPlantsPage.dart';
import 'SettingsPage.dart';
import 'WelcomePage.dart';
import 'LoginPage.dart';
import 'HomePage.dart';
import 'AccountCreationPage.dart';
import 'PlantProfilePage.dart';
import 'PredictionPage.dart';
import 'EditProfilePage.dart';
import 'ChangePasswordPage.dart';
import 'ScanPlantPage.dart';
import 'DiseaseTreatmentPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => PlantProvider()),
      ],
      child: const MyApp(), // Ensure MyApp is const if possible
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        if (kDebugMode) {
          print(
              "🔄 MyApp Rebuilt: ${themeProvider.isDarkMode ? "Dark Mode" : "Light Mode"}");
        }
        return MaterialApp(
          title: 'PlantCareAi',
          theme: themeProvider.theme, // Use the theme from ThemeProvider
          // darkTheme: AppThemes.darkTheme, // Or themeProvider.darkTheme if defined
          // themeMode: themeProvider.themeMode, // If you add ThemeMode support
          initialRoute: getInitialRoute(),
          routes: {
            '/': (context) => const WelcomePage(),
            '/login': (context) => LoginPage(),
            '/home': (context) => const HomePage(),
            '/create': (context) => AccountCreationPage(),
            '/myPlants': (context) => const MyPlantsPage(),
            '/pProfile': (context) => PlantProfilePage(),
            '/settings': (context) => const SettingsPage(),
            '/editProfile': (context) => const EditProfilePage(),
            '/changePassword': (context) => const ChangePasswordPage(),
            '/scan': (context) => const ScanPlantPage(),
            '/diseaseTreatment': (context) => const DiseaseTreatmentPage(),
            '/prediction': (context) {
              final args = ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;

              // Basic validation for essential arguments
              if (args == null ||
                  args['plantData'] == null ||
                  args['plantImage'] == null) {
                // Handle error: Navigate back or show an error page
                if (kDebugMode) {
                  print(
                      "Error: Missing required arguments for /prediction route.");
                }
                // You could return a simple error Scaffold:
                return Scaffold(
                    appBar: AppBar(title: const Text("Error")),
                    body: const Center(
                        child: Text("Could not load prediction data.")));
              }

              // Extract arguments for the constructor
              final plantData = args['plantData'];
              final plantImage = args['plantImage'];
              final isUpdate = args['isUpdate'] as bool? ??
                  false; // Safely get isUpdate flag
              final plantId = args['plantId']
                  as String?; // Safely get plantId (can be null)

              // Pass arguments to the constructor
              return PredictionPage(
                //
                plantData: plantData,
                plantImage: plantImage,
                isUpdate: isUpdate, // Pass the flag
                plantId: plantId, // Pass the ID
              );
            },
          },
        );
      },
    );
  }

  String getInitialRoute() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return '/home';
    } else {
      return '/';
    }
  }
}
