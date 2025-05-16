import 'package:flutter/foundation.dart';
import 'package:plantcareai/core/services/firestore_service.dart'; //
import 'package:cloud_firestore/cloud_firestore.dart';

class PlantProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _plants = [];
  bool _isLoading = false;
  String? _error;
  bool _isDeleting = false;

  // Getters
  List<Map<String, dynamic>> get plants => List.unmodifiable(_plants); // Return unmodifiable list
  bool get isLoading => _isLoading;
  bool get isDeleting => _isDeleting;
  String? get error => _error;

  // --- fetchPlants ---
   Future<void> fetchPlants() async { 
       if (_isLoading) return; _isLoading = true; _error = null; notifyListeners();
       try { _plants = await allPlants(); _error = null;} //
       catch (e) { if (kDebugMode) print("Error fetching plants: $e"); _error = "Failed to load plants."; _plants = [];}
       finally { _isLoading = false; notifyListeners();}
   }

  // --- addPlantLocally ---
   void addPlantLocally(Map<String, dynamic> plantDataMap, String? imageUrl, String plantId) { 
       plantDataMap['plantId'] = plantId; plantDataMap['image'] = imageUrl ?? 'N/A';
       plantDataMap.putIfAbsent('last_watered', () => Timestamp.now());
       if (plantDataMap['healthStatus']?.toLowerCase() == 'unhealthy' && plantDataMap['diagnosisTimestamp'] == null) { plantDataMap['diagnosisTimestamp'] = Timestamp.now();}
       _plants.removeWhere((p) => p['plantId'] == plantId); _plants.add(plantDataMap); notifyListeners();
   }

  // FUNCTION to update local state for an existing plant ***
  void updatePlantLocally(String plantId, Map<String, dynamic> updatedData) {
    // Find the index of the plant to update
    int index = _plants.indexWhere((p) => p['plantId'] == plantId);

    if (index != -1) {
      // Merge the updated data into the existing plant map
      // This preserves fields not included in updatedData (like created_at)
      _plants[index].addAll(updatedData);

      // Ensure essential keys still exist if updateData somehow removed them (unlikely with addAll)
       _plants[index]['plantId'] = plantId; // Ensure ID is correct

      if (kDebugMode) print("Locally updated plant data for $plantId");
      notifyListeners(); // Notify listeners about the change
    } else {
       if (kDebugMode) print("Could not find plant $plantId locally to update.");
       // Optional: Fetch plants again if local state is inconsistent?
       // fetchPlants();
    }
  }


  // --- removePlant ---
   Future<void> removePlant(String plantId) async { 
        if (_isDeleting) return; Map<String, dynamic>? plantToRemove; try { plantToRemove = _plants.firstWhere((p) => p['plantId'] == plantId);} catch (e) { if (kDebugMode) { print("Plant $plantId not found locally for deletion."); } _error = "Could not find plant to delete."; _isDeleting = false; notifyListeners(); return;}
        final String? imageUrl = plantToRemove['image'] as String?; _isDeleting = true; _error = null; notifyListeners();
        try { await deleteUserPlant(plantId, imageUrl); _plants.removeWhere((p) => p['plantId'] == plantId); _error = null;} //
        catch (e) { if (kDebugMode) print("Error removing plant $plantId: $e"); _error = "Failed to delete plant.";}
        finally { _isDeleting = false;
        print("[PlantProvider] Calling notifyListeners() after deletion attempt."); notifyListeners();}
   }

  // --- markPlantAsWatered  ---
   Future<bool> markPlantAsWatered(String plantId) async { 
       _error = null; notifyListeners();
       try { await updateLastWatered(plantId); int index = _plants.indexWhere((p) => p['plantId'] == plantId); if (index != -1) { _plants[index]['last_watered'] = Timestamp.now(); _error = null; notifyListeners(); return true;} else { if (kDebugMode) print("Plant $plantId not found locally."); _error = "Plant not found locally."; notifyListeners(); return false;} } //
       catch (e) { if (kDebugMode) print("Error marking plant $plantId as watered: $e"); _error = "Failed to mark plant as watered."; notifyListeners(); return false;}
   }

  // --- clearPlants ---
   void clearPlants() { 
      _plants = []; _error = null; _isLoading = false; _isDeleting = false; notifyListeners();
   }
}