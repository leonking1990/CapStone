import 'package:flutter/material.dart';

// Widget for displaying a label and value row within info cards
class PlantDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlightValue; // Flag to indicate if value needs highlighting (e.g., overdue)

  const PlantDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.highlightValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = highlightValue
        ? Theme.of(context).colorScheme.error // Use error color for highlight
        : Theme.of(context).textTheme.bodyLarge?.color; // Default color

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2, // Allow value text to wrap slightly
            ),
          ),
        ],
      ),
    );
  }
}