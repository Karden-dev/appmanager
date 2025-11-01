// lib/providers/network_provider.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  NetworkProvider() {
    // Initialiser avec l'état actuel
    initialize();
  }

  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results.firstWhere((r) => r != ConnectivityResult.none, orElse: () => ConnectivityResult.none));
    
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
       _updateStatus(results.firstWhere((r) => r != ConnectivityResult.none, orElse: () => ConnectivityResult.none));
    });
  }

  void _updateStatus(ConnectivityResult result) {
    final newStatus = (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi);
    if (newStatus != _isOnline) {
      _isOnline = newStatus;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }
}