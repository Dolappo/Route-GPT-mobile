import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for handling event-aware navigation and traffic alerts
class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _eventsCollection = 'events';
  static const String _trafficAlertsCollection = 'traffic_alerts';

  /// Check for events that might affect travel in a specific area
  Future<List<Map<String, dynamic>>> getEventsInArea({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // If no dates provided, check for events in the next 24 hours
      final start = startDate ?? DateTime.now();
      final end = endDate ?? DateTime.now().add(const Duration(hours: 24));
      
      final query = _firestore
          .collection(_eventsCollection)
          .where('start_date', isGreaterThanOrEqualTo: start)
          .where('start_date', isLessThanOrEqualTo: end)
          .where('is_active', isEqualTo: true);

      final snapshot = await query.get();
      final events = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final eventData = doc.data();
        final eventLat = eventData['latitude'] as double? ?? 0.0;
        final eventLng = eventData['longitude'] as double? ?? 0.0;
        
        // Calculate distance from user location
        final distance = _calculateDistance(latitude, longitude, eventLat, eventLng);
        
        if (distance <= radiusKm) {
          events.add({
            'id': doc.id,
            'name': eventData['name'] ?? '',
            'description': eventData['description'] ?? '',
            'start_date': eventData['start_date'],
            'end_date': eventData['end_date'],
            'latitude': eventLat,
            'longitude': eventLng,
            'distance_km': distance,
            'event_type': eventData['event_type'] ?? 'general',
            'expected_attendance': eventData['expected_attendance'] ?? 0,
            'traffic_impact': eventData['traffic_impact'] ?? 'medium',
            'alternative_routes': eventData['alternative_routes'] ?? [],
          });
        }
      }

      // Sort by distance and traffic impact
      events.sort((a, b) {
        final distanceCompare = (a['distance_km'] as double).compareTo(b['distance_km'] as double);
        if (distanceCompare != 0) return distanceCompare;
        
        final impactA = _getTrafficImpactScore(a['traffic_impact'] as String);
        final impactB = _getTrafficImpactScore(b['traffic_impact'] as String);
        return impactB.compareTo(impactA);
      });

      return events;
    } catch (e) {
      print('Error getting events in area: $e');
      return [];
    }
  }

  /// Get traffic alerts for a specific route
  Future<List<Map<String, dynamic>>> getTrafficAlertsForRoute({
    required String origin,
    required String destination,
  }) async {
    try {
      final query = _firestore
          .collection(_trafficAlertsCollection)
          .where('is_active', isEqualTo: true)
          .where('start_date', isLessThanOrEqualTo: DateTime.now())
          .where('end_date', isGreaterThanOrEqualTo: DateTime.now());

      final snapshot = await query.get();
      final alerts = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final alertData = doc.data();
        alerts.add({
          'id': doc.id,
          'title': alertData['title'] ?? '',
          'description': alertData['description'] ?? '',
          'severity': alertData['severity'] ?? 'medium',
          'start_date': alertData['start_date'],
          'end_date': alertData['end_date'],
          'affected_areas': alertData['affected_areas'] ?? [],
          'alternative_routes': alertData['alternative_routes'] ?? [],
          'source': alertData['source'] ?? 'system',
        });
      }

      return alerts;
    } catch (e) {
      print('Error getting traffic alerts: $e');
      return [];
    }
  }

  /// Add a new event (for admin or user-submitted events)
  Future<String?> addEvent({
    required String name,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required double latitude,
    required double longitude,
    String eventType = 'general',
    int expectedAttendance = 0,
    String trafficImpact = 'medium',
    List<String> alternativeRoutes = const [],
  }) async {
    try {
      final docRef = await _firestore.collection(_eventsCollection).add({
        'name': name,
        'description': description,
        'start_date': startDate,
        'end_date': endDate,
        'latitude': latitude,
        'longitude': longitude,
        'event_type': eventType,
        'expected_attendance': expectedAttendance,
        'traffic_impact': trafficImpact,
        'alternative_routes': alternativeRoutes,
        'is_active': true,
        'created_at': DateTime.now(),
        'created_by': _auth.currentUser?.uid ?? 'anonymous',
      });

      return docRef.id;
    } catch (e) {
      print('Error adding event: $e');
      return null;
    }
  }

  /// Add a traffic alert
  Future<String?> addTrafficAlert({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    String severity = 'medium',
    List<String> affectedAreas = const [],
    List<String> alternativeRoutes = const [],
    String source = 'user',
  }) async {
    try {
      final docRef = await _firestore.collection(_trafficAlertsCollection).add({
        'title': title,
        'description': description,
        'start_date': startDate,
        'end_date': endDate,
        'severity': severity,
        'affected_areas': affectedAreas,
        'alternative_routes': alternativeRoutes,
        'source': source,
        'is_active': true,
        'created_at': DateTime.now(),
        'created_by': _auth.currentUser?.uid ?? 'anonymous',
      });

      return docRef.id;
    } catch (e) {
      print('Error adding traffic alert: $e');
      return null;
    }
  }

  /// Get event types and their typical traffic impact
  Map<String, String> getEventTypeTrafficImpact() {
    return {
      'sports': 'high',
      'concert': 'high',
      'festival': 'high',
      'conference': 'medium',
      'wedding': 'low',
      'funeral': 'low',
      'political': 'high',
      'religious': 'medium',
      'market': 'medium',
      'construction': 'high',
      'general': 'medium',
    };
  }

  /// Get traffic impact recommendations
  Map<String, List<String>> getTrafficImpactRecommendations() {
    return {
      'high': [
        'Expect significant delays',
        'Consider alternative routes',
        'Allow extra travel time',
        'Use public transport if available',
        'Check real-time traffic updates',
      ],
      'medium': [
        'Expect moderate delays',
        'Monitor traffic conditions',
        'Have backup routes ready',
        'Allow some extra time',
      ],
      'low': [
        'Minimal impact expected',
        'Normal travel conditions',
        'Standard route should be fine',
      ],
    };
  }

  /// Calculate distance between two coordinates
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * asin(sqrt(a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  /// Get traffic impact score for sorting
  int _getTrafficImpactScore(String impact) {
    switch (impact.toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 2;
    }
  }

  /// Get upcoming events for a user's saved locations
  Future<List<Map<String, dynamic>>> getUpcomingEventsForLocations({
    required List<Map<String, dynamic>> locations,
    int daysAhead = 7,
  }) async {
    final allEvents = <Map<String, dynamic>>[];
    
    for (final location in locations) {
      final lat = location['latitude'] as double? ?? 0.0;
      final lng = location['longitude'] as double? ?? 0.0;
      final name = location['name'] as String? ?? 'Unknown Location';
      
      if (lat != 0.0 && lng != 0.0) {
        final events = await getEventsInArea(
          latitude: lat,
          longitude: lng,
          radiusKm: 5.0,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(Duration(days: daysAhead)),
        );
        
        for (final event in events) {
          event['near_location'] = name;
          allEvents.add(event);
        }
      }
    }
    
    // Sort by start date
    allEvents.sort((a, b) {
      final dateA = a['start_date'] as DateTime;
      final dateB = b['start_date'] as DateTime;
      return dateA.compareTo(dateB);
    });
    
    return allEvents;
  }
}
