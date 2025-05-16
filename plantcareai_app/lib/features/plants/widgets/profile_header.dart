import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Widget for the top section: Image, Name, Species
class ProfileHeader extends StatelessWidget {
  final Future<String?>? imageUrlFuture; // Receive the Future for the image URL
  final String plantName;
  final String plantSpecies;

  const ProfileHeader({
    super.key,
    required this.imageUrlFuture,
    required this.plantName,
    required this.plantSpecies,
  });

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(context).colorScheme.surfaceVariant;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final headlineColor = Theme.of(context).textTheme.headlineSmall?.color ??
        Theme.of(context).textTheme.bodyLarge?.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // --- Profile Image ---
        SizedBox(
          width: 150,
          height: 150,
          child: ClipOval(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: placeholderColor, // Background if error/no image
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
              child: FutureBuilder<String?>(
                future: imageUrlFuture, // Use the future passed from the parent state
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(strokeWidth: 2, color: secondaryTextColor));
                  } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                    if (kDebugMode && snapshot.hasError) { print("[ProfileHeader] FutureBuilder error state: ${snapshot.error}"); }
                    return Icon(Icons.error_outline, color: secondaryTextColor, size: 70);
                  } else {
                    final imageUrl = snapshot.data!;
                    return CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: secondaryTextColor)),
                      errorWidget: (context, url, error) {
                        if (kDebugMode) { print("[ProfileHeader] CachedNetworkImage ERROR for '$plantName': $error, URL: $url"); }
                        return Icon(Icons.broken_image_outlined, color: secondaryTextColor, size: 70);
                      },
                    );
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- Plant Name & Species ---
        Text(
          plantName,
          style: TextStyle(
            color: headlineColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        // Show species only if different from name
        if (plantName != plantSpecies && plantSpecies != 'N/A')
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
      ],
    );
  }
}