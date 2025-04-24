import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'plant_provider.dart';
import 'PlantCard.dart';

class MyPlantsPage extends StatefulWidget {
  const MyPlantsPage({super.key});

  @override
  State<MyPlantsPage> createState() => _MyPlantsPageState();
}

class _MyPlantsPageState extends State<MyPlantsPage> {
  @override
  void initState() {
    super.initState();
    // Fetch plants when the page loads for the first time
    // Use WidgetsBinding to ensure context is available safely after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use listen: false because we're calling a method, not listening for changes here
      Provider.of<PlantProvider>(context, listen: false).fetchPlants();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Plant Collection',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodySmall?.color),
            ),
            const SizedBox(width: 5),
            Icon(FontAwesomeIcons.leaf,
                color: Theme.of(context).appBarTheme.iconTheme?.color),
          ],
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).appBarTheme.iconTheme?.color),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<PlantProvider>(
        builder: (context, plantProvider, child) {
          // Show loading indicator
          if (plantProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Show error message if any
          if (plantProvider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: ${plantProvider.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Show message if no plants are found
          if (plantProvider.plants.isEmpty) {
            return Center(
              child: Text(
                'No plants found. Add one from the Scan page!',
                // Use theme color
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
            );
          }

          // Display the grid if plants are loaded successfully
          final plants = plantProvider.plants;

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: GridView.builder(
              itemCount: plants.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 items per row
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75, // Adjust card proportions here
              ),
              itemBuilder: (context, index) {
                final plant = plants[index];
                return PlantCard(
                  plant: plant,
                  onTap: () {
                    // Pass the navigation logic as a callback
                    final String? actualPlantId = plant['plantId'] as String?;
                    if (actualPlantId != null && actualPlantId.isNotEmpty) {
                      Navigator.pushNamed(
                        context,
                        '/pProfile',
                        arguments: actualPlantId,
                      );
                    } else {
                      // Show a message if plantId is somehow missing from the data
                      print(
                          "Error: plantId missing for plant at index $index: ${plant['name'] ?? plant['species']}"); // Add debug print
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Cannot view details: Plant identifier is missing.')));
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
