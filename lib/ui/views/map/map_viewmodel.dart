import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:stacked/stacked.dart';

import '../../../app/app.locator.dart';
import '../../../services/maps_service.dart';

class MapViewModel extends BaseViewModel {
  final String originCoordinates;
  final String destinationCoordinates;
  final String travelMode;

  final _mapsService = locator<MapsService>();

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Map<String, dynamic>? _routeInfo;

  CameraPosition get initialCameraPosition => CameraPosition(
        target: _getCenterPoint(),
        zoom: 12.0,
      );

  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  Map<String, dynamic>? get routeInfo => _routeInfo;

  MapViewModel({
    required this.originCoordinates,
    required this.destinationCoordinates,
    required this.travelMode,
  });

  void onMapCreated(GoogleMapController controller) {
    try {
      _mapController = controller;
      _loadRoute();
    } catch (e) {
      print('Error in onMapCreated: $e');
    }
  }

  Future<void> _loadRoute() async {
    try {
      setBusy(true);

      // Parse coordinates
      final originParts = originCoordinates.split(',');
      final destParts = destinationCoordinates.split(',');

      if (originParts.length < 2 || destParts.length < 2) {
        throw Exception('Invalid coordinates format');
      }

      final originLat = double.parse(originParts[0].trim());
      final originLng = double.parse(originParts[1].trim());
      final destLat = double.parse(destParts[0].trim());
      final destLng = double.parse(destParts[1].trim());

      // Create markers
      _markers = {
        Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(originLat, originLng),
          infoWindow: const InfoWindow(title: 'Origin'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destLat, destLng),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };

      // Get route data
      final routeData = await _mapsService.getDirections(
        originCoordinates,
        destinationCoordinates,
        travelMode: travelMode,
      );

      // Create polyline
      final polylineData = routeData['polyline'] as String?;
      if (polylineData != null && polylineData.isNotEmpty) {
        final points = _decodePolyline(polylineData);
        if (points.isNotEmpty) {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: Colors.blue,
              width: 5,
            ),
          };
        }
      }

      // Store route info - handle different response structures
      if (routeData.containsKey('routeSummary')) {
        _routeInfo = routeData['routeSummary'] as Map<String, dynamic>? ?? {};
      } else {
        // If no routeSummary, create one from the main data
        _routeInfo = {
          'distance': routeData['distance'] ?? 'Unknown',
          'duration': routeData['duration'] ?? 'Unknown',
          'trafficDelay': routeData['trafficDelay'],
          'travelMode': routeData['travelMode'] ?? travelMode,
        };
      }

      // Fit bounds
      if (_mapController != null && _polylines.isNotEmpty) {
        final polyline = _polylines.first;
        if (polyline.points.isNotEmpty) {
          final bounds = _getBounds(polyline.points);
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 50.0),
          );
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error loading route: $e');
    } finally {
      setBusy(false);
    }
  }

  LatLng _getCenterPoint() {
    try {
      final originParts = originCoordinates.split(',');
      final destParts = destinationCoordinates.split(',');

      if (originParts.length < 2 || destParts.length < 2) {
        // Return a default center point if coordinates are invalid
        return const LatLng(0.0, 0.0);
      }

      final originLat = double.parse(originParts[0].trim());
      final originLng = double.parse(originParts[1].trim());
      final destLat = double.parse(destParts[0].trim());
      final destLng = double.parse(destParts[1].trim());

      return LatLng(
        (originLat + destLat) / 2,
        (originLng + destLng) / 2,
      );
    } catch (e) {
      print('Error parsing coordinates for center point: $e');
      return const LatLng(0.0, 0.0);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final p = LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
      poly.add(p);
    }
    return poly;
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;

    for (final point in points) {
      minLat = minLat == null
          ? point.latitude
          : (minLat < point.latitude ? minLat : point.latitude);
      maxLat = maxLat == null
          ? point.latitude
          : (maxLat > point.latitude ? maxLat : point.latitude);
      minLng = minLng == null
          ? point.longitude
          : (minLng < point.longitude ? minLng : point.longitude);
      maxLng = maxLng == null
          ? point.longitude
          : (maxLng > point.longitude ? maxLng : point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }
}
