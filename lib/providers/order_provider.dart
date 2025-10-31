// Fichier : lib/providers/order_provider.dart

import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:wink_manager/models/admin_order.dart'; 
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/models/return_tracking.dart'; 
import 'package:wink_manager/models/user.dart'; 
import 'package:wink_manager/services/admin_order_service.dart'; 
import 'package:wink_manager/services/auth_service.dart'; 

// --- CLASSE AJOUTÉE POUR RENDRE LE TYPE DELIVERYMAN VISIBLE ---
class Deliveryman {
  final int id;
  final String name;

  Deliveryman({required this.id, required this.name});

  @override
  String toString() => name;
}
// --- FIN CLASSE DELIVERYMAN ---


class OrderProvider with ChangeNotifier {
  final AdminOrderService _orderService; 

  OrderProvider(AuthService authService) : _orderService = AdminOrderService(authService); 
  
  // ----------------------------------------------------------------------
  // --- ÉTATS EXISTANTS (CONSERVÉS) ---
  // ----------------------------------------------------------------------
  List<AdminOrder> _orders = [];
  bool _isLoading = false;
  String? _error;

  DateTime _startDate = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  DateTime _endDate = DateTime.now().copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
  String _statusFilter = ''; 
  String _searchFilter = '';
  Timer? _debounce; 
  
  final Set<int> _selectedOrderIds = {};
  AdminOrder? _currentDetailOrder; 
  bool _isDetailLoading = false;

  // ----------------------------------------------------------------------
  // --- NOUVEAUX ÉTATS (HUB LOGISTIQUE) ---
  // ----------------------------------------------------------------------
  List<AdminOrder> _preparationOrders = [];
  bool _isLoadingPreparation = false;
  
  List<ReturnTracking> _pendingReturns = [];
  bool _isLoadingReturns = false;
  
  List<User> _deliverymen = [];
  bool _isLoadingDeliverymen = false;
  
  // ----------------------------------------------------------------------
  // --- GETTERS EXISTANTS (CONSERVÉS) ---
  // ----------------------------------------------------------------------
  List<AdminOrder> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  String get statusFilter => _statusFilter;
  String get searchFilter => _searchFilter;

  Set<int> get selectedOrderIds => _selectedOrderIds;
  bool get isSelectionMode => _selectedOrderIds.isNotEmpty;
  AdminOrder? get currentDetailOrder => _currentDetailOrder;
  bool get isDetailLoading => _isDetailLoading;


  // ----------------------------------------------------------------------
  // --- NOUVEAUX GETTERS (HUB LOGISTIQUE) ---
  // ----------------------------------------------------------------------
  List<AdminOrder> get preparationOrders => _preparationOrders;
  bool get isLoadingPreparation => _isLoadingPreparation;
  
  List<ReturnTracking> get pendingReturns => _pendingReturns;
  bool get isLoadingReturns => _isLoadingReturns;

  List<User> get deliverymen => _deliverymen;
  bool get isLoadingDeliverymen => _isLoadingDeliverymen;

  // ----------------------------------------------------------------------
  // LOGIQUE DE FILTRAGE & SÉLECTION (CORRIGÉE)
  // ----------------------------------------------------------------------
  void clearError() { _error = null; }
  
  // FIX 1: Ajout de setLoading pour la gestion manuelle par la vue
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setDateRange(DateTime start, DateTime end) {
    _startDate = start.copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    _endDate = end.copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
    // FIX 2: loadOrders() -> fetchOrders()
    fetchOrders(); 
  }
  void setStatusFilter(String status) { 
    _statusFilter = (status == 'ALL') ? '' : status; 
    // FIX 3: loadOrders() -> fetchOrders()
    fetchOrders(); 
  }
  void setSearchFilter(String query) {
    if (_searchFilter == query) return;
    _searchFilter = query;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () { 
      // FIX 4: loadOrders() -> fetchOrders()
      fetchOrders(); 
    });
    notifyListeners();
  }
  
  void toggleSelection(int orderId) {
    if (_selectedOrderIds.contains(orderId)) {
      _selectedOrderIds.remove(orderId);
    } else {
      _selectedOrderIds.add(orderId);
    }
    notifyListeners();
  }
  void toggleSelectAll(List<int> orderIdsOnPage) {
    final bool allSelected = orderIdsOnPage.every((id) => _selectedOrderIds.contains(id));
    if (allSelected) {
      _selectedOrderIds.removeAll(orderIdsOnPage);
    } else {
      _selectedOrderIds.addAll(orderIdsOnPage);
    }
    notifyListeners();
  }
  void clearSelection() { _selectedOrderIds.clear(); notifyListeners(); }
  
  // ----------------------------------------------------------------------
  // APPELS API DE LECTURE (READ) - EXISTANTS (CORRIGÉS)
  // ----------------------------------------------------------------------

  // Renommée de loadOrders() en fetchOrders() pour correspondre à l'appel de la vue.
  Future<void> fetchOrders() async {
    // Si la vue n'utilise pas setLoading, nous devons le faire ici
    if (!_isLoading) {
      _isLoading = true;
      notifyListeners();
    }

    _error = null;
    try {
      final orders = await _orderService.fetchAdminOrders(
        startDate: _startDate,
        endDate: _endDate,
        statusFilter: _statusFilter,
        searchFilter: _searchFilter,
      );
      _orders = orders;
      _selectedOrderIds.removeWhere((id) => !_orders.any((o) => o.id == id));
    } catch (e) {
      _error = 'Échec du chargement des commandes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchOrderById(int orderId) async {
    _isDetailLoading = true;
    _currentDetailOrder = null;
    notifyListeners();
    try {
      _currentDetailOrder = await _orderService.fetchOrderById(orderId);
    } catch (e) {
      _error = 'Échec du chargement des détails: $e';
    } finally {
      _isDetailLoading = false;
      notifyListeners();
    }
  }

  Future<List<Shop>> searchShops(String query) async {
    try {
      return await _orderService.searchShops(query);
    } catch (e) {
      return []; 
    }
  }
  
  Future<List<Deliveryman>> searchDeliverymen(String query) async {
    try {
      final List<Map<String, dynamic>> data = await _orderService.fetchActiveDeliverymen('');

      return data.map((json) => Deliveryman(
        id: json['id'] as int, 
        name: json['name'] as String
      )).toList();
      
    } catch (e) {
      return []; 
    }
  }


  // ----------------------------------------------------------------------
  // --- NOUVELLES MÉTHODES (HUB LOGISTIQUE - READ) ---
  // ----------------------------------------------------------------------

  /// Charge les commandes à préparer (statut in_progress ou ready_for_pickup)
  Future<void> fetchPreparationOrders({bool forceRefresh = false}) async {
    if (!forceRefresh && _preparationOrders.isNotEmpty && !isLoadingPreparation) return;
    
    _isLoadingPreparation = true;
    _error = null;
    notifyListeners();
    
    try {
      _preparationOrders = await _orderService.fetchPreparationOrders();
    } catch (e) {
      _error = 'Échec du chargement de la préparation: $e';
    } finally {
      _isLoadingPreparation = false;
      notifyListeners();
    }
  }

  /// Charge les retours en attente au hub (filtrés par le HubReturnsTab)
  Future<void> fetchPendingReturns({required Map<String, dynamic> filters, bool forceRefresh = false}) async {
    if (!forceRefresh && _pendingReturns.isNotEmpty && !isLoadingReturns && filters.isEmpty) return; // Sécurité
    
    _isLoadingReturns = true;
    _error = null;
    notifyListeners();
    
    try {
      _pendingReturns = await _orderService.fetchPendingReturns(filters);
    } catch (e) {
      _error = 'Échec du chargement des retours: $e';
    } finally {
      _isLoadingReturns = false;
      notifyListeners();
    }
  }
  
  /// Charge tous les livreurs actifs pour le filtre (HubReturnsTab)
  Future<void> fetchDeliverymen({bool forceRefresh = false}) async {
    if (!forceRefresh && _deliverymen.isNotEmpty) return;
    
    _isLoadingDeliverymen = true;
    notifyListeners();
    
    try {
      final List<Map<String, dynamic>> data = await _orderService.fetchActiveDeliverymen('');
      _deliverymen = data.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      _deliverymen = [];
    } finally {
      _isLoadingDeliverymen = false;
      notifyListeners();
    }
  }

  // ----------------------------------------------------------------------
  // --- NOUVELLES MÉTHODES (HUB LOGISTIQUE - ACTIONS) ---
  // ----------------------------------------------------------------------

  /// Marque une commande comme prête (PUT /api/orders/:id/ready)
  Future<void> markOrderAsReady(int orderId) async {
     try {
      await _orderService.markAsReady(orderId);
      
      // Recharge l'objet concerné pour avoir les champs 'prepared_at' et 'prepared_by_name'
      final updatedOrder = await _orderService.fetchOrderById(orderId);
      final index = _preparationOrders.indexWhere((o) => o.id == orderId);

      if (index != -1) {
        _preparationOrders[index] = updatedOrder;
      }
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
  
  /// Confirme la réception du retour au Hub (PUT /api/returns/:trackingId/confirm-hub)
  Future<void> confirmHubReception(int trackingId) async {
     try {
      await _orderService.confirmHubReception(trackingId);
      
      final index = _pendingReturns.indexWhere((r) => r.trackingId == trackingId);
      
      if (index != -1) {
        final oldReturn = _pendingReturns[index];
        // On crée une nouvelle instance de ReturnTracking avec le nouveau statut
        _pendingReturns[index] = ReturnTracking(
          trackingId: oldReturn.trackingId,
          orderId: oldReturn.orderId,
          deliverymanName: oldReturn.deliverymanName,
          shopName: oldReturn.shopName,
          // METTRE À JOUR LE STATUT
          returnStatus: 'received_at_hub', 
          declarationDate: oldReturn.declarationDate,
          comment: oldReturn.comment
        );
      }
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ----------------------------------------------------------------------
  // APPELS API D'ÉCRITURE (CREATE/UPDATE/DELETE/ACTIONS) - EXISTANTS (MIS À JOUR)
  // ----------------------------------------------------------------------

  Future<void> saveOrder(Map<String, dynamic> orderData, int? orderId) async {
    try {
      await _orderService.saveOrder(orderData, orderId);
      // Après sauvegarde, on recharge la liste générale et la liste de préparation
      await fetchOrders(); 
      await fetchPreparationOrders(forceRefresh: true); // Mise à jour de la préparation
    } catch (e) {
      _error = e.toString(); 
      notifyListeners();
      rethrow; 
    }
  }

  Future<void> deleteOrder(int orderId) async {
    try {
      await _orderService.deleteOrder(orderId);
      _orders.removeWhere((order) => order.id == orderId);
      _preparationOrders.removeWhere((order) => order.id == orderId); // MAJ: Supprimer aussi de la liste de préparation
      _selectedOrderIds.remove(orderId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteSelectedOrders() async {
    final idsToDelete = List<int>.from(_selectedOrderIds);
    _isLoading = true;
    notifyListeners();
    try {
      for (int id in idsToDelete) {
        await _orderService.deleteOrder(id);
      }
      _orders.removeWhere((o) => idsToDelete.contains(o.id));
      _preparationOrders.removeWhere((o) => idsToDelete.contains(o.id)); // MAJ: Supprimer aussi de la liste de préparation
      _selectedOrderIds.clear();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
      
      final updatedOrder = await _orderService.fetchOrderById(orderId);
      
      // Mise à jour de la liste générale
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = updatedOrder;
      } else {
        await fetchOrders(); 
      }
      
      // Mise à jour de la liste de préparation
      final prepIndex = _preparationOrders.indexWhere((o) => o.id == orderId);
      if (prepIndex != -1) {
         // Si le nouveau statut ne nécessite plus de préparation, elle disparaît
        if (updatedOrder.status == 'delivered' || updatedOrder.status == 'cancelled' || updatedOrder.status == 'en_route') {
             _preparationOrders.removeAt(prepIndex);
        } else {
             _preparationOrders[prepIndex] = updatedOrder;
        }
      }
      
      notifyListeners();

    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
  
  Future<void> assignOrders(List<int> orderIds, int deliverymanId) async {
    try {
      await _orderService.assignOrders(orderIds, deliverymanId);
      
      // Mettre à jour les commandes affectées dans les deux listes
      await Future.wait(orderIds.map((id) async {
         final updatedOrder = await _orderService.fetchOrderById(id);
         
         // Liste générale
         final index = _orders.indexWhere((o) => o.id == id);
         if (index != -1) {
           _orders[index] = updatedOrder;
         }
         
         // Liste de préparation (l'ordre va changer de nom de livreur)
         final prepIndex = _preparationOrders.indexWhere((o) => o.id == id);
         if (prepIndex != -1) {
            _preparationOrders[prepIndex] = updatedOrder;
         }
      }));
      
      clearSelection(); 
      notifyListeners();
      
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> assignOrder(int orderId, int deliverymanId) {
      return assignOrders([orderId], deliverymanId);
  }
}