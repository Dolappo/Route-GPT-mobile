import 'package:flutter/material.dart';
import 'package:route_gpt/ui/styles/style.dart';
import 'package:stacked/stacked.dart';

import '../../../app/app.locator.dart';
import '../../../models/chat_message.dart';
import '../../../models/firestore_message.dart';
import '../../../services/auth_service.dart';
import '../../../services/chat_history_service.dart';
import '../../../services/firestore_memory_service.dart';
import '../../../services/gemini_service.dart';
import '../../../services/maps_service.dart';
import '../../../services/network_service.dart';
import '../../../services/unified_response_service.dart';
import '../../../services/usage_service.dart';

class ChatViewModel extends ReactiveViewModel {
  final _geminiService = locator<GeminiService>();
  final _mapsService = locator<MapsService>();
  final _usageService = locator<UsageService>();
  final _authService = locator<AuthService>();
  final _chatHistoryService = locator<ChatHistoryService>();
  final _networkService = locator<NetworkService>();
  final _firestoreMemoryService = locator<FirestoreMemoryService>();
  final _unifiedResponseService = locator<UnifiedResponseService>();
  final _theme = locator<ThemeNotifier>();

  final List<ChatMessage> messages = [];
  final ScrollController scrollController = ScrollController();
  int _remainingFreePrompts = 0;
  bool _hasShownCreateAccountDialog = false;
  bool _hasLocationPermission = false;
  bool _isTyping = false;

  bool get isProcessing => isBusy;
  bool get hasLocationPermission => _hasLocationPermission;
  int get remainingFreePrompts => _remainingFreePrompts;
  bool get hasShownCreateAccountDialog => _hasShownCreateAccountDialog;
  bool get isAuthenticated => _authService.isAuthenticated;
  bool get isOnline => _networkService.isConnected;
  bool get isSyncing => _chatHistoryService.isSyncing;
  int get pendingMessagesCount => _chatHistoryService.pendingMessages.length;
  bool get hasMigrationData => _chatHistoryService.hasMigrationData;
  bool get isTyping => _isTyping;
  String? get currentUserName => _authService.user?.displayName;
  String? get currentUserFirstName => _authService.user?.displayName != null
    ? _authService.user!.displayName!.split(' ').first
    : null;
  String? get currentUserEmail => _authService.user?.email;
  String? get currentUserPhotoUrl => _authService.user?.photoURL;

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  List<ListenableServiceMixin> get listenableServices =>
      [_authService, _networkService, _chatHistoryService, _theme];

  Future<void> initialize() async {
    _remainingFreePrompts = await _usageService.getRemainingFreePrompts();
    _hasShownCreateAccountDialog =
        await _usageService.hasShownCreateAccountDialog();

    // Initialize chat history service (loads from Hive)
    await _chatHistoryService.initialize();

    // Load messages from Hive
    messages.addAll(_chatHistoryService.todayMessages);

    // Check for migration data and show prompt if needed
    if (hasMigrationData && isAuthenticated) {
      _showMigrationDialog();
    }

    notifyListeners();
  }

  bool isLightTheme = false;

  void toggleTheme(val) {
    _theme.switchMode();
    isLightTheme = val;
    notifyListeners();
  }

  void _showMigrationDialog() {
    // Show dialog to migrate local chats to user account
    // This will be implemented in the UI layer
  }

  void showCreateAccountDialogIfNeeded() {
    if (!_hasShownCreateAccountDialog && !isAuthenticated) {
      showCreateAccountDialog();
    }
  }

  void showCreateAccountDialog() {
    _hasShownCreateAccountDialog = true;
    _usageService.markCreateAccountDialogShown();
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: message,
      isUser: true,
      status: MessageStatus.sent,
      timestamp: DateTime.now(),
    );
    messages.add(userMessage);
    await _chatHistoryService.saveMessage(userMessage);
    notifyListeners();
    _scrollToBottom();

    // Network check for authenticated users
    if (isAuthenticated && !isOnline) {
      messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "You're offline. Connect to the internet to send messages.",
        isUser: false,
        status: MessageStatus.error,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
      return;
    }

    // Free prompt check
    if (!await _usageService.canMakePrompt()) {
      messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text:
            "You've used all your free prompts. Please create an account to get more!",
        isUser: false,
        status: MessageStatus.error,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
      return;
    }

    await _usageService.usePrompt();
    _remainingFreePrompts = await _usageService.getRemainingFreePrompts();

    // Show typing indicator
    _isTyping = true;
    notifyListeners();

    try {
      // Get conversation history for context (only for authenticated users)
      List<Map<String, dynamic>> conversationHistory = [];
      if (isAuthenticated) {
        conversationHistory = await _firestoreMemoryService.getGeminiContext();
      }

      // Determine query type and extract context
      final queryType = _unifiedResponseService.determineQueryType(message);
      final locationInfo = isAuthenticated && conversationHistory.isNotEmpty
          ? await runBusyFuture(_geminiService.extractLocationInfoWithContext(
              message, conversationHistory))
          : await runBusyFuture(_geminiService.extractLocationInfo(message));
      print("Gotten response");

      // Build context data for unified response service
      Map<String, dynamic> contextData = {
        'queryType': queryType,
        'travelMode': locationInfo['travelMode'] ?? 'DRIVE',
        'needsCurrentLocation': locationInfo['needsCurrentLocation'] ?? false,
        'query': message, // Pass the original query for better context
      };

      // Add location data if available
      if (locationInfo['origin'] != null) {
        print("I am here cos not null");
        // If origin is "current_location", get actual coordinates
        if (locationInfo['origin'] == 'current_location') {
          print("I am here cos current location");
          try {
            final currentLocation = await _mapsService.getCurrentLocation();
      contextData['origin'] =
        '${currentLocation.latitude},${currentLocation.longitude}';
            _hasLocationPermission = true;
          } catch (e) {
            print('Error getting current location: $e');
            // Ask user to provide location
            messages.add(ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text:
                  'I need your current location to provide directions. Please enable location access in your device settings, or tell me your starting location.',
              isUser: false,
              status: MessageStatus.error,
              timestamp: DateTime.now(),
            ));
            notifyListeners();
            return;
          }
        } else {
          contextData['origin'] = locationInfo['origin'];
        }
      }
      if (locationInfo['destination'] != null) {
        contextData['destination'] = locationInfo['destination'];
      }

      // Handle location-based queries (nearest, nearby, etc.)
      if (queryType == 'places' &&
          (message.toLowerCase().contains('nearest') ||
              message.toLowerCase().contains('nearby') ||
              message.toLowerCase().contains('closest'))) {
        // Check if we need current location for nearby searches
        if (locationInfo['needsCurrentLocation'] == true) {
          try {
            final currentLocation = await _mapsService.getCurrentLocation();
            contextData['latitude'] = currentLocation.latitude;
            contextData['longitude'] = currentLocation.longitude;
            _hasLocationPermission = true;
          } catch (e) {
            print('Error getting current location: $e');
            // If location permission is denied, ask user to provide location
            if (e.toString().contains('Location permission denied')) {
              messages.add(ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                text:
                    'I need your location to find nearby places. Please enable location access in your device settings, or tell me which area you\'re in (e.g., "nearest hospital in Mushin").',
                isUser: false,
                status: MessageStatus.error,
                timestamp: DateTime.now(),
              ));
              notifyListeners();
              return;
            }
          }
        }
      }

      // Get current location if needed for other queries
      if (contextData['needsCurrentLocation'] == true &&
          contextData['latitude'] == null) {
        try {
          final currentLocation = await _mapsService.getCurrentLocation();
          contextData['currentLatitude'] = currentLocation.latitude;
          contextData['currentLongitude'] = currentLocation.longitude;
          _hasLocationPermission = true;
        } catch (e) {
          print('Error getting current location: $e');
          if (e.toString().contains('Location permission denied')) {
            messages.add(ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text:
                  'I need location permission to provide accurate directions. Please enable location access in your device settings.',
              isUser: false,
              status: MessageStatus.error,
              timestamp: DateTime.now(),
            ));
            notifyListeners();
            return;
          }
        }
      }

      // Process query through unified response service
      final response = await runBusyFuture(_unifiedResponseService.processQuery(
        userQuery: message,
        queryType: queryType,
        contextData: contextData,
        conversationHistory: conversationHistory,
      ));

      // Create assistant message
      final assistantMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: response,
        isUser: false,
        status: MessageStatus.sent,
        timestamp: DateTime.now(),
        metadata: {
          'queryType': queryType,
          'hasContext': conversationHistory.isNotEmpty,
        },
      );
      messages.add(assistantMessage);
      await _chatHistoryService.saveMessage(assistantMessage);

      // Save messages to Firestore short-term memory (only for authenticated users)
      if (isAuthenticated) {
        try {
          final userFirestoreMessage =
              FirestoreMessage.fromChatMessage(userMessage);
          final assistantFirestoreMessage =
              FirestoreMessage.fromChatMessage(assistantMessage);
          await _firestoreMemoryService
              .addMessages([userFirestoreMessage, assistantFirestoreMessage]);
          print(
              'Successfully saved conversation to Firestore short-term memory');
        } catch (e) {
          print('Error saving to Firestore short-term memory: $e');
        }
      }

      notifyListeners();
      _scrollToBottom();
    } catch (e) {
      // Hide typing indicator on error
      _isTyping = false;
      String errorMessage =
          'Sorry, I encountered an error while processing your request.';
      if (e.toString().contains('Location permission denied')) {
        errorMessage =
            'I need location permission to provide directions. Please enable location access in your device settings.';
      } else if (e.toString().contains('No routes found')) {
        errorMessage =
            "I couldn't find a route between those locations. Please check the addresses and try again.";
      } else if (e.toString().contains('Place not found')) {
        errorMessage =
            "I couldn't find one of the locations you mentioned. Please provide more specific addresses.";
      }

      final errorMsg = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: errorMessage,
        isUser: false,
        status: MessageStatus.error,
        timestamp: DateTime.now(),
      );
      messages.add(errorMsg);
      await _chatHistoryService.saveMessage(errorMsg);
      notifyListeners();
    } finally {
      // Always hide typing indicator
      _isTyping = false;
      notifyListeners();
    }
  }

  void retryMessage(int messageIndex) {
    // Find the most recent user message before the provided index and resend it
    for (int i = messageIndex - 1; i >= 0; i--) {
      final prev = messages[i];
      if (prev.isUser) {
        sendMessage(prev.text);
        return;
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> logout() async {
    await _authService.signOut();
    _remainingFreePrompts = await _usageService.getRemainingFreePrompts();
    messages.clear();

    // Clear Firestore short-term memory session
    try {
      await _firestoreMemoryService.clearSession();
      print('Cleared Firestore short-term memory session');
    } catch (e) {
      print('Error clearing Firestore session: $e');
    }

    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    try {
      // Check if Google Sign-In is available
      final isAvailable = await _authService.isGoogleSignInAvailable();
      if (!isAvailable) {
        messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: 'Google Sign-In is not available on this device.',
          isUser: false,
          status: MessageStatus.error,
          timestamp: DateTime.now(),
        ));
        notifyListeners();
        return false;
      }

      final cred = await _authService.signInWithGoogle();
      if (cred != null) {
        _remainingFreePrompts = await _usageService.getRemainingFreePrompts();
        await _chatHistoryService.onAuthStateChanged();
        messages.addAll(_chatHistoryService.todayMessages);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error in signInWithGoogle: $e');
      // Show error message to user
      String errorMessage = 'Sign-in failed. Please try again.';
      if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('cancelled')) {
        errorMessage = 'Sign-in was cancelled.';
      }

      messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: errorMessage,
        isUser: false,
        status: MessageStatus.error,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      await _authService.signInWithEmail(email: email, password: password);
      _remainingFreePrompts = await _usageService.getRemainingFreePrompts();
      await _chatHistoryService.onAuthStateChanged();
      messages.addAll(_chatHistoryService.todayMessages);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearTodayChat() async {
    messages.clear();
    await _chatHistoryService.clearTodayHistory();
    notifyListeners();
  }

  Future<void> forceSync() async {
    if (isAuthenticated && isOnline) {
      await _chatHistoryService.forceSync();
      messages.clear();
      messages.addAll(_chatHistoryService.todayMessages);
      notifyListeners();
    }
  }

  Future<void> migrateLocalChats() async {
    if (isAuthenticated && hasMigrationData) {
      try {
        await _chatHistoryService
            .migrateLocalChatsToUser(_authService.user!.uid);
        notifyListeners();
      } catch (e) {
        // Handle migration error
        print('Migration failed: $e');
      }
    }
  }
}
