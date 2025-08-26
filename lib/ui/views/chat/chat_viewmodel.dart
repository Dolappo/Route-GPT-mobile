import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:route_gpt/app/app.dialogs.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import '../../../app/app.locator.dart';
import '../../../services/auth_service.dart';
import '../../../services/gemini_service.dart';
import '../../../services/maps_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/usage_service.dart';

class ChatViewModel extends ReactiveViewModel {
  final _geminiService = locator<GeminiService>();
  final _mapsService = locator<MapsService>();
  final _usageService = locator<UsageService>();
  final _authService = locator<AuthService>();
  final _profileService = locator<ProfileService>();
  final _dialog = locator<DialogService>();

  final List<ChatMessage> messages = [];
  final ScrollController scrollController = ScrollController();
  bool _isProcessing = false;
  bool _hasLocationPermission = false;
  int _remainingFreePrompts = 3;
  bool _hasShownCreateAccountDialog = false;

  bool get isProcessing => _isProcessing;
  bool get hasLocationPermission => _hasLocationPermission;
  int get remainingFreePrompts => _remainingFreePrompts;
  bool get hasShownCreateAccountDialog => _hasShownCreateAccountDialog;
  bool get isAuthenticated => _authService.isAuthenticated;
  String? get currentUserName => _authService.user?.displayName;
  String? get currentUserFirstName => _authService.user?.displayName != null
      ? _authService.user!.displayName!.split(' ').first
      : null;
  String? get currentUserEmail => _authService.user?.email;
  String? get currentUserPhotoUrl => _authService.user?.photoURL;

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> initialize() async {
    _remainingFreePrompts = await _usageService.getRemainingFreePrompts();
    _hasShownCreateAccountDialog =
        await _usageService.hasShownCreateAccountDialog();
    notifyListeners();
  }

  @override
  List<ListenableServiceMixin> get listenableServices => [_authService];

  @override
  void onServiceChanged(ListenableServiceMixin service) async {
    if (service == _authService) {
      // Auth state changed: refresh remaining prompts and UI
      _remainingFreePrompts = await _usageService.getRemainingFreePrompts();
      notifyListeners();
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
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    try {
      final cred = await _authService.signInWithGoogle();
      if (cred != null) {
        _remainingFreePrompts = await _usageService.getRemainingFreePrompts();
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      await _authService.signInWithEmail(email: email, password: password);
      _remainingFreePrompts = await _usageService.getRemainingFreePrompts();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    List<Map<String, dynamic>> memory = [];
    try {
      memory = await _profileService.getMemory();
    } catch (_) {}

    if (!await _usageService.canMakePrompt()) {
      messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text:
            'You\'ve used all your free prompts. Please create an account to get more!',
        isUser: false,
        status: MessageStatus.error,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
      _scrollToBottom();
      return;
    }

    final promptUsed = await _usageService.usePrompt();
    if (!promptUsed) {
      messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: 'Failed to process your request. Please try again.',
        isUser: false,
        status: MessageStatus.error,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
      _scrollToBottom();
      return;
    }

    _remainingFreePrompts = await _usageService.getRemainingFreePrompts();

    messages.add(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: message,
      isUser: true,
      status: MessageStatus.sent,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
    _scrollToBottom();

    _isProcessing = true;
    notifyListeners();

    try {
      final locationInfo =
          await runBusyFuture(_geminiService.extractLocationInfo(message));

      if (locationInfo['error'] != null) {
        messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              'I apologize, but I couldn\'t understand your request. Could you please rephrase it?',
          isUser: false,
          status: MessageStatus.sent,
          timestamp: DateTime.now(),
        ));
        notifyListeners();
        _scrollToBottom();
        return;
      }

      final queryType = locationInfo['queryType'] ?? 'directions';
      final travelMode = locationInfo['travelMode'] ?? 'DRIVE';
      final needsCurrentLocation =
          locationInfo['needsCurrentLocation'] ?? false;

      String origin = locationInfo['origin'] ?? '';
      String destination = locationInfo['destination'] ?? '';

      List<Future> tasks = [];
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
        }());
      } else if (origin.isNotEmpty) {
        tasks.add(() async {
          try {
            final originPlace = await _mapsService.searchPlace(origin);
            originCoordinates = '${originPlace['lat']},${originPlace['lng']}';
          } catch (e) {
            throw Exception('Could not find origin: $origin');
          }
        }());
      }

      if (destination.isNotEmpty) {
        tasks.add(() async {
          try {
            final destPlace = await _mapsService.searchPlace(destination);
            destinationCoordinates = '${destPlace['lat']},${destPlace['lng']}';
          } catch (e) {
            throw Exception('Could not find destination: $destination');
          }
        }());
      } else {
        messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              'I need a destination to provide directions. Where would you like to go?',
          isUser: false,
          status: MessageStatus.sent,
          timestamp: DateTime.now(),
        ));
        notifyListeners();
        _scrollToBottom();
        return;
      }

      try {
        await Future.wait(tasks);
      } catch (e) {
        String errorMessage =
            'Sorry, I encountered an error while processing your request.';
        if (e.toString().contains('Location permission denied')) {
          errorMessage =
              'I need location permission to provide directions. Please enable location access in your device settings.';
        } else if (e.toString().contains('Could not find origin')) {
          errorMessage =
              'I couldn\'t find the starting location. Could you please provide a more specific address?';
        } else if (e.toString().contains('Could not find destination')) {
          errorMessage =
              'I couldn\'t find the destination. Could you please provide a more specific address?';
        }
        messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: errorMessage,
          isUser: false,
          status: MessageStatus.error,
          originalQuery: message,
          timestamp: DateTime.now(),
        ));
        notifyListeners();
        _scrollToBottom();
        return;
      }

      String response;
      final memory = await _profileService.getMemory();
      final contextData = {'memory': memory};

      switch (queryType) {
        case 'route_summary':
        case 'duration':
          final routeData = await runBusyFuture(_mapsService.getRouteSummary(
              originCoordinates!, destinationCoordinates!,
              travelMode: travelMode));
          response = await _geminiService.formatRouteSummary(
                  {...routeData, ...contextData}, message) ??
              'Unable to get route summary';
          break;

        case 'directions':
        default:
          final mapsData = await runBusyFuture(_mapsService.getDirections(
              originCoordinates!, destinationCoordinates!,
              travelMode: travelMode));
          response = await _geminiService
                  .formatResponse({...mapsData, ...contextData}, message) ??
              'Unable to get directions';
          break;
      }

      messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: response,
        isUser: false,
        status: MessageStatus.sent,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
      _scrollToBottom();
    } catch (e) {
      String errorMessage =
          'Sorry, I encountered an error while processing your request.';
      if (e.toString().contains('Location permission denied')) {
        errorMessage =
            'I need location permission to provide directions. Please enable location access in your device settings.';
      } else if (e.toString().contains('No routes found')) {
        errorMessage =
            'I couldn\'t find a route between those locations. Please check the addresses and try again.';
      } else if (e.toString().contains('Place not found')) {
        errorMessage =
            'I couldn\'t find one of the locations you mentioned. Please provide more specific addresses.';
      }
      messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: errorMessage,
        isUser: false,
        status: MessageStatus.error,
        originalQuery: message,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
      _scrollToBottom();
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> retryMessage(int messageIndex) async {
    final message = messages[messageIndex];
    if (message.originalQuery != null) {
      messages.removeAt(messageIndex);
      notifyListeners();
      await sendMessage(message.originalQuery!);
    }
  }

  Future<void> requestLocationPermission() async {
    try {
      await _mapsService.getCurrentLocation();
      _hasLocationPermission = true;
      notifyListeners();
    } catch (e) {
      _hasLocationPermission = false;
      notifyListeners();
    }
  }

  void clearCache() {
    _mapsService.clearCache();
  }

  void showCreateAccountDialogIfNeeded() {
    // Only invoked from ChatView; ensure it doesn't run globally
    Future.delayed(const Duration(milliseconds: 300)).then((_) {
      _dialog.showCustomDialog(variant: DialogType.createAccount);
    });
  }

  void showCreateAccountDialog() {
    _dialog.showCustomDialog(variant: DialogType.createAccount);
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
}

enum MessageStatus {
  sent,
  error,
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final MessageStatus status;
  final String? originalQuery;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.status = MessageStatus.sent,
    this.originalQuery,
    required this.timestamp,
  });

  String get formattedTime {
    return DateFormat('HH:mm').format(timestamp);
  }
}
