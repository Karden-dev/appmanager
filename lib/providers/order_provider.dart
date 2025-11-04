// lib/providers/order_provider.dart

import 'package:flutter/material.dart';
import 'package:wink_manager/models/admin_order.dart'; 
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/models/deliveryman.dart'; 
import 'package:wink_manager/repositories/order_repository.dart'; 
// --- AJOUT ---
import 'package:wink_manager/services/sync_service.dart'; 
// --- FIN AJOUT ---
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
  // --- AJOUT ---
  final SyncService _syncService;
  // --- FIN AJOUT ---

  // CORRECTION : Le constructeur prend maintenant le Repository ET le SyncService
  OrderProvider(this._orderRepository, this._syncService);
  
  // ... (Listes de données et État et Filtres INCHANGÉS) ...
  List<AdminOrder> _orders = []; 
  List<AdminOrder> _hubPreparationOrders = [];
  List<ReturnTracking> _pendingReturns = [];
  bool _isLoading = false;
  String? _error;
  DateTime _startDate = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  DateTime _endDate = DateTime.now().copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
  String _statusFilter = ''; 
  String _searchFilter = '';
  bool _sortByLocation = false;

  // ... (Getters INCHANGÉS) ...
  List<AdminOrder> get hubPreparationOrders => _hubPreparationOrders; 
  List<ReturnTracking> get pendingReturns => _pendingReturns; 
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get sortByLocation => _sortByLocation;
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  String get statusFilter => _statusFilter;
  String get searchFilter => _searchFilter;
  List<AdminOrder> get orders {
    // ... (La logique de tri reste INCHANGÉE) ...
    if (!_sortByLocation) {
      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _orders;
    }
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
      return b.createdAt.compareTo(a.createdAt);
    });
    return _orders;
  }
  
  // ... (Méthodes de filtre et de chargement INCHANGÉES) ...
  // (loadOrders, setDateRange, setStatusFilter, setSearchFilter, toggleSortByLocation)
  void toggleSortByLocation() {
    _sortByLocation = !_sortByLocation;
    notifyListeners(); 
  }
  void setDateRange(DateTime start, DateTime end) {
    _startDate = start.copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    _endDate = end.copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
    loadOrders();
  }
  void setStatusFilter(String status) {
    _statusFilter = status;
    loadOrders();
  }
  void setSearchFilter(String query) {
    _searchFilter = query;
    loadOrders();
  }
  Future<void> loadOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners(); 
    try {
      final orders = await _orderRepository.fetchAdminOrders(
        startDate: _startDate,
        endDate: _endDate,
        statusFilter: _statusFilter,
        searchFilter: _searchFilter,
      );
      _orders = orders;
    } catch (e) {
      _error = 'Échec du chargement des commandes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- MÉTHODES DU HUB (Préparation) ---

  // (loadOrdersToPrepare INCHANGÉ)
  Future<void> loadOrdersToPrepare() async { 
     _isLoading = true;
     _error = null;
     notifyListeners();
     try {
       final orders = await _orderRepository.fetchOrdersToPrepare();
       _hubPreparationOrders = orders; 
     } catch (e) {
       _error = 'Échec du chargement des commandes à préparer: $e';
     } finally {
       _isLoading = false;
       notifyListeners();
     }
  }
  
  // Marque une commande comme Prête pour récupération (action Hub)
  Future<void> markOrderAsReady(int orderId) async { 
     try {
       await _orderRepository.markOrderAsReady(orderId);
       // --- AJOUT : Réveille le SyncService ---
       _syncService.processQueue();
       // --- FIN AJOUT ---
       await loadOrdersToPrepare();
     } catch (e) {
       rethrow;
     }
  }
  
  // --- MÉTHODES DU HUB (Retours) ---

  // (loadPendingReturns INCHANGÉ)
  Future<void> loadPendingReturns({
    int? deliverymanId, 
    DateTime? startDate, 
    DateTime? endDate,
  }) async {
     _isLoading = true;
     _error = null;
     notifyListeners();
     try {
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
  
  // Confirme la réception d'un retour au Hub
  Future<void> confirmHubReception(int trackingId) async {
    try {
      await _orderRepository.confirmHubReception(trackingId);
      // --- AJOUT : Réveille le SyncService ---
      _syncService.processQueue();
      // --- FIN AJOUT ---
      await loadPendingReturns();
    } catch (e) {
      rethrow;
    }
  }

  // --- MÉTHODES D'ÉDITION ET D'ACTION (Utilisées par les détails/édition) ---
  
  // (fetchOrderById INCHANGÉ)
  Future<AdminOrder> fetchOrderById(int orderId) async {
    try {
      return await _orderRepository.fetchOrderById(orderId);
    } catch (e) {
      rethrow; 
    }
  }
  
  // Sauvegarde/Met à jour une commande (création ou édition)
  Future<void> saveOrder(Map<String, dynamic> orderData, int? orderId) async {
    try {
      await _orderRepository.saveOrder(orderData, orderId);
      // --- AJOUT : Réveille le SyncService ---
      _syncService.processQueue();
      // --- FIN AJOUT ---
      await loadOrders(); 
    } catch (e) {
      rethrow;
    }
  }
  
  // Supprime une commande
  Future<void> deleteOrder(int orderId) async {
    try {
      await _orderRepository.deleteOrder(orderId);
      // --- AJOUT : Réveille le SyncService ---
      _syncService.processQueue();
      // --- FIN AJOUT ---
      _orders.removeWhere((order) => order.id == orderId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  // ... (searchShops et searchDeliverymen INCHANGÉS) ...
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
  
  // Assignation d'une ou plusieurs commandes
  Future<void> assignOrders(List<int> orderIds, int deliverymanId) async {
    try {
      for (final orderId in orderIds) {
        await _orderRepository.assignOrder(orderId, deliverymanId);
      }
      // --- AJOUT : Réveille le SyncService (une seule fois) ---
      _syncService.processQueue();
      // --- FIN AJOUT ---
      await loadOrders(); 
    } catch (e) {
      rethrow;
    }
  }

  // (assignOrder INCHANGÉ)
  Future<void> assignOrder(int orderId, int deliverymanId) {
      return assignOrders([orderId], deliverymanId);
  }
  
  // Mise à jour du statut (utilisé par les boîtes de dialogue)
  Future<void> updateOrderStatus(
    int orderId,
    String status,
    {String? paymentStatus, double? amountReceived}) async {
    try {
      await _orderRepository.updateOrderStatus(
        orderId,
        status,
        paymentStatus: paymentStatus,
        amountReceived: amountReceived,
      );
      // --- AJOUT : Réveille le SyncService ---
      _syncService.processQueue();
      // --- FIN AJANT ---
      await loadOrders(); 
    } catch (e) {
      rethrow;
    }
  }
}