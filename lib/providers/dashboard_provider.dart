// lib/providers/dashboard_provider.dart

import 'package:flutter/material.dart';
import 'package:wink_manager/models/dashboard_models.dart';
import 'package:wink_manager/services/dashboard_service.dart';

class DashboardProvider with ChangeNotifier {
  final DashboardService _dashboardService;

  DashboardProvider(this._dashboardService);

  // Données pour l'accueil (Top 5)
  DashboardData? _data;
  bool _isLoading = false;
  String? _error;

  // Données pour la page "Tous les marchands" (Top 100+)
  List<ShopRankingItem>? _fullShopRanking;
  bool _isLoadingFullShop = false;

  DashboardData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  List<ShopRankingItem>? get fullShopRanking => _fullShopRanking;
  bool get isLoadingFullShop => _isLoadingFullShop;

  // Charge le Dashboard (Top 5)
  Future<void> loadDashboardData(DateTime startDate, DateTime endDate) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _dashboardService.fetchDashboardData(startDate: startDate, endDate: endDate, limit: 5);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _data = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Charge la liste complète des marchands (Limit 100 ou plus)
  Future<void> loadFullShopRanking(DateTime startDate, DateTime endDate) async {
    _isLoadingFullShop = true;
    notifyListeners();

    try {
      // On demande une limite large (ex: 100) pour avoir tout le monde
      final result = await _dashboardService.fetchDashboardData(startDate: startDate, endDate: endDate, limit: 100);
      _fullShopRanking = result.ranking;
    } catch (e) {
      // En cas d'erreur, on garde la liste vide ou précédente
      debugPrint("Erreur chargement full shop ranking: $e");
    } finally {
      _isLoadingFullShop = false;
      notifyListeners();
    }
  }
}