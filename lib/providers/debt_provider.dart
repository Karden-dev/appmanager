// lib/providers/debt_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wink_manager/models/debt.dart';
import 'package:wink_manager/providers/network_provider.dart';
import 'package:wink_manager/repositories/debt_repository.dart';

class DebtStats {
  final int debtorsCount;
  final double totalPending;
  final double totalPaid;
  final double settlementRate;

  DebtStats({
    this.debtorsCount = 0,
    this.totalPending = 0.0,
    this.totalPaid = 0.0,
    this.settlementRate = 0.0,
  });
}

class DebtProvider with ChangeNotifier {
  // --- MODIFIÉ : Retrait de 'final' pour permettre la mise à jour ---
  DebtRepository _repository;
  final NetworkProvider _networkProvider;
  
  static const int _kItemsPerPage = 10; 

  // --- État ---
  List<Debt> _debts = [];
  DebtStats _stats = DebtStats();
  bool _isLoading = false;
  String? _error;

  // --- Filtres ---
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _searchQuery = '';
  int _currentTabIndex = 0; // 0: Pending, 1: Paid

  // --- Pagination ---
  int _page = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // --- Getters ---
  List<Debt> get debts => _debts;
  DebtStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  String get searchQuery => _searchQuery;
  int get currentTabIndex => _currentTabIndex;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;

  DebtProvider(this._repository, this._networkProvider) {
    // Initialisation des dates (Aujourd'hui par défaut)
    _startDate = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    _endDate = DateTime.now().copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
    _networkProvider.addListener(onNetworkChange);
  }
  
  void update(DebtRepository repository) {
    _repository = repository;
  }
  
  @override
  void dispose() {
    _networkProvider.removeListener(onNetworkChange);
    super.dispose();
  }

  void onNetworkChange() {
    if (_networkProvider.isOnline && !_isLoading) {
      loadData(forceApi: true);
    }
  }

  // --- CHARGEMENT DES DONNÉES ---

  /// Charge les données selon l'onglet actif et les filtres
  Future<void> loadData({bool loadMore = false, bool forceApi = false}) async {
    if (loadMore && (_isLoadingMore || !_hasMore)) return;
    
    _error = null;

    if (loadMore) {
      _isLoadingMore = true;
      _page++;
    } else {
      _isLoading = true;
      _page = 1;
      _hasMore = true;
      _debts = []; 
    }
    
    // Notification immédiate pour afficher le spinner si chargement complet
    if (_debts.isEmpty || loadMore) {
        notifyListeners();
    }
    
    try {
      // Détermine le statut en fonction de l'onglet
      // Onglet 0 (En attente) -> 'pending'
      // Onglet 1 (Historique) -> 'paid'
      final String statusFilter = _currentTabIndex == 0 ? 'pending' : 'paid';

      // 1. Charger la liste paginée
      final newDebts = await _repository.fetchDebts(
        startDate: _startDate,
        endDate: _endDate,
        status: statusFilter,
        search: _searchQuery,
        page: _page,
      );
      
      if (loadMore) {
        _debts.addAll(newDebts);
      } else {
        _debts = newDebts;
        // Au premier chargement, on recalcule aussi les statistiques globales
        _calculateGlobalStats();
      }
      
      _hasMore = newDebts.length == _kItemsPerPage;

    } catch (e) {
      _error = 'Échec du chargement: $e';
      _hasMore = false;
    } finally {
      if (loadMore) {
        _isLoadingMore = false;
      } else {
        _isLoading = false;
      }
      notifyListeners();
    }
  }
  
  Future<void> loadMore() async {
    await loadData(loadMore: true);
  }

  /// Calcule les KPIs (Statistiques) en récupérant TOUTES les données locales pour la période
  Future<void> _calculateGlobalStats() async {
    try {
      // On récupère tout le cache pour la période (sans pagination ni filtre de statut)
      // Cela permet d'avoir une vue d'ensemble (Payé + En attente)
      final allDebts = await _repository.getAllDebtsForStats(
        startDate: _startDate,
        endDate: _endDate,
        search: _searchQuery,
      );

      double pendingSum = 0;
      double paidSum = 0;
      final Set<int> debtors = {};

      for (var debt in allDebts) {
        if (debt.status == 'pending') {
          pendingSum += debt.amount;
          debtors.add(debt.shopId);
        } else if (debt.status == 'paid') {
          paidSum += debt.amount;
        }
      }

      final totalDebtAmount = pendingSum + paidSum;
      final rate = totalDebtAmount > 0 ? (paidSum / totalDebtAmount) * 100 : 0.0;

      _stats = DebtStats(
        debtorsCount: debtors.length,
        totalPending: pendingSum,
        totalPaid: paidSum,
        settlementRate: rate,
      );
      // notifyListeners() sera appelé à la fin de loadData
    } catch (e) {
      if (kDebugMode) print("Erreur calcul stats: $e");
    }
  }

  // --- SETTERS ET FILTRES ---

  void setTabIndex(int index) {
    if (_currentTabIndex == index) return;
    _currentTabIndex = index;
    // Réinitialiser la pagination et recharger
    loadData();
  }

  void setDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    loadData();
  }
  
  void setSearch(String query) {
    _searchQuery = query;
    loadData();
  }

  // --- ACTIONS CRUD ---

  Future<void> createDebt(Map<String, dynamic> debtData) async {
    try {
      await _repository.createDebt(debtData);
      await loadData(forceApi: true); // Recharger pour voir la nouvelle dette et mettre à jour les stats
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateDebt(int id, double amount, String comment) async {
    try {
      await _repository.updateDebt(id, amount, comment);
      await loadData(); // Recharger pour mettre à jour l'affichage
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteDebt(int id) async {
    try {
      await _repository.deleteDebt(id);
      // Suppression optimiste de la liste
      _debts.removeWhere((d) => d.id == id);
      _calculateGlobalStats(); // Recalculer les stats après suppression
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> settleDebt(int id) async {
    try {
      await _repository.settleDebt(id);
      // Si on est dans l'onglet "En attente", la dette doit disparaître
      if (_currentTabIndex == 0) {
        _debts.removeWhere((d) => d.id == id);
      }
      // Recalculer les stats (une dette est passée de Pending à Paid)
      _calculateGlobalStats();
      notifyListeners();
      
      // On pourrait aussi recharger toute la liste pour être sûr
      // await loadData(forceApi: true); 
    } catch (e) {
      rethrow;
    }
  }
}