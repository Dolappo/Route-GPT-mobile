import 'package:route_gpt/ui/bottom_sheets/notice/notice_sheet.dart';
import 'package:route_gpt/ui/dialogs/create_account/create_account_dialog.dart';
import 'package:route_gpt/ui/dialogs/info_alert/info_alert_dialog.dart';
import 'package:route_gpt/ui/views/home/home_view.dart';
import 'package:route_gpt/ui/views/onboarding/onboarding_view.dart';
import 'package:route_gpt/ui/views/startup/startup_view.dart';
import 'package:stacked/stacked_annotations.dart';
import 'package:stacked_services/stacked_services.dart';

import '../services/auth_service.dart';
import '../services/gemini_service.dart';
import '../services/local_storage_service.dart';
import '../services/maps_service.dart';
import '../services/usage_service.dart';
import '../ui/styles/theme_manager.dart';
import '../ui/views/chat/chat_view.dart';
// @stacked-import

@StackedApp(
  routes: [
    MaterialRoute(page: ChatView),
    MaterialRoute(page: HomeView),
    MaterialRoute(page: StartupView, initial: true),
    MaterialRoute(page: OnboardingView),
// @stacked-route
  ],
  dependencies: [
    LazySingleton(classType: BottomSheetService),
    LazySingleton(classType: DialogService),
    LazySingleton(classType: NavigationService),
    LazySingleton(classType: GeminiService),
    LazySingleton(classType: MapsService),
    LazySingleton(classType: LocalStorageService),
    LazySingleton(classType: UsageService),
    LazySingleton(classType: AuthService),
    LazySingleton(classType: ThemeNotifier),
    // @stacked-service
  ],
  bottomsheets: [
    StackedBottomsheet(classType: NoticeSheet),
    // @stacked-bottom-sheet
  ],
  dialogs: [
    StackedDialog(classType: InfoAlertDialog),
    StackedDialog(classType: CreateAccountDialog),
// @stacked-dialog
  ],
  logger: StackedLogger(),
)
class App {}
