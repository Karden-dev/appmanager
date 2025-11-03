// lib/providers/network_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  
  // --- MODIFICATION : Le StreamSubscription gère un résultat UNIQUE (v3.x) ---
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  bool _isOnline = true; // Assumer online par défaut
  bool get isOnline => _isOnline;

  NetworkProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Vérification initiale
    try {
      // --- MODIFICATION : checkConnectivity() retourne un résultat UNIQUE (v3.x) ---
      final result = await _connectivity.checkConnectivity();
      _handleConnectivityChange(result); // Passe un UNIQUE
    } catch (e) {
      if (kDebugMode) {
        print("NetworkProvider: Erreur_initialize: $e");
      }
      _isOnline = false; // Prudence en cas d'erreur
      notifyListeners();
    }

    // Écoute des changements
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen(_handleConnectivityChange); // --- 'listen' attend un UNIQUE (v3.x) ---
  }

  // --- MODIFICATION : La méthode accepte un résultat UNIQUE (v3.x) ---
  void _handleConnectivityChange(ConnectivityResult result) {
    if (kDebugMode) {
      print("NetworkProvider: Résultat connectivité: $result");
    }

    bool wasOnline = _isOnline;
    
    // --- MODIFICATION : Logique pour un résultat UNIQUE (v3.x) ---
    _isOnline = (result != ConnectivityResult.none);

    if (kDebugMode) {
      print("NetworkProvider: Statut Online déterminé: $_isOnline");
    }

    // Notifie seulement si le statut a changé
    if (wasOnline != _isOnline) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}