
/// Service for tracking fuel consumption and costs
class FuelTrackerService {
  // Default fuel consumption rates (liters per 100km)
  static const Map<String, double> _vehicleConsumptionRates = {
    'small_car': 6.0,      // Toyota Corolla, Honda Civic
    'medium_car': 8.0,     // Toyota Camry, Honda Accord
    'large_car': 10.0,     // Toyota Avalon, Honda Pilot
    'suv': 12.0,           // Toyota Highlander, Honda CR-V
    'truck': 15.0,         // Pickup trucks
    'motorcycle': 3.0,     // Motorcycles
    'default': 8.0,        // Default average
  };

  // Current fuel prices in Nigerian Naira (per liter)
  static const Map<String, double> _fuelPrices = {
    'premium': 700.0,      // Premium fuel
    'regular': 650.0,      // Regular fuel
    'diesel': 680.0,       // Diesel
  };

  /// Calculate fuel consumption for a trip
  Future<Map<String, dynamic>> calculateFuelConsumption({
    required double distanceInKm,
    String vehicleType = 'default',
    String fuelType = 'regular',
    double? customConsumptionRate,
  }) async {
    // Get consumption rate
    final consumptionRate = customConsumptionRate ?? 
        _vehicleConsumptionRates[vehicleType] ?? 
        _vehicleConsumptionRates['default']!;
    
    // Calculate fuel needed
    final fuelNeeded = (distanceInKm * consumptionRate) / 100;
    
    // Get fuel price
    final fuelPrice = _fuelPrices[fuelType] ?? _fuelPrices['regular']!;
    
    // Calculate cost
    final fuelCost = fuelNeeded * fuelPrice;
    
    // Calculate CO2 emissions (approximate)
    final co2Emissions = fuelNeeded * 2.3; // kg CO2 per liter
    
    return {
      'distance_km': distanceInKm,
      'vehicle_type': vehicleType,
      'fuel_type': fuelType,
      'consumption_rate_per_100km': consumptionRate,
      'fuel_needed_liters': fuelNeeded,
      'fuel_price_per_liter': fuelPrice,
      'total_fuel_cost': fuelCost,
      'co2_emissions_kg': co2Emissions,
      'currency': 'NGN',
      'calculation_timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Calculate fuel consumption for multiple trips
  Future<Map<String, dynamic>> calculateMultipleTripsFuelConsumption({
    required List<Map<String, dynamic>> trips,
    String vehicleType = 'default',
    String fuelType = 'regular',
  }) async {
    double totalDistance = 0;
    double totalFuelNeeded = 0;
    double totalCost = 0;
    double totalCO2 = 0;
    
    final tripDetails = <Map<String, dynamic>>[];
    
    for (final trip in trips) {
      final distance = trip['distance'] as double? ?? 0.0;
      final tripResult = await calculateFuelConsumption(
        distanceInKm: distance,
        vehicleType: vehicleType,
        fuelType: fuelType,
      );
      
      totalDistance += distance;
      totalFuelNeeded += tripResult['fuel_needed_liters'];
      totalCost += tripResult['total_fuel_cost'];
      totalCO2 += tripResult['co2_emissions_kg'];
      
      tripDetails.add({
        'trip_name': trip['name'] ?? 'Trip ${tripDetails.length + 1}',
        'distance_km': distance,
        'fuel_needed_liters': tripResult['fuel_needed_liters'],
        'fuel_cost': tripResult['total_fuel_cost'],
        'co2_emissions_kg': tripResult['co2_emissions_kg'],
      });
    }
    
    return {
      'total_trips': trips.length,
      'total_distance_km': totalDistance,
      'total_fuel_needed_liters': totalFuelNeeded,
      'total_fuel_cost': totalCost,
      'total_co2_emissions_kg': totalCO2,
      'average_fuel_efficiency': totalDistance > 0 ? (totalFuelNeeded / totalDistance) * 100 : 0,
      'trip_details': tripDetails,
      'vehicle_type': vehicleType,
      'fuel_type': fuelType,
      'currency': 'NGN',
      'calculation_timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Get fuel efficiency tips
  List<String> getFuelEfficiencyTips() {
    return [
      'Maintain steady speeds and avoid rapid acceleration',
      'Keep your tires properly inflated',
      'Remove unnecessary weight from your vehicle',
      'Use air conditioning sparingly',
      'Plan your route to avoid traffic congestion',
      'Keep your engine well-maintained',
      'Use cruise control on highways when possible',
      'Avoid idling for long periods',
      'Combine multiple errands into one trip',
      'Consider carpooling or ride-sharing for regular commutes',
    ];
  }

  /// Get vehicle type recommendations based on usage
  String getVehicleTypeRecommendation({
    required double averageDailyDistance,
    required String primaryUse, // 'city', 'highway', 'mixed'
  }) {
    if (averageDailyDistance < 20) {
      return 'small_car'; // Most fuel-efficient for short city trips
    } else if (averageDailyDistance < 50) {
      return primaryUse == 'highway' ? 'medium_car' : 'small_car';
    } else {
      return primaryUse == 'highway' ? 'large_car' : 'medium_car';
    }
  }

  /// Calculate fuel savings from efficiency improvements
  Map<String, dynamic> calculateFuelSavings({
    required double currentConsumptionRate,
    required double improvedConsumptionRate,
    required double monthlyDistance,
  }) {
    final currentFuel = (monthlyDistance * currentConsumptionRate) / 100;
    final improvedFuel = (monthlyDistance * improvedConsumptionRate) / 100;
    final fuelSaved = currentFuel - improvedFuel;
    final costSaved = fuelSaved * _fuelPrices['regular']!;
    
    return {
      'current_monthly_fuel_liters': currentFuel,
      'improved_monthly_fuel_liters': improvedFuel,
      'monthly_fuel_saved_liters': fuelSaved,
      'monthly_cost_saved': costSaved,
      'annual_cost_saved': costSaved * 12,
      'improvement_percentage': ((currentConsumptionRate - improvedConsumptionRate) / currentConsumptionRate) * 100,
      'currency': 'NGN',
    };
  }

  /// Get current fuel prices
  Map<String, dynamic> getCurrentFuelPrices() {
    return {
      'prices': _fuelPrices,
      'currency': 'NGN',
      'last_updated': DateTime.now().toIso8601String(),
      'note': 'Prices may vary by location and time',
    };
  }

  /// Get vehicle consumption rates
  Map<String, dynamic> getVehicleConsumptionRates() {
    return {
      'consumption_rates': _vehicleConsumptionRates,
      'unit': 'liters_per_100km',
      'note': 'Actual consumption may vary based on driving conditions and vehicle maintenance',
    };
  }
}
