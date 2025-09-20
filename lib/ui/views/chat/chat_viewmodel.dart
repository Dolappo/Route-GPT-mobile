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
import '../../../services/profile_service.dart';
import '../../../services/usage_service.dart';

class ChatViewModel extends ReactiveViewModel {
  final _geminiService = locator<GeminiService>();
  final _mapsService = locator<MapsService>();
  final _usageService = locator<UsageService>();
  final _authService = locator<AuthService>();
  final _profileService = locator<ProfileService>();
  final _chatHistoryService = locator<ChatHistoryService>();
  final _networkService = locator<NetworkService>();
  final _firestoreMemoryService = locator<FirestoreMemoryService>();
  final _theme = locator<ThemeNotifier>();

  final List<ChatMessage> messages = [];
  final ScrollController scrollController = ScrollController();
  int _remainingFreePrompts = 0;
  bool _hasShownCreateAccountDialog = false;
  bool _hasLocationPermission = false;

  // Conversational state for missing destination
  bool _awaitingDestination = false;
  bool _awaitingOrigin = false;
  String? _lastOriginCoordinates;
  String? _lastOriginText;
  String? _lastTravelMode;

  bool get isProcessing => isBusy;
  bool get hasLocationPermission => _hasLocationPermission;
  int get remainingFreePrompts => _remainingFreePrompts;
  bool get hasShownCreateAccountDialog => _hasShownCreateAccountDialog;
  bool get isAuthenticated => _authService.isAuthenticated;
  bool get isOnline => _networkService.isConnected;
  bool get isSyncing => _chatHistoryService.isSyncing;
  int get pendingMessagesCount => _chatHistoryService.pendingMessages.length;
  bool get hasMigrationData => _chatHistoryService.hasMigrationData;
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

    // If we're waiting for more info, handle follow-up without extra prompt checks
    if (_awaitingDestination || _awaitingOrigin) {
      await _handleFollowUpReply(replyText: message);
      return;
    }

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

    try {
      // Get conversation history for context (only for authenticated users)
      List<Map<String, dynamic>> conversationHistory = [];
      if (isAuthenticated) {
        conversationHistory = await _firestoreMemoryService.getGeminiContext();
      }

      // Extract location info with or without context
      final locationInfo = isAuthenticated && conversationHistory.isNotEmpty
          ? await runBusyFuture(_geminiService.extractLocationInfoWithContext(message, conversationHistory))
          : await runBusyFuture(_geminiService.extractLocationInfo(message));

      if (locationInfo['error'] != null) {
        final errorMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              "I apologize, but I couldn't understand your request. Could you please rephrase it?",
          isUser: false,
          status: MessageStatus.sent,
          timestamp: DateTime.now(),
        );
        messages.add(errorMessage);
        await _chatHistoryService.saveMessage(errorMessage);
        notifyListeners();
        return;
      }

      final queryType = locationInfo['queryType'] ?? 'directions';
      final travelMode = locationInfo['travelMode'] ?? 'DRIVE';
      final needsCurrentLocation =
          locationInfo['needsCurrentLocation'] ?? false;

      String origin = locationInfo['origin'] ?? '';
      String destination = locationInfo['destination'] ?? '';
      // Keep last origin text to help with follow-up resolution
      if (origin.isNotEmpty) _lastOriginText = origin;

      final tasks = <Future<void> Function()>[];
      String? originCoordinates;
      String? destinationCoordinates;

      if (needsCurrentLocation ||
          origin == 'current_location' ||
          origin.isEmpty) {
        tasks.add(() async {
          try {
            final currentLocation = await _mapsService.getCurrentLocation();
            originCoordinates =
                '${currentLocation.latitude},${currentLocation.longitude}';
            _hasLocationPermission = true;
          } catch (e) {
            throw Exception('Location permission denied');
          }
        });
      }

      if (origin.isNotEmpty && origin != 'current_location') {
        tasks.add(() async {
          try {
            final placeData = await _mapsService.searchPlace(origin);
            print('Origin place data: $placeData');
            originCoordinates = placeData['coordinates'];
            print('Origin coordinates: $originCoordinates');
            if (originCoordinates == null) {
              throw Exception('Could not find origin');
            }
          } catch (e) {
            throw Exception('Could not find origin');
          }
        });
      }

      if (destination.isNotEmpty) {
        tasks.add(() async {
          try {
            final placeData = await _mapsService.searchPlace(destination);
            print('Destination place data: $placeData');
            destinationCoordinates = placeData['coordinates'];
            print('Destination coordinates: $destinationCoordinates');
            if (destinationCoordinates == null) {
              throw Exception('Could not find destination');
            }
          } catch (e) {
            throw Exception('Could not find destination');
          }
        });
      }

      try {
        await Future.wait(tasks.map((task) => task()));
      } catch (e) {
        String errorMessage =
            'Sorry, I encountered an error while processing your request.';
        if (e.toString().contains('Location permission denied')) {
          errorMessage =
              'I need location permission to provide directions. Please enable location access in your device settings.';
        } else if (e.toString().contains('Could not find origin')) {
          errorMessage =
              "I couldn't find the starting location. Could you please provide a more specific address?";
        } else if (e.toString().contains('Could not find destination')) {
          errorMessage =
              "I couldn't find the destination. Please tell me where you'd like to go.";
          // Switch to conversational follow-up mode for destination
          _awaitingDestination = true;
          _awaitingOrigin = false;
          _lastOriginCoordinates = originCoordinates;
          _lastTravelMode = travelMode;
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
        return;
      }

      if (destination.isEmpty) {
        // Ask user for destination, save context to follow up
        _awaitingDestination = true;
        _awaitingOrigin = false;
        _lastOriginCoordinates = originCoordinates;
        _lastTravelMode = travelMode;

        final noDestMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              'I need a destination to provide directions. Where would you like to go?',
          isUser: false,
          status: MessageStatus.sent,
          timestamp: DateTime.now(),
        );
        messages.add(noDestMessage);
        await _chatHistoryService.saveMessage(noDestMessage);
        notifyListeners();
        return;
      }

      await _buildAndSendResponse(
        queryType: queryType,
        travelMode: travelMode,
        originCoordinates: originCoordinates!,
        destinationCoordinates: destinationCoordinates!,
        originalQuery: message,
      );
    } catch (e) {
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
    }
  }

  // Handle follow-up flow when awaiting extra info from the user (origin/destination)
  Future<void> _handleFollowUpReply({required String replyText}) async {
    final travelMode = _lastTravelMode ?? 'DRIVE';
    String? originCoordinates = _lastOriginCoordinates;
    String? destinationCoordinates;

    try {
      // Get conversation history for context (only for authenticated users)
      List<Map<String, dynamic>> conversationHistory = [];
      if (isAuthenticated) {
        conversationHistory = await _firestoreMemoryService.getGeminiContext();
      }

      // Try to parse the follow-up for any explicit origin/destination
      final parsed = isAuthenticated && conversationHistory.isNotEmpty
          ? await _geminiService.extractLocationInfoWithContext(replyText, conversationHistory)
          : await _geminiService.extractLocationInfo(replyText);
      final parsedOriginText = (parsed['origin'] as String?)?.trim() ?? '';
      final parsedDestinationText =
          (parsed['destination'] as String?)?.trim() ?? '';

      // Resolve origin
      if (originCoordinates == null) {
        if (parsedOriginText.isNotEmpty) {
          final placeData = await _mapsService.searchPlace(parsedOriginText);
          originCoordinates = placeData['coordinates'] ??
              ((placeData['lat'] != null && placeData['lng'] != null)
                  ? '${placeData['lat']},${placeData['lng']}'
                  : null);
        } else if (_lastOriginText != null && _lastOriginText!.isNotEmpty) {
          final placeData = await _mapsService.searchPlace(_lastOriginText!);
          originCoordinates = placeData['coordinates'] ??
              ((placeData['lat'] != null && placeData['lng'] != null)
                  ? '${placeData['lat']},${placeData['lng']}'
                  : null);
        }
      }

      // Resolve destination
      if (parsedDestinationText.isNotEmpty) {
        final placeData = await _mapsService.searchPlace(parsedDestinationText);
        destinationCoordinates = placeData['coordinates'] ??
            ((placeData['lat'] != null && placeData['lng'] != null)
                ? '${placeData['lat']},${placeData['lng']}'
                : null);
      } else {
        // If Gemini didn't extract, assume the reply is the destination
        final placeData = await _mapsService.searchPlace(replyText);
        destinationCoordinates = placeData['coordinates'] ??
            ((placeData['lat'] != null && placeData['lng'] != null)
                ? '${placeData['lat']},${placeData['lng']}'
                : null);
      }

      if (originCoordinates == null) {
        _awaitingOrigin = true;
        _awaitingDestination = false;
        final msg = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              "I'm missing the starting point. Please provide both origin and destination.",
          isUser: false,
          status: MessageStatus.error,
          timestamp: DateTime.now(),
        );
        messages.add(msg);
        await _chatHistoryService.saveMessage(msg);
        notifyListeners();
        return;
      }

      if (destinationCoordinates == null) {
        _awaitingDestination = true;
        _awaitingOrigin = false;
        final msg = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              "I couldn't find that destination. Could you try a different name or include the city?",
          isUser: false,
          status: MessageStatus.error,
          timestamp: DateTime.now(),
        );
        messages.add(msg);
        await _chatHistoryService.saveMessage(msg);
        notifyListeners();
        return;
      }

      // We have both - clear awaiting flags and proceed
      _awaitingDestination = false;
      _awaitingOrigin = false;
      _lastOriginCoordinates = originCoordinates;
      _lastTravelMode = travelMode;

      await _buildAndSendResponse(
        queryType: 'directions',
        travelMode: travelMode,
        originCoordinates: originCoordinates,
        destinationCoordinates: destinationCoordinates,
        originalQuery: replyText,
      );
    } catch (e) {
      final errorMsg = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text:
            'Sorry, I had trouble understanding that. Could you rephrase or provide clearer locations?',
        isUser: false,
        status: MessageStatus.error,
        timestamp: DateTime.now(),
      );
      messages.add(errorMsg);
      await _chatHistoryService.saveMessage(errorMsg);
      notifyListeners();
    }
  }

  Future<void> _buildAndSendResponse({
    required String queryType,
    required String travelMode,
    required String originCoordinates,
    required String destinationCoordinates,
    required String originalQuery,
  }) async {
    String response = '';

    switch (queryType) {
      case 'directions':
        final mapsData = await _mapsService.getDirections(
            originCoordinates, destinationCoordinates,
            travelMode: travelMode);

        Map<String, dynamic> contextData = {};
        List<Map<String, dynamic>> conversationHistory = [];
        if (isAuthenticated) {
          contextData = _chatHistoryService.getContextForAI();
          final userProfile = await _profileService.getUserProfile();
          if (userProfile != null) {
            contextData['userProfile'] = userProfile;
          }
          // Get conversation history for context
          conversationHistory = await _firestoreMemoryService.getGeminiContext();
        }

        response = await _geminiService
                .formatResponseWithContext({...mapsData, ...contextData}, originalQuery, conversationHistory) ??
            'Unable to get directions';
        break;
      case 'traffic':
        final trafficData = await _mapsService.getRouteSummary(
            originCoordinates, destinationCoordinates,
            travelMode: travelMode);

        Map<String, dynamic> contextData = {};
        List<Map<String, dynamic>> conversationHistory = [];
        if (isAuthenticated) {
          contextData = _chatHistoryService.getContextForAI();
          // Get conversation history for context
          conversationHistory = await _firestoreMemoryService.getGeminiContext();
        }

        response = await _geminiService.formatResponseWithContext(
                {...trafficData, ...contextData}, originalQuery, conversationHistory) ??
            'Unable to get traffic information';
        break;
      default:
        response = "I'm not sure how to help with that request.";
    }

    final assistantMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: response,
      isUser: false,
      status: MessageStatus.sent,
      timestamp: DateTime.now(),
      metadata: {
        'queryType': queryType,
        'travelMode': travelMode,
        'originCoordinates': originCoordinates,
        'destinationCoordinates': destinationCoordinates,
        'hasMapData': true,
      },
    );
    messages.add(assistantMessage);

    await _chatHistoryService.saveMessage(assistantMessage);
    
    // Save messages to Firestore short-term memory (only for authenticated users)
    if (isAuthenticated) {
      try {
        // Find the user message that corresponds to this response
        final userMessage = messages.reversed
            .firstWhere((msg) => msg.isUser && msg.text == originalQuery);
        
        // Create FirestoreMessage objects
        final userFirestoreMessage = FirestoreMessage.fromChatMessage(userMessage);
        final assistantFirestoreMessage = FirestoreMessage.fromChatMessage(assistantMessage);
        
        // Save both messages to Firestore
        await _firestoreMemoryService.addMessages([userFirestoreMessage, assistantFirestoreMessage]);
        print('Successfully saved conversation to Firestore short-term memory');
      } catch (e) {
        print('Error saving to Firestore short-term memory: $e');
        // Don't fail the entire operation if Firestore save fails
      }
    }
    
    final newContext = {
      'lastQuery': originalQuery,
      'lastResponse': response,
      'lastTravelMode': travelMode,
      'lastOrigin': originCoordinates,
      'lastDestination': destinationCoordinates,
      'lastInteractionTime': DateTime.now().toIso8601String(),
    };
    await _chatHistoryService.updateUserMemory(newContext);

    notifyListeners();
    _scrollToBottom();
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
