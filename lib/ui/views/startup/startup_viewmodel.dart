import 'package:route_gpt/app/app.locator.dart';
import 'package:route_gpt/app/app.router.dart';
import 'package:route_gpt/services/auth_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import '../../../services/local_storage_service.dart';
import '../../../services/maps_service.dart';

class StartupViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _mapsService = locator<MapsService>();
  final _authService = locator<AuthService>();
  final _localStorageService = locator<LocalStorageService>();

  Future runStartupLogic() async {
    await Future.delayed(const Duration(seconds: 2));

    // Check if this is the first launch
    final isFirstLaunch = await _localStorageService.getFirstTimeLaunchStatus();

    if (isFirstLaunch) {
      // Request location permission on first launch
      try {
        await _mapsService.getCurrentLocation();
        await _localStorageService.persistLocPermStatus(true);
        print('Location permission granted on first launch');
      } catch (e) {
        await _localStorageService.persistLocPermStatus(false);
        print('Location permission not granted on first launch: $e');
        // Continue anyway, permission can be requested later
      }
    }
    isFirstLaunch
        ? _navigationService.replaceWithOnboardingView()
        : _navigationService.replaceWithChatView();
  }
}
