import 'dart:convert';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service for handling distance and time calculations using Google Distance Matrix API
class DistanceService {
  final String _apiKey;

  DistanceService() : _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  /// Get distance and time between two points
  Future<Map<String, dynamic>> getDistanceAndTime(
      String origin, String destination,
      {String travelMode = 'DRIVE'}) async {
    try {
      final url =
          Uri.parse('https://maps.googleapis.com/maps/api/distancematrix/json');

      final response = await http.get(
        url.replace(queryParameters: {
          'origins': origin,
          'destinations': destination,
          'mode': travelMode.toLowerCase(),
          'departure_time': 'now',
          'units': 'metric',
          'key': _apiKey,
        }),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['rows'].isNotEmpty) {
        final row = data['rows'][0];
        if (row['elements'].isNotEmpty) {
          final element = row['elements'][0];

          if (element['status'] == 'OK') {
            final distance = element['distance'];
            final duration = element['duration'];
            final durationInTraffic = element['duration_in_traffic'];

            return {
              'distance': distance['text'],
              'distanceValue': distance['value'], // in meters
              'duration': duration['text'],
              'durationValue': duration['value'], // in seconds
              'durationInTraffic':
                  durationInTraffic?['text'] ?? duration['text'],
              'durationInTrafficValue':
                  durationInTraffic?['value'] ?? duration['value'],
              'origin': data['origin_addresses'][0],
              'destination': data['destination_addresses'][0],
              'travelMode': travelMode,
              'hasTrafficData': durationInTraffic != null,
            };
          }
        }
      }

      throw Exception('Unable to calculate distance and time');
    } catch (e) {
      print('Error getting distance and time: $e');
      rethrow;
    }
  }

  /// Get distance and time for multiple destinations
  Future<List<Map<String, dynamic>>> getDistanceAndTimeMultiple(
      String origin, List<String> destinations,
      {String travelMode = 'DRIVE'}) async {
    try {
      final url =
          Uri.parse('https://maps.googleapis.com/maps/api/distancematrix/json');

      final response = await http.get(
        url.replace(queryParameters: {
          'origins': origin,
          'destinations': destinations.join('|'),
          'mode': travelMode.toLowerCase(),
          'units': 'metric',
          'key': _apiKey,
        }),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['rows'].isNotEmpty) {
        final row = data['rows'][0];
        final results = <Map<String, dynamic>>[];

        for (int i = 0; i < row['elements'].length; i++) {
          final element = row['elements'][i];

          if (element['status'] == 'OK') {
            final distance = element['distance'];
            final duration = element['duration'];
            final durationInTraffic = element['duration_in_traffic'];

            results.add({
              'distance': distance['text'],
              'distanceValue': distance['value'],
              'duration': duration['text'],
              'durationValue': duration['value'],
              'durationInTraffic':
                  durationInTraffic?['text'] ?? duration['text'],
              'durationInTrafficValue':
                  durationInTraffic?['value'] ?? duration['value'],
              'origin': data['origin_addresses'][0],
              'destination': data['destination_addresses'][i],
              'travelMode': travelMode,
              'hasTrafficData': durationInTraffic != null,
            });
          }
        }

        return results;
      }

      throw Exception('Unable to calculate distances and times');
    } catch (e) {
      print('Error getting multiple distances and times: $e');
      rethrow;
    }
  }

  /// Calculate straight-line distance between two coordinates
  double calculateStraightLineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  /// Format distance for display
  String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).round()} meters';
    } else if (distanceInKm < 10) {
      return '${distanceInKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceInKm.round()} km';
    }
  }

  /// Format duration for display
  String formatDuration(int durationInSeconds) {
    final hours = durationInSeconds ~/ 3600;
    final minutes = (durationInSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
