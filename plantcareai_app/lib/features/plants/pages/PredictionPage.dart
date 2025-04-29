import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/plant_provider.dart'; //
import '../../../core/services/firestore_service.dart'; //
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class PredictionPage extends StatefulWidget {
  // Data received from server or previous step
  final dynamic plantData;
  final ImageProvider plantImage;

  // ** ADD arguments received from ScanPage **
  final bool isUpdate;
  final String? plantId; // Existing plant ID if isUpdate is true

  const PredictionPage({
    super.key,
    required this.plantData,
    required this.plantImage,
    // Receive arguments directly (alternative to ModalRoute in build)
    this.isUpdate = false, // Default to false
    this.plantId,
  });

  @override
  _PredictionPageState createState() => _PredictionPageState();
}


class _PredictionPageState extends State<PredictionPage> {
  bool _isSaving = false; // Tracks saving/updating process

  // --- _handleSaveOrUpdatePlant: Decides whether to create or update ---
  Future<void> _handleSaveOrUpdatePlant() async {
    if (!mounted || _isSaving) return;
    setState(() { _isSaving = true; });

    // --- Extract common data fields ---
    final String speciesName = widget.plantData?['species'] as String? ?? "Unknown";
    final String? customName = widget.plantData?['name'] as String?; // Server might not return custom name
    final String waterFrequency = widget.plantData?['watering_frequency'] as String? ?? 'Weekly';
    final String? sunlight = widget.plantData?['sunlight'] as String?;
    final String? cycle = widget.plantData?['cycle'] as String?;
    final String? description = widget.plantData?['description'] as String?;
    final String? family = widget.plantData?['family'] as String?;
    final String? genus = widget.plantData?['genus'] as String?;
    final String healthStatus = widget.plantData?['health_status'] as String? ?? 'Unknown';
    final String? diseaseName = widget.plantData?['disease_name'] as String?;
    final String? diseaseDetails = widget.plantData?['disease_details'] as String?;
    int? speciesId;
    final dynamic rawSpeciesId = widget.plantData?['species_id'];
    if (rawSpeciesId is int) { speciesId = rawSpeciesId; }
    else if (rawSpeciesId is String) { speciesId = int.tryParse(rawSpeciesId); }


    try {
      // 1. Upload new image (common to both add and update)
      String? newImageUrl = await uploadPlantImage(widget.plantImage); //

      // 2. Decide Action: Update existing or Add new
      if (widget.isUpdate && widget.plantId != null) {
          // --- UPDATE Existing Plant ---
          Map<String, dynamic> updateData = {
             'healthStatus': healthStatus,
             'diseaseName': diseaseName,
             'diseaseDetails': diseaseDetails,
             'last_updated': FieldValue.serverTimestamp(), // Included in updatePlantData
             if (newImageUrl != null) 'image': newImageUrl, // Only include if upload succeeded
              // Conditionally add/remove diagnosis timestamp
             if (healthStatus.toLowerCase() == 'unhealthy' && diseaseName != null && diseaseName.isNotEmpty)
                'diagnosisTimestamp': FieldValue.serverTimestamp()
             else
                'diagnosisTimestamp': FieldValue.delete(),
          };
          updateData.removeWhere((key, value) => value == null && key != 'diseaseName' && key != 'diseaseDetails');
          // Explicitly handle setting diseaseName/Details to null if needed by update function
           if (diseaseName == null) updateData['diseaseName'] = null;
           if (diseaseDetails == null) updateData['diseaseDetails'] = null;


          await updatePlantData( //
            plantId: widget.plantId!,
            imageUrl: newImageUrl, // Pass new URL if available
            healthStatus: healthStatus,
            diseaseName: diseaseName,
            diseaseDetails: diseaseDetails,
          );

          // Update local state for existing plant
          if (mounted) {
              // Add plantId to the update map for local identification
              updateData['plantId'] = widget.plantId!;
              // Ensure necessary fields are present for local update, even if not updated in Firestore
               updateData['last_updated'] = Timestamp.now(); // Use local time approximation

              Provider.of<PlantProvider>(context, listen: false)
                  .updatePlantLocally(widget.plantId!, updateData); // - Need this function!
          }

          if (kDebugMode) print("Plant ${widget.plantId} updated.");

      } else {
          // --- ADD New Plant ---
          String? generatedPlantId = await addPlantData( //
             widget.plantData, // Original data map
             newImageUrl,      // URL from upload
             waterFrequency,   // Extracted fields...
             healthStatus,
             diseaseName,
             diseaseDetails,
             sunlight,
             cycle,
             description,
             customName,
             speciesId
          );

          if (generatedPlantId == null) {
            throw Exception("Failed to save new plant data (no ID returned).");
          }

          // Prepare data for local add
          if (mounted) {
              Map<String, dynamic> dataForProvider = {
                 'plantId': generatedPlantId, // Use the returned ID
                 'species_id': speciesId,
                 'species': speciesName,
                 'name': customName ?? 'My $speciesName', // Need name for local state
                 'family': family,
                 'genus': genus,
                 'watering_frequency': waterFrequency,
                 'sunlight': sunlight,
                 'cycle': cycle,
                 'description': description,
                 'healthStatus': healthStatus,
                 'diseaseName': diseaseName,
                 'diseaseDetails': diseaseDetails,
                 'image': newImageUrl ?? 'N/A',
                 'last_watered': Timestamp.now(), // Initial local approximation
                 if (healthStatus.toLowerCase() == 'unhealthy' && diseaseName != null && diseaseName.isNotEmpty)
                    'diagnosisTimestamp': Timestamp.now(), // Initial local approximation
                 // 'created_at' will be set by Firestore, fetched later
              };
              dataForProvider.removeWhere((key, value) => value == null);


              Provider.of<PlantProvider>(context, listen: false)
                  .addPlantLocally(dataForProvider, newImageUrl, generatedPlantId); //
          }
           if (kDebugMode) print("New plant $generatedPlantId added.");
      }

      // 3. Navigate after success (common to add and update)
      if (mounted) {
        // Go back to profile page if it was an update, else go to MyPlants
         if (widget.isUpdate) {
            // Check if we can pop back to profile, otherwise go to MyPlants as fallback
             int popCount = 0;
             Navigator.popUntil(context, (route) {
                 popCount++;
                 // Pop until PlantProfilePage or root (pop twice: ScanPage, PredictionPage)
                 // Or check route name if available: route.settings.name == '/pProfile'
                 return popCount == 3 || !Navigator.canPop(context);
             });
              // If popUntil stopped early (e.g., user somehow skipped profile), go to MyPlants
             if (Navigator.canPop(context)) { // Should be at profile now
                 // Maybe refresh profile page state if needed? Depends on implementation.
             } else {
                  Navigator.pushReplacementNamed(context, '/myPlants');
             }
         } else {
            Navigator.pushReplacementNamed(context, '/myPlants');
         }
      }

    } catch (e) {
      if (kDebugMode) print("Error saving or updating plant: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to ${widget.isUpdate ? 'update' : 'save'} plant: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      } else {
         _isSaving = false; // Reset flag anyway
      }
    }
  }

  // --- build() method ---
  @override
  Widget build(BuildContext context) {
     // Determine button text based on update status
     final String buttonText = widget.isUpdate ? 'Update Plant Health' : 'Save Plant to Collection';

    // ... (extract display data: healthStatus, diseaseName, diseaseDetailsForDisplay etc.) ...
     final String healthStatus = widget.plantData?['health_status'] as String? ?? 'Unknown';
     final String? diseaseName = widget.plantData?['disease_name'] as String?;
     final String? diseaseDetailsForDisplay = widget.plantData?['disease_details'] as String?;
     final bool isUnhealthy = healthStatus.toLowerCase() == 'unhealthy';
     final Color statusColor = isUnhealthy ? Colors.orangeAccent : Colors.greenAccent;
     final IconData statusIcon = isUnhealthy ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded;
     final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black);
     final boldTextColor = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor);
     final normalTextColor = TextStyle(fontSize: 14, color: textColor);
     final titleTextColor = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor);


    return Scaffold(
       appBar: AppBar(
         backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
         elevation: 0,
         leading: IconButton( icon: Icon(Icons.arrow_back, color: Theme.of(context).appBarTheme.iconTheme?.color ?? Colors.white), onPressed: _isSaving ? null : () => Navigator.pop(context),),
         title: Row( mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [ Text( 'Prediction Details', style: TextStyle( color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.bold, fontSize: 20,),), const SizedBox(width: 5), Icon(Icons.eco, color: Theme.of(context).appBarTheme.iconTheme?.color),],),
       ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
               // --- Image section ---
                Container( height: 200, width: double.infinity, decoration: BoxDecoration( borderRadius: BorderRadius.circular(16), image: DecorationImage( image: widget.plantImage, fit: BoxFit.cover,), boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2),),],),),
               const SizedBox(height: 20),

               // --- Prediction Results section (display only) ---
               Container(
                 width: double.infinity, padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration( color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1),),],),
                 child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                     Text('Prediction Results', style: titleTextColor),
                     const Divider(height: 20),
                     // Species
                     Text('Identified Species', style: boldTextColor), Text(widget.plantData?['species'] ?? 'N/A', style: normalTextColor), const SizedBox(height: 15),
                     // Health Status
                     Text('Health Status', style: boldTextColor), Row( children: [ Icon(statusIcon, color: statusColor, size: 18), const SizedBox(width: 8), Text( healthStatus, style: TextStyle( fontSize: 14, color: statusColor, fontWeight: FontWeight.w600),),],), const SizedBox(height: 15),
                      // Disease Info (Conditional Display)
                      if (isUnhealthy && diseaseName != null && diseaseName.isNotEmpty && diseaseName.toLowerCase() != 'n/a' && diseaseName.toLowerCase() != 'healthy') ...[
                         Text('Identified Disease', style: boldTextColor), Text(diseaseName, style: TextStyle(fontSize: 14, color: statusColor)), const SizedBox(height: 10),
                         if (diseaseDetailsForDisplay != null && diseaseDetailsForDisplay.isNotEmpty && diseaseDetailsForDisplay.toLowerCase() != 'n/a')
                              Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('Details / Suggestions:', style: boldTextColor.copyWith(fontSize: 12)), const SizedBox(height: 4), Text(diseaseDetailsForDisplay, style: normalTextColor.copyWith(fontSize: 12)),])
                         else
                              Text('(No specific details provided by analysis)', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                         const SizedBox(height: 15),],
                      // Basic Care Needs
                      const Divider(height: 20), Text('Basic Care Needs', style: boldTextColor),
                      Text( 'Watering: ${widget.plantData?['watering_frequency'] ?? 'N/A'}', style: normalTextColor),
                      Text('Sunlight: ${widget.plantData?['sunlight'] ?? 'N/A'}', style: normalTextColor),
                      Text('Cycle: ${widget.plantData?['cycle'] ?? 'N/A'}', style: normalTextColor),
                      if (widget.plantData?['description'] != null && (widget.plantData?['description'] as String).isNotEmpty) ...[ const SizedBox(height: 8), Text('Description:', style: boldTextColor.copyWith(fontSize: 14)), Text(widget.plantData?['description'], style: normalTextColor.copyWith(fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis,),],
                   ],),),
               const SizedBox(height: 20),

              // --- Save or Update Button ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  // Use appropriate icon based on action
                  icon: _isSaving ? Container() : Icon(widget.isUpdate ? Icons.sync_alt : Icons.save_alt_outlined),
                  label: _isSaving
                      ? const SizedBox( height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      // Use dynamic button text
                      : Text(buttonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: _isSaving ? 0 : 4,
                    disabledBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    disabledForegroundColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                  ),
                  // Call the unified handler function
                  onPressed: _isSaving ? null : _handleSaveOrUpdatePlant,
                ),
              ),
              const SizedBox(height: 20), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}


// Helper to get arguments safely in build or initState/didChangeDependencies
PredictionPageArguments _getArguments(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    return PredictionPageArguments(
        plantData: args?['plantData'], // Already required by constructor?
        plantImage: args?['plantImage'], // Already required?
        isUpdate: args?['isUpdate'] ?? false,
        plantId: args?['plantId']
    );
}

// Simple class to hold arguments if needed (alternative to passing via constructor)
class PredictionPageArguments {
    final dynamic plantData;
    final ImageProvider? plantImage;
    final bool isUpdate;
    final String? plantId;

    PredictionPageArguments({this.plantData, this.plantImage, this.isUpdate = false, this.plantId});
}
