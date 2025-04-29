import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  // Need TickerProvider for animation
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 250), // Short duration for quick press
      lowerBound: 0.95, // Scale down to 95%
      upperBound: 1.0, // Scale back up to 100%
    );
    // Start at full scale
    _controller.value = 1.0;
    // Create animation (can use CurvedAnimation if desired)
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);

    // Alternative using CurvedAnimation for smoother effect:
    // _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose controller!
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.reverse(
        from: 1.0); // Animate scale down (reverse from upper bound)
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.forward(from: 0.95).whenComplete(() {
      // This code runs only after the forward animation (scale up) is done
      if (mounted) {
        // Good practice to check if widget is still mounted
        widget.onTap?.call();
      } // Trigger the original onTap callback
    });
  }

  void _handleTapCancel() {
    _controller.forward(from: 0.95); // Animate scale up if tap is cancelled
  }

  @override
  Widget build(BuildContext context) {
    // --- Copy the styling logic from _buildPlantCard ---
    final cardBackgroundColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.blueGrey
        : const Color.fromARGB(255, 168, 207, 226);
    final primaryTextColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.blueGrey;
    final placeholderColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[700]
        : Colors.grey[400];

    final String imageUrl = widget.plant['imageThumbnailUrl'] as String? ??
        widget.plant['image'] as String? ??
        'N/A';
    // --- End styling logic ---

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        // Apply the scale animation
        scale:
            _controller, // Use controller directly or _scaleAnimation if using CurvedAnimation
        child: Container(
          // The original card container
          decoration: BoxDecoration(
              color: cardBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: (imageUrl != 'N/A' && imageUrl.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: placeholderColor,
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: secondaryTextColor)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: placeholderColor,
                            child: Icon(Icons.broken_image,
                                color: secondaryTextColor, size: 40),
                          ),
                        )
                      : Container(
                          /* ... Placeholder setup ... */
                          color: placeholderColor,
                          child: Icon(Icons.local_florist,
                              color: secondaryTextColor, size: 40),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        widget.plant['name'] ?? widget.plant['family'] ?? 'N/A',
                        style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Center(
                      child: Text(
                        widget.plant['species'] ?? 'Unnamed Plant',
                        style: TextStyle(
                            color: secondaryTextColor,
                            
                            fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
