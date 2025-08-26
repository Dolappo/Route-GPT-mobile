import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:route_gpt/app/app.bottomsheets.dart';
import 'package:route_gpt/app/app.dialogs.dart';
import 'package:route_gpt/app/app.locator.dart';
import 'package:route_gpt/app/app.router.dart';
import 'package:route_gpt/ui/styles/theme_manager.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:route_gpt/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize dependencies
  await setupLocator();
  setupDialogUi();
  setupBottomSheetUi();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<MainViewModel>.reactive(
        viewModelBuilder: () => MainViewModel(),
        builder: (context, viewModel, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'RouteGPT',
            theme: viewModel.themeNotifier.getTheme(),
            initialRoute: Routes.startupView,
            navigatorKey: StackedService.navigatorKey,
            onGenerateRoute: StackedRouter().onGenerateRoute,
          );
        });
  }
}

class MainViewModel extends ReactiveViewModel {
  final themeNotifier = ThemeNotifier.getInstance;

  void toggleTheme() {
    themeNotifier.switchMode();
  }

  @override
  List<ListenableServiceMixin> get listenableServices => [themeNotifier];
}
