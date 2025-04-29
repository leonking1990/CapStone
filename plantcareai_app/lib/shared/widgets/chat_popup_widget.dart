import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plantcareai/core/services/gemini_api.dart';
import 'package:plantcareai/features/chat/models/chat_message.dart'; // Import the public ChatMessage model

class ChatPopupWidget extends StatefulWidget {
  final String? initialContext; // Accept initial context

  const ChatPopupWidget({super.key, this.initialContext});

  @override
  State<ChatPopupWidget> createState() => _ChatPopupWidgetState();
}

class _ChatPopupWidgetState extends State<ChatPopupWidget> {
  final TextEditingController _controller = TextEditingController();
  List<ChatMessage> _messages = []; // Use public ChatMessage
  final GeminiApi _geminiApi = GeminiApi();
  bool _isLoading = false;
  bool _historyLoading = true;
  String? _chatContext;
  StreamSubscription? _streamSubscription;
  final ScrollController _scrollController = ScrollController();
  String _streamingMessageId = '';
  static const String _historyKey = 'chatHistory';

  // --- Load Messages from SharedPreferences ---
  Future<void> _loadMessages() async {
     setState(() { _historyLoading = true; }); // Indicate history loading
     try {
        final prefs = await SharedPreferences.getInstance();
        final List<String>? savedMessagesJson = prefs.getStringList(_historyKey);

        if (savedMessagesJson != null) {
           final loadedMessages = savedMessagesJson
              .map((jsonString) => ChatMessage.fromJsonString(jsonString))
              .toList();
           // Insert loaded messages, maintaining reverse chronological order for UI
           _messages = loadedMessages.where((msg) => !msg.text.startsWith("[Error loading")).toList(); // Assign directly
        } else {
           // No saved history, add initial greeting if no context
           if (_chatContext == null || _chatContext!.isEmpty) {
              _messages.insert(0, ChatMessage(text: "Hi! How can I help?", isUser: false, id: 'greeting_msg'));
           }
        }
     } catch (e) {
         print("Error loading chat history: $e");
         // Handle error, maybe show a default greeting
         _messages = [ChatMessage(text: "Hi! Error loading history.", isUser: false, id: 'error_msg')];
     } finally {
        if (mounted) {
           setState(() { _historyLoading = false; });
           _scrollToBottom(); // Scroll after loading
        }
     }
  }

  // --- Save Messages to SharedPreferences ---
  Future<void> _saveMessages() async {
     try {
        final prefs = await SharedPreferences.getInstance();
        // Limit history size before saving (optional but recommended)
        const int maxSavedHistory = 50; // Save max 50 messages
        final messagesToSave = (_messages.length <= maxSavedHistory)
            ? _messages
            : _messages.sublist(0, maxSavedHistory); // Take newest messages

        final List<String> messagesJson = messagesToSave
            .map((msg) => msg.toJsonString()) // Convert each message to JSON string
            .toList();
        await prefs.setStringList(_historyKey, messagesJson);
     } catch (e) {
        print("Error saving chat history: $e");
        // Optionally notify user or log error
     }
  }

  Future<void> _clearChat() async {
     // Cancel any ongoing stream
     await _streamSubscription?.cancel();
     _isLoading = false; // Ensure loading indicator stops

     // Clear messages from SharedPreferences
     try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_historyKey);
        print("Chat history cleared from SharedPreferences.");
     } catch (e) {
        print("Error clearing chat history from SharedPreferences: $e");
     }

     // Clear messages from state and add default greeting
     setState(() {
       _messages.clear();
       // Add back greeting or context message if applicable
       if (_chatContext != null && _chatContext!.isNotEmpty) {
          // Maybe show context persistently? Or just a generic greeting after clear?
          // Let's stick to a generic greeting after clearing.
          _messages.insert(0, ChatMessage(text: "History cleared. How can I help?", isUser: false, id: 'cleared_msg'));
       } else {
          _messages.insert(0, ChatMessage(text: "Hi! How can I help?", isUser: false, id: 'greeting_msg'));
       }
     });
     _scrollToBottom(); // Scroll to top (which is bottom of reversed list)
  }

  @override
  void initState() {
    super.initState();
    _chatContext = widget.initialContext;
    _loadMessages();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    await _streamSubscription?.cancel();

    final userMessage = ChatMessage(text: text, isUser: true);
    _streamingMessageId = 'streaming_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _messages.insert(0, userMessage);
      _controller.clear();
      _isLoading = true;
      _messages.insert(
          0, ChatMessage(text: '', isUser: false, id: _streamingMessageId));
    });
    _scrollToBottom();
    await _saveMessages();

    const int historyLimit = 6;
    final historyToSend = _messages
        .skip(1)
        .take(historyLimit)
        .map((msg) => msg.toApiMap())
        .toList()
        .reversed
        .toList();

    try {
      final stream = _geminiApi.streamMessage(text,
          context: _chatContext, history: historyToSend);
      StringBuffer buffer = StringBuffer();

      _streamSubscription = stream.listen(
        (chunk) {
          if (mounted) {
            setState(() {
              final index =
                  _messages.indexWhere((msg) => msg.id == _streamingMessageId);
              if (index != -1) {
                buffer.write(chunk);
                _messages[index] =
                    _messages[index].copyWith(text: buffer.toString());
                _scrollToBottom();
              }
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              final index =
                  _messages.indexWhere((msg) => msg.id == _streamingMessageId);
              String errorText = "Error: ${error.toString()}";
              if (index != -1) {
                _messages[index] = _messages[index].copyWith(
                    text: buffer.isNotEmpty
                        ? buffer.toString() + "\n\n$errorText"
                        : errorText);
              } else {
                _messages.insert(
                    0, ChatMessage(text: errorText, isUser: false));
              }
              _isLoading = false;
              _scrollToBottom();
            });
             _saveMessages();
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              final index =
                  _messages.indexWhere((msg) => msg.id == _streamingMessageId);
              if (index != -1 && buffer.isEmpty) {
                _messages[index] =
                    _messages[index].copyWith(text: "[No response]");
              }
              _isLoading = false;
              _scrollToBottom();
            });
             _saveMessages();
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((msg) => msg.id == _streamingMessageId);
          _messages.insert(
              0,
              ChatMessage(
                  text: "Error starting chat: ${e.toString()}", isUser: false));
          _isLoading = false;
          _scrollToBottom();
        });
         _saveMessages();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _streamSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_historyLoading) {
       return const Center(child: CircularProgressIndicator());
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
          maxWidth: 350,
        ),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 1,
              )
            ]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  // Optional Title
                  child: Text(
                    "Plant AI",
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                  tooltip: "Clear Chat History",
                  // Disable while loading to prevent unexpected state
                  onPressed: _isLoading ? null : _clearChat,
                  // Reduce visual clutter
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            // Optional Divider
            // Divider(height: 1, thickness: 0.5),
             const SizedBox(height: 4), // Spacing after header
            Flexible(
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                shrinkWrap: true,
                padding: const EdgeInsets.all(4.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final ChatMessage msg = _messages[index];
                  final userMsgColor = theme.colorScheme.primaryContainer;
                  final botMsgColor = theme.colorScheme.secondaryContainer;
                  final userTextColor = theme.colorScheme.onPrimaryContainer;
                  final botTextColor = theme.colorScheme.onSecondaryContainer;
                  final errorTextColor = theme.colorScheme.error;
                  bool isErrorMessage =
                      msg.text.startsWith("Error:") && !msg.isUser;
                  bool isStreamingPlaceholder = msg.id == _streamingMessageId &&
                      _isLoading &&
                      msg.text.isEmpty;
                  String displayText = msg.text;
                  // if (isStreaming && msg.text.isEmpty) displayText = "Typing...";
                  // else if (isStreaming) displayText += '...';

                  Widget messageContent;
                  if (msg.isUser) {
                    // User messages remain as Text
                    messageContent = Text(
                      displayText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: userTextColor,
                      ),
                    );
                  } else if (isStreamingPlaceholder) {
                    // --- Use Loading Animation Widget ---
                    // Show animation while waiting for the first chunk
                    messageContent = LoadingAnimationWidget.staggeredDotsWave(
                      // Use a color that fits the bot message theme
                      color: botTextColor, // Or theme.colorScheme.primary, etc.
                      size: 30, // Adjust size as needed
                    );
                    // --- End Loading Animation ---
                  } else {
                    // Bot messages use MarkdownBody
                    messageContent = MarkdownBody(
                      data: displayText,
                      selectable: true, // Allow selecting text
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        // Customize styles based on theme
                        p: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                isErrorMessage ? errorTextColor : botTextColor),
                        // Add styling for other elements like lists, bold, etc. if needed
                        // Example: strong: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: botTextColor),
                        //          listBullet: theme.textTheme.bodyMedium?.copyWith(color: botTextColor),
                      ),
                      // Optional: Handle link taps
                      // onTapLink: (text, href, title) { /* Handle link tap */ },
                    );
                  }

                  const double avatarRadius = 15.0; // Size for the avatar
                  final Widget userAvatar = CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor:
                        theme.colorScheme.primary, // Match user bubble theme
                    child: Icon(Icons.person_outline,
                        size: avatarRadius * 1.2,
                        color: theme.colorScheme.onPrimary),
                  );
                  final Widget botAvatar = CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor:
                        theme.colorScheme.secondary, // Match bot bubble theme
                    child: Icon(Icons.auto_awesome,
                        size: avatarRadius * 1.2,
                        color: theme
                            .colorScheme.onSecondary), // Or Icons.support_agent
                  );

                  return Padding(
                    // Add padding around the entire row (avatar + bubble)
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      // Align avatar and bubble to start/end based on sender
                      mainAxisAlignment: msg.isUser
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment:
                          CrossAxisAlignment.end, // Align items to the bottom
                      children: [
                        // Show bot avatar on the left for bot messages
                        if (!msg.isUser) ...[
                          botAvatar,
                          const SizedBox(
                              width: 8), // Spacing between avatar and bubble
                        ],

                        // Bubble Container (Constrained Width)
                        Container(
                          // Add constraints to prevent bubble from becoming too wide
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width *
                                  0.75 // Max 75% of popup width
                              ),
                          padding:
                              EdgeInsets.all(isStreamingPlaceholder ? 12 : 8),
                          decoration: BoxDecoration(
                            color: isErrorMessage
                                ? theme.colorScheme.errorContainer
                                : (msg.isUser ? userMsgColor : botMsgColor),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: messageContent,
                        ),

                        // Show user avatar on the right for user messages
                        if (msg.isUser) ...[
                          const SizedBox(
                              width: 8), // Spacing between bubble and avatar
                          userAvatar,
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: const InputDecoration(
                          hintText: 'Ask plant care...',
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 8)),
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    onPressed: _isLoading ? null : _sendMessage,
                    tooltip: 'Send message',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
