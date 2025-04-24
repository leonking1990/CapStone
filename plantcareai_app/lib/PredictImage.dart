import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

Future<Map<String, dynamic>?> predictImage(File imageFile) async {
  try {
    // Define the server URL
    final uri = Uri.parse('http://35.239.234.106:8000/predict');

    // Create a multipart request
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
    ));

    // Send the request with a timeout
    var streamedResponse = await request.send().timeout(const Duration(seconds: 15));
    var response = await http.Response.fromStream(streamedResponse);

    // Check response status
    if (response.statusCode == 200) {
      //print('Raw Response Body: ${response.body}');
      
      // First decode to get the actual JSON string inside
      final decodedString = json.decode(response.body);

      // Then decode the JSON string to a Map
      final jsonResponse = json.decode(decodedString);

      if (jsonResponse is Map<String, dynamic>) {
        if (kDebugMode) {
          print('Full Response: $jsonResponse');
        }
        return jsonResponse;  // ✅ Return the parsed JSON directly
      } else {
        if (kDebugMode) {
          print('Unexpected response format: ${jsonResponse.runtimeType}');
        }
        return null;
      }
    } else {
      if (kDebugMode) {
        print('Server error: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
      return null;  // ✅ Return null if there's a server error
    }
  } on SocketException catch (e) {
    if (kDebugMode) {
      print('Network Error: $e');
    }
    return null;  // ✅ Return null if there’s a network error
  } on FormatException catch (e) {
    if (kDebugMode) {
      print('Invalid JSON Format: $e');
    }
    return null;  // ✅ Return null if there’s invalid JSON
  } on TimeoutException catch (e) {
    if (kDebugMode) {
      print('Request Timed Out: $e');
    }
    return null;  // ✅ Return null if the request times out
  } catch (e) {
    if (kDebugMode) {
      print('Unexpected Error: $e');
    }
    return null;  // ✅ Return null for any other error
  }
}
