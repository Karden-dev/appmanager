// lib/providers/remittance_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wink_manager/models/remittance.dart';
import 'package:wink_manager/providers/network_provider.dart';
import 'package:wink_manager/repositories/remittance_repository.dart';

class RemittanceProvider with ChangeNotifier {
  // --- MODIFIÉ : Retrait de 'final' pour permettre la mise à jour ---
  RemittanceRepository _repository;
  final NetworkProvider _networkProvider;
  
  // Alignement sur la pagination définie: 5 éléments par page
  static const int _kItemsPerPage = 5; 

  // --- État de la liste et des données ---
  List<Remittance> _remittances = [];
  RemittanceStats _stats = RemittanceStats();
  bool _isLoading = false;
  String? _error;

  // --- État des filtres et de la pagination ---
  DateTime _selectedDate = DateTime.now();
  String _statusFilter = 'all'; // Filtre par défaut: 'all'
  String _searchQuery = '';
  int _page = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // --- Getters ---
  List<Remittance> get remittances => _remittances;
  RemittanceStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedDate => _selectedDate;
  String get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  RemittanceProvider(this._repository, this._networkProvider) {
    _selectedDate = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    _networkProvider.addListener(onNetworkChange);
  }
  
  // --- NOUVEAU : Méthode pour mettre à jour le repository sans tuer le provider ---
  void update(RemittanceRepository repository) {
    _repository = repository;
  }
  
  @override
  void dispose() {
    _networkProvider.removeListener(onNetworkChange);
    super.dispose();
  }

  void onNetworkChange() {
    if (_networkProvider.isOnline && !_isLoading) {
      // Force le rechargement de la page 1 en cas de retour en ligne
      loadData(forceApi: true);
    }
  }
  
  // --- LOGIQUE DE CHARGEMENT PRINCIPALE (Pagination Infinie) ---

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
      _remittances = []; 
    }
    
    if (_remittances.isEmpty || loadMore) {
        notifyListeners();
    }
    
    try {
      final apiData = await _repository.fetchRemittances(
        date: _selectedDate,
        page: _page,
        status: _statusFilter,
        search: _searchQuery,
      );
      
      if (loadMore) {
        _remittances.addAll(apiData.remittances);
      } else {
        _remittances = apiData.remittances;
      }
      
      _stats = apiData.stats;
      
      // La condition de 'hasMore' se base sur la taille de la dernière page (5)
      _hasMore = apiData.remittances.length == _kItemsPerPage;

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

  // Utilisé par le ScrollController
  Future<void> loadMore() async {
    await loadData(loadMore: true);
  }
  
  // --- SETTERS DE FILTRE ---

  void setDate(DateTime newDate) {
    _selectedDate = newDate;
    loadData(); 
  }
  
  void setStatusFilter(String status) {
    _statusFilter = status;
    loadData(); 
  }
  
  void setSearch(String query) {
    _searchQuery = query;
    loadData(); 
  }
  
  // --- ACTIONS (avec Feedback Synchro) ---
  
  // Forcer la synchronisation des données (Appelé par le bouton "Sync")
  Future<void> syncData() async {
    _isSyncing = true;
    notifyListeners();
    try {
      // Force le rechargement de la page 1 depuis l'API, ce qui met à jour le cache
      await loadData(loadMore: false, forceApi: true);
      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      _isSyncing = false;
      notifyListeners();
      rethrow;
    }
  }

  // Marquer comme payé
  Future<void> markAsPaid(int remittanceId) async {
    try {
      await _repository.markAsPaid(remittanceId);
      await loadData(forceApi: true); 
    } catch (e) {
      rethrow;
    }
  }
  
  // Éditer les infos de paiement
  Future<void> updatePaymentDetails(int shopId, String name, String phone, String operator) async {
    try {
      await _repository.updateShopPaymentDetails(shopId, name, phone, operator);
      // On recharge les données pour mettre à jour la liste sans écraser le cache.
      await loadData(); 
    } catch (e) {
      rethrow;
    }
  }
}