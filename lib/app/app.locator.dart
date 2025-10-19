// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// StackedLocatorGenerator
// **************************************************************************

// ignore_for_file: public_member_api_docs, implementation_imports, depend_on_referenced_packages

import 'package:get_it/get_it.dart';
import 'package:route_gpt/ui/styles/style.dart';
import 'package:stacked_services/stacked_services.dart';

import '../services/auth_service.dart';
import '../services/chat_history_service.dart';
import '../services/cost_estimator_service.dart';
import '../services/distance_service.dart';
import '../services/event_service.dart';
import '../services/firestore_memory_service.dart';
import '../services/fuel_tracker_service.dart';
import '../services/gemini_service.dart';
import '../services/hive_chat_service.dart';
import '../services/local_storage_service.dart';
import '../services/maps_service.dart';
import '../services/network_service.dart';
import '../services/places_service.dart';
import '../services/profile_service.dart';
import '../services/unified_response_service.dart';
import '../services/usage_service.dart';

final locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton(() => NavigationService());
  locator.registerLazySingleton(() => DialogService());
  locator.registerLazySingleton(() => SnackbarService());
  locator.registerLazySingleton(() => BottomSheetService());

  locator.registerLazySingleton(() => MapsService());
  locator.registerLazySingleton(() => GeminiService());
  locator.registerLazySingleton(() => LocalStorageService());
  locator.registerLazySingleton(() => AuthService());
  locator.registerLazySingleton(() => UsageService());
  locator.registerLazySingleton(() => ProfileService());
  locator.registerLazySingleton(() => NetworkService());
  locator.registerLazySingleton(() => FirestoreMemoryService());
  locator.registerLazySingleton(() => PlacesService());
  locator.registerLazySingleton(() => DistanceService());
  locator.registerLazySingleton(() => CostEstimatorService());
  locator.registerLazySingleton(() => FuelTrackerService());
  locator.registerLazySingleton(() => EventService());
  locator.registerLazySingleton(() => UnifiedResponseService());
  locator.registerLazySingleton(() => ThemeNotifier.getInstance);

  // Register HiveChatService first
  locator.registerLazySingleton(() => HiveChatService());

  // Register ChatHistoryService with HiveChatService dependency
  locator.registerLazySingleton(
      () => ChatHistoryService(locator<HiveChatService>()));
}
