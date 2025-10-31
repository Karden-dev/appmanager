// lib/providers/order_provider.dart

import 'package:flutter/material.dart';
import 'package:wink_manager/models/admin_order.dart'; 
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/models/user.dart'; 
import 'package:wink_manager/models/deliveryman.dart'; // Import pour le modèle Livreur
import 'package:wink_manager/services/admin_order_service.dart'; 
import 'package:wink_manager/services/auth_service.dart';
import 'package:wink_manager/widgets/order_action_dialogs.dart'; // Utilisé pour les alias de type si nécessaire
import 'package:wink_manager/models/return_tracking.dart'; 

// --- Logique de Tri par Lieu (Portage de orders.js) ---

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
        // Capitalize
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
  final AdminOrderService _orderService;

  OrderProvider(AuthService authService) : _orderService = AdminOrderService(authService);
  
  // --- Listes de données ---
  List<AdminOrder> _orders = []; 
  List<AdminOrder> _hubPreparationOrders = []; // Pour l'onglet Préparation
  List<ReturnTracking> _pendingReturns = []; // Pour l'onglet Retours
  
  // --- État et Filtres ---
  bool _isLoading = false;
  String? _error;

  DateTime _startDate = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  DateTime _endDate = DateTime.now().copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
  String _statusFilter = ''; 
  String _searchFilter = '';
  
  bool _sortByLocation = false;

  // --- GETTERS DÉDIÉS AU HUB ---
  List<AdminOrder> get hubPreparationOrders => _hubPreparationOrders; 
  List<ReturnTracking> get pendingReturns => _pendingReturns; 

  // --- GETTERS DE L'ÉTAT GÉNÉRAL ET FILTRES ---
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get sortByLocation => _sortByLocation;
  
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  String get statusFilter => _statusFilter;
  String get searchFilter => _searchFilter;

  List<AdminOrder> get orders {
    // Logique de tri par date ou par lieu
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
  
  // --- MÉTHODES DE FILTRE ET DE CHARGEMENT ---

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
  
  // Charge la liste principale des commandes (écran AdminOrdersScreen)
  Future<void> loadOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final orders = await _orderService.fetchAdminOrders(
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

  // Charge les commandes à préparer (onglet Préparation)
  Future<void> loadOrdersToPrepare() async { 
     _isLoading = true;
     _error = null;
     notifyListeners();
     try {
       final orders = await _orderService.fetchOrdersToPrepare();
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
       await _orderService.markOrderAsReady(orderId);
     } catch (e) {
       rethrow;
     }
  }
  
  // --- MÉTHODES DU HUB (Retours) ---

  // Charge les retours en attente, avec filtres
  Future<void> loadPendingReturns({
    int? deliverymanId, 
    DateTime? startDate, 
    DateTime? endDate,
  }) async {
     _isLoading = true;
     _error = null;
     notifyListeners();
     try {
       final returns = await _orderService.fetchPendingReturns(
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
      await _orderService.confirmHubReception(trackingId);
    } catch (e) {
      rethrow;
    }
  }

  // --- MÉTHODES D'ÉDITION ET D'ACTION (Utilisées par les détails/édition) ---
  
  // Récupère une commande spécifique
  Future<AdminOrder> fetchOrderById(int orderId) async {
    try {
      return await _orderService.fetchOrderById(orderId);
    } catch (e) {
      rethrow; 
    }
  }
  
  // Sauvegarde/Met à jour une commande (création ou édition)
  Future<void> saveOrder(Map<String, dynamic> orderData, int? orderId) async {
    try {
      await _orderService.saveOrder(orderData, orderId);
      await loadOrders(); 
    } catch (e) {
      rethrow;
    }
  }
  
  // Supprime une commande
  Future<void> deleteOrder(int orderId) async {
    try {
      await _orderService.deleteOrder(orderId);
      _orders.removeWhere((order) => order.id == orderId); // Mise à jour locale
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  // Recherche dynamique des marchands (pour édition)
  Future<List<Shop>> searchShops(String query) async {
    try {
      return await _orderService.searchShops(query);
    } catch (e) {
      return []; 
    }
  }
  
  // Recherche dynamique des livreurs (pour assignation)
  // Le type de retour est Deliveryman (l'objet attendu par l'UI)
  Future<List<Deliveryman>> searchDeliverymen(String query) async { 
    try {
      final List<Map<String, dynamic>> data = await _orderService.fetchActiveDeliverymen(query);
      // Mappe la réponse du service vers le modèle Deliveryman
      return data.map((json) => Deliveryman.fromJson(json)).toList(); 
    } catch (e) {
      return []; 
    }
  }
  
  // Assignation d'une ou plusieurs commandes
  Future<void> assignOrders(List<int> orderIds, int deliverymanId) async {
    try {
      await _orderService.assignOrders(orderIds, deliverymanId);
      await loadOrders(); 
    } catch (e) {
      rethrow;
    }
  }

  // Wrapper pour l'assignation d'une seule commande
  Future<void> assignOrder(int orderId, int deliverymanId) {
      return assignOrders([orderId], deliverymanId);
  }
  
  // Mise à jour du statut (utilisé par les boîtes de dialogue)
  Future<void> updateOrderStatus(
    int orderId,
    String status,
    {String? paymentStatus, double? amountReceived}) async {
    try {
      await _orderService.updateOrderStatus(
        orderId,
        status,
        paymentStatus: paymentStatus,
        amountReceived: amountReceived,
      );
      await loadOrders(); 
    } catch (e) {
      rethrow;
    }
  }
}