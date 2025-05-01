import 'dart:async';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

String? _generateThumbnailUrl(String? originalUrl, String sizeSuffix) {
  if (originalUrl == null ||
      !originalUrl.contains('.') ||
      originalUrl == 'N/A') {
    return null; // Cannot generate if original URL is invalid
  }

  try {
    // Find the last dot for the file extension
    int dotIndex = originalUrl.lastIndexOf('.');
    // Find the '?' which usually marks the start of query parameters (like the token)
    int queryIndex = originalUrl.indexOf('?', dotIndex);

    String baseName = originalUrl.substring(0, dotIndex);
    String extension = originalUrl.substring(
        dotIndex, queryIndex != -1 ? queryIndex : originalUrl.length);
    String queryParams =
        queryIndex != -1 ? originalUrl.substring(queryIndex) : '';

    // Construct the thumbnail URL
    // Assuming the suffix is like "_200x200"
    return '$baseName$sizeSuffix$extension$queryParams';
  } catch (e) {
    if (kDebugMode) {
      print("Error generating thumbnail URL for $originalUrl: $e");
    }
    return null; // Return null or original on error
  }
}

// --- addUserData ---
Future<void> addUserData(Map<String, String> data) async {
  CollectionReference users = FirebaseFirestore.instance.collection('users');

  await users.doc(data['uid']).set({
    'fName': data['fName'],
    'lName': data['lName'],
    'email': data['email'],
    'created_at': FieldValue.serverTimestamp(),
    'last_login': FieldValue
        .serverTimestamp(), // Note: Might want to update last_login separately on actual login
    'last_updated': FieldValue.serverTimestamp(),
  }).then((_) {
    if (kDebugMode) {
      print("User data added successfully!");
    }
  }).catchError((error) {
    if (kDebugMode) {
      print("Failed to add user: $error");
    }
    // Consider rethrowing or handling more gracefully
    throw Exception("Failed to add user data: $error");
  });
}

// --- _getImageData (Helper) ---
Future<ByteData?> _getImageData(ImageProvider imageProvider) async {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  final ImageStream stream = imageProvider.resolve(ImageConfiguration());

  // Using a listener with error handling
  late ImageStreamListener listener;
  listener = ImageStreamListener((ImageInfo image, bool synchronousCall) {
    // Ensure stream is disposed after completion or error
    stream.removeListener(listener);
    completer.complete(image.image);
  }, onError: (dynamic error, StackTrace? stackTrace) {
    stream.removeListener(listener);
    if (kDebugMode) {
      print("Error loading image for conversion: $error");
    }
    completer.completeError(error, stackTrace);
  });

  stream.addListener(listener);

  try {
    // Await the image completion
    final ui.Image image = await completer.future;
    // Convert to ByteData
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData;
  } catch (e) {
    if (kDebugMode) {
      print("Failed to convert ImageProvider to ByteData: $e");
    }
    return null;
  }
}

// --- uploadPlantImage ---
Future<String?> uploadPlantImage(ImageProvider plantImage) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    if (kDebugMode) print("User not logged in for image upload.");
    return null; // Or throw Exception("User not authenticated");
  }

  Directory? tempDir; // Declare outside try for finally block access
  try {
    if (kDebugMode) print("User: ${user.uid} logged in for image upload.");

    // Convert ImageProvider to File
    final ByteData? byteData = await _getImageData(plantImage);
    if (byteData == null) {
      if (kDebugMode) print("Failed to convert ImageProvider to ByteData.");
      return null;
    }
    final uuid = const Uuid(); // Use const if uuid object doesn't change
    tempDir = await Directory.systemTemp
        .createTemp('plantcareai_img_'); // Create temp dir
    final filePath = path.join(tempDir.path, 'plant_image_${uuid.v4()}.png');
    final file = File(filePath);
    await file
        .writeAsBytes(byteData.buffer.asUint8List()); // Use await for write
    if (kDebugMode) print("Temporary image file created at: $filePath");

    // Create a storage reference
    String fileName = path.basename(file.path);
    Reference storageRef = FirebaseStorage.instance
        .ref()
        .child('users/${user.uid}/plants/images/$fileName'); // Consistent path

    // Upload file
    if (kDebugMode) print("Uploading image to Firebase Storage...");
    UploadTask uploadTask = storageRef.putFile(file);
    TaskSnapshot snapshot = await uploadTask;

    // Get the download URL
    String downloadUrl = await snapshot.ref.getDownloadURL();
    if (kDebugMode) print("Image uploaded successfully: $downloadUrl");
    return downloadUrl;
  } catch (e) {
    if (kDebugMode) print("Failed to upload image: $e");
    // Consider rethrowing specific errors if needed by caller
    return null; // Return null on error
  } finally {
    // Clean up temp directory/file in finally block
    if (tempDir != null) {
      try {
        if (await tempDir.exists()) {
          // Check if it exists before deleting
          await tempDir.delete(recursive: true);
          if (kDebugMode) print("Temporary directory deleted: ${tempDir.path}");
        }
      } catch (e) {
        if (kDebugMode) print("Error deleting temp directory: $e");
        // Decide if this error needs further handling
      }
    }
  }
}

// --- updateLastWatered ---
Future<void> updateLastWatered(String plantId) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    if (kDebugMode) print("User not logged in for updateLastWatered");
    throw Exception("User not authenticated");
  }

  DocumentReference plantDocRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('plants')
      .doc(plantId);

  try {
    await plantDocRef.update({
      'last_watered': FieldValue.serverTimestamp(),
      'last_updated': FieldValue.serverTimestamp(),
    });
    if (kDebugMode) print("Updated last_watered for $plantId");
  } catch (e) {
    if (kDebugMode) print("Failed to update last_watered for $plantId: $e");
    rethrow;
  }
}

// --- addPlantData ---
Future<String?> addPlantData(
    dynamic data, // Original prediction data map from server/API
    String? url, // Image URL
    String waterFrequency,
    String healthStatus,
    String? diseaseName, // Keep diseaseName reference
    String? diseaseDetails, // <-- RE-ADD diseaseDetails parameter
    String? sunlight,
    String? cycle,
    String? description,
    String? customName,
    int? speciesId) async {
  CollectionReference users = FirebaseFirestore.instance.collection('users');
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    if (kDebugMode) print("User not logged in for addPlantData");
    throw Exception("User not authenticated");
  }
  // Generate unique ID for the new plant document
  DocumentReference plantDocRef =
      users.doc(user.uid).collection('plants').doc();
  String plantId = plantDocRef.id;

  String? thumbnailUrl = _generateThumbnailUrl(url, "_200x200");

  // Prepare the data map, including the re-added diseaseDetails
  Map<String, dynamic> plantDocData = {
    'plantId': plantId, // Store the document ID within the document
    'species_id': speciesId, // Store the species ID from external source
    'created_at': FieldValue.serverTimestamp(),
    'last_updated': FieldValue.serverTimestamp(),
    'image': url ?? 'N/A',
    'imageThumbnailUrl': thumbnailUrl ?? url ?? 'N/A',
    'name': customName ?? data?['name'] ?? 'My ${data?['species'] ?? 'Plant'}',
    'species': data?['species'] ?? 'N/A',
    'genus': data?['genus'] ?? 'N/A',
    'family': data?['family'] ?? 'N/A',
    'water_frequency': waterFrequency,
    'sunlight': sunlight ?? 'N/A',
    'cycle': cycle ?? 'N/A',
    'description': description ?? 'N/A', // Plant description
    'healthStatus': healthStatus,
    'diseaseName': diseaseName, // Store the name reference
    'diseaseDetails':
        diseaseDetails, // <-- RE-ADD storage for description/treatment
    'last_watered': FieldValue.serverTimestamp(), // Initial watering timestamp
    // Add diagnosis timestamp only if unhealthy and disease detected
    if (healthStatus.toLowerCase() == 'unhealthy' &&
        diseaseName != null &&
        diseaseName.isNotEmpty)
      'diagnosisTimestamp': FieldValue.serverTimestamp(),
  };

  // Remove any fields that ended up being null to keep Firestore clean
  plantDocData.removeWhere((key, value) => value == null);

  try {
    // Set the data for the new document reference
    await plantDocRef.set(plantDocData);
    if (kDebugMode) {
      print("Plant Added/Updated with ID: $plantId, Disease Details included.");
    }
    return plantId; // Return the generated ID
  } catch (error) {
    if (kDebugMode) {
      print("Failed to add/update plant ($plantId): $error");
    }
    rethrow; // Rethrow error for handling in UI/Provider
  }
}

// for updating existing plant data ***
Future<void> updatePlantData({
  required String plantId, // ID of the plant document to update
  String? imageUrl, // New image URL (if changed)
  required String healthStatus, // Updated health status
  String? diseaseName, // Updated disease name (could be null if now healthy)
  String? diseaseDetails, // Updated details (could be null)
  // Add any other fields that should be updated during a re-scan
}) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    if (kDebugMode) print("User not logged in for updatePlantData");
    throw Exception("User not authenticated");
  }

  // Reference the specific plant document
  DocumentReference plantDocRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('plants')
      .doc(plantId);

  // Prepare map of fields to update
  Map<String, dynamic> dataToUpdate = {
    'healthStatus': healthStatus,
    'diseaseName': diseaseName, // Will update to null if diseaseName is null
    'diseaseDetails':
        diseaseDetails, // Will update to null if diseaseDetails is null
    'last_updated': FieldValue.serverTimestamp(),
    // Conditionally add diagnosis timestamp if now unhealthy with a disease
    if (healthStatus.toLowerCase() == 'unhealthy' &&
        diseaseName != null &&
        diseaseName.isNotEmpty)
      'diagnosisTimestamp': FieldValue.serverTimestamp()
    else // If now healthy or no disease, consider removing old diagnosis timestamp? Optional.
      'diagnosisTimestamp':
          FieldValue.delete(), // Example: Delete timestamp if healthy

    // Only update image if a new URL is provided
    if (imageUrl != null) ...{
      'image': imageUrl,

      'imageThumbnailUrl': _generateThumbnailUrl(imageUrl, "_200x200") ??
          imageUrl, // Fallback to new original
    }
  };

  // Remove null values before sending to Firestore's update method
  // Note: FieldValue.delete() is handled correctly by update() and not removed here.
  dataToUpdate.removeWhere((key, value) =>
      value == null && key != 'diseaseName' && key != 'diseaseDetails');
  // Explicitly handle setting diseaseName/Details to null if needed
  if (diseaseName == null) dataToUpdate['diseaseName'] = null;
  if (diseaseDetails == null) dataToUpdate['diseaseDetails'] = null;

  if (kDebugMode)
    print("Attempting to update plant $plantId with data: $dataToUpdate");

  try {
    await plantDocRef.update(dataToUpdate);
    if (kDebugMode) print("Plant $plantId updated successfully.");
  } catch (e) {
    if (kDebugMode) print("Failed to update plant $plantId: $e");
    rethrow; // Rethrow error for handling in UI/Provider
  }
}

// --- allPlants ---
Future<List<Map<String, dynamic>>> allPlants() async {
  User? user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> plantsList = [];

  if (user != null) {
    // Get the reference to the collection first
    CollectionReference plantsCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('plants');

    try {
      // Apply orderBy and then get the snapshot directly from the resulting Query
      QuerySnapshot snapshot = await plantsCollection
          .orderBy('created_at',
              descending: true) // Apply ordering - returns a Query
          .get(); // Call get() on the Query

      // Process the snapshot as before
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['plantId'] == null || data['plantId'] != doc.id) {
          if (kDebugMode && data['plantId'] != null) {
            print(
                "Warning: Mismatched plantId field (${data['plantId']}) in doc ${doc.id}. Using doc.id.");
          }
          data['plantId'] = doc.id;
        }
        plantsList.add(data);
      }
      if (kDebugMode)
        print("Fetched ${plantsList.length} plants for user ${user.uid}");
    } catch (error) {
      if (kDebugMode) print("Failed to retrieve plants data: $error");
      throw Exception("Failed to retrieve plants: $error");
    }
  } else {
    if (kDebugMode) print("User not logged in for allPlants.");
    // throw Exception("User not logged in"); // Or return empty list
  }
  return plantsList;
}

// --- deleteUserPlant ---
Future<void> deleteUserPlant(String plantId, String? imageUrl) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    if (kDebugMode) print("User not logged in. Cannot delete plant.");
    throw Exception("User not authenticated");
  }

  DocumentReference plantDocRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('plants')
      .doc(plantId);

  if (kDebugMode)
    print("Attempting to delete Firestore doc: ${plantDocRef.path}");
  try {
    await plantDocRef.delete();
    if (kDebugMode) print("Firestore document deleted successfully: $plantId");
  } catch (error) {
    if (kDebugMode)
      print("Failed to delete Firestore document ($plantId): $error");
    rethrow; // Important to rethrow so UI knows deletion failed
  }

  // 2. Delete Firebase Storage Image (if URL exists and is valid)
  if (imageUrl != null &&
      imageUrl.isNotEmpty &&
      imageUrl != 'N/A' &&
      imageUrl.startsWith('gs://')) {
    if (kDebugMode) print("Attempting to delete Storage image: $imageUrl");
    try {
      Reference storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
      await storageRef.delete();
      if (kDebugMode)
        print("Firebase Storage image deleted successfully: $imageUrl");
    } catch (error) {
      // Log storage deletion errors, but decide if they should block success
      if (kDebugMode) {
        print("Failed to delete Firebase Storage image ($imageUrl): $error");
        // remember future Stevie: check for common errors:
        // Common error: Permission denied (check rules)
        // Common error: Object not found (maybe already deleted or URL mismatch)
        // Common error: Permissions issue
      }
      // note to future Stevie: Consider if you want to rethrow this error or not.
      // Optional: Rethrow only specific critical storage errors?
      // For now, we allow Firestore deletion to succeed even if image deletion fails.
      // Consider adding logging to track these failures.
    }
  } else if (imageUrl != null &&
      !imageUrl.startsWith('gs://') &&
      imageUrl != 'N/A') {
    if (kDebugMode)
      print(
          "Skipping image deletion: URL does not appear to be a Firebase Storage URL: $imageUrl");
  }
}

// --- getUserData ---
Future<Map<String, dynamic>?> getUserData() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    if (kDebugMode) print("User not logged in for getUserData");
    return null;
  }

  try {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      return userDoc.data() as Map<String, dynamic>?;
    } else {
      if (kDebugMode)
        print("User document does not exist for uid: ${user.uid}");
      return null;
    }
  } catch (e) {
    if (kDebugMode) print("Error getting user data: $e");
    return null; // Return null on error
  }
}

// --- updateUserData ---
Future<void> updateUserData({String? fName, String? lName}) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    if (kDebugMode) print("User not logged in for updateUserData");
    throw Exception("User not authenticated");
  }

  Map<String, dynamic> dataToUpdate = {};
  if (fName != null) dataToUpdate['fName'] = fName;
  if (lName != null) dataToUpdate['lName'] = lName;

  // Only update if there's something to change
  if (dataToUpdate.isEmpty) {
    if (kDebugMode) print("No data provided to update user profile.");
    return; // Nothing to update
  }

  // Always update the timestamp when profile data changes
  dataToUpdate['last_updated'] = FieldValue.serverTimestamp();

  DocumentReference userDocRef =
      FirebaseFirestore.instance.collection('users').doc(user.uid);

  try {
    await userDocRef.update(dataToUpdate);
    if (kDebugMode) print("User data updated successfully.");
  } catch (e) {
    if (kDebugMode) print("Failed to update user data: $e");
    rethrow; // Rethrow error for UI handling
  }
}
