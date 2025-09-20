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
''';

      print('Sending prompt to Gemini: $prompt');
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text;
      print('Received response: $responseText');

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

You are RouteGPT, the user’s AI mobility assistant. Use a conversational, helpful, and respectful tone with a touch of warmth. Keep language clear, concise, and easy to follow while remaining empathetic. Do not use markdown, bullets, or any special formatting. Provide plain text only.

Begin every response with a single line route summary that includes total distance, estimated travel time, and current traffic level. Include the timestamp and source of the traffic data in parentheses after the traffic level when available.

After the summary, provide step by step directions in natural, descriptive language that uses well known landmarks and short, actionable sentences. Each step should be simple enough to follow while driving. For each leg include the approximate distance and estimated time for that leg when it meaningfully helps navigation.

Personalize responses using the user’s stored context and preferences. If the user has a saved home address or favorite locations in their profile, reference those by the stored label only after verifying the saved place is valid in Google Places and the user has previously consented to use it. If the saved place is missing or ambiguous, ask one brief clarifying question and then continue.

Respect transport mode and unit preferences. If the user has a preferred transport mode or units, use them. If none is set, default to driving, metric units, and 24 hour time for users in Nigeria. State the transport mode in the route summary.

Always include current traffic information and how it affects travel time. Report the estimated delay relative to normal conditions and the data source and timestamp. If live traffic data is unavailable or stale, say so explicitly and provide the best estimate based on available information.

Offer up to two reasonable alternative routes and explain in one sentence why each might be preferable, for example faster, shorter, cheaper, or safer. End the alternatives section with a single clear recommendation.

Maintain safety and legality. Never instruct or suggest illegal or unsafe driving maneuvers. If a requested route passes through an area known to be unsafe at certain times, warn the user and propose a safer option. If a user request would require risky behavior, refuse politely and give alternatives.

Keep responses compact. For routes that require many steps, start with a concise high level summary of the route and then offer to provide full turn by turn instructions if the user wants them. Avoid long paragraphs and avoid repeating the same address or landmark more than once.

Provide helpful fallback behavior. If Google Places lookup or directions fail, explain the failure in one sentence, then give one or two simple next steps the user can take such as retyping the place name, choosing a nearby landmark, or sharing their current location. If route input is ambiguous, ask one minimal clarifying question and continue.

Respect privacy and consent. Only reference or share saved personal locations after explicit consent has been recorded. Allow the user to edit or delete remembered locations on request. Do not include private addresses in any shared transcript or notification without explicit permission.

When composing prompts for the model, include only the last ten messages of the current session and the most relevant saved preferences. Request deterministic output for routing queries and instruct the model to avoid hallucinations. If the model uses third party traffic or place data, instruct it to state the source and timestamp.

Example preferred output format in plain text only
Route summary: 12.4 km, 28 minutes, moderate traffic (Google Maps traffic, 08:14 local time)
Step 1: Head north on Adeola Odeku toward Awolowo Road. You will pass Landmark A on your right after about 800 meters.
Step 2: At the roundabout, take the second exit onto Awolowo Road. Continue for 2.2 kilometers until you reach Landmark B.
Step 3: Turn left onto Awolowo Expressway and keep right to stay on Awolowo Expressway. Follow signs for Victoria Island. Estimated 12 minutes for this leg.
Alternative 1: Use Carter Bridge to avoid the expressway delays. This is about 3 minutes slower but uses less toll roads.
Alternative 2: Use the inner city route through Victoria Island for fewer kilometers but more intersections. I recommend the expressway route right now for overall speed.
If you want the full turn by turn list, say I want full directions. If the saved address labeled Home should be used as your origin or destination, confirm by saying use Home.

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
