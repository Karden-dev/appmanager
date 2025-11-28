// lib/providers/shop_provider.dart

import 'package:flutter/foundation.dart';
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/repositories/shop_repository.dart';
import 'package:wink_manager/providers/network_provider.dart';

class ShopProvider with ChangeNotifier {
  ShopRepository _repository;
  final NetworkProvider _networkProvider;

  // --- État ---
  List<Shop> _shops = [];
  Map<String, int> _stats = {'total': 0, 'active': 0, 'inactive': 0};
  
  bool _isLoading = false;
  String? _error;

  // --- Filtres ---
  String _searchQuery = '';
  String? _statusFilter; // null = Tous, 'actif', 'inactif'

  // --- Getters ---
  List<Shop> get shops => _shops;
  Map<String, int> get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get statusFilter => _statusFilter;

  ShopProvider(this._repository, this._networkProvider) {
    _networkProvider.addListener(_onNetworkChange);
  }

  void update(ShopRepository repo) {
    _repository = repo;
  }

  @override
  void dispose() {
    _networkProvider.removeListener(_onNetworkChange);
    super.dispose();
  }

  void _onNetworkChange() {
    if (_networkProvider.isOnline && !_isLoading) {
      loadData(); // Recharger les données fraîches quand on revient en ligne
    }
  }

  // --- Chargement des Données ---

  Future<void> loadData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Charger les stats (API First généralement)
      final statsData = await _repository.fetchStats();
      _stats = statsData;

      // 2. Charger la liste avec les filtres actuels
      await _fetchFilteredShops();

    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Appelé en interne ou quand on change un filtre
  Future<void> _fetchFilteredShops() async {
    try {
      final result = await _repository.fetchShops(
        search: _searchQuery,
        status: _statusFilter,
      );
      _shops = result;
    } catch (e) {
      _error = 'Erreur chargement liste: $e';
      _shops = []; // Ou garder l'ancienne liste si on préfère
    }
  }

  // --- Gestion des Filtres ---

  void setSearch(String query) {
    _searchQuery = query;
    // On recharge la liste avec le nouveau filtre
    // Note: On pourrait filtrer en local si la liste est petite, 
    // mais ici on suit la logique "search API/DB" du repository
    _fetchFilteredShops().then((_) => notifyListeners());
  }

  void setStatusFilter(String? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    _fetchFilteredShops().then((_) => notifyListeners());
  }

  // --- Actions CRUD ---

  Future<void> createShop(Map<String, dynamic> shopData) async {
    try {
      await _repository.createShop(shopData);
      await loadData(); // Recharger tout (stats + liste)
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateShop(int id, Map<String, dynamic> shopData) async {
    try {
      await _repository.updateShop(id, shopData);
      await loadData(); // Recharger pour voir les modifs
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleShopStatus(Shop shop) async {
    try {
      final newStatus = shop.status == 'actif' ? 'inactif' : 'actif';
      await _repository.updateShopStatus(shop.id, newStatus);
      
      // Mise à jour optimiste locale pour la réactivité immédiate
      final index = _shops.indexWhere((s) => s.id == shop.id);
      if (index != -1) {
        // On ne peut pas modifier un champ final, on crée une copie manuelle (ou on recharge)
        // Ici, on recharge tout pour garantir la cohérence des stats
        await loadData(); 
      }
    } catch (e) {
      rethrow;
    }
  }
}