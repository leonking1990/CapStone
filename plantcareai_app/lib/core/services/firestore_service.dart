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
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

String? _generateThumbnailUrl(String? originalUrl, String sizeSuffix) {
  if (kDebugMode) {
    print("[_generateThumbnailUrl] Input URL: $originalUrl"); // Log input
  }
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
    
    // Construct the thumbnail URL
    // Assuming the suffix is like "_200x200"
    final thumbnailUrl = '$baseName$sizeSuffix$extension';
    if (kDebugMode) {
      print("[_generateThumbnailUrl] Generated URL: $thumbnailUrl"); // Log output
    }
    return thumbnailUrl;
  } catch (e) {
    if (kDebugMode) {
      print("[_generateThumbnailUrl] Error generating thumbnail URL for $originalUrl: $e");
    }
    return null; // Return null or original on error
  }
}

// --- Upload Original and Thumbnail Image ---
// Takes a File, resizes it, uploads both, returns clean URLs for original and thumbnail
Future<Map<String, String?>> uploadOriginalAndThumbnail(File imageFile) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception("User not authenticated for image upload.");
  }

  String? originalUrl;
  String? thumbnailUrl;
  // Generate unique base name using UUID
  final String fileId = const Uuid().v4();
  // Get original extension (e.g., ".png", ".jpg")
  final String originalExtension = path.extension(imageFile.path);
  // Define filenames
  final String originalFileName = 'plant_original_${fileId}$originalExtension';
  final String thumbnailFileName = 'plant_thumb_${fileId}.jpg'; // Standardize thumbnail to JPG

  try {
    // 1. Read and Decode Image File
    final imageBytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception("Failed to decode image file.");
    }

    // 2. Create Thumbnail
    // Resize (e.g., 400px width, maintaining aspect ratio). Adjust width as needed.
    img.Image thumbnail = img.copyResize(image, width: 400);
    // Encode thumbnail as JPG bytes (adjust quality 0-100)
    List<int> thumbnailBytes = img.encodeJpg(thumbnail, quality: 85);

    // 3. Get Storage References
    String basePath = 'users/${user.uid}/plants/images';
    Reference storageRefOriginal = FirebaseStorage.instance.ref().child('$basePath/$originalFileName');
    Reference storageRefThumbnail = FirebaseStorage.instance.ref().child('$basePath/$thumbnailFileName');

    // 4. Upload Both Files (can run in parallel)
    if (kDebugMode) print("Uploading original: $originalFileName");
    UploadTask originalUploadTask = storageRefOriginal.putData(imageBytes, SettableMetadata(contentType: 'image/${originalExtension.substring(1)}')); // Use original bytes and determined content type

    if (kDebugMode) print("Uploading thumbnail: $thumbnailFileName");
    UploadTask thumbnailUploadTask = storageRefThumbnail.putData(Uint8List.fromList(thumbnailBytes), SettableMetadata(contentType: 'image/jpeg')); // JPG content type

    // Wait for uploads to complete
    TaskSnapshot originalSnapshot = await originalUploadTask;
    TaskSnapshot thumbnailSnapshot = await thumbnailUploadTask;

    // 5. Get Download URLs
    String rawOriginalUrl = await originalSnapshot.ref.getDownloadURL();
    String rawThumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();

    // Remove tokens/query params to store clean URLs
    originalUrl = rawOriginalUrl.contains('?') ? rawOriginalUrl.substring(0, rawOriginalUrl.indexOf('?')) : rawOriginalUrl;
    thumbnailUrl = rawThumbnailUrl.contains('?') ? rawThumbnailUrl.substring(0, rawThumbnailUrl.indexOf('?')) : rawThumbnailUrl;

    if (kDebugMode) {
      print("Original Clean URL: $originalUrl");
      print("Thumbnail Clean URL: $thumbnailUrl");
    }

  } catch (e) {
    if (kDebugMode) print("Failed during image upload/resize: $e");
    // Rethrow the error so the caller knows something went wrong
    rethrow;
  }

  // Return map containing both clean URLs (or null if an error occurred)
  return {
    'originalUrl': originalUrl,
    'thumbnailUrl': thumbnailUrl,
  };
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
    dynamic predictionData, // Data from your prediction model/API
    File? imageFileToUpload, // *** CHANGED: Accept File? instead of String? url ***
    String waterFrequency,
    String healthStatus,
    String? diseaseName,
    String? diseaseDetails,
    String? sunlight,
    String? cycle,
    String? description,
    String? customName,
    int? speciesId) async { // Keep other parameters

  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
      if (kDebugMode) print("User not logged in for addPlantData");
      throw Exception("User not authenticated");
  }

  String finalOriginalUrl = 'N/A'; // Default value
  String finalThumbnailUrl = 'N/A'; // Default value

  // --- Upload images IF a file is provided ---
  if (imageFileToUpload != null) {
     if (kDebugMode) print("[addPlantData] Image file provided, attempting upload...");
     try {
        // Call the new upload function which returns both URLs
        final Map<String, String?> urls = await uploadOriginalAndThumbnail(imageFileToUpload);

        // Assign URLs from the returned map, handle potential nulls
        finalOriginalUrl = urls['originalUrl'] ?? 'N/A';
        // Use original URL as fallback for thumbnail if thumbnail fails for some reason
        finalThumbnailUrl = urls['thumbnailUrl'] ?? finalOriginalUrl;

        if (kDebugMode) print("[addPlantData] Upload complete. Original: $finalOriginalUrl, Thumb: $finalThumbnailUrl");

     } catch (e) {
        if (kDebugMode) print("[addPlantData] Image upload failed: $e");
        // Still proceed to save plant data, but URLs will be 'N/A'
        // Alternatively, you could throw the error here to stop the process: throw Exception("Image upload failed: $e");
     }
  } else {
      if (kDebugMode) print("[addPlantData] No image file provided, saving plant data without image URLs.");
  }
  // --- End image upload ---


  // --- Prepare data for Firestore ---
  CollectionReference users = FirebaseFirestore.instance.collection('users');
  // Generate unique ID for the new plant document
  DocumentReference plantDocRef = users.doc(user.uid).collection('plants').doc();
  String plantId = plantDocRef.id;

  // Build the map to save, using the potentially updated URLs
  Map<String, dynamic> plantDocData = {
    'plantId': plantId, // Store the document ID within the document
    'species_id': speciesId, // Store the species ID from external source
    'created_at': FieldValue.serverTimestamp(),
    'last_updated': FieldValue.serverTimestamp(),
    'image': finalOriginalUrl, // Save the CLEAN original URL
    'imageThumbnailUrl': finalThumbnailUrl, // Save the CLEAN thumbnail URL
    'name': customName ?? predictionData?['name'] ?? 'My ${predictionData?['species'] ?? 'Plant'}',
    'species': predictionData?['species'] ?? 'N/A',
    'genus': predictionData?['genus'] ?? 'N/A',
    'family': predictionData?['family'] ?? 'N/A',
    'water_frequency': waterFrequency,
    'sunlight': sunlight ?? 'N/A',
    'cycle': cycle ?? 'N/A',
    'description': description ?? 'N/A', // Plant description
    'healthStatus': healthStatus,
    'diseaseName': diseaseName, // Store the name reference
    'diseaseDetails': diseaseDetails,
    'last_watered': FieldValue.serverTimestamp(), // Initial watering timestamp
    if (healthStatus.toLowerCase() == 'unhealthy' && diseaseName != null && diseaseName.isNotEmpty)
      'diagnosisTimestamp': FieldValue.serverTimestamp(),
  };

  // Remove any fields that ended up being null to keep Firestore clean
  plantDocData.removeWhere((key, value) => value == null);

  // --- Save data to Firestore ---
  try {
    await plantDocRef.set(plantDocData);
    if (kDebugMode) {
      print("Plant Added with ID: $plantId. Data saved to Firestore.");
    }
    return plantId; // Return the generated ID
  } catch (error) {
    if (kDebugMode) {
      print("Failed to add plant data to Firestore ($plantId): $error");
    }
    // Consider deleting uploaded images if Firestore save fails? More complex cleanup.
    rethrow; // Rethrow error for handling in UI/Provider
  }
}

// for updating existing plant data ***
Future<void> updatePlantData({
  required String plantId,
  File? newImageFile, // *** CHANGED: Accept optional File object ***
  required String healthStatus,
  String? diseaseName,
  String? diseaseDetails,
  // Removed imageUrl String parameter
}) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception("User not authenticated");

  DocumentReference plantDocRef = FirebaseFirestore.instance
      .collection('users').doc(user.uid).collection('plants').doc(plantId);

  // Start with data fields that are always updated
  Map<String, dynamic> dataToUpdate = {
    'healthStatus': healthStatus,
    'diseaseName': diseaseName, // Will be set to null if diseaseName is null
    'diseaseDetails': diseaseDetails, // Will be set to null if diseaseDetails is null
    'last_updated': FieldValue.serverTimestamp(),
    // Update diagnosis timestamp based on new health status
    if (healthStatus.toLowerCase() == 'unhealthy' && diseaseName != null && diseaseName.isNotEmpty)
      'diagnosisTimestamp': FieldValue.serverTimestamp()
    else
      'diagnosisTimestamp': FieldValue.delete(), // Remove timestamp if healthy or no disease
  };

  // --- Handle Image Replacement if newImageFile is provided ---
  if (newImageFile != null) {
      if (kDebugMode) print("[updatePlantData] New image file provided for $plantId. Processing...");

      // 1. Try to delete OLD images before uploading new ones
      try {
         DocumentSnapshot currentPlantDoc = await plantDocRef.get();
         if (currentPlantDoc.exists) {
            final currentData = currentPlantDoc.data() as Map<String, dynamic>?;
            // Get clean URLs stored previously
            final oldOriginalUrl = currentData?['image'] as String?;
            final oldThumbnailUrl = currentData?['imageThumbnailUrl'] as String?;

            // Attempt deletion (ignore errors, best effort)
            if (oldOriginalUrl != null && oldOriginalUrl != 'N/A' && oldOriginalUrl.startsWith('https://firebasestorage')) {
               try {
                  if (kDebugMode) print("[updatePlantData] Attempting to delete old original: $oldOriginalUrl");
                  await FirebaseStorage.instance.refFromURL(oldOriginalUrl).delete();
               } catch (e) { if (kDebugMode) print("Ignoring error deleting old original: $e");}
            }
             if (oldThumbnailUrl != null && oldThumbnailUrl != 'N/A' && oldThumbnailUrl != oldOriginalUrl && oldThumbnailUrl.startsWith('https://firebasestorage')) {
               try {
                  if (kDebugMode) print("[updatePlantData] Attempting to delete old thumbnail: $oldThumbnailUrl");
                  await FirebaseStorage.instance.refFromURL(oldThumbnailUrl).delete();
               } catch (e) { if (kDebugMode) print("Ignoring error deleting old thumbnail: $e");}
            }
         }
      } catch (e) {
         if (kDebugMode) print("[updatePlantData] Error getting current doc / deleting old images: $e");
         // Continue even if deletion fails
      }

      // 2. Upload NEW images (original and thumbnail)
      try {
        final urls = await uploadOriginalAndThumbnail(newImageFile); // Use the updated upload function

        // Add new URLs to the update map (handle potential upload failures)
        String? newOriginalUrl = urls['originalUrl'];
        String? newThumbnailUrl = urls['thumbnailUrl'];

        if (newOriginalUrl != null) {
           dataToUpdate['image'] = newOriginalUrl;
           // Fallback thumbnail to original if thumbnail upload failed but original succeeded
           dataToUpdate['imageThumbnailUrl'] = newThumbnailUrl ?? newOriginalUrl;
           if (kDebugMode) print("[updatePlantData] New images uploaded. Original: ${dataToUpdate['image']}, Thumb: ${dataToUpdate['imageThumbnailUrl']}");
        } else {
           // Handle case where even original upload failed
           if (kDebugMode) print("[updatePlantData] Upload of new original image failed. Image fields will not be updated.");
           // Consider throwing error or just proceeding without image update
        }

      } catch (e) {
          if (kDebugMode) print("[updatePlantData] New image upload failed: $e");
          // Proceed with other updates, but image fields won't be changed
          // You could throw an error here if image update is mandatory: throw Exception("Failed to upload new image: $e");
      }
  }
  // --- End Handle Image Replacement ---

  // Remove null values for fields that should be explicitly set to null
  // Firestore's update method handles non-provided fields correctly (doesn't change them),
  // but we want to explicitly set diseaseName/Details to null if they are passed as null.
  if (diseaseName == null) dataToUpdate['diseaseName'] = null;
  if (diseaseDetails == null) dataToUpdate['diseaseDetails'] = null;

  // Perform the Firestore update
  if (kDebugMode) print("[updatePlantData] Attempting Firestore update for $plantId with data: $dataToUpdate");
  try {
    await plantDocRef.update(dataToUpdate);
    if (kDebugMode) print("[updatePlantData] Plant $plantId updated successfully in Firestore.");
  } catch (e) {
    if (kDebugMode) print("[updatePlantData] Failed Firestore update for plant $plantId: $e");
    rethrow; // Critical error, rethrow for UI handling
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
      imageUrl.startsWith('https://firebasestorage.googleapis.com/')) {
    if (kDebugMode) { print("Attempting to delete ORIGINAL Storage image using URL: $imageUrl"); }
    
   try {
        Reference storageRefOriginal = FirebaseStorage.instance.refFromURL(imageUrl);
        await storageRefOriginal.delete();
        if (kDebugMode) { print("Firebase Storage ORIGINAL image deleted successfully: $imageUrl"); }
      } catch (error) {
        if (kDebugMode) { print("Failed to delete Firebase Storage ORIGINAL image ($imageUrl): $error"); }
        // Decide if failure here should be fatal - often okay to continue if Firestore doc deleted
      }

      // 3. Attempt to Delete Thumbnail Image
      // Construct the expected thumbnail URL (without token)
      String? thumbnailUrl = _generateThumbnailUrl(imageUrl, "_200x200"); // Use the helper

      if (thumbnailUrl != null) {
        if (kDebugMode) { print("Attempting to delete THUMBNAIL Storage image using URL: $thumbnailUrl"); }
        try {
           Reference storageRefThumbnail = FirebaseStorage.instance.refFromURL(thumbnailUrl);
           await storageRefThumbnail.delete();
           if (kDebugMode) { print("Firebase Storage THUMBNAIL image deleted successfully: $thumbnailUrl"); }
        } catch (error) {
           if (kDebugMode) { print("Failed to delete Firebase Storage THUMBNAIL image ($thumbnailUrl): $error"); }
           // Log error, but usually okay to proceed if original/doc deleted.
           // Common error here: object-not-found if thumbnail creation failed earlier.
        }
      } else {
         if (kDebugMode) { print("Could not generate thumbnail URL for deletion from original: $imageUrl"); }
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
