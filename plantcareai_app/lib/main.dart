import 'dart:io';

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
          debugShowCheckedModeBanner: false,
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

              // Validate essential arguments
              if (args == null ||
                      args['plantData'] == null ||
                      // args['plantImage'] == null || // plantImage is for display only, maybe less critical?
                      args['imageFile'] ==
                          null // *** ADDED: Check for imageFile ***
                  ) {
                if (kDebugMode) {
                  print(
                      "Error: Missing required arguments for /prediction route.");
                }
                return Scaffold(
                    appBar: AppBar(title: const Text("Error")),
                    body: const Center(
                        child: Text(
                            "Could not load prediction data or image file.")));
              }

              // Extract arguments safely
              final plantData = args['plantData'];
              // Provide a fallback for plantImage if needed, although ScanPage should always pass it
              final plantImage = args['plantImage'] as ImageProvider? ??
                  const AssetImage(
                      'assets/placeholder.png'); // Example fallback
              final imageFile = args['imageFile']
                  as File; // *** ADDED: Extract the File object ***
              final isUpdate = args['isUpdate'] as bool? ?? false;
              final plantId = args['plantId'] as String?;

              // Pass arguments to the constructor, including imageFile
              return PredictionPage(
                plantData: plantData,
                plantImage: plantImage,
                imageFile: imageFile, // *** ADDED: Pass the file object ***
                isUpdate: isUpdate,
                plantId: plantId,
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
