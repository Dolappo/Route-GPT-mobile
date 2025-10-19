import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:stacked/stacked.dart';

class NetworkService with ListenableServiceMixin {
  final Connectivity _connectivity = Connectivity();
  final ReactiveValue<bool> _isConnected = ReactiveValue<bool>(true);
  final ReactiveValue<ConnectivityResult> _connectivityResult = ReactiveValue<ConnectivityResult>(ConnectivityResult.none);
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  bool get isConnected => _isConnected.value;
  ConnectivityResult get connectivityResult => _connectivityResult.value;

  NetworkService() {
    listenToReactiveValues([_isConnected, _connectivityResult]);
    _initializeConnectivity();
  }

  Future<void> _initializeConnectivity() async {
    try {
      // Get initial connectivity status
      final result = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(result);

      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
        _updateConnectivityStatus(result);
      });
    } catch (e) {
      print('Error initializing connectivity: $e');
      _isConnected.value = false;
    }
  }

  void _updateConnectivityStatus(ConnectivityResult result) {
    _connectivityResult.value = result;
    
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.mobile:
      case ConnectivityResult.ethernet:
        _isConnected.value = true;
        break;
      case ConnectivityResult.none:
      case ConnectivityResult.bluetooth:
      case ConnectivityResult.vpn:
      case ConnectivityResult.other:
        _isConnected.value = false;
        break;
    }
  }

  Future<bool> checkInternetConnection() async {
    if (!isConnected) return false;
    
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
