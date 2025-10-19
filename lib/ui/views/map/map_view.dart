import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:stacked/stacked.dart';

import 'map_viewmodel.dart';

class MapView extends StackedView<MapViewModel> {
  final String originCoordinates;
  final String destinationCoordinates;
  final String travelMode;

  const MapView({
    Key? key,
    required this.originCoordinates,
    required this.destinationCoordinates,
    required this.travelMode,
  }) : super(key: key);

  @override
  Widget builder(BuildContext context, MapViewModel viewModel, Widget? child) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Map'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: viewModel.initialCameraPosition,
            markers: viewModel.markers,
            polylines: viewModel.polylines,
            onMapCreated: (GoogleMapController controller) {
              viewModel.onMapCreated(controller);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          if (viewModel.isBusy)
            const Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Loading route...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (viewModel.routeInfo != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Route Summary',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _getTravelModeIcon(travelMode),
                            size: 20,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${viewModel.routeInfo!['distance']} • ${viewModel.routeInfo!['duration']}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      if (viewModel.routeInfo!['trafficDelay'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.traffic,
                                size: 16,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Traffic delay: ${viewModel.routeInfo!['trafficDelay']}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  MapViewModel viewModelBuilder(BuildContext context) => MapViewModel(
        originCoordinates: originCoordinates,
        destinationCoordinates: destinationCoordinates,
        travelMode: travelMode,
      );

  IconData _getTravelModeIcon(String mode) {
    switch (mode.toUpperCase()) {
      case 'WALK':
        return Icons.directions_walk;
      case 'BICYCLE':
        return Icons.directions_bike;
      case 'TRANSIT':
        return Icons.directions_bus;
      default:
        return Icons.directions_car;
    }
  }
}
