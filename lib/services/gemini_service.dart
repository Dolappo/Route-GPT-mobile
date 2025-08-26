import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

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

  Future<String?> formatResponse(
      Map<String, dynamic> mapsData, String originalQuery) async {
    print("Formatting response with enhanced data");
    try {
      final prompt = '''
Format this route data naturally: $mapsData
Query: $originalQuery

Instructions:
- Conversational tone, no formatting
- Include distance, duration, traffic (if driving)
- Add landmarks when available
- Number steps naturally
- Focus on first 3 steps for speed
- Remove all bullets/special chars

Format: "Route by [mode]: [distance] in [duration]. [traffic info if driving] [numbered steps with landmarks]"
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text
          ?.replaceAll('*', '')
          .replaceAll('-', '')
          .replaceAll('•', '');
    } catch (e) {
      return 'Sorry, I had trouble formatting the response. Error: $e';
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
}
