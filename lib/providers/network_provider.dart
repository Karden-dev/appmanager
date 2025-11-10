// lib/providers/network_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  
  // --- MODIFICATION : Le StreamSubscription gère une LISTE (v6.x) ---
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isOnline = true; // Assumer online par défaut
  bool get isOnline => _isOnline;

  NetworkProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Vérification initiale
    try {
      // --- MODIFICATION : checkConnectivity() retourne une LISTE (v6.x) ---
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results); // Passe une LISTE
    } catch (e) {
      if (kDebugMode) {
        print("NetworkProvider: Erreur_initialize: $e");
      }
      _isOnline = false; // Prudence en cas d'erreur
      notifyListeners();
    }

    // Écoute des changements
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen(_handleConnectivityChange); // --- 'listen' attend une LISTE (v6.x) ---
  }

  // --- MODIFICATION : La méthode accepte une LISTE (v6.x) ---
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (kDebugMode) {
      print("NetworkProvider: Résultat connectivité: $results");
    }

    bool wasOnline = _isOnline;
    
    // --- MODIFICATION : Logique pour une LISTE (v6.x) ---
    // Si la liste contient 1 seul élément ET que cet élément est 'none',
    // alors l'appareil est hors ligne.
    // Dans tous les autres cas (ex: [wifi], [mobile], [wifi, mobile], [vpn], [wifi, none]),
    // l'appareil est considéré comme en ligne.
    if (results.length == 1 && results.first == ConnectivityResult.none) {
      _isOnline = false;
    } else {
      _isOnline = true;
    }

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