import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

// Callback type for when an image is selected from the grid
typedef OnImageSelected = Function(File imageFile);

class GalleryGridBottomSheet extends StatefulWidget {
  final OnImageSelected onImageSelected;

  const GalleryGridBottomSheet({
    super.key,
    required this.onImageSelected,
  });

  @override
  State<GalleryGridBottomSheet> createState() => _GalleryGridBottomSheetState();
}

class _GalleryGridBottomSheetState extends State<GalleryGridBottomSheet> {
  List<AssetEntity> _assets = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Gallery permission denied.';
        });
      }
      return;
    }

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          containsPathModified: true, // Useful for some platforms
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false) // Recent first
          ],
        ),
      );

      if (albums.isEmpty) {
        if (mounted) setState(() => _error = 'No image albums found.');
        return;
      }

      // Load a reasonable number of assets, e.g., first 100 from the primary album
      final List<AssetEntity> recentAssets = await albums[0].getAssetListPaged(page: 0, size: 100);

      if (mounted) {
        setState(() {
          _assets = recentAssets;
        });
      }
    } catch (e) {
      if (kDebugMode) print("Error loading assets: $e");
      if (mounted) setState(() => _error = 'Failed to load images.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9, // Start at 90% of maxHeight
      minChildSize: 0.4,     // Can be dragged down to 40%
      maxChildSize: 0.9,     // Can be dragged up to 90%
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Optional: Handle for dragging
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            // Header for the bottom sheet
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                "Select from Gallery",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _buildContent(scrollController), // Use helper for content
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_assets.isEmpty) {
      return const Center(child: Text('No images found in gallery.'));
    }

    return GridView.builder(
      controller: scrollController, // Important for DraggableScrollableSheet
      padding: const EdgeInsets.all(8.0),
      itemCount: _assets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 4 images per row
        crossAxisSpacing: 4.0,
        mainAxisSpacing: 4.0,
      ),
      itemBuilder: (BuildContext context, int index) {
        AssetEntity asset = _assets[index];
        return FutureBuilder<Uint8List?>(
          // Request a reasonably sized thumbnail
          future: asset.thumbnailDataWithSize(const ThumbnailSize(250, 250), quality: 90),
          builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
              return GestureDetector(
                onTap: () async {
                  File? file = await asset.file; // Get the full image file
                  if (file != null) {
                    widget.onImageSelected(file); // Call the callback
                    Navigator.pop(context); // Close the bottom sheet
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not load selected image.')),
                      );
                    }
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.memory(snapshot.data!, fit: BoxFit.cover),
                ),
              );
            }
            // Placeholder while loading individual thumbnail
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Center(child: Icon(Icons.image_search_outlined, color: Colors.grey))
            );
          },
        );
      },
    );
  }
}