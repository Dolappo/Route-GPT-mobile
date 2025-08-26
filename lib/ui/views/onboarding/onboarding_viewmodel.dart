import 'package:route_gpt/app/app.locator.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import '../../../app/app.router.dart';

class OnboardingViewModel extends BaseViewModel {
  final _nav = locator<NavigationService>();

  void navToHome() {
    _nav.navigateTo(Routes.chatView);
  }

  List<Map<String, dynamic>> pages = [{}, {}, {}];
}
