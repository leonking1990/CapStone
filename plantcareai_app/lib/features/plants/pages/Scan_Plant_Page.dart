import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plantcareai/core/services/prediction_api.dart';
import '../widgets/gallery_grid_bottom_sheet.dart';

class ScanPlantPage extends StatefulWidget {
  const ScanPlantPage({super.key});

  @override
  _ScanPlantPageState createState() => _ScanPlantPageState();
}

class _ScanPlantPageState extends State<ScanPlantPage> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false; // Add state for analyzing indicator

  // Arguments received from previous page (e.g., PlantProfilePage)
  bool _isUpdate = false;
  String? _plantId;
  String? _plantNameForContext; // Name for context

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Extract arguments passed to this page
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _isUpdate = args['isUpdate'] ?? false;
      _plantId = args['plantId'];
      _plantNameForContext = args['plantName'];
      if (kDebugMode && _isUpdate) {
        print(
            "ScanPage received update context: plantId=$_plantId, name=$_plantNameForContext");
      }
    }
  }

  Future<void> _showGallery() async {
    if (_isAnalyzing) return;

    showModalBottomSheet<File>( // Expect a File to be returned
      context: context,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75, // Set max height
      ),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext bsc) {
        return GalleryGridBottomSheet(
          onImageSelected: (File selectedImageFile) {
            if (mounted) {
              setState(() {
                _imageFile = selectedImageFile;
              });
            }
            // Navigator.pop(bsc) is now handled inside GalleryGridBottomSheet on tap
          },
        );
      },
    );
  }

  Future<void> _captureImageWithCamera() async {
    if (_isAnalyzing) return; // Prevent capture while analyzing
    final XFile? capturedFile =
        await _picker.pickImage(source: ImageSource.camera);
    if (capturedFile != null && mounted) {
      // Check mounted after await
      setState(() {
        _imageFile = File(capturedFile.path);
      });
    }
  }

  Future<void> _analyzePlant() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Center(child: Text('Please select or capture an image first!')),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    if (_isAnalyzing) return; // Prevent concurrent analysis

    setState(() {
      _isAnalyzing = true;
    }); // Show loading indicator

    try {
      // Call the backend prediction function
      final response = await predictImage(_imageFile!); //

      if (response != null && response['plant_data'] is Map<String, dynamic>) {
        final plantData = response['plant_data'];

        if (mounted) {
          // Check mounted before navigation
          // Navigate to PredictionPage, passing the data AND context args
          Navigator.pushNamed(context, '/prediction', arguments: {
            'plantData': plantData,
            'plantImage': FileImage(_imageFile!), // Pass FileImage for display
            'imageFile': _imageFile,
            'isUpdate': _isUpdate,
            'plantId': _plantId,
          });
        }
      } else {
        // Handle case where prediction failed or response format is wrong
        if (kDebugMode) print('Prediction failed or returned invalid data.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Center(
                  child: Text('Could not analyze plant. Please try again.')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error during plant analysis: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('An error occurred: ${e.toString()}')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        }); // Hide loading indicator
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the plant name in the title if it's an update
    final String pageTitle =
        _isUpdate ? 'Re-Scan "$_plantNameForContext"' : 'Scan New Plant';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Prevent overflow
          children: [
            Flexible(
              // Allow text to wrap or shrink
              child: Text(
                pageTitle, // Dynamic title
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis, // Add ellipsis if too long
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              FontAwesomeIcons.leaf,
              color: Theme.of(context).appBarTheme.iconTheme?.color,
              size: 20,
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        leading: IconButton(
          // Disable back button while analyzing
          icon: Icon(Icons.arrow_back,
              color: _isAnalyzing
                  ? Colors.grey
                  : Theme.of(context).appBarTheme.iconTheme?.color),
          onPressed: _isAnalyzing ? null : () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildImagePreview(),
            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 20),
            _buildAnalyzeButton(), // Button now shows loading indicator
          ],
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }

  Widget _buildImagePreview() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: _imageFile != null
            ? Colors.transparent
            : Theme.of(context).colorScheme.surfaceVariant,
        boxShadow: [
          if (_imageFile != null)
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: _imageFile != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.file(_imageFile!, fit: BoxFit.cover),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_search,
                    size: 80,
                    color: Theme.of(context).textTheme.bodySmall?.color),
                const SizedBox(height: 10),
                Text(
                  'Select or capture image',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
    );
  }

  

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _buildButton(
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            color: Colors.blueGrey, // Themeing?
            // Disable button while analyzing
            onPressed: _isAnalyzing
                ? null
                : _showGallery, //_pickImageFromGallery,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildButton(
            icon: Icons.camera_alt_outlined,
            label: 'Camera',
            color: Colors.blueGrey, // Themeing?
            // Disable button while analyzing
            onPressed: _isAnalyzing ? null : _captureImageWithCamera,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      // Wrap in SizedBox to control height easily
      width: double.infinity,
      height: 50,
      child: _buildButton(
        icon: FontAwesomeIcons.seedling,
        label: _isAnalyzing ? 'Analyzing...' : 'Analyze Plant',
        color: Colors.green,
        // Disable button while analyzing, also check if image selected
        onPressed: (_isAnalyzing || _imageFile == null) ? null : _analyzePlant,
        // Show loading indicator inside button if analyzing
        showLoading: _isAnalyzing,
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed, // Allow null onPressed for disabled state
    bool showLoading = false, // Add flag for loading state
  }) {
    return ElevatedButton.icon(
      // Show progress indicator instead of icon when loading
      icon: showLoading
          ? Container(
              width: 20,
              height: 20,
              margin:
                  const EdgeInsets.only(right: 8.0), // Add spacing like icon
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onPrimary,
              ))
          : Icon(icon, size: 18), // Smaller icon?
      label: Text(label),
      style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Theme.of(context)
              .colorScheme
              .onPrimary, // Use theme contrast color
          // Use theme's disabled color if onPressed is null
          disabledBackgroundColor: color.withOpacity(0.5),
          disabledForegroundColor:
              Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
          minimumSize:
              const Size(double.infinity, 50), // Ensure consistent height
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation:
              onPressed != null ? 4 : 0, // Reduce elevation when disabled
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600) // Adjust style
          ),
      onPressed: onPressed, // Pass onPressed directly
    );
  }
}
