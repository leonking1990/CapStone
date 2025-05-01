import 'dart:async';
import 'package:flutter/material.dart';
// Update this import to reflect the new location of GeminiApi
import 'package:plantcareai/core/services/gemini_api.dart';

class ChatBoxScreen extends StatefulWidget {
  const ChatBoxScreen({super.key});

  @override
  State<ChatBoxScreen> createState() => _ChatBoxScreenState();
}

class _ChatBoxScreenState extends State<ChatBoxScreen> {
  final TextEditingController _controller = TextEditingController();
  // Messages list: Newest messages will be at index 0
  final List<_ChatMessage> _messages = [];
  final GeminiApi _geminiApi = GeminiApi(); // create an instance of GeminiApi
  bool _isLoading = false;
  String? _chatContext; // For optional context passing
  StreamSubscription? _streamSubscription;

  final String _streamingMessageId = 'streaming_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    // Initialize the chat with a welcome message
    _messages.insert(0, _ChatMessage(text: "Hello! How can I help you with PlantCareAI?", isUser: false));
  }


  // Example of how to receive context if passed via arguments
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_chatContext == null) {
       final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
       setState(() { // Use setState if you want to potentially display the context
         _chatContext = args?['context'] as String?;
         //  Add context as a message for debugging/visibility
         // if (_chatContext != null && _messages.isEmpty) {
         //   _messages.insert(0, _ChatMessage(text: "Context: $_chatContext", isUser: false));
         // }
       });
    }
  }


  void _sendMessage() async {
    final text = _controller.text.trim();
    // Prevent sending empty messages or sending while already loading
    if (text.isEmpty || _isLoading) return;

    await _streamSubscription?.cancel();

    // Add user message immediately and set loading state
    final userMessage = _ChatMessage(text: text, isUser: true);
    setState(() {
      // Insert new message at the beginning for the reversed list
      _messages.insert(0, userMessage);
      _controller.clear();
      _isLoading = true;

      _messages.insert(0, _ChatMessage(text: '', isUser: false, id: _streamingMessageId));
    });

    const int historyLimit = 10;
    final historyToSend = _messages
        .skip(1) // Skip the bot placeholder we just added
        .take(historyLimit) // Take the last N messages (including the latest user one)
        .map((msg) => msg.toApiMap()) // Convert to Map format
        .toList()
        .reversed // Reverse to maintain chronological order (oldest first)
        .toList();
    try {
      final stream = _geminiApi.streamMessage(text, context: _chatContext, history: historyToSend);
      StringBuffer buffer = StringBuffer();
      
      _streamSubscription = stream.listen(
        (chunk) {
          // --- Update Existing Bot Message ---
          if (mounted) {
            setState(() {
               // Find the streaming message by ID and append the chunk
               final index = _messages.indexWhere((msg) => msg.id == _streamingMessageId);
               if (index != -1) {
                  buffer.write(chunk); // Add chunk to buffer
                 // Update the text of the existing message object
                 _messages[index] = _messages[index].copyWith(text: buffer.toString());
               }
               // Note to future Stevie: This section is to rebuilds the list view on every chunk.
               // For very rapid streams, performance optimization might be needed
               // (e.g., updating only the specific Text widget state).
            });
          }
          // --- End Update ---
        },
        onError: (error) {
          // --- Handle Stream Error ---
          if (mounted) {
            setState(() {
              final index = _messages.indexWhere((msg) => msg.id == _streamingMessageId);
              String errorText = "Error: ${error.toString()}";
               if (index != -1) {
                 // Append or replace the text with the error
                  _messages[index] = _messages[index].copyWith(text: buffer.isNotEmpty ? buffer.toString() + "\n\n$errorText" : errorText);
               } else {
                  // If placeholder somehow got removed, add error as new message
                  _messages.insert(0, _ChatMessage(text: errorText, isUser: false));
               }
              _isLoading = false; // Stop loading on error
            });
          }
          // --- End Handle Error ---
        },
        onDone: () {
          // --- Handle Stream Completion ---
          if (mounted) {
            setState(() {
              // Find the message and ensure its text is finalized from the buffer
               final index = _messages.indexWhere((msg) => msg.id == _streamingMessageId);
               if (index != -1) {
                  // Check if the message is still empty (e.g., API returned nothing)
                   if(buffer.isEmpty) {
                     _messages[index] = _messages[index].copyWith(text: "[No response received]");
                   } else {
                     _messages[index] = _messages[index].copyWith(text: buffer.toString());
                   }
               }
              _isLoading = false; // Stop loading when stream is done
            });
          }
          // --- End Handle Completion ---
        },
        cancelOnError: true, // Automatically cancel subscription on error
      );
    } catch (e) {
      // Display the error message directly in the chat
       if (mounted) {
        setState(() {
           // Remove the placeholder if stream couldn't even start
           _messages.removeWhere((msg) => msg.id == _streamingMessageId);
           // Add an error message
           _messages.insert(0, _ChatMessage(text: "Error starting chat: ${e.toString()}", isUser: false));
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = _chatContext != null ? 'Plant AI (Context Aware)' : 'Plant AI Assistant';
    return Scaffold(
      appBar: AppBar(
        // Consider using theme colors here too
        title: Text(appBarTitle),
         leading: IconButton(
           icon: Icon(Icons.arrow_back, color: Theme.of(context).appBarTheme.iconTheme?.color),
           onPressed: () => Navigator.pop(context),
         ),
         backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Chat messages area
          Expanded(
            child: ListView.builder(
              reverse: true, // Shows latest messages at the bottom
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                // Access message directly because we insert at index 0
                final msg = _messages[index];

                // Determine colors based on theme
                final userMsgColor = Theme.of(context).colorScheme.primaryContainer;
                final botMsgColor = Theme.of(context).colorScheme.secondaryContainer;
                final userTextColor = Theme.of(context).colorScheme.onPrimaryContainer;
                final botTextColor = Theme.of(context).colorScheme.onSecondaryContainer;
                final errorTextColor = Theme.of(context).colorScheme.error;

                 // Check if the message is an error message to style differently
                bool isErrorMessage = msg.text.startsWith("Error:") && !msg.isUser;

                // commented out for now, but can be used for streaming messages
                // bool isStreaming = msg.id == _streamingMessageId && _isLoading;
                //  String displayText = msg.text;
                //  if (isStreaming && msg.text.isEmpty) {
                //    displayText = "Typing..."; // Placeholder while waiting for first chunk
                //  } else if (isStreaming) {
                //     displayText += '...'; // Add ellipsis while streaming
                //  }

                return Align(
                  // Align user messages to the right, bot messages to the left
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      // Use theme colors, or error color for bot errors
                      color: isErrorMessage
                          ? Theme.of(context).colorScheme.errorContainer // Specific color for errors
                          : (msg.isUser ? userMsgColor : botMsgColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        // Use theme text colors, or error color
                        color: isErrorMessage
                            ? errorTextColor
                            : (msg.isUser ? userTextColor : botTextColor),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),

          // Input area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    // Apply theming to TextField as well if needed via InputDecorationTheme
                    decoration: const InputDecoration(
                      hintText: 'Ask about plant care...', // Updated hint text
                      // border: OutlineInputBorder(...),
                    ),
                    // Send message when user presses Enter/Done
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                // Send button
                IconButton(
                  icon: Icon(
                    Icons.send,
                    // Use theme color for icon
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  // Disable button while loading
                  onPressed: _isLoading ? null : _sendMessage,
                  tooltip: 'Send message',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Simple class to hold message data
class _ChatMessage {
  final String id; // Unique identifier, useful for streaming updates
  final String text;
  final bool isUser;

  _ChatMessage({
    required this.text,
    required this.isUser,
    String? id, // Make ID optional
  }) : id = id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}_${text.hashCode}'; // Generate default ID

   // Add copyWith method for easier updates during streaming
   _ChatMessage copyWith({String? text}) {
     return _ChatMessage(
       id: id, // Keep the original ID
       text: text ?? this.text,
       isUser: isUser,
     );
   }
   Map<String, String> toApiMap() {
     return {
       'role': isUser ? 'user' : 'model',
       'text': text,
     };
  }
}