import 'package:route_gpt/services/places_service.dart';
import 'package:route_gpt/services/distance_service.dart';
import 'package:route_gpt/services/cost_estimator_service.dart';
import 'package:route_gpt/services/fuel_tracker_service.dart';
import 'package:route_gpt/services/event_service.dart';
import 'package:route_gpt/services/gemini_service.dart';
import 'package:route_gpt/services/maps_service.dart';

/// Unified service that handles all types of queries and routes them through Gemini for conversational responses
class UnifiedResponseService {
  final PlacesService _placesService = PlacesService();
  final DistanceService _distanceService = DistanceService();
  final CostEstimatorService _costEstimatorService = CostEstimatorService();
  final FuelTrackerService _fuelTrackerService = FuelTrackerService();
  final EventService _eventService = EventService();
  final GeminiService _geminiService = GeminiService();
  final MapsService _mapsService = MapsService();

  /// Process any type of query and return a conversational response
  Future<String> processQuery({
    required String userQuery,
    required String queryType,
    Map<String, dynamic>? contextData,
    List<Map<String, dynamic>>? conversationHistory,
  }) async {
    try {
      Map<String, dynamic> structuredData = {};
      
      // Process based on query type
      switch (queryType) {
        case 'directions':
          structuredData = await _processDirectionsQuery(userQuery, contextData);
          break;
        case 'distance':
          structuredData = await _processDistanceQuery(userQuery, contextData);
          break;
        case 'places':
          structuredData = await _processPlacesQuery(userQuery, contextData);
          break;
        case 'cost':
          structuredData = await _processCostQuery(userQuery, contextData);
          break;
        case 'fuel':
          structuredData = await _processFuelQuery(userQuery, contextData);
          break;
        case 'events':
          structuredData = await _processEventsQuery(userQuery, contextData);
          break;
        case 'general':
          structuredData = await _processGeneralQuery(userQuery, contextData);
          break;
        default:
          structuredData = {'error': 'Unknown query type: $queryType'};
      }

      // Route through Gemini for conversational response
      return await _geminiService.formatResponseWithContext(
        structuredData, 
        userQuery, 
        conversationHistory ?? []
      ) ?? 'I apologize, but I couldn\'t process your request. Please try again.';

    } catch (e) {
      print('Error processing query: $e');
      return 'I encountered an error while processing your request. Please try again.';
    }
  }

  /// Process directions query
  Future<Map<String, dynamic>> _processDirectionsQuery(
    String userQuery, 
    Map<String, dynamic>? contextData
  ) async {
    try {
      final origin = contextData?['origin'] as String? ?? '';
      final destination = contextData?['destination'] as String? ?? '';
      final travelMode = contextData?['travelMode'] as String? ?? 'DRIVE';

      if (origin.isEmpty || destination.isEmpty) {
        return {'error': 'Origin and destination are required for directions'};
      }

      // Get directions from MapsService
      final directionsData = await _mapsService.getDirections(origin, destination, travelMode: travelMode);
      
      // Check for events that might affect the route
      final events = await _eventService.getEventsInArea(
        latitude: double.parse(origin.split(',')[0]),
        longitude: double.parse(origin.split(',')[1]),
        radiusKm: 10.0,
      );

      return {
        'query_type': 'directions',
        'directions': directionsData,
        'events': events,
        'has_events': events.isNotEmpty,
      };
    } catch (e) {
      return {'error': 'Failed to get directions: $e'};
    }
  }

  /// Process distance query
  Future<Map<String, dynamic>> _processDistanceQuery(
    String userQuery, 
    Map<String, dynamic>? contextData
  ) async {
    try {
      final origin = contextData?['origin'] as String? ?? '';
      final destination = contextData?['destination'] as String? ?? '';
      final travelMode = contextData?['travelMode'] as String? ?? 'DRIVE';

      if (origin.isEmpty || destination.isEmpty) {
        return {'error': 'Origin and destination are required for distance calculation'};
      }

      final distanceData = await _distanceService.getDistanceAndTime(origin, destination, travelMode: travelMode);
      
      return {
        'query_type': 'distance',
        'distance_data': distanceData,
      };
    } catch (e) {
      return {'error': 'Failed to calculate distance: $e'};
    }
  }

  /// Process places query
  Future<Map<String, dynamic>> _processPlacesQuery(
    String userQuery, 
    Map<String, dynamic>? contextData
  ) async {
    try {
      final query = contextData?['query'] as String? ?? userQuery;
      final latitude = contextData?['latitude'] as double?;
      final longitude = contextData?['longitude'] as double?;
      final maxResults = contextData?['maxResults'] as int? ?? 3;

      List<Map<String, dynamic>> places = [];

      // Check if it's a "nearest" query with current location
      if (query.toLowerCase().contains('nearest') && latitude != null && longitude != null) {
        // Extract place type from query
        final placeType = _placesService.extractPlaceTypeFromQuery(query);
        if (placeType.isNotEmpty) {
          places = await _placesService.findNearestPlaces(latitude, longitude, placeType, maxResults: maxResults);
        }
      } 
      // Check if it's a query with a specific area (e.g., "hospital in Mushin")
      else if (query.toLowerCase().contains(' in ') || query.toLowerCase().contains(' near ')) {
        final area = _extractAreaFromQuery(query);
        if (area.isNotEmpty) {
          places = await _placesService.searchPlacesInArea(query, area, maxResults: maxResults);
        } else {
          // Fallback to regular search
          places = await _placesService.searchPlaces(query, maxResults: maxResults);
        }
      } 
      // Regular search
      else {
        places = await _placesService.searchPlaces(query, maxResults: maxResults);
      }

      // Add additional context for better responses
      return {
        'query_type': 'places',
        'places': places,
        'query': query,
        'count': places.length,
        'is_nearby_search': query.toLowerCase().contains('nearest') || query.toLowerCase().contains('near me'),
        'is_area_search': query.toLowerCase().contains(' in ') || query.toLowerCase().contains(' near '),
        'place_type': _extractPlaceTypeFromQuery(query),
        'area': _extractAreaFromQuery(query),
        'user_location': latitude != null && longitude != null ? {
          'latitude': latitude,
          'longitude': longitude,
        } : null,
      };
    } catch (e) {
      return {'error': 'Failed to search places: $e'};
    }
  }

  /// Process cost query
  Future<Map<String, dynamic>> _processCostQuery(
    String userQuery, 
    Map<String, dynamic>? contextData
  ) async {
    try {
      final distance = contextData?['distance'] as double? ?? 0.0;
      final duration = contextData?['duration'] as int? ?? 0;
      final travelMode = contextData?['travelMode'] as String? ?? 'DRIVE';

      if (distance == 0.0) {
        return {'error': 'Distance is required for cost estimation'};
      }

      final costData = await _costEstimatorService.estimateCosts(
        distanceInKm: distance,
        durationInMinutes: duration,
        travelMode: travelMode,
      );

      return {
        'query_type': 'cost',
        'cost_data': costData,
      };
    } catch (e) {
      return {'error': 'Failed to estimate costs: $e'};
    }
  }

  /// Process fuel query
  Future<Map<String, dynamic>> _processFuelQuery(
    String userQuery, 
    Map<String, dynamic>? contextData
  ) async {
    try {
      final distance = contextData?['distance'] as double? ?? 0.0;
      final vehicleType = contextData?['vehicleType'] as String? ?? 'default';
      final fuelType = contextData?['fuelType'] as String? ?? 'regular';

      if (distance == 0.0) {
        return {'error': 'Distance is required for fuel calculation'};
      }

      final fuelData = await _fuelTrackerService.calculateFuelConsumption(
        distanceInKm: distance,
        vehicleType: vehicleType,
        fuelType: fuelType,
      );

      return {
        'query_type': 'fuel',
        'fuel_data': fuelData,
      };
    } catch (e) {
      return {'error': 'Failed to calculate fuel consumption: $e'};
    }
  }

  /// Process events query
  Future<Map<String, dynamic>> _processEventsQuery(
    String userQuery, 
    Map<String, dynamic>? contextData
  ) async {
    try {
      final latitude = contextData?['latitude'] as double? ?? 0.0;
      final longitude = contextData?['longitude'] as double? ?? 0.0;
      final radius = contextData?['radius'] as double? ?? 10.0;

      if (latitude == 0.0 || longitude == 0.0) {
        return {'error': 'Location coordinates are required for event search'};
      }

      final events = await _eventService.getEventsInArea(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radius,
      );

      return {
        'query_type': 'events',
        'events': events,
        'count': events.length,
      };
    } catch (e) {
      return {'error': 'Failed to get events: $e'};
    }
  }

  /// Process general query
  Future<Map<String, dynamic>> _processGeneralQuery(
    String userQuery, 
    Map<String, dynamic>? contextData
  ) async {
    // For general queries, we'll let Gemini handle them directly
    return {
      'query_type': 'general',
      'user_query': userQuery,
      'context': contextData ?? {},
    };
  }

  /// Extract place type from query (e.g., "nearest hospital" -> "hospital")
  String _extractPlaceTypeFromQuery(String query) {
    final lowerQuery = query.toLowerCase();
    
    // Common place types
    final placeTypes = {
      'hospital': 'hospital',
      'clinic': 'hospital',
      'pharmacy': 'pharmacy',
      'restaurant': 'restaurant',
      'food': 'restaurant',
      'hotel': 'lodging',
      'bank': 'bank',
      'atm': 'atm',
      'gas station': 'gas_station',
      'fuel': 'gas_station',
      'school': 'school',
      'university': 'university',
      'police': 'police',
      'fire station': 'fire_station',
      'post office': 'post_office',
      'shopping': 'shopping_mall',
      'mall': 'shopping_mall',
      'gym': 'gym',
      'park': 'park',
      'church': 'church',
      'mosque': 'mosque',
      'temple': 'place_of_worship',
    };

    for (final entry in placeTypes.entries) {
      if (lowerQuery.contains(entry.key)) {
        return entry.value;
      }
    }

    return '';
  }

  /// Extract area from query (e.g., "hospital in Mushin" -> "Mushin")
  String _extractAreaFromQuery(String query) {
    final lowerQuery = query.toLowerCase();
    
    // Look for "in [area]" pattern
    if (lowerQuery.contains(' in ')) {
      final parts = lowerQuery.split(' in ');
      if (parts.length > 1) {
        return parts[1].trim();
      }
    }
    
    // Look for "near [area]" pattern
    if (lowerQuery.contains(' near ')) {
      final parts = lowerQuery.split(' near ');
      if (parts.length > 1) {
        return parts[1].trim();
      }
    }
    
    // Look for "around [area]" pattern
    if (lowerQuery.contains(' around ')) {
      final parts = lowerQuery.split(' around ');
      if (parts.length > 1) {
        return parts[1].trim();
      }
    }
    
    return '';
  }

  /// Get query type from user input
  String determineQueryType(String userQuery) {
    final lowerQuery = userQuery.toLowerCase();
    
    // Directions keywords
    if (lowerQuery.contains('directions') || 
        lowerQuery.contains('how to get to') ||
        lowerQuery.contains('route to') ||
        lowerQuery.contains('navigate to') ||
        lowerQuery.contains('how do i get to') ||
        lowerQuery.contains('get to')) {
      return 'directions';
    }
    
    // Distance keywords
    if (lowerQuery.contains('how far') || 
        lowerQuery.contains('distance') ||
        lowerQuery.contains('how long') ||
        lowerQuery.contains('travel time')) {
      return 'distance';
    }
    
    // Places keywords
    if (lowerQuery.contains('nearest') || 
        lowerQuery.contains('find') ||
        lowerQuery.contains('where is') ||
        lowerQuery.contains('near me')) {
      return 'places';
    }
    
    // Fuel keywords (check before cost to avoid conflicts)
    if (lowerQuery.contains('fuel') || 
        lowerQuery.contains('petrol') ||
        lowerQuery.contains('gas') ||
        lowerQuery.contains('consumption')) {
      return 'fuel';
    }
    
    // Cost keywords
    if (lowerQuery.contains('cost') || 
        lowerQuery.contains('price') ||
        lowerQuery.contains('how much') ||
        lowerQuery.contains('expensive')) {
      return 'cost';
    }
    
    // Events keywords
    if (lowerQuery.contains('event') || 
        lowerQuery.contains('traffic') ||
        lowerQuery.contains('congestion') ||
        lowerQuery.contains('delay')) {
      return 'events';
    }
    
    return 'general';
  }
}
