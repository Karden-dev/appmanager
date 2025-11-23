// lib/providers/order_provider.dart

import 'package:flutter/material.dart';
import 'package:wink_manager/models/admin_order.dart'; 
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/models/deliveryman.dart'; 
import 'package:wink_manager/repositories/order_repository.dart'; 
import 'package:wink_manager/models/return_tracking.dart'; 

// --- Logique de Tri par Lieu (INCHANGÉE) ---
const List<String> _locationKeywords = [
  'bastos', 'etoudi', 'ngousso', 'mvan', 'messa', 'centre ville', 'nkomo',
  'mimboman', 'obia', 'elig', 'jouvence', 'odza', 'emana', 'nkouloulou',
  'mokolo', 'simbock', 'ekounou', 'mfandena'
];
String _normalize(String s) {
  return s.toLowerCase()
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ûü]'), 'u')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
String? _extractLocationKeyword(String? locationString) {
  if (locationString == null || locationString.isEmpty) return null;
  String normalized = _normalize(locationString);
  List<String> words = normalized.split(' ');
  for (final word in words) {
    if (word.length < 3) continue;
    for (final keyword in _locationKeywords) {
      if (word.contains(keyword) || keyword.contains(word)) {
        return keyword[0].toUpperCase() + keyword.substring(1);
      }
    }
  }
  return null;
}
String? _getOrderLocationKey(AdminOrder order) {
  const unprocessedStatuses = ['pending', 'in_progress', 'ready_for_pickup'];
  if (!unprocessedStatuses.contains(order.status)) return null;
  return _extractLocationKeyword(order.deliveryLocation);
}
// --- Fin de la logique de Tri ---


class OrderProvider with ChangeNotifier {
  final OrderRepository _orderRepository;

  OrderProvider(this._orderRepository);
  
  // --- NOUVEAU : Constante de pagination ---
  static const int _kOrdersPerPage = 10;

  List<AdminOrder> _orders = []; 
  List<AdminOrder> _hubPreparationOrders = [];
  List<ReturnTracking> _pendingReturns = [];
  
  bool _isLoading = false;
  String? _error;
  
  // Filtres
  DateTime _startDate = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  DateTime _endDate = DateTime.now().copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
  String _statusFilter = ''; 
  String _searchFilter = '';
  bool _sortByLocation = false;

  // --- NOUVEAU : État de pagination des commandes ---
  int _orderPage = 1;
  bool _isLoadingMoreOrders = false;
  bool _hasMoreOrders = true;
  // --- FIN NOUVEAU ---

  // Getters
  List<AdminOrder> get hubPreparationOrders => _hubPreparationOrders; 
  List<ReturnTracking> get pendingReturns => _pendingReturns; 
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get sortByLocation => _sortByLocation;
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  String get statusFilter => _statusFilter;
  String get searchFilter => _searchFilter;

  // --- NOUVEAU : Getters de pagination ---
  bool get isLoadingMoreOrders => _isLoadingMoreOrders;
  bool get hasMoreOrders => _hasMoreOrders;
  // --- FIN NOUVEAU ---

  List<AdminOrder> get orders {
    if (!_sortByLocation) {
      // Le tri par date est déjà géré par le repo (orderBy: 'created_at DESC')
      return _orders;
    }
    // Le tri par lieu ne s'applique que sur la liste déjà chargée
    _orders.sort((a, b) {
      const unprocessedStatuses = ['pending', 'in_progress', 'ready_for_pickup'];
      final isUnprocessedA = unprocessedStatuses.contains(a.status);
      final isUnprocessedB = unprocessedStatuses.contains(b.status);
      if (isUnprocessedA && !isUnprocessedB) return -1;
      if (!isUnprocessedA && isUnprocessedB) return 1;
      if (isUnprocessedA && isUnprocessedB) {
        final keyA = _getOrderLocationKey(a);
        final keyB = _getOrderLocationKey(b);
        if (keyA == keyB) {
          return a.createdAt.compareTo(b.createdAt);
        }
        if (keyA == null) return 1;
        if (keyB == null) return -1;
        return keyA.compareTo(keyB);
      }
      // Le tri par défaut est déjà 'created_at DESC'
      return 0; 
    });
    return _orders;
  }
  
  void toggleSortByLocation() {
    _sortByLocation = !_sortByLocation;
    notifyListeners(); 
  }
  void setDateRange(DateTime start, DateTime end) {
    _startDate = start.copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    _endDate = end.copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
    loadOrders(); // Recharge la page 1
  }
  void setStatusFilter(String status) {
    _statusFilter = status;
    loadOrders(); // Recharge la page 1
  }
  void setSearchFilter(String query) {
    _searchFilter = query;
    loadOrders(); // Recharge la page 1
  }

  // --- MODIFIÉ : Gestion de la pagination (loadMore) ---
  Future<void> loadOrders({bool loadMore = false}) async {
    // Protection contre les appels multiples
    if (loadMore && _isLoadingMoreOrders) return;
    if (loadMore && !_hasMoreOrders) return;
    
    _error = null;

    if (loadMore) {
      _isLoadingMoreOrders = true;
      _orderPage++;
    } else {
      _isLoading = true;
      _orderPage = 1;
      _hasMoreOrders = true;
      // Vide la liste pour un refresh
      _orders = []; 
    }
    notifyListeners(); 
    
    try {
      final newOrders = await _orderRepository.fetchAdminOrders(
        startDate: _startDate,
        endDate: _endDate,
        statusFilter: _statusFilter,
        searchFilter: _searchFilter,
        page: _orderPage, // <-- NOUVEAU
        limit: _kOrdersPerPage, // <-- NOUVEAU
      );
      
      if (loadMore) {
        _orders.addAll(newOrders); // Ajoute les nouvelles commandes
      } else {
        _orders = newOrders; // Remplace les commandes
      }
      
      // Met à jour s'il y a plus de pages
      _hasMoreOrders = newOrders.length == _kOrdersPerPage;

    } catch (e) {
      _error = 'Échec du chargement des commandes: $e';
      _hasMoreOrders = false; // Arrête la pagination en cas d'erreur
    } finally {
      if (loadMore) {
        _isLoadingMoreOrders = false;
      } else {
        _isLoading = false;
      }
      notifyListeners();
    }
  }
  // --- FIN MODIFICATION ---

  // --- NOUVELLE MÉTHODE : Pour l'UI ---
  Future<void> loadMoreOrders() async {
    await loadOrders(loadMore: true);
  }
  // --- FIN NOUVELLE MÉTHODE ---


  // --- MÉTHODES DU HUB (Préparation) ---
  Future<void> loadOrdersToPrepare() async { 
     _isLoading = true;
     _error = null;
     notifyListeners();
     try {
       // La pagination n'est pas appliquée ici, car c'est un écran de "tâches"
       final orders = await _orderRepository.fetchOrdersToPrepare();
       _hubPreparationOrders = orders; 
     } catch (e) {
       _error = 'Échec du chargement des commandes à préparer: $e';
     } finally {
       _isLoading = false;
       notifyListeners();
     }
  }
  
  Future<void> markOrderAsReady(int orderId) async { 
     try {
       await _orderRepository.markOrderAsReady(orderId);
       await loadOrdersToPrepare();
     } catch (e) {
       rethrow; 
     }
  }
  
  // --- MÉTHODES DU HUB (Retours) ---
  Future<void> loadPendingReturns({
    int? deliverymanId, 
    DateTime? startDate, 
    DateTime? endDate,
  }) async {
     _isLoading = true;
     _error = null;
     notifyListeners();
     try {
       // Pas de pagination ici non plus
       final returns = await _orderRepository.fetchPendingReturns(
         deliverymanId: deliverymanId,
         startDate: startDate,
         endDate: endDate,
       );
       _pendingReturns = returns; 
     } catch (e) {
       _error = 'Échec du chargement des retours: $e';
     } finally {
       _isLoading = false;
       notifyListeners();
     }
  }
  
  Future<void> confirmHubReception(int trackingId) async {
    try {
      await _orderRepository.confirmHubReception(trackingId);
      await loadPendingReturns();
    } catch (e) {
      rethrow; 
    }
  }

  // --- MÉTHODES D'ÉDITION ET D'ACTION (Utilisées par les détails/édition) ---
  
  Future<AdminOrder> fetchOrderById(int orderId) async {
    try {
      return await _orderRepository.fetchOrderById(orderId);
    } catch (e) {
      rethrow; 
    }
  }
  
  Future<void> saveOrder(Map<String, dynamic> orderData, int? orderId) async {
    try {
      await _orderRepository.saveOrder(orderData, orderId);
      await loadOrders(); // Recharge la page 1
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> deleteOrder(int orderId) async {
    try {
      await _orderRepository.deleteOrder(orderId);
      // Supprime l'élément de la liste en mémoire au lieu de recharger
      _orders.removeWhere((order) => order.id == orderId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<List<Shop>> searchShops(String query) async {
    try {
      return await _orderRepository.searchShops(query);
    } catch (e) {
      return []; 
    }
  }
  Future<List<Deliveryman>> searchDeliverymen(String query) async { 
    try {
      return await _orderRepository.searchDeliverymen(query); 
    } catch (e) {
      return []; 
    }
  }
  
  Future<void> assignOrders(List<int> orderIds, int deliverymanId) async {
    try {
      for (final orderId in orderIds) {
        await _orderRepository.assignOrder(orderId, deliverymanId);
      }
      await loadOrders(); // Recharge la page 1
    } catch (e) {
      rethrow;
    }
  }

  Future<void> assignOrder(int orderId, int deliverymanId) {
      return assignOrders([orderId], deliverymanId);
  }
  
  Future<void> updateOrderStatus(
    int orderId,
    String status,
    {String? paymentStatus, 
     double? amountReceived,
     DateTime? followUpAt,
     }) async {
    try {
      await _orderRepository.updateOrderStatus(
        orderId,
        status,
        paymentStatus: paymentStatus,
        amountReceived: amountReceived,
        followUpAt: followUpAt,
      );
      await loadOrders(); // Recharge la page 1
    } catch (e) {
      rethrow;
    }
  }
}