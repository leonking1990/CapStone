import 'dart:async';
import 'dart:convert'; // For jsonEncode/jsonDecode
import 'package:http/http.dart' as http; // For making HTTP requests
import 'package:flutter/foundation.dart'; // For kDebugMode and String.fromEnvironment

class GeminiApi {
  // --- API Key Handling (IMPORTANT) ---
  // Retrieve the API key from environment variables passed during build.
  // Use: flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY_HERE
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  // Base URL for the Gemini API endpoint
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash'; // Using Flash for potentially faster responses, adjust if needed

  /// Sends a message to the Gemini API and returns the text response.
  ///
  /// Throws an [Exception] if the API key is not configured,
  /// if the network request fails, or if the API returns an error.
  Future<String> sendMessage(String userMessage, {String? context}) async {
    // Check if the API key was provided during the build process
    if (_apiKey.isEmpty) {
      // Throw a specific error if the key is missing
      throw Exception(
          'Gemini API Key not configured. Use --dart-define=GEMINI_API_KEY=YOUR_KEY during build/run.');
    }

    // Construct the full API endpoint URL
    final Uri url = Uri.parse('$_baseUrl:generateContent?key=$_apiKey');

    String contextPreamble = '';
    if (context != null && context.isNotEmpty) {
      // Format the context nicely for the prompt
      contextPreamble = '''

Current user context within the app:
$context
''';
    }

    final String structuredPrompt = '''
You are PlantPal, the friendly and knowledgeable plant care assistant for the PlantCareAI app!
Your goal is to help users with plant identification, diagnosing problems, and providing **specific, actionable plant care advice** (watering, sunlight, soil, pests, etc.).
Speak in a **conversational, encouraging, and helpful tone**. Avoid overly robotic or technical language unless necessary for clarity.
**Actively use the 'Current user context'** provided below to make your answers less generic and more tailored to the user's specific situation or plant, especially when asked directly about it (e.g., "this plant").
Keep answers focused and reasonably concise, but **provide sufficient detail and clear steps** when giving advice.
If the user asks a question unrelated to plants, gardening, or using the PlantCareAI app, **politely explain you specialize in plant care and cannot answer**.
If a user's plant-related question is vague, **ask for clarifying details** before providing a comprehensive answer. Try to keep your answers concise (about 3 to 4 sentences) unless necessary for clarity the.
The plant has a nick name in to following $contextPreamble

User's question: "$userMessage"
''';

    if (kDebugMode) {
      print("Sending prompt to Gemini: $structuredPrompt");
    }

    try {
      // Make the POST request to the Gemini API
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": structuredPrompt}
              ]
            }
          ],
          // --- Optional: Safety Settings ---
          // Adjust thresholds to control content filtering (e.g., BLOCK_LOW_AND_ABOVE)
          "safetySettings": [
            {
              "category": "HARM_CATEGORY_HARASSMENT",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
              "category": "HARM_CATEGORY_HATE_SPEECH",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
              "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
              "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
          ],
          // --- Optional: Generation Configuration ---
          // "generationConfig": {
          //   "temperature": 0.7, // Controls randomness (0.0 = deterministic, 1.0 = max creative)
          //   "topK": 40,         // Consider top K most likely tokens
          //   "topP": 0.95,       // Consider tokens with cumulative probability >= 0.95
          //   "maxOutputTokens": 512, // Limit response length
          //   "stopSequences": [] // Sequences that stop generation
          // }
        }),
        // Add a timeout to prevent hanging indefinitely
        // timeout: const Duration(seconds: 30),
      );

      // --- Response Handling ---
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check for content and candidates safely
        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content']?['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          // Successfully received content
          final content = data['candidates'][0]['content']['parts'][0]['text'];
          if (kDebugMode) {
            print("Received from Gemini: $content");
          }
          return content.trim();
        }
        // Check if the prompt or response was blocked by safety settings
        else if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['finishReason'] == 'SAFETY') {
          final safetyRatings = data['candidates'][0]['safetyRatings'];
          String blockDetails = "due to safety guidelines.";
          if (safetyRatings != null && safetyRatings.isNotEmpty) {
            // Find the specific category that caused the block (if available)
            final blockedCategory = safetyRatings.firstWhere(
                (r) => r['probability'] != 'NEGLIGIBLE',
                orElse: () => null);
            if (blockedCategory != null) {
              blockDetails =
                  "due to safety guidelines regarding ${blockedCategory['category']}.";
            }
          }
          if (kDebugMode) print('❌ Gemini API content blocked: $blockDetails');
          return "I cannot provide a response $blockDetails";
        } else if (data['promptFeedback']?['blockReason'] != null) {
          // Handle cases where the *prompt* itself was blocked
          final reason = data['promptFeedback']['blockReason'];
          final safetyRatings = data['promptFeedback']?['safetyRatings'];
          String blockDetails = "due to safety guidelines ($reason).";
          if (safetyRatings != null && safetyRatings.isNotEmpty) {
            final blockedCategory = safetyRatings.firstWhere(
                (r) => r['probability'] != 'NEGLIGIBLE',
                orElse: () => null);
            if (blockedCategory != null) {
              blockDetails =
                  "due to safety guidelines ($reason) regarding ${blockedCategory['category']}.";
            }
          }
          if (kDebugMode) print('❌ Gemini API prompt blocked: $blockDetails');
          return "I cannot process that request $blockDetails";
        } else {
          // Handle cases where the response is 200 OK, but format is unexpected
          if (kDebugMode) {
            print(
                '❌ Gemini API unexpected 200 OK response format: ${response.body}');
          }
          throw Exception(
              'Received an unexpected response format from the assistant.');
        }
      } else {
        // Handle HTTP errors (e.g., 4xx, 5xx)
        String errorMessage =
            'Failed to connect to the assistant (Error ${response.statusCode}).';
        try {
          // Try to parse error details from the response body
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error']?['message'] ?? errorMessage;
        } catch (_) {
          // Ignore parsing errors, use the default message
        }
        if (kDebugMode) {
          print(
              '❌ Gemini API HTTP error ${response.statusCode}: ${response.body}');
        }
        throw Exception(errorMessage);
      }
    }
    // Catch network issues, timeouts, or other exceptions during the HTTP call
    on TimeoutException catch (e) {
      if (kDebugMode) print('❌ Gemini API request timed out: $e');
      throw Exception(
          'The request to the assistant timed out. Please try again.');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error calling Gemini API: $e');
      }
      // Throw a user-friendly exception for general errors
      throw Exception(
          'Could not reach the assistant. Please check your connection or try again later.');
    }
  }

  // --- streamMessage (NEW Streaming Version) ---
  Stream<String> streamMessage(String userMessage, {String? context, List<Map<String, String>>? history}) async* {
    // Use async* for streams
    if (_apiKey.isEmpty) {
      throw Exception('Gemini API Key not configured.');
    }

    // Use the :streamGenerateContent endpoint
    final Uri url = Uri.parse(
        '$_baseUrl:streamGenerateContent?key=$_apiKey&alt=sse'); // Add alt=sse for Server-Sent Events

    List<Map<String, dynamic>> contents = [];

    String contextPreamble = '';
    if (context != null && context.isNotEmpty) {
      contextPreamble = '\n\nCurrent user context:\n$context';
    }

   if (history != null && history.isNotEmpty) {
       for (var message in history) {
          // Ensure roles are 'user' or 'model' as expected by the API
          if (message['role'] == 'user' || message['role'] == 'model') {
             contents.add({
               "role": message['role'],
               "parts": [{"text": message['text']}]
             });
          }
       }
    }

     // Add the current user message
     // Prepend context/instructions to the latest user message if desired
     String finalUserMessage = contextPreamble + userMessage;
      contents.add({
        "role": "user",
        "parts": [{"text": finalUserMessage}]
      });

      if (kDebugMode) {
       print("Sending multi-turn content to Gemini: ${jsonEncode({"contents": contents})}");
    }

    final client = http.Client();
    try {
      final request = http.Request('POST', url);
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        "contents": contents,
        "safetySettings": [/* ... your safety settings ... */],
        // NOTE: generationConfig might behave differently with streaming, test carefully
      });

      final response = await client.send(request);

      if (response.statusCode == 200) {
        // Listen to the stream of Server-Sent Events (SSE)
        // Each event might contain a chunk of the response
        await for (final chunk in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (chunk.startsWith('data: ')) {
            final dataString = chunk.substring(6); // Remove 'data: ' prefix
            if (dataString.trim() == '[DONE]')
              break; // Check if stream is finished (though not standard SSE)

            try {
              final data = jsonDecode(dataString);
              // Extract text safely, checking structure
              if (data['candidates'] != null &&
                  data['candidates'].isNotEmpty &&
                  data['candidates'][0]['content']?['parts'] != null &&
                  data['candidates'][0]['content']['parts'].isNotEmpty) {
                final textChunk = data['candidates'][0]['content']['parts'][0]
                    ['text'] as String?;
                if (textChunk != null) {
                  yield textChunk; // Yield the text chunk to the stream listener
                }
              }
              // Handle potential safety blocks within the stream if necessary
              else if (data['candidates'] != null &&
                  data['candidates'].isNotEmpty &&
                  data['candidates'][0]['finishReason'] == 'SAFETY') {
                // Decide how to handle mid-stream safety blocks - maybe yield an error message?
                yield "\n\n[Content stopped due to safety guidelines]";
                break; // Stop processing further chunks
              } else if (data['promptFeedback']?['blockReason'] != null) {
                // Handle prompt blocks (should ideally happen before streaming starts, but check anyway)
                yield "\n\n[Request blocked due to safety guidelines: ${data['promptFeedback']['blockReason']}]";
                break;
              }
            } catch (e) {
              if (kDebugMode)
                print("Error parsing stream chunk: $dataString \nError: $e");
              // Decide how to handle parsing errors, maybe yield an error indicator?
              yield " [Error processing response chunk] ";
            }
          }
        }
      } else {
        // Handle initial HTTP error before streaming starts
        String errorMessage =
            'Failed to connect to the assistant stream (Error ${response.statusCode}).';
        try {
          // Attempt to read the error body (might not be standard SSE format)
          final errorBody = await response.stream.bytesToString();
          final errorData = jsonDecode(errorBody);
          errorMessage = errorData['error']?['message'] ?? errorMessage;
        } catch (_) {/* Ignore parsing error */}
        if (kDebugMode) print('❌ Gemini API HTTP error ${response.statusCode}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error calling Gemini stream API: $e');
      throw Exception(
          'Could not reach the assistant stream. Check connection.');
    } finally {
      client.close(); // Ensure the HTTP client is closed
    }
  }
}
