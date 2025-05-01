import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plantcareai/core/providers/plant_provider.dart'; //
import 'package:intl/intl.dart'; // For date formatting
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp
import 'package:plantcareai/shared/widgets/chat_popup_widget.dart';

class PlantProfilePage extends StatefulWidget {
  
  const PlantProfilePage({super.key}); 
  @override
  State<PlantProfilePage> createState() => _PlantProfilePageState();
}

class _PlantProfilePageState extends State<PlantProfilePage> {
  // Helper to format Timestamp or return placeholder

  OverlayEntry? _overlayEntry;
  bool _isOverlayVisible = false;
  final GlobalKey _fabKey = GlobalKey();

  // Inside _PlantProfilePageState in Plant_Profile_Page.dart

void _showOverlay(BuildContext context, String plantContext) {
  final overlay = Overlay.of(context);
  final RenderBox? fabRenderBox = _fabKey.currentContext?.findRenderObject() as RenderBox?;

  if (fabRenderBox == null) {
    print("Error: Could not find FAB RenderBox."); // <-- Debug Check
    return;
  }
   print("FAB RenderBox found. Position: ${fabRenderBox.localToGlobal(Offset.zero)}, Size: ${fabRenderBox.size}"); // <-- Debug Print

  final fabSize = fabRenderBox.size;
  final fabPosition = fabRenderBox.localToGlobal(Offset.zero);
  // final screenWidth = MediaQuery.of(context).size.width;

  _overlayEntry = OverlayEntry(
    builder: (context) {
       
       try { // Add try-catch around the builder content
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          // ... rest of calculations ...
          //final double rightPadding = fabSize.width / 2;
          final double bottomPadding = fabSize.height + 10 + keyboardHeight;
          const double horizontalPadding = 15.0; 
          final double relativeTailCenterX =
              (fabPosition.dx + fabSize.width / 2); // - horizontalPadding; // Adjusted for padding

          return Stack(
            children: [
              // Dismiss Barrier
              Positioned.fill(
                child: GestureDetector(
                  onTap: _hideOverlay,
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: Colors.black.withOpacity(0.1)),
                 ),
              ),
              // Positioned Chat Popup
              Positioned(
                left: horizontalPadding, // Copied from your uploaded file
                right: horizontalPadding, // Copied from your uploaded file
                bottom: bottomPadding+keyboardHeight, // Copied from your uploaded file
                child: Material(
                  color: Colors.transparent, // Copied from your uploaded file
                  elevation: 4.0, // Copied from your uploaded file
                  shadowColor: Colors.black.withOpacity(0.3), // Copied from your uploaded file
                  borderRadius: BorderRadius.circular(12), // Copied from your uploaded file
                  child: CustomPaint(
                    painter: ChatBubblePainter( // Copied from your uploaded file
                       color: Theme.of(context).colorScheme.surface, // Copied from your uploaded file
                       tailCenterX: relativeTailCenterX, // Copied from your uploaded file
                       borderRadius: 12, // Copied from your uploaded file
                       tailHeight: 10, // Copied from your uploaded file
                    ),
                    child: ChatPopupWidget(initialContext: plantContext),
                  ),
                ),
              ),
            ],
          );
       } catch (e, s) { // Catch errors during build
           print("Error building OverlayEntry content: $e\n$s"); // <-- Debug Error Catching 
           // Return a simple error widget instead
           return Positioned(top: 100, left: 50, child: Material(child: Text("Error building overlay: $e")));
       }
    },
  );

  print("OverlayEntry created. Inserting..."); // <-- Debug Print
  overlay.insert(_overlayEntry!);
  print("OverlayEntry inserted."); // <-- Debug Print

  // Use setState inside WidgetsBinding callback to avoid potential build conflicts
  WidgetsBinding.instance.addPostFrameCallback((_) {
     if (mounted) { // Check if still mounted
        setState(() {
           _isOverlayVisible = true;
        });
         print("State set, _isOverlayVisible: $_isOverlayVisible"); // <-- Debug Print
     }
  });
}

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isOverlayVisible = false;
    });
  }

  @override
  void dispose() {
    _hideOverlay(); // Clean up overlay
    super.dispose();
  }
  // --

  String _formatTimestamp(Timestamp? timestamp, {String placeholder = 'N/A'}) {
    if (timestamp == null) return placeholder;
    try {
      return DateFormat.yMd().add_jm().format(timestamp.toDate());
    } catch (e) {
      return placeholder;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    // Expect plantId as argument
    final String? plantId =
        ModalRoute.of(context)?.settings.arguments as String?;

    // Get theme colors safely
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final titleColor =
        Theme.of(context).textTheme.titleLarge?.color ?? primaryTextColor;
    final headlineColor =
        Theme.of(context).textTheme.headlineSmall?.color ?? titleColor;
    final errorColor = Theme.of(context).colorScheme.error;

    return Consumer<PlantProvider>(
      //
      builder: (context, plantProvider, child) {
        // Find plant by plantId
        Map<String, dynamic>? plant;
        if (plantId != null && plantProvider.plants.isNotEmpty) {
          try {
            plant = plantProvider.plants.firstWhere(
              (p) => p['plantId'] == plantId,
            );
          } catch (e) {
            plant = null;
            if (kDebugMode) {
              print("Plant with ID '$plantId' not found in provider list.");
            }
          }
        }

        // Extract data safely using null checks
        final String plantName = plant?['name'] as String? ??
            plant?['species'] as String? ??
            'Unknown Plant';
        final String plantSpecies = plant?['species'] as String? ?? 'N/A';
        final String healthStatus =
            plant?['healthStatus'] as String? ?? 'Unknown';
        final bool isUnhealthy = healthStatus.toLowerCase() == 'unhealthy';
        final String? diseaseName = plant?['diseaseName'] as String?;
        // ** RE-ADD extraction of diseaseDetails from plant data **
        final String? diseaseDetails = plant?['diseaseDetails'] as String?;
        final String imageUrl = plant?['imageThumbnailUrl'] as String? ??
            plant?['image'] as String? ??
            'N/A';
        final String genus = plant?['genus'] as String? ?? 'N/A';
        final String family = plant?['family'] as String? ?? 'N/A';
        final String waterFreq = plant?['water_frequency'] as String? ?? 'N/A';
        final String sunlight = plant?['sunlight'] as String? ?? 'N/A';
        final String cycle = plant?['cycle'] as String? ?? 'N/A';
        final String description = plant?['description'] as String? ?? 'N/A';
        final Timestamp? lastWateredTs = plant?['last_watered'] as Timestamp?;
        final Timestamp? diagnosisTs =
            plant?['diagnosisTimestamp'] as Timestamp?;
        // final Timestamp? createdAtTs = plant?['created_at'] as Timestamp?;

        final String lastWateredStr = _formatTimestamp(lastWateredTs);
        final String diagnosisDateStr =
            _formatTimestamp(diagnosisTs, placeholder: 'N/A');
        // final String addedDateStr =
        //     _formatTimestamp(createdAtTs, placeholder: 'N/A');
        final int frequencyInDays = _parseFrequency(waterFreq);
        final DateTime lastWateredDate = lastWateredTs!.toDate();
        final DateTime nextDueDate =
            lastWateredDate.add(Duration(days: frequencyInDays));
        final DateTime nextDueDateOnly =
            DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);

        String currentPlantContext =
            "User is viewing the profile for plant ID: $plantId.";
        if (plant != null) {
          currentPlantContext = """
Currently viewing plant:
Name: ${plant['name'] ?? 'N/A'}
Species: ${plant['species'] ?? 'N/A'}
Health: ${plant['healthStatus'] ?? 'N/A'}
Watering: ${plant['water_frequency'] ?? 'N/A'}
Sunlight: ${plant['sunlight'] ?? 'N/A'}""";
          if (healthStatus.toLowerCase() == 'unhealthy' &&
              diseaseName != null &&
              diseaseName.isNotEmpty) {
            currentPlantContext += "\nCurrent Disease: $diseaseName";
          }
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back,
                  color: Theme.of(context).appBarTheme.iconTheme?.color),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              plantName,
              style: TextStyle(
                  color: Theme.of(context).appBarTheme.titleTextStyle?.color ??
                      Colors.white,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            centerTitle: true, // Keep title centered
            // Removed search/edit actions for simplicity for now
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: plant == null
              ? Center(
                  /* ... Loading/Not Found logic ... */
                  child: plantId == null
                      ? Text('No plant specified.',
                          style: TextStyle(color: primaryTextColor))
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (plantProvider.isLoading)
                              const CircularProgressIndicator()
                            else
                              Text('Plant details not found.',
                                  style: TextStyle(color: primaryTextColor)),
                            const SizedBox(height: 15),
                            ElevatedButton(
                              child: const Text('Go Back'),
                              onPressed: () => Navigator.pop(context),
                            )
                          ],
                        ))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // --- Profile Image ---
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: ClipOval(
                          // Use ClipOval for the circular shape
                          child: Container(
                            // Container for background color and border
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant, // Background if error/no image
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                                width: 2,
                              ),
                            ),
                            child: (imageUrl != 'N/A' && imageUrl.isNotEmpty)
                                ? CachedNetworkImage(
                                    // Use the FULL imageUrl here, not thumbnail if you want higher quality
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    // Placeholder like in MyPlantsPage
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color,
                                      ),
                                    ),
                                    // Error widget like in MyPlantsPage
                                    errorWidget: (context, url, error) {
                                      if (kDebugMode) {
                                        print(
                                            "Profile image load error: $error");
                                      }
                                      return Icon(
                                        Icons.broken_image_outlined,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color,
                                        size: 70,
                                      );
                                    },
                                  )
                                : Icon(
                                    // Default icon if no URL
                                    Icons.local_florist_outlined,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color,
                                    size: 70,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- Plant Name ---
                      Text(
                        plantName,
                        style: TextStyle(
                          color: headlineColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (plantName != plantSpecies)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '($plantSpecies)',
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 16),

                      // --- Health Status Card ---
                      _buildInfoCard(context,
                          title: 'Health Status',
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    isUnhealthy
                                        ? Icons.warning_amber_rounded
                                        : Icons.check_circle_outline_rounded,
                                    color:
                                        isUnhealthy ? errorColor : Colors.green,
                                    size: 20),
                                const SizedBox(width: 8),
                                Text(healthStatus,
                                    style: TextStyle(
                                        color: isUnhealthy
                                            ? errorColor
                                            : Colors.green,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            if (isUnhealthy &&
                                diseaseName != null &&
                                diseaseName.isNotEmpty &&
                                diseaseName != 'N/A') ...[
                              const SizedBox(height: 8),
                              Text('Disease: $diseaseName',
                                  style: TextStyle(
                                      color: secondaryTextColor, fontSize: 14)),
                              if (diagnosisDateStr != 'N/A')
                                Text('Diagnosed: $diagnosisDateStr',
                                    style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 12)),
                            ],
                          ]),
                      const SizedBox(height: 16),

                      // --- Care Info Card ---
                      _buildInfoCard(context,
                          title: 'Care Information',
                          children: [
                            _buildDetailRow(context, 'Watering', waterFreq),
                            _buildDetailRow(
                                context, 'Last Watered', lastWateredStr,
                                needWater:
                                    nextDueDateOnly.isBefore(DateTime.now()) ||
                                        nextDueDateOnly
                                            .isAtSameMomentAs(DateTime.now())),
                            _buildDetailRow(context, 'Sunlight', sunlight),
                            _buildDetailRow(context, 'Cycle', cycle),
                          ]),
                      const SizedBox(height: 16),

                      // --- Additional Info Card ---
                      _buildInfoCard(context,
                          title: 'Plant Details',
                          children: [
                            _buildDetailRow(context, 'Genus', genus),
                            _buildDetailRow(context, 'Family', family),
                            _buildDetailRow(context, 'species', plantSpecies),
                            Center(
                              child: Text(
                                'Description:',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.color,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (description != 'N/A' && description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Center(
                                  child: Text(description,
                                      style: TextStyle(
                                          color: secondaryTextColor,
                                          fontSize: 14),
                                      textAlign: TextAlign.center),
                                ),
                              ),
                          ]),
                      const SizedBox(height: 30), // Spacer before buttons

                      // --- Buttons Section ---
                      _buildActionButton(
                        context,
                        'Re-Scan Plant Health',
                        plantProvider.isDeleting
                            ? null
                            : () {
                                if (plantId != null) {
                                  Navigator.pushNamed(
                                    context,
                                    '/scan',
                                    arguments: {
                                      'isUpdate': true,
                                      'plantId': plantId,
                                      'plantName': plantName,
                                    },
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Cannot initiate scan: Plant ID missing.')));
                                }
                              },
                        icon: Icons.camera_alt_outlined,
                      ),
                      const SizedBox(height: 12),

                      // ** View Disease / Treatments Button (Conditional) **
                      if (isUnhealthy &&
                          diseaseName != null &&
                          diseaseName.isNotEmpty &&
                          diseaseName != 'N/A') ...[
                        _buildActionButton(
                          context,
                          'View Disease / Treatments',
                          plantProvider.isDeleting
                              ? null
                              : () {
                                  Navigator.pushNamed(
                                    context,
                                    '/diseaseTreatment',
                                    arguments: {
                                      'name': diseaseName, // Pass name
                                      'details': diseaseDetails ??
                                          'No details available.' // Pass details from plant data
                                    },
                                  );
                                },
                          icon: Icons.medical_information_outlined,
                          isDestructive: false,
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // --- Delete Button ---
                      _buildActionButton(
                          context,
                          'Delete Plant',
                          plantProvider.isDeleting
                              ? null
                              : () async {
                                  final bool? confirmed =
                                      await _showDeleteConfirmationDialog(
                                          context, plantName);
                                  if (confirmed == true && plantId != null) {                                    
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text('Deleting "$plantName"...'),
                                      duration: const Duration(seconds: 2),
                                    ));
                                    // Call provider method
                                    await Provider.of<PlantProvider>(context,
                                            listen: false)
                                        .removePlant(plantId);
                                    final error = Provider.of<PlantProvider>(
                                            context,
                                            listen: false)
                                        .error;
                                    if (context.mounted) {
                                      if (error == null) {
                                        Navigator.pop(context);
                                      } // Pop only on success
                                      else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              'Error deleting plant: $error'),
                                          backgroundColor: Colors.redAccent,
                                        ));
                                      }
                                    }
                                  }
                                },
                          icon: Icons.delete_outline,
                          isDestructive: true),
                    ],
                  ),
                ),
          floatingActionButton: plant == null
              ? null
              : SizedBox(
                width: _isOverlayVisible ? 30 : 70,
                height: _isOverlayVisible ? 30 : 70,
                child: FloatingActionButton(
                  key: _fabKey,
                    // Only show if plant data exists
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: Icon(_isOverlayVisible ? Icons.close : Icons.chat_bubble_outline),
                    tooltip: 'Ask about this plant',
                    onPressed: () {
                          print("FAB tapped. _isOverlayVisible: $_isOverlayVisible"); // <-- Add Print
                          if (_isOverlayVisible) {
                            _hideOverlay();
                          } else {
                            // Make sure currentPlantContext is valid before calling
                            print("Attempting to show overlay with context: $currentPlantContext"); // <-- Add Print
                            _showOverlay(context, currentPlantContext);
                          }
                        },
                  ),
              ),
        );
      },
    );
  }

  // --- Confirmation Dialog ---
  Future<bool?> _showDeleteConfirmationDialog(
      BuildContext context, String plantName) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
              'Are you sure you want to delete "$plantName"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false)),
            TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
                onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );
  }

  // --- Helper widget for info cards ---
  Widget _buildInfoCard(BuildContext context,
      {required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
          ),
          const Divider(height: 16),
          ...children, // Spread the children widgets
        ],
      ),
    );
  }

  // --- Helper widget for detail rows ---
  Widget _buildDetailRow(BuildContext context, String label, String value,
      {bool needWater = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: needWater
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper widget for action buttons ---
  Widget _buildActionButton(
      BuildContext context, String text, VoidCallback? onPressed,
      {bool isDestructive = false, IconData? icon, Color? color}) {
    final Color defaultButtonColor = color ??
        (isDestructive
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary);
    final Color defaultTextColor = isDestructive
        ? Theme.of(context).colorScheme.onError
        : Theme.of(context).colorScheme.onPrimary;
    final Color disabledButtonColor =
        Theme.of(context).disabledColor.withOpacity(0.12);
    final Color disabledTextColor =
        Theme.of(context).disabledColor.withOpacity(0.38);
    final ButtonStyle style = ElevatedButton.styleFrom(
      backgroundColor: defaultButtonColor,
      foregroundColor: defaultTextColor,
      disabledBackgroundColor: disabledButtonColor,
      disabledForegroundColor: disabledTextColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      elevation: onPressed != null ? 2 : 0,
    );
    return SizedBox(
      // width: double.infinity,
      child: icon != null
          ? ElevatedButton.icon(
              style: style,
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(text),
            )
          : ElevatedButton(
              style: style,
              onPressed: onPressed,
              child: Text(text),
            ),
    );
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