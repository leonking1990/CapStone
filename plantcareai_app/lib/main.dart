import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/plant_provider.dart';
import 'features/chat/pages/chat_box_screen.dart';
import 'features/plants/pages/My_Plants_Page.dart';
import 'features/settings/pages/Settings_Page.dart';
import 'features/welcome/pages/Welcome_Page.dart';
import 'features/auth/pages/Login_Page.dart';
import 'features/home/pages/Home_Page.dart';
import 'features/auth/pages/Account_Creation_Page.dart';
import 'features/plants/pages/Plant_Profile_Page.dart';
import 'features/plants/pages/Prediction_Page.dart';
import 'features/settings/pages/Edit_Profile_Page.dart';
import 'features/settings/pages/Change_Password_Page.dart';
import 'features/plants/pages/Scan_Plant_Page.dart';
import 'features/plants/pages/Disease_Treatment_Page.dart';

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
          // darkTheme: AppThemes.darkTheme,
          // themeMode: themeProvider.themeMode,
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
            '/chat': (context) => const ChatBoxScreen(),
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
