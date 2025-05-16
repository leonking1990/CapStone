import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:plantcareai/core/providers/plant_provider.dart';
import 'package:plantcareai/shared/widgets/chat_popup_widget.dart';
import 'package:plantcareai/shared/widgets/chat_bubble_painter.dart'; // Moved painter
import '../widgets/profile_header.dart'; // Import new widget
import '../widgets/plant_info_card.dart'; // Import new widget
import '../widgets/plant_detail_row.dart'; // Import new widget
import '../widgets/profile_action_buttons.dart'; // Import new widget

class PlantProfilePage extends StatefulWidget {
  const PlantProfilePage({super.key});
  @override
  State<PlantProfilePage> createState() => _PlantProfilePageState();
}

class _PlantProfilePageState extends State<PlantProfilePage> {
  // --- State for Image URL Future ---
  Future<String?>? _profileImageUrlFuture;
  String? _currentPlantIdForImage;

  // --- State for Overlay ---
  OverlayEntry? _overlayEntry;
  bool _isOverlayVisible = false;
  final GlobalKey _fabKey = GlobalKey();

  // --- Helper function to get download URL ---
  Future<String?> _getDownloadUrl(String storageUrl) async {
    String cleanUrl = storageUrl;
    if (cleanUrl.contains('?')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.indexOf('?'));
    }
    try {
      if (kDebugMode) {
        print(
            "[PlantProfilePage] Getting download URL for clean path: $cleanUrl");
      }
      final ref = FirebaseStorage.instance.refFromURL(cleanUrl);
      final downloadUrl = await ref.getDownloadURL();
      if (kDebugMode) {
        print("[PlantProfilePage] Successfully got download URL: $downloadUrl");
      }
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print(
            "[PlantProfilePage] Failed to get download URL for $cleanUrl: $e");
      }
      return null;
    }
  }

  // --- Function to initialize/update the image URL future ---
  void _initializeProfileImageUrl(
      Map<String, dynamic>? plantData, String? plantId) {
    if (plantData == null || plantId == null) {
      if (_profileImageUrlFuture != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted)
            setState(() => _profileImageUrlFuture = Future.value(null));
        });
      }
      _currentPlantIdForImage = null;
      return;
    }
    if (plantId != _currentPlantIdForImage || _profileImageUrlFuture == null) {
      _currentPlantIdForImage = plantId;
      final String? storedThumbnailUrl =
          plantData['imageThumbnailUrl'] as String?;
      final String? storedOriginalUrl = plantData['image'] as String?;
      final String? urlToLoad =
          (storedThumbnailUrl != null && storedThumbnailUrl != 'N/A')
              ? storedThumbnailUrl
              : ((storedOriginalUrl != null && storedOriginalUrl != 'N/A')
                  ? storedOriginalUrl
                  : null);
      Future<String?> newFuture;
      if (urlToLoad != null &&
          urlToLoad.startsWith('https://firebasestorage.googleapis.com/')) {
        newFuture = _getDownloadUrl(urlToLoad);
      } else {
        newFuture = Future.value(null);
        if (kDebugMode && urlToLoad != null && urlToLoad != 'N/A') {
          print(
              "[PlantProfilePage] Skipping getDownloadURL for non-Firebase URL or N/A: $urlToLoad");
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _profileImageUrlFuture = newFuture;
          });
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get plantId argument from the route
    final newPlantId = ModalRoute.of(context)?.settings.arguments as String?;

    // Check if the plantId has changed from the last time we initialized,
    // or if the image future hasn't been initialized yet (_profileImageUrlFuture == null).
    // We use _currentPlantIdForImage to track the ID associated with the current future.
    if (newPlantId != _currentPlantIdForImage ||
        _profileImageUrlFuture == null) {
      _currentPlantIdForImage = newPlantId; // Update the tracked ID

      // Get the current plant data SYNCHRONOUSLY from the provider
      // to pass to the initialization function. listen: false is correct here.
      final plantProvider = Provider.of<PlantProvider>(context, listen: false);
      Map<String, dynamic>? plant;
      if (_currentPlantIdForImage != null) {
        try {
          plant = plantProvider.plants
              .firstWhere((p) => p['plantId'] == _currentPlantIdForImage);
        } catch (e) {
          plant = null;
        }
      }
      // --- THIS IS THE CALL WE MOVED ---
      // Initialize the image loading process using the found plant data and ID
      _initializeProfileImageUrl(plant, _currentPlantIdForImage);
      // --- END OF MOVED CALL ---
    }
  }

  // --- Formatters and Parsers ---
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
    if (frequency.contains('every 3-4 days')) return 3;
    if (frequency.contains('weekly')) return 7;
    if (frequency.contains('bi-weekly')) return 14;
    if (frequency.contains('monthly')) return 30;
    return 7;
  }

  // --- Overlay Methods ---
  void _showOverlay(BuildContext context, String plantContext) {
    final overlay = Overlay.of(context);
    final RenderBox? fabRenderBox =
        _fabKey.currentContext?.findRenderObject() as RenderBox?;
    if (fabRenderBox == null) {
      print("Error: Could not find FAB RenderBox.");
      return;
    }
    final fabSize = fabRenderBox.size;
    final fabPosition = fabRenderBox.localToGlobal(Offset.zero);
    _overlayEntry = OverlayEntry(
      builder: (context) {
        try {
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final double bottomPadding = fabSize.height + 10 + keyboardHeight;
          const double horizontalPadding = 15.0;
          final double relativeTailCenterX =
              (fabPosition.dx + fabSize.width / 2);
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _hideOverlay,
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: Colors.black.withOpacity(0.1)),
                ),
              ),
              Positioned(
                left: horizontalPadding,
                right: horizontalPadding,
                bottom: bottomPadding,
                child: Material(
                  color: Colors.transparent,
                  elevation: 4.0,
                  shadowColor: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    painter: ChatBubblePainter(
                      color: Theme.of(context).colorScheme.surface,
                      tailCenterX: relativeTailCenterX,
                      borderRadius: 12,
                      tailHeight: 10,
                    ),
                    child: ChatPopupWidget(initialContext: plantContext),
                  ),
                ),
              ),
            ],
          );
        } catch (e, s) {
          print("Error building OverlayEntry content: $e\n$s");
          return Positioned(
              top: 100,
              left: 50,
              child: Material(child: Text("Error building overlay: $e")));
        }
      },
    );
    overlay.insert(_overlayEntry!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isOverlayVisible = true;
        });
      }
    });
  }

  void _hideOverlay({bool calledFromDispose = false}) {
    // Add an optional parameter
    _overlayEntry?.remove();
    _overlayEntry = null;

    if (!calledFromDispose) {
      // Only call setState if not called from dispose
      if (mounted) {
        setState(() {
          _isOverlayVisible = false;
        });
      }
    } else {
      // If called from dispose, just update the flag directly without setState,
      // as the widget is going away anyway.
      _isOverlayVisible = false;
    }
  }

  @override
  void dispose() {
    _hideOverlay(calledFromDispose: true);
    super.dispose();
  }

  // --- Delete Confirmation Dialog ---
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

  @override
  Widget build(BuildContext context) {
    final String? plantId =
        ModalRoute.of(context)?.settings.arguments as String?;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final errorColor = Theme.of(context).colorScheme.error;

     // Text styles based on theme
     final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black);
     final boldTextColor = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor);
     final normalTextColor = TextStyle(fontSize: 14, color: textColor);
     final titleTextColor = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor);
     final smallMutedColor = Theme.of(context).textTheme.bodySmall?.color;

    if (kDebugMode) {
      print("[MyPlantsPage] BUILD method called.");
    }

    return Consumer<PlantProvider>(
      builder: (context, plantProvider, child) {
        if (kDebugMode) {
          print(
              "[MyPlantsPage] CONSUMER BUILDER called. Plant count: ${plantProvider.plants.length}");
        }
        Map<String, dynamic>? plant;
        if (plantId != null && plantProvider.plants.isNotEmpty) {
          try {
            plant =
                plantProvider.plants.firstWhere((p) => p['plantId'] == plantId);
          } catch (e) {
            plant = null;
            if (kDebugMode) {
              print(
                  "[PlantProfilePage] Plant with ID '$plantId' not found in provider list during build.");
            }
          }
        }

        if (plant == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(plantId == null ? 'Error' : 'Loading Plant...'),
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context)),
            ),
            body: Center(
                child: plantId == null
                    ? const Text('No plant specified.')
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (plantProvider.isLoading)
                            const CircularProgressIndicator()
                          else
                            const Text('Plant details not found.'),
                          const SizedBox(height: 15),
                          ElevatedButton(
                            child: const Text('Go Back'),
                            onPressed: () => Navigator.pop(context),
                          )
                        ],
                      )),
          );
        }

        // Data Extraction (Simplified)
        final String plantName = plant['name'] as String? ??
            plant['species'] as String? ??
            'Unknown Plant';
        final String plantSpecies = plant['species'] as String? ?? 'N/A';
        final String healthStatus =
            plant['healthStatus'] as String? ?? 'Unknown';
        final bool isUnhealthy = healthStatus.toLowerCase() == 'unhealthy';
        final String? diseaseName = plant['diseaseName'] as String?;
        final String? diseaseDetails = plant['diseaseDetails'] as String?;
        final String waterFreq = plant['water_frequency'] as String? ?? 'N/A';
        final String sunlight = plant['sunlight'] as String? ?? 'N/A';
        final String cycle = plant['cycle'] as String? ?? 'N/A';
        final String description = plant['description'] as String? ?? 'N/A';
        final String genus = plant['genus'] as String? ?? 'N/A';
        final String family = plant['family'] as String? ?? 'N/A';
        final Timestamp? lastWateredTs = plant['last_watered'] as Timestamp?;
        final Timestamp? diagnosisTs =
            plant['diagnosisTimestamp'] as Timestamp?;
        final String lastWateredStr = _formatTimestamp(lastWateredTs);
        final String diagnosisDateStr =
            _formatTimestamp(diagnosisTs, placeholder: 'N/A');

        // Calculate next due date safely
        final DateTime? lastWateredDate = lastWateredTs?.toDate();
        bool needsWater = false;
        if (lastWateredDate != null) {
          final int frequencyInDays = _parseFrequency(waterFreq);
          final DateTime nextDueDate =
              lastWateredDate.add(Duration(days: frequencyInDays));
          final DateTime nextDueDateOnly =
              DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
          final DateTime today = DateTime(
              DateTime.now().year, DateTime.now().month, DateTime.now().day);
          needsWater = nextDueDateOnly.isBefore(today) ||
              nextDueDateOnly.isAtSameMomentAs(today);
        }

        // Generate chat context
        String currentPlantContext = """Currently viewing plant:
Name: ${plant['name'] ?? 'N/A'}
Species: ${plant['species'] ?? 'N/A'}
Health: ${plant['healthStatus'] ?? 'N/A'}
Watering: ${plant['water_frequency'] ?? 'N/A'}
Sunlight: ${plant['sunlight'] ?? 'N/A'}""";
        if (isUnhealthy && diseaseName != null && diseaseName.isNotEmpty) {
          currentPlantContext += "\nCurrent Disease: $diseaseName";
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
            centerTitle: true,
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Use ProfileHeader Widget
                ProfileHeader(
                  imageUrlFuture: _profileImageUrlFuture,
                  plantName: plantName,
                  plantSpecies: plantSpecies,
                ),
                const SizedBox(height: 16),

                // Use PlantInfoCard for Health Status
                PlantInfoCard(title: 'Health Status', children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          isUnhealthy
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline_rounded,
                          color: isUnhealthy ? errorColor : Colors.green,
                          size: 20),
                      const SizedBox(width: 8),
                      Text(healthStatus,
                          style: TextStyle(
                              color: isUnhealthy ? errorColor : Colors.green,
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
                        style:
                            TextStyle(color: secondaryTextColor, fontSize: 14)),
                    if (diagnosisDateStr != 'N/A')
                      Text('Diagnosed: $diagnosisDateStr',
                          style: TextStyle(
                              color: secondaryTextColor, fontSize: 12)),
                  ],
                ]),
                const SizedBox(height: 16),

                // Use PlantInfoCard for Care Info
                PlantInfoCard(title: 'Care Information', children: [
                  PlantDetailRow(label: 'Watering', value: waterFreq),
                  PlantDetailRow(
                      label: 'Last Watered',
                      value: lastWateredStr,
                      highlightValue: needsWater),
                  PlantDetailRow(label: 'Sunlight', value: sunlight),
                  PlantDetailRow(label: 'Cycle', value: cycle),
                ]),
                const SizedBox(height: 16),

                // Use PlantInfoCard for Additional Details
                PlantInfoCard(title: 'Plant Details', children: [
                  PlantDetailRow(label: 'Genus', value: genus),
                  PlantDetailRow(label: 'Family', value: family),
                  if (description != 'N/A' && description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Description',
                        style: boldTextColor,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Center(
                        child: Text(description,
                            style: normalTextColor.copyWith(fontSize: 14),
                            textAlign: TextAlign.center),
                      ),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Center(
                          child: Text("(No description provided)",
                              style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center)),
                    ),
                ]),
                const SizedBox(height: 30), // Spacer before buttons

                // Use ProfileActionButtons Widget
                ProfileActionButtons(
                  plantId: plantId,
                  plantName: plantName,
                  isUnhealthy: isUnhealthy,
                  diseaseName: diseaseName,
                  diseaseDetails: diseaseDetails,
                  showDeleteConfirmation:
                      _showDeleteConfirmationDialog, // Pass the dialog function
                ),
                const SizedBox(height: 40), // Bottom padding
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            key: _fabKey,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: Icon(
                _isOverlayVisible ? Icons.close : Icons.chat_bubble_outline),
            tooltip: _isOverlayVisible ? 'Close Chat' : 'Ask about this plant',
            onPressed: () {
              if (_isOverlayVisible) {
                _hideOverlay();
              } else {
                _showOverlay(context, currentPlantContext);
              }
            },
          ),
        );
      },
    );
  }
}
