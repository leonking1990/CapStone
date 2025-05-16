import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
import 'package:flutter/foundation.dart'; // Import for kDebugMode

class PlantCard extends StatefulWidget {
  final Map<String, dynamic> plant;
  final VoidCallback? onTap; // Callback for when tapped

  const PlantCard({
    super.key,
    required this.plant,
    this.onTap,
  });

  @override
  State<PlantCard> createState() => _PlantCardState();
}

class _PlantCardState extends State<PlantCard>
    with SingleTickerProviderStateMixin {
  // Animation controller for tap feedback
  late AnimationController _controller;

  // --- State for Image URL Future ---
  Future<String?>? _imageUrlFuture;
  // Track which plant data this future belongs to, to handle widget updates
  Map<String, dynamic>? _currentPlantDataForImage;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      lowerBound: 0.95,
      upperBound: 1.0,
    );
    _controller.value = 1.0; // Start at full scale

    // Initialize the future to get the download URL
    _currentPlantDataForImage = widget.plant; // Store initial plant data
    _initializeImageUrl();
  }

  @override
  void didUpdateWidget(covariant PlantCard oldWidget) {
     super.didUpdateWidget(oldWidget);
     // Re-initialize if the plant data reference actually changes
     // (Comparing maps directly can be tricky, might need a better check if data updates frequently within the same card instance)
     // A simple check if the image URLs themselves changed is often sufficient
     final oldThumb = oldWidget.plant['imageThumbnailUrl'] as String?;
     final newThumb = widget.plant['imageThumbnailUrl'] as String?;
     final oldOrig = oldWidget.plant['image'] as String?;
     final newOrig = widget.plant['image'] as String?;

     if (oldThumb != newThumb || oldOrig != newOrig) {
        if(kDebugMode) print("[PlantCard] Plant data changed for ${widget.plant['name']}, re-initializing image future.");
        _currentPlantDataForImage = widget.plant; // Update tracked data
        _initializeImageUrl();
     }
  }

  // --- Function to start the process of getting the download URL ---
  void _initializeImageUrl() {
    // Determine which URL to use (prefer thumbnail, fallback to original)
    final String? storedThumbnailUrl = _currentPlantDataForImage?['imageThumbnailUrl'] as String?;
    final String? storedOriginalUrl = _currentPlantDataForImage?['image'] as String?;
    final String? urlToLoad = (storedThumbnailUrl != null && storedThumbnailUrl != 'N/A')
        ? storedThumbnailUrl
        : ((storedOriginalUrl != null && storedOriginalUrl != 'N/A') ? storedOriginalUrl : null);

    Future<String?> newFuture;
    if (urlToLoad != null && urlToLoad.startsWith('https://firebasestorage.googleapis.com/')) {
       // Get the Future<String?> by calling _getDownloadUrl
       newFuture = _getDownloadUrl(urlToLoad);
    } else {
       // No valid URL, create a future that resolves immediately to null
       newFuture = Future.value(null);
       if (kDebugMode && urlToLoad != null && urlToLoad != 'N/A') {
          print("[PlantCard] Skipping getDownloadURL for non-Firebase URL or N/A: $urlToLoad");
       }
    }

    // Use addPostFrameCallback for safety if experiencing setState issues during build
     WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) {
            // Update the state variable that holds the Future
            setState(() { _imageUrlFuture = newFuture; });
         }
     });
  }

  // --- Helper function to get the download URL ---
  Future<String?> _getDownloadUrl(String storageUrl) async {
    String cleanUrl = storageUrl;
    if (cleanUrl.contains('?')) { cleanUrl = cleanUrl.substring(0, cleanUrl.indexOf('?')); }
    try {
      if (kDebugMode) { print("[PlantCard] Getting download URL for clean path: $cleanUrl"); }
      final ref = FirebaseStorage.instance.refFromURL(cleanUrl);
      // This call fetches the URL *with* a fresh, valid download token
      final downloadUrl = await ref.getDownloadURL();
      if (kDebugMode) { print("[PlantCard] Successfully got download URL: $downloadUrl"); }
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) { print("[PlantCard] Failed to get download URL for $cleanUrl: $e"); }
      return null; // Return null if fetching URL fails
    }
  }


  @override
  void dispose() {
    _controller.dispose(); // Dispose animation controller
    super.dispose();
  }

  // Tap Animation Handlers
  void _handleTapDown(TapDownDetails details) { _controller.reverse(from: 1.0); }
  void _handleTapUp(TapUpDetails details) { _controller.forward(from: 0.95).whenComplete(() { if (mounted) { widget.onTap?.call(); } }); }
  void _handleTapCancel() { _controller.forward(from: 0.95); }

  @override
  Widget build(BuildContext context) {
    // Theme and Styling Setup
    final cardBackgroundColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.blueGrey[800]
        : const Color.fromARGB(255, 225, 236, 240);
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final placeholderColor = Theme.of(context).colorScheme.surfaceVariant;

    // Extract display names safely
    final String displayName = widget.plant['name'] as String? ?? widget.plant['family'] as String? ?? 'N/A';
    final String speciesName = widget.plant['species'] as String? ?? 'Unnamed Plant';

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _controller, // Apply tap animation
        child: Container(
          decoration: BoxDecoration(
              color: cardBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [ BoxShadow( color: Theme.of(context).shadowColor.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3), ), ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Image Section with FutureBuilder ---
              AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: FutureBuilder<String?>(
                    future: _imageUrlFuture, // Use the future state variable
                    builder: (context, snapshot) {
                      // While waiting for the URL
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container( color: placeholderColor, child: Center( child: CircularProgressIndicator( strokeWidth: 2, color: secondaryTextColor)),);
                      }
                      // If error fetching URL or URL is null/empty
                      else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                        if (kDebugMode && snapshot.hasError) { print("[PlantCard] FutureBuilder error state: ${snapshot.error}"); }
                         return Container( color: placeholderColor, child: Icon(Icons.error_outline, color: secondaryTextColor, size: 40),);
                      }
                      // If URL is successfully fetched
                      else {
                        final imageUrl = snapshot.data!; // The fresh URL with token
                        return CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container( color: placeholderColor, child: Center( child: CircularProgressIndicator( strokeWidth: 2, color: secondaryTextColor))),
                          errorWidget: (context, url, error) {
                            if (kDebugMode) { print("[PlantCard] CachedNetworkImage ERROR for '$displayName': $error, URL: $url"); }
                            return Container( color: placeholderColor, child: Icon(Icons.broken_image, color: secondaryTextColor, size: 40));
                          },
                        );
                      }
                    },
                  ),
                ),
              ),
              // --- Text Section ---
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center( child: Text( displayName, style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis,),),
                    const SizedBox(height: 2),
                    Center( child: Text( speciesName, style: TextStyle( color: secondaryTextColor, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis,),),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}