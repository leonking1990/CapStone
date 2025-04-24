import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:intl/intl.dart'; // Import intl for date formatting
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Timestamp
import 'plant_provider.dart'; // Import PlantProvider

class WateringTask {
  final String plantId;
  final String plantName;
  final DateTime dueDate;
  final bool isOverdue;

  WateringTask({
    required this.plantId,
    required this.plantName,
    required this.dueDate,
    required this.isOverdue,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key}); //

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Fetch plants when the widget is first initialized.
    // Use WidgetsBinding.instance.addPostFrameCallback to ensure context is safely available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Check if the widget is still in the tree
        // Use listen: false as this is a one-time action call in initState
        Provider.of<PlantProvider>(context, listen: false).fetchPlants(); //
      }
    });
  }

  // --- Helper Function to Parse Frequency String ---
  int _parseFrequency(String? frequency) {
    frequency = frequency?.toLowerCase() ?? '';
    if (frequency.contains('daily')) return 1;
    if (frequency.contains('every 3-4 days')) return 3; // Average
    if (frequency.contains('weekly')) return 7;
    if (frequency.contains('bi-weekly')) return 14;
    if (frequency.contains('monthly')) return 30;
    // Add more specific parsing if needed (e.g., 'Every X days')
    return 7; // Default to weekly if unknown
  }

  // --- Helper Function to Generate Watering Tasks ---
  List<WateringTask> _generateWateringTasks(List<Map<String, dynamic>> plants) {
    List<WateringTask> tasks = [];
    final DateTime now = DateTime.now();
    // Consider only the date part for comparison to avoid time issues
    final DateTime today = DateTime(now.year, now.month, now.day);

    for (var plant in plants) {
      final String? plantId = plant['plantId'] as String?;
      final String? freqStr = plant['water_frequency'];
      final Timestamp? lastWateredTs = plant['last_watered'] as Timestamp?;

      if (plantId == null ||
          freqStr == null ||
          freqStr == 'N/A' ||
          lastWateredTs == null) {
        continue;
      }

      final int frequencyInDays = _parseFrequency(freqStr);
      final DateTime lastWateredDate = lastWateredTs.toDate();
      final DateTime nextDueDate =
          lastWateredDate.add(Duration(days: frequencyInDays));
      // Consider only the date part of the due date
      final DateTime nextDueDateOnly =
          DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);

      // Check if the due date is today or in the past
      if (nextDueDateOnly.isBefore(today) ||
          nextDueDateOnly.isAtSameMomentAs(today)) {
        tasks.add(WateringTask(
          plantId: plantId, // Use the unique Firestore document ID
          plantName: plant['name'] ??
              plant['species'] ??
              'Unknown Plant', // Display name
          dueDate: nextDueDateOnly,
          isOverdue: nextDueDateOnly
              .isBefore(today), // Check if it was due before today
        ));
      }
    }
    // Optional: Sort tasks by due date
    tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    // Access the PlantProvider
    // Use watch to rebuild when notifyListeners is called
    final plantProvider = context.watch<PlantProvider>();

    // Generate tasks based on current plant list
    // Handle loading/error states from provider if needed before generating
    final List<WateringTask> wateringTasks =
        plantProvider.isLoading || plantProvider.error != null
            ? [] // Don't generate tasks if loading or error
            : _generateWateringTasks(plantProvider.plants);
    User? currentUser = FirebaseAuth.instance.currentUser;
    String welcomeName = currentUser?.displayName ?? 'Guest'; 

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'GreenGuru',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 5),
            Icon(FontAwesomeIcons.leaf,
                color: Theme.of(context).appBarTheme.iconTheme?.color),
            
          ],
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(
              Icons.menu,
              color: Colors.white,
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer(); // Opens the drawer
            },
          ),
        ),
      ),
      // note to future stevie: make a custom drawer widget
      // to make it more readable and maintainable
      drawer: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Drawer Header
            DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).appBarTheme.backgroundColor,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Menu',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      FontAwesomeIcons.leaf,
                      color: Colors.green,
                      size: 20,
                    ),
                  ],
                )),
            // Drawer Items
            ListTile(
              leading: const Icon(FontAwesomeIcons.searchengin),
              title: const Text('Scan Plant'),
              onTap: () {
                Navigator.pushNamed(context, '/scan');
              },
            ),
            ListTile(
              leading: const Icon(FontAwesomeIcons.leaf),
              title: const Text('My Plants'),
              onTap: () {
                Navigator.pushNamed(context, '/myPlants');
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Calendar'),
              onTap: () {
                // Handle calendar navigation here
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: RefreshIndicator(
          // The onRefresh callback triggers the data fetch again
          onRefresh: () => Provider.of<PlantProvider>(context, listen: false)
              .fetchPlants(), //
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                // --- planning to put a Welcome message or other widgets ---
                Text(
                  'Welcome $welcomeName!',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'My Tasks',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                // --- Display Tasks or Loading/Error/Empty State ---
                if (plantProvider.isLoading)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator()))
                else if (plantProvider.error != null)
                  Center(
                      child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                              'Error loading plant data: ${plantProvider.error}',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))))
                else if (wateringTasks.isEmpty &&
                    plantProvider.plants.isNotEmpty)
                  // Show message if there are plants but no tasks due
                  Center(
                      child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text('No watering tasks due right now!',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color))))
                else if (plantProvider.plants.isEmpty)
                  // Show message if there are no plants at all
                  Center(
                      child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text('Add some plants to see tasks.',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color))))
                else
                  // Build the list using the dynamic tasks
                  _buildTaskList(context, wateringTasks), // Pass dynamic tasks
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, List<WateringTask> tasks) {
    // Use ListView.separated for dividers between items
    return ListView.separated(
      shrinkWrap: true, // Important inside SingleChildScrollView
      physics:
          const NeverScrollableScrollPhysics(), // Disable ListView's own scrolling
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final bool isOverdue = task.isOverdue;
        final String dueDateString =
            DateFormat.yMd().format(task.dueDate); // Format date

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 0),
          title: Text(
            "Water ${task.plantName}", // Dynamic title
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            isOverdue
                ? "Overdue (Due: $dueDateString)"
                : "Due: $dueDateString", // Dynamic subtitle
            style: TextStyle(
              color: isOverdue
                  ? Colors.redAccent
                  : Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color, // Highlight overdue
            ),
          ),
          trailing: TextButton(
            // Changed to TextButton for clearer action
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.green, // Style the button
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () async {
              // Call the provider method to mark as watered
              // Use listen: false as it's an action call
              bool success =
                  await Provider.of<PlantProvider>(context, listen: false)
                      .markPlantAsWatered(task.plantId);
              // Show feedback SnackBar
              if (context.mounted) {
                // Check mounted after async call
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(success
                          ? '${task.plantName} marked as watered!'
                          : 'Failed to mark ${task.plantName} as watered.'),
                      backgroundColor:
                          success ? Colors.green : Colors.redAccent,
                      duration: const Duration(seconds: 2)),
                );
              }
            },
            child: const Text('Watered'),
          ),
        );
      },
      separatorBuilder: (context, index) =>
          Divider(color: Theme.of(context).dividerColor), // Use theme color
    );
  }
}
