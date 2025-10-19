import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service for handling location-based queries using Google Places API
class PlacesService {
  final String _apiKey;

  PlacesService() : _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  /// Search for places by text query
  Future<List<Map<String, dynamic>>> searchPlaces(String query, {int maxResults = 3}) async {
    try {
      final url = Uri.parse('https://places.googleapis.com/v1/places:searchText');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'places.formattedAddress,places.displayName,places.location,places.types,places.rating,places.userRatingCount',
        },
        body: json.encode({
          'textQuery': query,
          'maxResultCount': maxResults,
        }),
      );

      final data = json.decode(response.body);
      
      if (data['places'] != null && data['places'].isNotEmpty) {
        final places = data['places'] as List;
        return places.map((place) => {
          'name': place['displayName']?['text'] ?? '',
          'address': place['formattedAddress'] ?? '',
          'latitude': place['location']?['latitude']?.toString() ?? '',
          'longitude': place['location']?['longitude']?.toString() ?? '',
          'coordinates': '${place['location']?['latitude']},${place['location']?['longitude']}',
          'types': place['types'] ?? [],
          'rating': place['rating']?.toString() ?? '',
          'userRatingCount': place['userRatingCount']?.toString() ?? '',
        }).toList();
      }
      
      return [];
    } catch (e) {
      print('Error searching places: $e');
      return [];
    }
  }

  /// Find nearest places of a specific type
  Future<List<Map<String, dynamic>>> findNearestPlaces(
    double latitude, 
    double longitude, 
    String placeType, 
    {int maxResults = 3}
  ) async {
    try {
      final url = Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'places.formattedAddress,places.displayName,places.location,places.types,places.rating,places.userRatingCount',
        },
        body: json.encode({
          'locationRestriction': {
            'circle': {
              'center': {
                'latitude': latitude,
                'longitude': longitude,
              },
              'radius': 5000.0, // 5km radius
            }
          },
          'includedTypes': [placeType],
          'maxResultCount': maxResults,
        }),
      );

      final data = json.decode(response.body);
      
      if (data['places'] != null && data['places'].isNotEmpty) {
        final places = data['places'] as List;
        return places.map((place) => {
          'name': place['displayName']?['text'] ?? '',
          'address': place['formattedAddress'] ?? '',
          'latitude': place['location']?['latitude']?.toString() ?? '',
          'longitude': place['location']?['longitude']?.toString() ?? '',
          'coordinates': '${place['location']?['latitude']},${place['location']?['longitude']}',
          'types': place['types'] ?? [],
          'rating': place['rating']?.toString() ?? '',
          'userRatingCount': place['userRatingCount']?.toString() ?? '',
        }).toList();
      }
      
      return [];
    } catch (e) {
      print('Error finding nearest places: $e');
      return [];
    }
  }

  /// Get place details by place ID
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse('https://places.googleapis.com/v1/places/$placeId');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'formattedAddress,displayName,location,types,rating,userRatingCount,websiteUri,formattedPhoneNumber,openingHours',
        },
      );

      final data = json.decode(response.body);
      
      if (data != null) {
        return {
          'name': data['displayName']?['text'] ?? '',
          'address': data['formattedAddress'] ?? '',
          'latitude': data['location']?['latitude']?.toString() ?? '',
          'longitude': data['location']?['longitude']?.toString() ?? '',
          'coordinates': '${data['location']?['latitude']},${data['location']?['longitude']}',
          'types': data['types'] ?? [],
          'rating': data['rating']?.toString() ?? '',
          'userRatingCount': data['userRatingCount']?.toString() ?? '',
          'website': data['websiteUri'] ?? '',
          'phone': data['formattedPhoneNumber'] ?? '',
          'openingHours': data['openingHours'] ?? {},
        };
      }
      
      return null;
    } catch (e) {
      print('Error getting place details: $e');
      return null;
    }
  }

  /// Search for places by category (hospital, restaurant, etc.)
  Future<List<Map<String, dynamic>>> searchByCategory(
    String category, 
    double? latitude, 
    double? longitude, 
    {int maxResults = 3}
  ) async {
    if (latitude != null && longitude != null) {
      return await findNearestPlaces(latitude, longitude, category, maxResults: maxResults);
    } else {
      return await searchPlaces(category, maxResults: maxResults);
    }
  }

  /// Search for places in a specific area (e.g., "hospital in Mushin")
  Future<List<Map<String, dynamic>>> searchPlacesInArea(
    String query, 
    String area, 
    {int maxResults = 3}
  ) async {
    try {
      // First, search for the area to get coordinates
      final areaResults = await searchPlaces(area, maxResults: 1);
      if (areaResults.isEmpty) {
        // If area not found, try general search
        return await searchPlaces('$query $area', maxResults: maxResults);
      }

      final areaLocation = areaResults.first;
      final latitude = double.tryParse(areaLocation['latitude'] ?? '');
      final longitude = double.tryParse(areaLocation['longitude'] ?? '');

      if (latitude != null && longitude != null) {
        // Extract place type from query
        final placeType = extractPlaceTypeFromQuery(query);
        if (placeType.isNotEmpty) {
          return await findNearestPlaces(latitude, longitude, placeType, maxResults: maxResults);
        } else {
          // If no specific type, search for the query in that area
          return await searchPlaces('$query near $area', maxResults: maxResults);
        }
      } else {
        // Fallback to general search
        return await searchPlaces('$query $area', maxResults: maxResults);
      }
    } catch (e) {
      print('Error searching places in area: $e');
      return [];
    }
  }

  /// Extract place type from query (hospital, restaurant, etc.)
  String extractPlaceTypeFromQuery(String query) {
    final lowerQuery = query.toLowerCase();
    
    // Common place types
    final placeTypes = {
      'hospital': 'hospital',
      'clinic': 'hospital',
      'medical': 'hospital',
      'pharmacy': 'pharmacy',
      'drugstore': 'pharmacy',
      'restaurant': 'restaurant',
      'food': 'restaurant',
      'cafe': 'restaurant',
      'bank': 'bank',
      'atm': 'atm',
      'gas station': 'gas_station',
      'petrol station': 'gas_station',
      'fuel': 'gas_station',
      'school': 'school',
      'university': 'school',
      'college': 'school',
      'hotel': 'lodging',
      'accommodation': 'lodging',
      'shopping': 'shopping_mall',
      'mall': 'shopping_mall',
      'market': 'shopping_mall',
      'police': 'police',
      'station': 'police',
      'fire station': 'fire_station',
      'fire': 'fire_station',
      'church': 'church',
      'mosque': 'mosque',
      'temple': 'place_of_worship',
      'gym': 'gym',
      'fitness': 'gym',
      'park': 'park',
      'library': 'library',
      'post office': 'post_office',
      'postal': 'post_office',
    };

    for (final entry in placeTypes.entries) {
      if (lowerQuery.contains(entry.key)) {
        return entry.value;
      }
    }

    return '';
  }
}
