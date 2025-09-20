import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:route_gpt/models/chat_message.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'app/app.locator.dart';
import 'app/app.router.dart';
import 'firebase_options.dart';
import 'ui/styles/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Setup service locator
  setupLocator();
  await Hive.initFlutter();
  Hive.registerAdapter(ChatMessageAdapter());

  // Initialize Hive (this will be done by HiveChatService)

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
