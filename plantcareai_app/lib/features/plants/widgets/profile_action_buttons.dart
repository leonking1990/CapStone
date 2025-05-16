// lib/features/plants/widgets/profile_action_buttons.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plantcareai/core/providers/plant_provider.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

// Widget for the action buttons at the bottom of the profile
class ProfileActionButtons extends StatelessWidget {
  final String? plantId;
  final String plantName;
  final bool isUnhealthy;
  final String? diseaseName;
  final String? diseaseDetails;
  // Ensure the function signature for showDeleteConfirmation matches how it's defined and called.
  // It takes BuildContext and String, and returns Future<bool?>.
  final Future<bool?> Function(BuildContext, String) showDeleteConfirmation;

  const ProfileActionButtons({
    super.key,
    required this.plantId,
    required this.plantName,
    required this.isUnhealthy,
    this.diseaseName,
    this.diseaseDetails,
    required this.showDeleteConfirmation,
  });

  @override
  Widget build(BuildContext context) {
    // Use context.watch only if you need the widget to rebuild when plantProvider.isDeleting changes.
    // If it's just for one-time read, context.read or Provider.of with listen:false is better.
    // However, for disabling the button while deleting, `watch` is appropriate here.
    final plantProvider = context.watch<PlantProvider>();

    return Column(
      children: [
        // --- Re-Scan Button ---
        _buildActionButton(
          context,
          'Re-Scan Plant Health',
          plantProvider.isDeleting ? null : () { // Disable if deleting
            if (plantId != null) {
              Navigator.pushNamed(
                context,
                '/scan',
                arguments: {
                  'isUpdate': true,
                  'plantId': plantId,
                  'plantName': plantName,
                },
              );
            } else {
              // Check context.mounted before showing SnackBar after a potential async gap
              // (though in this specific `onPressed`, there isn't an await before this else block)
              if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot initiate scan: Plant ID missing.')));
              }
            }
          },
          icon: Icons.camera_alt_outlined,
        ),
        const SizedBox(height: 12),

        // --- View Disease Button (Conditional) ---
        if (isUnhealthy && diseaseName != null && diseaseName!.isNotEmpty && diseaseName != 'N/A') ...[
          _buildActionButton(
            context,
            'View Disease / Treatments',
             plantProvider.isDeleting ? null : () { // Disable if deleting
              Navigator.pushNamed(
                context,
                '/diseaseTreatment',
                arguments: {
                  'name': diseaseName,
                  'details': diseaseDetails ?? 'No details available.'
                },
              );
            },
            icon: Icons.medical_information_outlined,
            isDestructive: false,
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 12),
        ],

        // --- Delete Button (MODIFIED LOGIC) ---
        _buildActionButton(
        context, // This context is from the build method
        'Delete Plant',
        plantProvider.isDeleting
            ? null
            : () async {
                // Use the 'context' from the build method to show the dialog.
                // This context is valid at the point of calling showDeleteConfirmation.
                final bool? confirmed = await showDeleteConfirmation(
                    context, plantName);

                // After an await, ALWAYS check if the State object is still mounted.
                if (!context.mounted) {
                  if (kDebugMode) {
                    print("[ProfileActionButtons] Delete confirmed, but widget is no longer mounted. Aborting.");
                  }
                  return;
                }

                // If mounted, 'this.context' (or just 'context' within the State class)
                // should refer to the valid BuildContext of this State object.
                if (confirmed == true && plantId != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar( // Using this.context
                    content: Text('Deleting "${plantName}"...'),
                    duration: const Duration(seconds: 2),
                  ));

                  final plantProv =
                      Provider.of<PlantProvider>(context, listen: false); // Using this.context
                  String? deletionErrorMsg;

                  try {
                    await plantProv.removePlant(plantId!);
                    deletionErrorMsg = plantProv.error;
                  } catch (e) {
                    deletionErrorMsg = e.toString();
                    if (kDebugMode) {
                      print(
                          "Exception caught during plantProv.removePlant: $e");
                    }
                  }

                  // CRITICAL: Check mounted status AGAIN after the main async operation.
                  if (!context.mounted) {
                    if (kDebugMode) {
                      print("[ProfileActionButtons] Post-deletion, widget is no longer mounted. Aborting UI updates.");
                    }
                    return;
                  }

                  if (deletionErrorMsg == null) {
                    Navigator.of(context).pop('deleted'); // Using this.context
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar( // Using this.context
                      content:
                          Text('Error deleting plant: $deletionErrorMsg'),
                      backgroundColor: Colors.redAccent,
                    ));
                  }
                } else if (confirmed == true && plantId == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar( // Using this.context
                    content: Text('Cannot delete: Plant ID is missing.'),
                    backgroundColor: Colors.orangeAccent,
                  ));
                }
              },
        icon: Icons.delete_outline,
        isDestructive: true,
      ),
      ],
    );
  }

  // Reusable action button builder
  Widget _buildActionButton( BuildContext context, String text, VoidCallback? onPressed, {bool isDestructive = false, IconData? icon, Color? color}) {
    final Color defaultButtonColor = color ?? (isDestructive ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary);
    final Color defaultTextColor = isDestructive ? Theme.of(context).colorScheme.onError : Theme.of(context).colorScheme.onPrimary;
    final Color disabledButtonColor = Theme.of(context).disabledColor.withOpacity(0.12); // Using theme's disabled color
    final Color disabledTextColor = Theme.of(context).disabledColor.withOpacity(0.38); // Using theme's disabled color for text

    final ButtonStyle style = ElevatedButton.styleFrom(
        backgroundColor: defaultButtonColor,
        foregroundColor: defaultTextColor,
        disabledBackgroundColor: disabledButtonColor, // Apply disabled background color
        disabledForegroundColor: disabledTextColor, // Apply disabled foreground color
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        elevation: onPressed != null ? 2 : 0,
    );

    return SizedBox(
       width: double.infinity, // Make buttons take full width
       child: icon != null
          ? ElevatedButton.icon(
              style: style,
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(text),
            )
          : ElevatedButton(
              style: style,
              onPressed: onPressed,
              child: Text(text),
            ),
    );
  }
}