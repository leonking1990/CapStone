import 'dart:io'; // Required for File type
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:cloud_firestore/cloud_firestore.dart'; // Only needed if using Timestamp directly here

import '../../../core/providers/plant_provider.dart';
import '../../../core/services/firestore_service.dart'; // Where addPlantData/updatePlantData live

class PredictionPage extends StatefulWidget {
  final dynamic plantData; // Raw data received from prediction
  final ImageProvider plantImage; // For displaying the image on *this* page
  final File? imageFile; // The actual image File for uploading
  final bool isUpdate; // Is this an update for an existing plant?
  final String? plantId; // Existing plant ID if isUpdate is true

  const PredictionPage({
    super.key,
    required this.plantData,
    required this.plantImage,
    required this.imageFile, // Make sure this is passed from ScanPage route arguments
    this.isUpdate = false,
    this.plantId,
  });

  @override
  _PredictionPageState createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  bool _isSaving = false; // Tracks saving/updating process state

  // --- Handles Saving New Plant or Updating Existing Plant ---
  Future<void> _handleSaveOrUpdatePlant() async {
    if (!mounted || _isSaving) return; // Prevent multiple simultaneous operations

    // Basic validation: Need an image file when adding a new plant
    if (!widget.isUpdate && widget.imageFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error: Image file is missing for new plant.'),
          backgroundColor: Colors.redAccent,
        ));
      }
      return;
    }

    String initialSuggestedName = widget.plantData?['species'] as String? ?? 'My Plant';
  if (widget.isUpdate && widget.plantData?['name'] != null) { // If updating, use existing custom name as initial
      final String? currentName = widget.plantData?['name'] as String?;
      if (currentName != null && currentName.isNotEmpty && currentName != (widget.plantData?['species'] as String?)) {
          initialSuggestedName = currentName;
      }
  }

  final String? userProvidedNickname = await _showNicknameDialog(context, initialSuggestedName);

    setState(() { _isSaving = true; }); // Show loading indicator

    // --- Extract necessary data fields from widget.plantData ---
    // These are passed to the service functions
    final String speciesName = widget.plantData?['species'] as String? ?? "Unknown";
    final String waterFrequency = widget.plantData?['watering_frequency'] as String? ?? 'Weekly';
    final String healthStatus = widget.plantData?['health_status'] as String? ?? 'Unknown';
    final String? diseaseName = widget.plantData?['disease_name'] as String?;
    final String? diseaseDetails = widget.plantData?['disease_details'] as String?;
    final String? sunlight = widget.plantData?['sunlight'] as String?;
    final String? cycle = widget.plantData?['cycle'] as String?;
    final String? description = widget.plantData?['description'] as String?;
    // Custom name might need specific handling - perhaps a default or user input later
    
    int? speciesId;
     final dynamic rawSpeciesId = widget.plantData?['species_id'];
     if (rawSpeciesId is int) { speciesId = rawSpeciesId; }
     else if (rawSpeciesId is String) { speciesId = int.tryParse(rawSpeciesId); }
    // --- End data extraction ---
      final String? customNameForSave = (userProvidedNickname != null && userProvidedNickname.isNotEmpty)
                                    ? userProvidedNickname
                                    : (initialSuggestedName == (widget.plantData?['species'] as String? ?? 'My Plant') ? null : initialSuggestedName);
                                    // If initialSuggestedName is just the default species, pass null for customName
                                    // so Firestore service might default it. Otherwise pass the (potentially unchanged) initial name.


    // --- try-catch block for the core logic ---
    try {
      // Decide Action: Update existing or Add new
      if (widget.isUpdate && widget.plantId != null) {
        // --- UPDATE Existing Plant ---
        if (kDebugMode) print("[PredictionPage] Update path selected for plant: ${widget.plantId}");

        // Call the updatePlantData service function
        // Pass the NEW image file ONLY if it exists (widget.imageFile can be null for updates if image wasn't re-scanned)
        // Assumes updatePlantData in firestore_service is updated to handle File upload
        await updatePlantData(
          plantId: widget.plantId!,
          newImageFile: widget.imageFile, // Pass the new file if available
          healthStatus: healthStatus,
          diseaseName: diseaseName,
          diseaseDetails: diseaseDetails,
        );

        // Update local state - Refetching the entire list is simplest for now
        // to ensure updated image URLs (if changed) are reflected.
        if (mounted) {
            if (kDebugMode) print("[PredictionPage] Update successful for Firestore, refetching local plant list...");
            // Use await if fetchPlants is async and navigation should wait
            await Provider.of<PlantProvider>(context, listen: false).fetchPlants();
        }
        if (kDebugMode) print("[PredictionPage] Plant ${widget.plantId} update sequence completed.");

      } else {
        // --- ADD New Plant ---
        if (kDebugMode) print("[PredictionPage] Add path selected.");

        // Call the addPlantData service function
        // Pass the image File object (already confirmed non-null for adds)
        // Assumes addPlantData in firestore_service is updated to handle File upload
        String? generatedPlantId = await addPlantData(
           widget.plantData,
           widget.imageFile, // Pass the File object received by the widget
           waterFrequency,
           healthStatus,
           diseaseName,
           diseaseDetails,
           sunlight,
           cycle,
           description,
           customNameForSave, // Pass custom name if available
           speciesId
        );

        // Check if plant ID was successfully generated and returned
        if (generatedPlantId == null) {
             throw Exception("Failed to save new plant data (Firestore service did not return an ID).");
        }

        // Update local state - Refetching is simplest for now
        if (mounted) {
            if (kDebugMode) print("[PredictionPage] Add successful for Firestore, refetching local plant list...");
            // Use await if fetchPlants is async and navigation should wait
            await Provider.of<PlantProvider>(context, listen: false).fetchPlants();
        }
        if (kDebugMode) print("[PredictionPage] New plant $generatedPlantId add sequence completed.");
      }

      // Navigate after successful add/update
      if (mounted) {
          if (kDebugMode) print("[PredictionPage] Navigating to /myPlants");
          // Go back to MyPlants list after saving/updating
          Navigator.pushNamedAndRemoveUntil(context, '/myPlants', (route) => false);
      }

    } catch (e) {
      // Catch any errors from upload, Firestore save/update, or provider update
      if (kDebugMode) print("[PredictionPage] Error saving or updating plant: $e");
      if (mounted) {
        // Show error message to the user
        ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Text('Failed to ${widget.isUpdate ? 'update' : 'save'} plant: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),);
      }
    } finally {
      // Ensure the loading indicator is turned off regardless of success or failure
      if (mounted) {
         if (kDebugMode) print("[PredictionPage] Resetting loading state.");
         setState(() { _isSaving = false; });
      } else {
         // If widget is disposed during async operation, just ensure flag is reset
         _isSaving = false;
         if (kDebugMode) print("[PredictionPage] Widget disposed during save/update, reset loading state flag anyway.");
      }
    }
    // --- End try-catch block ---

  } // End _handleSaveOrUpdatePlant

  Future<String?> _showNicknameDialog(BuildContext context, String initialSuggestedName) async {
  final TextEditingController nicknameController = TextEditingController(text: initialSuggestedName);
  // Use a GlobalKey if you need form validation within the dialog
  // final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  return showDialog<String?>(
    context: context,
    barrierDismissible: false, // User must tap a button to close
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Add a Nickname?'),
        content: TextField(
          controller: nicknameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'E.g., "My Favorite Fern"',
            // Optional: Add more styling or validation
            // errorText: _validateNickname(nicknameController.text), // Example
          ),
          onSubmitted: (value) { // Allow submitting with keyboard 'done' action
            Navigator.of(dialogContext).pop(nicknameController.text.trim());
          },
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Skip'),
            onPressed: () {
              Navigator.of(dialogContext).pop(null); // Return null if skipped
            },
          ),
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(dialogContext).pop(initialSuggestedName); // Return null or original if canceled (or a specific marker)
                                                                       // Let's return initialSuggestedName for cancel,
                                                                       // so if they cancel, the default name is used.
                                                                       // Or pop(null) and handle null as "use default"
            },
          ),
          ElevatedButton(
            child: const Text('Save Nickname'),
            onPressed: () {
              final String nickname = nicknameController.text.trim();
              // Optional: Add validation here if needed
              // if (nickname.isEmpty) { /* show error or prevent close */ return; }
              Navigator.of(dialogContext).pop(nickname.isNotEmpty ? nickname : initialSuggestedName); // Return entered or initial name
            },
          ),
        ],
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
     // Button text changes based on whether it's an update or add operation
     final String buttonText = widget.isUpdate ? 'Update Plant Health' : 'Save Plant to Collection';

     // Extract data needed for display on *this* page from widget.plantData
     // (This is separate from the data passed to the service functions)
     final String displaySpecies = widget.plantData?['species'] as String? ?? 'N/A';
     final String displayHealthStatus = widget.plantData?['health_status'] as String? ?? 'Unknown';
     final String? displayDiseaseName = widget.plantData?['disease_name'] as String?;
     final String? displayDiseaseDetails = widget.plantData?['disease_details'] as String?;
     final String displayWatering = widget.plantData?['watering_frequency'] as String? ?? 'N/A';
     final String displaySunlight = widget.plantData?['sunlight'] as String? ?? 'N/A';
     final String displayCycle = widget.plantData?['cycle'] as String? ?? 'N/A';
     final String displayDescription = widget.plantData?['description'] as String? ?? 'N/A';

     // Styling elements based on health status
     final bool isDisplayUnhealthy = displayHealthStatus.toLowerCase() == 'unhealthy';
     final Color statusColor = isDisplayUnhealthy ? Colors.orangeAccent : Colors.greenAccent;
     final IconData statusIcon = isDisplayUnhealthy ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded;

     // Text styles based on theme
     final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black);
     final boldTextColor = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor);
     final normalTextColor = TextStyle(fontSize: 14, color: textColor);
     final titleTextColor = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor);
     final smallMutedColor = Theme.of(context).textTheme.bodySmall?.color;


     return Scaffold(
       appBar: AppBar(
         backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
         elevation: 0,
         leading: IconButton( icon: Icon(Icons.arrow_back, color: Theme.of(context).appBarTheme.iconTheme?.color ?? Colors.white), onPressed: _isSaving ? null : () => Navigator.pop(context),), // Disable back while saving
         title: Row( mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [ Text( 'Prediction Details', style: TextStyle( color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.bold, fontSize: 20,),), const SizedBox(width: 5), Icon(Icons.eco, color: Theme.of(context).appBarTheme.iconTheme?.color),],),
         centerTitle: true,
       ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
               // --- Image section (uses widget.plantImage ImageProvider for display) ---
                Container(
                   height: 200,
                   width: double.infinity,
                   decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                         // Use the ImageProvider passed to the widget for display here
                         image: widget.plantImage,
                         fit: BoxFit.cover,
                         // Add error builder for ImageProvider if needed
                         onError: (exception, stackTrace) {
                           if (kDebugMode) print("Error loading display image: $exception");
                         },
                      ),
                      boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2),),],
                   ),
                   // Optional: Add placeholder/error handling for the display image itself
                   // child: widget.plantImage == null ? Center(child: Text("No image")) : null, // Example
                ),
               const SizedBox(height: 20),

               // --- Prediction Results section (displays data from widget.plantData) ---
               Container(
                 width: double.infinity, padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration( color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1),),],),
                 child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                     Text('Prediction Results', style: titleTextColor),
                     const Divider(height: 20),
                     Text('Identified Species', style: boldTextColor), Text(displaySpecies, style: normalTextColor), const SizedBox(height: 15),
                     Text('Health Status', style: boldTextColor), Row( children: [ Icon(statusIcon, color: statusColor, size: 18), const SizedBox(width: 8), Text( displayHealthStatus, style: TextStyle( fontSize: 14, color: statusColor, fontWeight: FontWeight.w600),),],), const SizedBox(height: 15),
                      // Disease Info (Conditional Display)
                      if (isDisplayUnhealthy && displayDiseaseName != null && displayDiseaseName.isNotEmpty && displayDiseaseName.toLowerCase() != 'n/a' && displayDiseaseName.toLowerCase() != 'healthy') ...[
                         Text('Identified Disease', style: boldTextColor), Text(displayDiseaseName, style: TextStyle(fontSize: 14, color: statusColor)), const SizedBox(height: 10),
                         if (displayDiseaseDetails != null && displayDiseaseDetails.isNotEmpty && displayDiseaseDetails.toLowerCase() != 'n/a')
                              Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('Details / Suggestions:', style: boldTextColor.copyWith(fontSize: 12)), const SizedBox(height: 4), Text(displayDiseaseDetails, style: normalTextColor.copyWith(fontSize: 12)),])
                         else
                              Text('(No specific details provided)', style: TextStyle(fontSize: 12, color: smallMutedColor)),
                         const SizedBox(height: 15),],
                      // Basic Care Needs
                      const Divider(height: 20), Text('Basic Care Needs', style: boldTextColor),
                      Text( 'Watering: $displayWatering', style: normalTextColor),
                      Text('Sunlight: $displaySunlight', style: normalTextColor),
                      Text('Cycle: $displayCycle', style: normalTextColor),
                      if (displayDescription.isNotEmpty && displayDescription != 'N/A') ...[ const SizedBox(height: 8), Center(child: Text('Description', style: boldTextColor.copyWith())), Text(displayDescription, style: normalTextColor.copyWith(fontSize: 12), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,),],
                   ],),),
               const SizedBox(height: 20),

              // --- Save or Update Button ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: _isSaving ? Container() : Icon(widget.isUpdate ? Icons.sync_alt : Icons.save_alt_outlined),
                  label: _isSaving
                      ? const SizedBox( height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(buttonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: _isSaving ? 0 : 4,
                    disabledBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    disabledForegroundColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                  ),
                  onPressed: _isSaving ? null : _handleSaveOrUpdatePlant, // Calls the updated handler
                ),
              ),
              const SizedBox(height: 40), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}