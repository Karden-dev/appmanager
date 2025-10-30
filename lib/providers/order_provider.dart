// lib/providers/order_provider.dart

import 'dart:async'; // Importé pour Timer
import 'package:flutter/material.dart';
import 'package:wink_manager/models/admin_order.dart'; 
import 'package:wink_manager/models/shop.dart';
// --- CORRECTION: Ajout de l'import manquant ---
import 'package:wink_manager/services/admin_order_service.dart'; 
// --- FIN CORRECTION ---
import 'package:wink_manager/services/auth_service.dart'; // Import pour le constructeur
// Importation nécessaire pour le dialogue Autocomplete dans order_action_dialogs.dart
import 'package:wink_manager/widgets/order_action_dialogs.dart'; 

class OrderProvider with ChangeNotifier {
  final AdminOrderService _orderService; // L'erreur 'Undefined class' est résolue

  // CORRECTION: Assure que le constructeur accepte AuthService et l'utilise pour initialiser AdminOrderService
  OrderProvider(AuthService authService) : _orderService = AdminOrderService(authService); // L'erreur 'Undefined method' est résolue
  
  // --- État de la liste de commandes ---
  List<AdminOrder> _orders = [];
  bool _isLoading = false;
  String? _error;

  // --- État des filtres ---
  DateTime _startDate = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  DateTime _endDate = DateTime.now().copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
  String _statusFilter = ''; // Correspond à 'Tous (sauf retours)'
  String _searchFilter = '';
  
  // --- AJOUT: État de la sélection groupée ---
  final Set<int> _selectedOrderIds = {};
  AdminOrder? _currentDetailOrder; // Pour l'écran de détails
  bool _isDetailLoading = false;

  // --- Getters publics ---
  List<AdminOrder> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  String get statusFilter => _statusFilter;
  String get searchFilter => _searchFilter;

  // AJOUT: Getters pour la sélection et les détails
  Set<int> get selectedOrderIds => _selectedOrderIds;
  bool get isSelectionMode => _selectedOrderIds.isNotEmpty;
  AdminOrder? get currentDetailOrder => _currentDetailOrder;
  bool get isDetailLoading => _isDetailLoading;


  // ----------------------------------------------------------------------
  // LOGIQUE DE FILTRAGE
  // ----------------------------------------------------------------------

  void setDateRange(DateTime start, DateTime end) {
    // Assure que l'heure de début est minuit et l'heure de fin est 23:59:59
    _startDate = start.copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    _endDate = end.copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
    loadOrders();
    notifyListeners();
  }

  void setStatusFilter(String status) {
    // MODIFIÉ: Permet de sélectionner 'Tous' (vide)
    _statusFilter = status;
    loadOrders();
    notifyListeners();
  }

  void setSearchFilter(String query) {
    _searchFilter = query;
    // La recherche est généralement trop rapide pour nécessiter un appel API immédiat.
    // Dans ce cas, nous laissons le widget de liste utiliser les filtres clients si nécessaire,
    // mais ici, nous déclenchons quand même un appel pour la recherche côté serveur.
    // Ajout d'un debounce pourrait être nécessaire en production.
    loadOrders();
    notifyListeners();
  }
  
  // ----------------------------------------------------------------------
  // AJOUT: LOGIQUE DE SÉLECTION GROUPÉE
  // ----------------------------------------------------------------------
  
  void toggleSelection(int orderId) {
    if (_selectedOrderIds.contains(orderId)) {
      _selectedOrderIds.remove(orderId);
    } else {
      _selectedOrderIds.add(orderId);
    }
    notifyListeners();
  }

  void toggleSelectAll(List<int> orderIdsOnPage) {
    // Si tous ceux de la page sont déjà sélectionnés (ou certains), on désélectionne tout
    final bool allSelected = orderIdsOnPage.every((id) => _selectedOrderIds.contains(id));

    if (allSelected) {
      _selectedOrderIds.removeAll(orderIdsOnPage);
    } else {
      _selectedOrderIds.addAll(orderIdsOnPage);
    }
    notifyListeners();
  }
  
  void clearSelection() {
    _selectedOrderIds.clear();
    notifyListeners();
  }
  
  // ----------------------------------------------------------------------
  // APPELS API DE LECTURE (READ)
  // ----------------------------------------------------------------------

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
      // Nettoyer la sélection si les commandes chargées ne contiennent plus les ID
      _selectedOrderIds.removeWhere((id) => !_orders.any((o) => o.id == id));
    } catch (e) {
      _error = 'Échec du chargement des commandes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- AJOUT: NOUVELLE FONCTION ---
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
  // --- FIN AJOUT ---

  Future<List<Shop>> searchShops(String query) async {
    try {
      // Retourne la liste des shops pour l'Autocomplete
      return await _orderService.searchShops(query);
    } catch (e) {
      // En cas d'erreur, retourne une liste vide
      return []; 
    }
  }
  
  // NOTE: Méthode pour l'Autocomplete de livreurs (utilisée par order_action_dialogs.dart)
  Future<List<Deliveryman>> searchDeliverymen(String query) async {
    try {
      // Cette méthode doit appeler votre API Node.js pour les livreurs actifs
      // Remplacez la ligne suivante par l'appel réel
      final List<Map<String, dynamic>> data = await _orderService.fetchActiveDeliverymen(query);

      return data.map((json) => Deliveryman(
        id: json['id'] as int, 
        name: json['name'] as String
      )).toList();
      
    } catch (e) {
      return []; 
    }
  }


  // ----------------------------------------------------------------------
  // APPELS API D'ÉCRITURE (CREATE/UPDATE/DELETE/ACTIONS)
  // ----------------------------------------------------------------------

  // Méthode pour créer ou mettre à jour une commande
  Future<void> saveOrder(Map<String, dynamic> orderData, int? orderId) async {
    try {
      await _orderService.saveOrder(orderData, orderId);
      // Après sauvegarde, on recharge la liste pour mettre à jour l'UI
      await loadOrders(); 
    } catch (e) {
      rethrow; // Relancer l'erreur pour que l'écran puisse afficher une SnackBar
    }
  }

  // Méthode pour supprimer une commande
  Future<void> deleteOrder(int orderId) async {
    try {
      await _orderService.deleteOrder(orderId);
      // Supprimer l'élément de la liste locale pour un feedback rapide
      _orders.removeWhere((order) => order.id == orderId);
      // Retirer de la sélection si présent
      _selectedOrderIds.remove(orderId);
      notifyListeners();
      // Pas besoin de recharger, la liste locale est à jour.
      // await loadOrders(); // puis recharger pour s'assurer de la cohérence
    } catch (e) {
      rethrow;
    }
  }

  // AJOUT: Suppression groupée
  Future<void> deleteSelectedOrders() async {
    final idsToDelete = List<int>.from(_selectedOrderIds);
    _isLoading = true;
    notifyListeners();
    try {
      for (int id in idsToDelete) {
        await _orderService.deleteOrder(id);
      }
      _orders.removeWhere((o) => idsToDelete.contains(o.id));
      _selectedOrderIds.clear();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Méthode pour changer le statut d'une commande
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
      // Mettre à jour la liste après changement de statut
      await loadOrders(); 
    } catch (e) {
      rethrow;
    }
  }
  
  // Méthode pour assigner une ou plusieurs commandes (Multi-Assignation)
  Future<void> assignOrders(List<int> orderIds, int deliverymanId) async {
    try {
      // Logique pour gérer l'assignation multiple côté service
      await _orderService.assignOrders(orderIds, deliverymanId);
      
      // Mettre à jour la liste après assignation
      // Ceci est crucial pour que le riderName apparaisse sur la carte
      await loadOrders(); 
      clearSelection(); // Vider la sélection après l'action groupée
      
    } catch (e) {
      rethrow;
    }
  }

  // Méthode utilitaire pour l'assignation individuelle (si nécessaire)
  Future<void> assignOrder(int orderId, int deliverymanId) {
      return assignOrders([orderId], deliverymanId);
  }
}