import 'package:flutter/material.dart';
import 'package:plantcareai/features/chat/pages/chat_box_screen.dart';

class BaseScaffold extends StatelessWidget {
  final Widget body;
  final String title; // Or AppBar widget itself
  final Widget? leading; // Optional leading widget for AppBar

  const BaseScaffold({
      super.key,
      required this.body,
      required this.title,
      this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title), // Customize as needed
        leading: leading,
        // ... other AppBar properties ...
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurpleAccent, // Use Theme color later
        child: const Icon(Icons.chat_bubble_outline),
        tooltip: 'Chat Assistant',
        onPressed: () {
          Navigator.pushNamed(context, '/chat'); // Use named route
        },
      ),
    );
  }
}