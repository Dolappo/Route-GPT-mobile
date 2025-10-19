import 'dart:math';

/// Service for estimating travel costs across different transportation modes
class CostEstimatorService {
  // Cost constants (in Nigerian Naira)
  static const double _fuelPricePerLiter = 650.0; // Current fuel price
  static const double _averageFuelConsumption = 8.0; // Liters per 100km
  static const double _uberBaseFare = 200.0;
  static const double _uberPerKm = 45.0;
  static const double _uberPerMinute = 8.0;
  static const double _boltBaseFare = 180.0;
  static const double _boltPerKm = 42.0;
  static const double _boltPerMinute = 7.0;
  static const double _publicTransportPerKm = 15.0;
  static const double _taxiBaseFare = 150.0;
  static const double _taxiPerKm = 35.0;
  static const double _taxiPerMinute = 6.0;

  /// Estimate costs for different transportation modes
  Future<Map<String, dynamic>> estimateCosts({
    required double distanceInKm,
    required int durationInMinutes,
    String travelMode = 'DRIVE',
  }) async {
    final costs = <String, Map<String, dynamic>>{};

    // Driving costs (fuel only)
    if (travelMode == 'DRIVE' || travelMode == 'driving') {
      costs['driving'] = _calculateDrivingCost(distanceInKm);
    }

    // Ride-hailing costs
    costs['uber'] = _calculateUberCost(distanceInKm, durationInMinutes);
    costs['bolt'] = _calculateBoltCost(distanceInKm, durationInMinutes);
    costs['taxi'] = _calculateTaxiCost(distanceInKm, durationInMinutes);

    // Public transport costs
    costs['public_transport'] = _calculatePublicTransportCost(distanceInKm);

    return {
      'distance': distanceInKm,
      'duration': durationInMinutes,
      'travelMode': travelMode,
      'costs': costs,
      'recommendation': _getCostRecommendation(costs),
    };
  }

  /// Calculate driving costs (fuel only)
  Map<String, dynamic> _calculateDrivingCost(double distanceInKm) {
    final fuelNeeded = (distanceInKm * _averageFuelConsumption) / 100;
    final fuelCost = fuelNeeded * _fuelPricePerLiter;
    
    return {
      'type': 'driving',
      'fuel_needed_liters': fuelNeeded,
      'fuel_cost': fuelCost,
      'cost_breakdown': {
        'fuel': fuelCost,
        'maintenance': fuelCost * 0.1, // 10% for maintenance
        'total': fuelCost * 1.1,
      },
      'description': 'Fuel cost only (does not include vehicle depreciation, insurance, etc.)',
    };
  }

  /// Calculate Uber costs
  Map<String, dynamic> _calculateUberCost(double distanceInKm, int durationInMinutes) {
    const baseCost = _uberBaseFare;
    final distanceCost = distanceInKm * _uberPerKm;
    final timeCost = durationInMinutes * _uberPerMinute;
    final totalCost = baseCost + distanceCost + timeCost;
    
    // Add surge pricing (random factor between 1.0 and 1.5)
    final surgeMultiplier = 1.0 + (Random().nextDouble() * 0.5);
    final finalCost = totalCost * surgeMultiplier;
    
    return {
      'type': 'uber',
      'base_fare': baseCost,
      'distance_cost': distanceCost,
      'time_cost': timeCost,
      'surge_multiplier': surgeMultiplier,
      'total_cost': finalCost,
      'description': 'Uber ride with potential surge pricing',
    };
  }

  /// Calculate Bolt costs
  Map<String, dynamic> _calculateBoltCost(double distanceInKm, int durationInMinutes) {
    const baseCost = _boltBaseFare;
    final distanceCost = distanceInKm * _boltPerKm;
    final timeCost = durationInMinutes * _boltPerMinute;
    final totalCost = baseCost + distanceCost + timeCost;
    
    // Add surge pricing (random factor between 1.0 and 1.3)
    final surgeMultiplier = 1.0 + (Random().nextDouble() * 0.3);
    final finalCost = totalCost * surgeMultiplier;
    
    return {
      'type': 'bolt',
      'base_fare': baseCost,
      'distance_cost': distanceCost,
      'time_cost': timeCost,
      'surge_multiplier': surgeMultiplier,
      'total_cost': finalCost,
      'description': 'Bolt ride with potential surge pricing',
    };
  }

  /// Calculate traditional taxi costs
  Map<String, dynamic> _calculateTaxiCost(double distanceInKm, int durationInMinutes) {
    const baseCost = _taxiBaseFare;
    final distanceCost = distanceInKm * _taxiPerKm;
    final timeCost = durationInMinutes * _taxiPerMinute;
    final totalCost = baseCost + distanceCost + timeCost;
    
    return {
      'type': 'taxi',
      'base_fare': baseCost,
      'distance_cost': distanceCost,
      'time_cost': timeCost,
      'total_cost': totalCost,
      'description': 'Traditional taxi (negotiable rates)',
    };
  }

  /// Calculate public transport costs
  Map<String, dynamic> _calculatePublicTransportCost(double distanceInKm) {
    final baseCost = distanceInKm * _publicTransportPerKm;
    
    // Add transfer costs (assume 1-2 transfers for longer distances)
    final transferCost = distanceInKm > 10 ? 50.0 : 0.0;
    final totalCost = baseCost + transferCost;
    
    return {
      'type': 'public_transport',
      'base_cost': baseCost,
      'transfer_cost': transferCost,
      'total_cost': totalCost,
      'description': 'Public transport (bus, BRT, etc.)',
    };
  }

  /// Get cost recommendation
  String _getCostRecommendation(Map<String, Map<String, dynamic>> costs) {
    if (costs.isEmpty) return 'No cost estimates available';
    
    // Find the cheapest option
    String cheapestOption = '';
    double cheapestCost = double.infinity;
    
    costs.forEach((key, value) {
      final cost = value['total_cost'] as double? ?? value['cost_breakdown']?['total'] as double? ?? 0.0;
      if (cost < cheapestCost) {
        cheapestCost = cost;
        cheapestOption = key;
      }
    });
    
    // Generate recommendation based on cheapest option
    switch (cheapestOption) {
      case 'public_transport':
        return 'Public transport is the most economical option';
      case 'driving':
        return 'Driving your own car is the most cost-effective';
      case 'uber':
        return 'Uber offers the best value among ride-hailing services';
      case 'bolt':
        return 'Bolt provides competitive pricing for ride-hailing';
      case 'taxi':
        return 'Traditional taxi might be negotiable for better rates';
      default:
        return 'Consider your preferences and convenience when choosing';
    }
  }

  /// Get fuel price information
  Map<String, dynamic> getFuelPriceInfo() {
    return {
      'current_price_per_liter': _fuelPricePerLiter,
      'currency': 'NGN',
      'last_updated': DateTime.now().toIso8601String(),
      'note': 'Prices may vary by location and time',
    };
  }

  /// Update fuel price (for future use with real-time data)
  void updateFuelPrice(double newPrice) {
    // This would be used to update fuel prices from an API
    // For now, we'll keep the constant value
  }
}
