import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

// Revert back to StatelessWidget
class DiseaseTreatmentPage extends StatelessWidget {
  const DiseaseTreatmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Extract arguments passed from PlantProfilePage
    final Map<String, dynamic>? args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    // Get specific data, provide defaults if args are null or keys missing
    // Use the name passed in arguments for the title
    final String diseaseName = args?['name'] as String? ?? 'Unknown Disease';
    // Use the details passed in arguments
    final String diseaseDetails =
        args?['details'] as String? ?? 'No details available.';

    // Check if essential arguments are missing
    if (args == null || args['name'] == null) {
      if (kDebugMode)
        print("Error: Missing arguments for DiseaseTreatmentPage.");
      // later: Set-up error message or navigate back (still deciding)
      // For simplicity, app will show an error message in the body below
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(diseaseName), // Show disease name from args in AppBar
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).appBarTheme.iconTheme?.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: (args == null ||
              args['name'] == null) // Show error if arguments were invalid
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: Could not load disease information. Please go back and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            )
          : SingleChildScrollView(
              // Allow scrolling for potentially long details
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Disease Information', // Section Title
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.color // Use theme color
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(diseaseName, // Display Name from args
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.orangeAccent // Highlight disease name
                          )),
                  const Divider(height: 24),
                  Text(
                    // Use "Details / Treatment Suggestions" as the heading now
                    'Details / Treatment Suggestions:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      diseaseDetails, // Display the details passed via arguments
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          height:
                              1.5 // Improve readability for potentially long text
                          )),
                ],
              ),
            ),
    );
  }
}
