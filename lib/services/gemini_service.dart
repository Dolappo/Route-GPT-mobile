import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    print('API Key length: ${apiKey.length}');
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );
  }

  Future<Map<String, dynamic>> extractLocationInfo(String userQuery) async {
    print('Processing query: $userQuery');
    try {
      final prompt = '''
Extract location info from: "$userQuery"
Return JSON only:
{
  "origin": "location or current_location",
  "destination": "location", 
  "queryType": "directions|duration|traffic|route_summary",
  "travelMode": "DRIVE|WALK|BICYCLE|TRANSIT",
  "needsCurrentLocation": true/false
}

Rules:
- If user asks for directions from their current location, set origin to "current_location"
- If user asks for directions between two specific places, set both origin and destination
- If user asks for distance/time between places, set both origin and destination
- If user asks for nearest places, set needsCurrentLocation to true
- Always set travelMode to a valid value (DRIVE, WALK, BICYCLE, TRANSIT)
''';

      print('Sending prompt to Gemini: $prompt');
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text;
      print('Received response: $responseText');

      // Parse the response as a Map
      final cleanedResponse =
          responseText?.replaceAll('```json', '').replaceAll('```', '').trim();
      print("Cleaned response: $cleanedResponse");
      if (cleanedResponse != null) {
        print("Cleaned response true");
        try {
          final Map<String, dynamic> parsedInfo = json.decode(cleanedResponse);
          return parsedInfo;
        } catch (e) {
          print('Error parsing JSON response: $e');
          return {'raw_response': cleanedResponse};
        }
      }
      return {'raw_response': responseText};
    } catch (e) {
      print('Error in extractLocationInfo: $e');
      return {
        'error': 'Failed to process query: $e',
      };
    }
  }

  /// Extract location info with conversation context for better understanding
  Future<Map<String, dynamic>> extractLocationInfoWithContext(
      String userQuery, List<Map<String, dynamic>> conversationHistory) async {
    print('Processing query with context: $userQuery');
    try {
      // Build context from conversation history
      String contextPrompt = '';
      if (conversationHistory.isNotEmpty) {
        contextPrompt = '\n\nConversation context:\n';
        for (final msg in conversationHistory.take(5)) {
          // Last 5 messages for context
          final role = msg['role'] as String? ?? '';
          final parts = msg['parts'] as List<dynamic>? ?? [];
          if (parts.isNotEmpty) {
            final text = parts.first['text'] as String? ?? '';
            contextPrompt += '$role: $text\n';
          }
        }
      }

      final prompt = '''
Extract location info from: "$userQuery"$contextPrompt

Consider the conversation context when interpreting the query. For example:
- If user says "there" or "that place", refer to previous messages
- If user mentions "same route" or "continue", use previous origin/destination
- If user asks for "alternatives", they likely want different routes to the same destination

Return JSON only:
{
  "origin": "location or current_location",
  "destination": "location", 
  "queryType": "directions|duration|traffic|route_summary",
  "travelMode": "DRIVE|WALK|BICYCLE|TRANSIT",
  "needsCurrentLocation": true/false
}

Rules:
- If user asks for directions from their current location, set origin to "current_location"
- If user asks for directions between two specific places, set both origin and destination
- If user asks for distance/time between places, set both origin and destination
- If user asks for nearest places, set needsCurrentLocation to true
- Always set travelMode to a valid value (DRIVE, WALK, BICYCLE, TRANSIT)
- Never set travelMode to "null" - use "DRIVE" as default
''';

      print('Sending contextual prompt to Gemini: $prompt');
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text;
      print('Received contextual response: $responseText');

      // Parse the response as a Map
      final cleanedResponse =
          responseText?.replaceAll('```json', '').replaceAll('```', '').trim();
      if (cleanedResponse != null) {
        try {
          final Map<String, dynamic> parsedInfo = json.decode(cleanedResponse);
          return parsedInfo;
        } catch (e) {
          print('Error parsing JSON response: $e');
          return {'raw_response': cleanedResponse};
        }
      }
      return {'raw_response': responseText};
    } catch (e) {
      print('Error in extractLocationInfoWithContext: $e');
      return {
        'error': 'Failed to process query with context: $e',
      };
    }
  }

  Future<String?> formatResponse(
      Map<String, dynamic> data, String userQuery) async {
    return await formatResponseWithContext(data, userQuery, []);
  }

  /// Format response with conversation context for better personalization
  Future<String?> formatResponseWithContext(Map<String, dynamic> data,
      String userQuery, List<Map<String, dynamic>> conversationHistory) async {
    try {
      final directions = data['directions'] as List<dynamic>? ?? [];
      final routeSummary = data['routeSummary'] as Map<String, dynamic>? ?? {};
      final todayChatHistory = data['todayChatHistory'] as List<dynamic>? ?? [];
      final userMemory = data['userMemory'] as Map<String, dynamic>? ?? {};
      final userProfile = data['userProfile'] as Map<String, dynamic>? ?? {};

      String contextPrompt = '';

      // Add conversation history context (from Firestore short-term memory)
      if (conversationHistory.isNotEmpty) {
        contextPrompt += '\n\nRecent conversation context:\n';
        for (final msg in conversationHistory.take(5)) {
          final role = msg['role'] as String? ?? '';
          final parts = msg['parts'] as List<dynamic>? ?? [];
          if (parts.isNotEmpty) {
            final text = parts.first['text'] as String? ?? '';
            contextPrompt += '$role: $text\n';
          }
        }
      }

      // Add specific context for places queries
      if (data.containsKey('places') && data['places'] is List) {
        final places = data['places'] as List<dynamic>;
        final isNearby = data['is_nearby_search'] as bool? ?? false;
        final isAreaSearch = data['is_area_search'] as bool? ?? false;
  final area = data['area'] as String? ?? '';

        if (places.isNotEmpty) {
          contextPrompt += '\n\nPlaces found:\n';
          for (int i = 0; i < places.length; i++) {
            final place = places[i] as Map<String, dynamic>;
            final name = place['name'] as String? ?? 'Unknown';
            final address = place['address'] as String? ?? '';
            final rating = place['rating'] as String? ?? '';
            final userRatingCount = place['userRatingCount'] as String? ?? '';

            contextPrompt += '${i + 1}. $name';
            if (address.isNotEmpty) contextPrompt += ' - $address';
            if (rating.isNotEmpty) contextPrompt += ' (Rating: $rating';
            if (userRatingCount.isNotEmpty)
              contextPrompt += ' from $userRatingCount reviews';
            if (rating.isNotEmpty) contextPrompt += ')';
            contextPrompt += '\n';
          }

          // Add context about search type
          if (isNearby) {
            contextPrompt +=
                '\nThese are the nearest places to your current location.\n';
          } else if (isAreaSearch && area.isNotEmpty) {
            contextPrompt += '\nThese places are in or near $area.\n';
          }
        }
      }

      // Add specific context for distance queries
      if (data.containsKey('distance_data')) {
        final distanceData = data['distance_data'] as Map<String, dynamic>?;
        if (distanceData != null) {
          contextPrompt += '\n\nDistance information:\n';
          contextPrompt +=
              'Distance: ${distanceData['distance'] ?? 'Unknown'}\n';
          contextPrompt +=
              'Duration: ${distanceData['duration'] ?? 'Unknown'}\n';
          if (distanceData['durationInTraffic'] != null) {
            contextPrompt +=
                'Duration with traffic: ${distanceData['durationInTraffic']}\n';
          }
          contextPrompt += 'From: ${distanceData['origin'] ?? 'Unknown'}\n';
          contextPrompt += 'To: ${distanceData['destination'] ?? 'Unknown'}\n';
        }
      }

      // Add today's chat history context (legacy from Hive)
      if (todayChatHistory.isNotEmpty) {
        contextPrompt += '\n\nToday\'s conversation context:\n';
        for (final msg in todayChatHistory.take(5)) {
          // Last 5 messages for context
          final role = msg['role'] as String? ?? '';
          final content = msg['content'] as String? ?? '';
          contextPrompt += '$role: $content\n';
        }
      }

      // Add user memory/context
      if (userMemory.isNotEmpty) {
        contextPrompt += '\nUser preferences and context:\n';
        userMemory.forEach((key, value) {
          if (key != 'lastInteractionTime') {
            contextPrompt += '- $key: $value\n';
          }
        });
      }

      // Add user profile for personalization
      if (userProfile.isNotEmpty) {
        contextPrompt += '\nUser profile:\n';
        if (userProfile['homeAddress'] != null) {
          contextPrompt += '- Home: ${userProfile['homeAddress']}\n';
        }
        if (userProfile['favoriteLocations'] != null) {
          final locations =
              userProfile['favoriteLocations'] as List<dynamic>? ?? [];
          if (locations.isNotEmpty) {
            contextPrompt += '- Favorite places: ${locations.join(', ')}\n';
          }
        }
      }

      final prompt = '''
You are a helpful navigation assistant. Provide natural, descriptive directions and route information.

$contextPrompt

Current request: $userQuery

Route information:
${_formatDirectionsData(directions, routeSummary)}

You are RouteGPT, a helpful navigation and location assistant.
Always respond in plain conversational text only, no markdown, no bullet points, and no special formatting.

For navigation requests:

Begin with a friendly route summary that includes distance, estimated travel time, and current traffic conditions.

Provide step-by-step directions in natural, descriptive language with landmarks, making it easy to follow as if you were guiding a friend.

If there are alternative routes, describe them conversationally, explaining the pros and cons.

End with a gentle recommendation on which route is best given current conditions.

For cost estimates:

Compare ride-hailing, public transport, and driving in clear, everyday language.

Always mention the reasoning, like distance, fuel cost, or average fares.

For fuel tracking:

Estimate fuel consumption and cost in simple, relatable terms.

Mention assumptions like fuel price or vehicle efficiency in a natural way.

For event-aware navigation:

If there are events affecting traffic, mention them as if giving a heads-up.

Suggest alternative routes conversationally if needed.

For general location questions:

If asked about nearby places, use Google Places data and answer naturally: "There are two pharmacies nearby, one on XYZ Street and another inside ABC Mall."

For area-specific searches (like "hospital in Mushin"), use phrases like "I found X places in [area]" or "Here are the places in [area]": "I found three hospitals in Mushin: ABC Hospital on Main Street, XYZ Clinic near the market, and DEF Medical Center on Lagos Road."

For distance and time questions, return the answer as a clear, friendly statement.

If no data is available, say so politely and helpfully.

General style:

Always sound like a friendly local guide who knows the city.

Keep responses helpful, clear, and easy to understand.

Never display raw data, coordinates, or JSON. Only natural text.
Response:''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.replaceAll('*', '').replaceAll('•', '');
    } catch (e) {
      print('Error formatting response: $e');
      return null;
    }
  }

  Future<String?> formatRouteSummary(
      Map<String, dynamic> routeData, String originalQuery) async {
    print("Formatting route summary");
    try {
      final prompt = '''
Create brief route summary: $routeData
Query: $originalQuery

Focus on: distance, duration, traffic (if driving), travel mode
No formatting, plain text only.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text
          ?.replaceAll('*', '')
          .replaceAll('-', '')
          .replaceAll('•', '');
    } catch (e) {
      return 'Sorry, I had trouble creating the summary. Error: $e';
    }
  }

  String _formatDirectionsData(
      List<dynamic> directions, Map<String, dynamic> routeSummary) {
    String formatted = '';

    // Add route summary
    if (routeSummary.isNotEmpty) {
      formatted += 'Route Summary:\n';
      if (routeSummary['distance'] != null) {
        formatted += '- Distance: ${routeSummary['distance']}\n';
      }
      if (routeSummary['duration'] != null) {
        formatted += '- Duration: ${routeSummary['duration']}\n';
      }
      if (routeSummary['trafficDelay'] != null) {
        formatted += '- Traffic Delay: ${routeSummary['trafficDelay']}\n';
      }
      formatted += '\n';
    }

    // Add step-by-step directions
    if (directions.isNotEmpty) {
      formatted += 'Directions:\n';
      for (int i = 0; i < directions.length && i < 10; i++) {
        final step = directions[i] as Map<String, dynamic>? ?? {};
        final instruction = step['instruction'] ?? '';
        final distance = step['distance'] ?? '';
        final duration = step['duration'] ?? '';
        final landmarks = step['landmarks'] as List<dynamic>? ?? [];

        formatted += '${i + 1}. $instruction';
        if (distance.isNotEmpty) formatted += ' ($distance)';
        if (duration.isNotEmpty) formatted += ' - $duration';
        if (landmarks.isNotEmpty) {
          formatted += ' - Landmarks: ${landmarks.join(', ')}';
        }
        formatted += '\n';
      }
    }

    return formatted;
  }
}
