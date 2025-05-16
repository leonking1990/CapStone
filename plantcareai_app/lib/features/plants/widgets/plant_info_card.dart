import 'package:flutter/material.dart';

// Reusable card structure for displaying sections of plant info
class PlantInfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children; // Allows passing custom widgets (like PlantDetailRow)

  const PlantInfoCard({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // Use theme card color
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05), // Use theme shadow
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleMedium?.color, // Use theme title color
            ),
          ),
          const Divider(height: 16),
          ...children, // Display the provided widgets
        ],
      ),
    );
  }
}