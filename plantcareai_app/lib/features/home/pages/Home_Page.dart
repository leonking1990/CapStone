import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:intl/intl.dart'; // Import intl for date formatting
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Timestamp
import '../../../core/providers/plant_provider.dart'; // Import PlantProvider
import 'package:plantcareai/shared/widgets/chat_popup_widget.dart';

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
  
  // --- State for Overlay ---
  OverlayEntry? _overlayEntry; // Holds the reference to the overlay
  bool _isOverlayVisible = false; // Tracks if the overlay is currently shown
  final GlobalKey _fabKey = GlobalKey(); // Key to get FAB's position
  // --- End State for Overlay ---
  
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

  // --- Method to Show the Overlay ---
  void _showOverlay(BuildContext context) {
    // Get the OverlayState
    final overlay = Overlay.of(context);
    // Get the RenderBox of the FAB using its GlobalKey
    final RenderBox? fabRenderBox = _fabKey.currentContext?.findRenderObject() as RenderBox?;
    // User? currentUser = FirebaseAuth.instance.currentUser;
    // String welcomeName = currentUser?.displayName ?? 'Guest'; 

    if (fabRenderBox == null) {
      print("Error: Could not find Overlay or FAB RenderBox.");
      return;
    }

    // Get the size and position of the FAB in global coordinates
    final fabSize = fabRenderBox.size;
    final fabPosition = fabRenderBox.localToGlobal(Offset.zero);

    // --- Create the OverlayEntry ---
    _overlayEntry = OverlayEntry(
      builder: (context) {
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        // Calculate position for the chat popup (e.g., above the FAB)
        // Adjust these calculations as needed for desired placement & padding
        // final double rightPadding = fabSize.width / 2; // Align right edge roughly with FAB center
        final double bottomPadding = fabSize.height + 10; // Place 10px above the FAB
        const double horizontalPadding = 15.0; 
          final double relativeTailCenterX =
              (fabPosition.dx + fabSize.width / 2); // - horizontalPadding; 

        // Use a Stack to layer the dismiss barrier and the chat content
        return Stack(
          children: [
            // --- Dismiss Barrier ---
            // Full screen GestureDetector to capture taps outside the popup
            Positioned.fill(
              child: GestureDetector(
                onTap: _hideOverlay, // Hide overlay when tapped outside
                behavior: HitTestBehavior.translucent, // Captures taps on transparent areas
                // Optional: Add a semi-transparent background
                child: Container(
                  color: Colors.black.withOpacity(0.1),
                ),
              ),
            ),
            // --- Positioned Chat Popup ---
            Positioned(
              // Position relative to the screen edges
              left: horizontalPadding,
              right: horizontalPadding, // Distance from the right edge of the screen
              bottom: bottomPadding+keyboardHeight, // Distance from the bottom edge of the screen
              // Constrain the size of the chat popup
              child: Material( // Add Material for theme defaults if needed by ChatPopupWidget internals
                 elevation: 4.0, // Add shadow
                 borderRadius: BorderRadius.circular(12), // Match potential bubble shape
                 child: CustomPaint(
                    painter: ChatBubblePainter( // Copied from your uploaded file
                       color: Theme.of(context).colorScheme.surface, // Copied from your uploaded file
                       tailCenterX: relativeTailCenterX, // Copied from your uploaded file
                       borderRadius: 12, // Copied from your uploaded file
                       tailHeight: 10, // Copied from your uploaded file
                    ),
                    child: ChatPopupWidget(),
                  ),
              ),
            ),
          ],
        );
      },
    );

    // Insert the OverlayEntry into the Overlay
    overlay.insert(_overlayEntry!);
    setState(() {
      _isOverlayVisible = true;
    });
  }

  // --- Method to Hide the Overlay ---
  void _hideOverlay() {
    // Remove the overlay entry and update state
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isOverlayVisible = false;
    });
  }

  // Ensure overlay is removed when the widget is disposed
  @override
  void dispose() {
    _hideOverlay(); // Clean up overlay if visible
    super.dispose();
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
            // note to future stevie: add a calendar page
            // to show watering schedule and other tasks
            // ListTile(
            //   leading: const Icon(Icons.calendar_today),
            //   title: const Text('Calendar'),
            //   onTap: () {
            //     // Handle calendar navigation here
            //   },
            // ),
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
      floatingActionButton: SizedBox(
        width: _isOverlayVisible ? 30 : 70,
        height: _isOverlayVisible ? 30 : 70,
        child: FloatingActionButton(
          key: _fabKey, // Assign key to get position later
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          tooltip: _isOverlayVisible ? 'Close Chat' : 'Chat Assistant',          
          onPressed: () {
            // Toggle the overlay's visibility
            if (_isOverlayVisible) {
              _hideOverlay();
            } else {
              _showOverlay(context);
            }
          },
          // mini: _isOverlayVisible ? true : false, // Make it mini when overlay is shown
          // Change icon based on overlay visibility
          child: Icon(_isOverlayVisible ? Icons.close : Icons.chat_bubble_outline),
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

class Triangle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white // Change to your desired color
      ..style = PaintingStyle.fill;

    final path = Path();
      path.lineTo(-10, 0);
      path.lineTo(0, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false; // No need to repaint unless the size changes or color changes
  }
}
class ChatBubblePainter extends CustomPainter {
   final Color color;
   final double tailBaseWidth;
   final double tailHeight;
   final double borderRadius;
   final double tailCenterX;

   ChatBubblePainter({
     required this.color,
     this.tailBaseWidth = 20.0,
     this.tailHeight = 10.0,
     this.borderRadius = 12.0,
     required this.tailCenterX,
   });

   @override
   void paint(Canvas canvas, Size size) {
      final paint = Paint()
       ..color = color
       ..style = PaintingStyle.fill;
      final path = Path();
      // ... (drawing logic for rounded rect + tail) ...
       path.moveTo(borderRadius, 0);
       path.lineTo(size.width - borderRadius, 0);
       path.arcToPoint(Offset(size.width, borderRadius), radius: Radius.circular(borderRadius));
       path.lineTo(size.width, size.height - borderRadius);
       path.arcToPoint(Offset(size.width - borderRadius, size.height), radius: Radius.circular(borderRadius));
       path.lineTo(tailCenterX + (tailBaseWidth / 2), size.height);
       path.lineTo(tailCenterX, size.height + tailHeight);
       path.lineTo(tailCenterX - (tailBaseWidth / 2), size.height);
       path.lineTo(borderRadius, size.height);
       path.arcToPoint(Offset(0, size.height - borderRadius), radius: Radius.circular(borderRadius));
       path.lineTo(0, borderRadius);
       path.arcToPoint(Offset(borderRadius, 0), radius: Radius.circular(borderRadius));
       path.close();
       canvas.drawPath(path, paint);
   }

   @override
   bool shouldRepaint(covariant ChatBubblePainter oldDelegate) {
     return oldDelegate.color != color || oldDelegate.tailCenterX != tailCenterX;
   }
 }