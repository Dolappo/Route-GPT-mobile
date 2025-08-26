import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';

class MapsService {
  final Location _location = Location();
  final String _apiKey;
  LocationData? _currentLocation;

  // Cache for place searches to avoid repeated API calls
  final Map<String, Map<String, dynamic>> _placeCache = {};
  final Map<String, List<String>> _landmarkCache = {};

  MapsService() : _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  Future<LocationData> getCurrentLocation() async {
    // Return cached location if available and recent (within 30 seconds)
    if (_currentLocation != null) {
      final now = DateTime.now();
      final locationTime = DateTime.fromMillisecondsSinceEpoch(
          _currentLocation!.time?.toInt() ?? 0);
      if (now.difference(locationTime).inSeconds < 30) {
        return _currentLocation!;
      }
    }

    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        throw Exception('Location permission denied');
      }
    }

    _currentLocation = await _location.getLocation();
    return _currentLocation!;
  }

  Future<LocationData?> getCachedLocation() async {
    if (_currentLocation != null) {
      return _currentLocation;
    }
    try {
      return await getCurrentLocation();
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getDirections(String origin, String destination,
      {String travelMode = 'DRIVE'}) async {
    try {
      const url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

      // Build request body based on travel mode
      final requestBody = {
        'origin': {
          'location': {
            'latLng': {
              'latitude': double.parse(origin.split(',')[0]),
              'longitude': double.parse(origin.split(',')[1]),
            }
          }
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': double.parse(destination.split(',')[0]),
              'longitude': double.parse(destination.split(',')[1]),
            }
          }
        },
        'travelMode': travelMode,
        'computeAlternativeRoutes': false,
        'languageCode': 'en-US',
        'units': 'METRIC',
      };

      // Only add routing preference for driving mode
      if (travelMode == 'DRIVE') {
        requestBody['routingPreference'] = 'TRAFFIC_AWARE';
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask':
              'routes.duration,routes.distanceMeters,routes.legs.steps,routes.legs.steps.navigationInstruction,routes.legs.steps.polyline,routes.legs.startLocation,routes.legs.endLocation,routes.legs.staticDuration,routes.travelAdvisory,routes.legs.travelAdvisory,routes.legs.steps.travelAdvisory',
        },
        body: json.encode(requestBody),
      );

      final data = json.decode(response.body);
      debugPrint('Routes API Response: $data', wrapWidth: 1024);

      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final leg = route['legs'][0];

        // Convert meters to a readable format
        final distanceInKm =
            (route['distanceMeters'] / 1000).toStringAsFixed(1);

        // Parse duration
        final duration = route['duration'];
        final durationInSeconds = int.parse(duration.replaceAll('s', ''));
        final durationInMinutes = (durationInSeconds / 60).round();

        // Handle traffic data (only available for driving mode)
        int staticDurationInMinutes = durationInMinutes;
        int trafficDelay = 0;
        bool hasTrafficDelay = false;

        if (travelMode == 'DRIVE' && leg['staticDuration'] != null) {
          final staticDuration = leg['staticDuration'];
          final staticDurationInSeconds =
              int.parse(staticDuration.replaceAll('s', ''));
          staticDurationInMinutes = (staticDurationInSeconds / 60).round();

          // Calculate traffic delay
          trafficDelay = durationInMinutes - staticDurationInMinutes;
          hasTrafficDelay = trafficDelay > 0;
        }

        // Get basic steps first (faster response)
        final basicSteps = (leg['steps'] as List)
            .map((step) => step['navigationInstruction']?['instructions'] ?? "")
            .toList();

        // Return basic response immediately, then enhance with landmarks in background
        final basicResponse = {
          'distance': '$distanceInKm km',
          'duration': '$durationInMinutes mins',
          'staticDuration': travelMode == 'DRIVE'
              ? '$staticDurationInMinutes mins'
              : '$durationInMinutes mins',
          'trafficDelay': hasTrafficDelay ? '$trafficDelay mins' : '0 mins',
          'hasTrafficDelay': hasTrafficDelay,
          'travelMode': _getReadableTravelMode(travelMode),
          'startAddress': leg['startAddress'],
          'endAddress': leg['endAddress'],
          'steps': basicSteps,
          'rawSteps': basicSteps,
        };

        // Enhance with landmarks in background (non-blocking)
        _enhanceStepsWithLandmarksAsync(leg['steps']).then((enhancedSteps) {
          basicResponse['steps'] = enhancedSteps;
        });

        return basicResponse;
      } else {
        throw Exception('No routes found');
      }
    } catch (e) {
      throw Exception('Error getting directions: $e');
    }
  }

  // Non-blocking landmark enhancement
  Future<List<Map<String, dynamic>>> _enhanceStepsWithLandmarksAsync(
      List steps) async {
    List<Map<String, dynamic>> enhancedSteps = [];

    // Process only first 3 steps for speed (most important ones)
    final stepsToProcess = steps.take(3).toList();

    for (int i = 0; i < stepsToProcess.length; i++) {
      final step = stepsToProcess[i];
      final instruction = step['navigationInstruction']?['instructions'] ?? "";

      // Get nearby landmarks for this step (with caching)
      List<String> landmarks = [];
      if (step['startLocation'] != null) {
        try {
          final lat = step['startLocation']['latLng']['latitude'];
          final lng = step['startLocation']['latLng']['longitude'];
          final cacheKey =
              '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';

          if (_landmarkCache.containsKey(cacheKey)) {
            landmarks = _landmarkCache[cacheKey]!;
          } else {
            landmarks = await _getNearbyLandmarks(lat, lng);
            _landmarkCache[cacheKey] = landmarks;
          }
        } catch (e) {
          debugPrint('Error getting landmarks: $e');
        }
      }

      enhancedSteps.add({
        'instruction': instruction,
        'landmarks': landmarks,
        'distance': step['distanceMeters'] != null
            ? '${(step['distanceMeters'] / 1000).toStringAsFixed(2)} km'
            : '',
        'duration': step['staticDuration'] != null
            ? '${(int.parse(step['staticDuration'].replaceAll('s', '')) / 60).round()} mins'
            : '',
      });
    }

    return enhancedSteps;
  }

  Future<List<String>> _getNearbyLandmarks(double lat, double lng) async {
    try {
      final url =
          Uri.parse('https://places.googleapis.com/v1/places:searchNearby');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'places.displayName,places.types',
        },
        body: json.encode({
          'locationRestriction': {
            'circle': {
              'center': {
                'latitude': lat,
                'longitude': lng,
              },
              'radius': 50.0, // Reduced radius for faster response
            }
          },
          'includedTypes': ['establishment', 'point_of_interest'],
          'maxResultCount': 2, // Reduced count for faster response
        }),
      );

      final data = json.decode(response.body);
      if (data['places'] != null) {
        final places = data['places'] as List;
        final landmarks = <String>[];
        for (final place in places) {
          final name = place['displayName']?['text'] as String?;
          if (name != null && name.isNotEmpty) {
            landmarks.add(name);
          }
        }
        return landmarks;
      }
    } catch (e) {
      debugPrint('Error fetching nearby landmarks: $e');
    }

    return <String>[];
  }

  String _getReadableTravelMode(String mode) {
    switch (mode) {
      case 'DRIVE':
        return 'driving';
      case 'WALK':
        return 'walking';
      case 'BICYCLE':
        return 'cycling';
      case 'TRANSIT':
        return 'public transport';
      default:
        return 'driving';
    }
  }

  Future<Map<String, dynamic>> searchPlace(String query) async {
    // Check cache first
    if (_placeCache.containsKey(query)) {
      return _placeCache[query]!;
    }

    print('Searching for place: $query');
    try {
      final url =
          Uri.parse('https://places.googleapis.com/v1/places:searchText');

      print('Places API URL: $url');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask':
              'places.formattedAddress,places.displayName,places.location',
        },
        body: json.encode({
          'textQuery': query,
        }),
      );
      final data = json.decode(response.body);
      print('Places API Response: $data');

      if (data['places'] != null && data['places'].isNotEmpty) {
        final place = data['places'][0];
        final result = {
          'address': place['formattedAddress'],
          'name': place['displayName']['text'] ?? '',
          'lat': place['location']['latitude'].toString(),
          'lng': place['location']['longitude'].toString(),
        };

        // Cache the result
        _placeCache[query] = result;
        return result;
      } else {
        throw Exception('Place not found: ${data['status'] ?? 'No results'}');
      }
    } catch (e) {
      throw Exception('Error searching for place: $e');
    }
  }

  Future<Map<String, dynamic>> getRouteSummary(
      String origin, String destination,
      {String travelMode = 'DRIVE'}) async {
    try {
      final directions =
          await getDirections(origin, destination, travelMode: travelMode);

      return {
        'summary': {
          'distance': directions['distance'],
          'duration': directions['duration'],
          'trafficDelay': directions['trafficDelay'],
          'hasTrafficDelay': directions['hasTrafficDelay'],
          'travelMode': directions['travelMode'],
          'startAddress': directions['startAddress'],
          'endAddress': directions['endAddress'],
        },
        'steps': directions['steps'],
      };
    } catch (e) {
      throw Exception('Error getting route summary: $e');
    }
  }

  // Clear cache when needed
  void clearCache() {
    _placeCache.clear();
    _landmarkCache.clear();
  }
}
