import 'dart:convert';


class ChatMessage {
  final String id; // Unique identifier, useful for streaming updates
  final String text;
  final bool isUser; // True if the message is from the user, false if from the bot

  ChatMessage({
    required this.text,
    required this.isUser,
    String? id, // Make ID optional
    // Generate default ID using timestamp and hashcode for uniqueness within session
  }) : id = id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}_${text.hashCode}';

   // Add copyWith method for easier updates during streaming
   ChatMessage copyWith({String? text}) {
     return ChatMessage(
       id: id, // Keep the original ID
       text: text ?? this.text,
       isUser: isUser,
     );
   }

  // Add a method to convert to the map format needed by GeminiApi
  Map<String, String> toApiMap() {
     return {
       'role': isUser ? 'user' : 'model',
       'text': text,
     };
  }

  // Convert ChatMessage object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      // Note: We aren't storing timestamps here, but you could add one if needed
    };
  }

  // Create a ChatMessage object from a JSON map
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? 'fallback_id_${DateTime.now().millisecondsSinceEpoch}', // Provide fallback ID
      text: json['text'] as String? ?? '', // Provide fallback text
      isUser: json['isUser'] as bool? ?? false, // Provide fallback role
    );
  }

  // Helper to encode to JSON string (optional but convenient)
  String toJsonString() => jsonEncode(toJson());

  // Helper to decode from JSON string (optional but convenient)
  factory ChatMessage.fromJsonString(String jsonString) {
     try {
       final map = jsonDecode(jsonString) as Map<String, dynamic>;
       return ChatMessage.fromJson(map);
     } catch (e) {
       // Print the problematic string and the error
       print("Error decoding ChatMessage from string: $e");
       print("Problematic JSON string: $jsonString");
       // Return a specific error message that might indicate loading failure
       return ChatMessage(text: "[Error loading message data]", isUser: false, id: 'error_load_${DateTime.now().millisecondsSinceEpoch}');
     }
  }
}