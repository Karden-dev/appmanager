import 'package:flutter/material.dart';
// import 'package:provider/provider.dart'; // <-- CORRECTION: Supprimé (Résout l'erreur unused_import)
import 'package:wink_manager/models/admin_order.dart'; 
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/services/admin_order_service.dart'; 
import 'package:wink_manager/services/auth_service.dart'; // Import pour le constructeur
// Importation nécessaire pour le dialogue Autocomplete dans order_action_dialogs.dart
import 'package:wink_manager/widgets/order_action_dialogs.dart'; 

class OrderProvider with ChangeNotifier {
  final AdminOrderService _orderService;

  // CORRECTION: Assure que le constructeur accepte AuthService et l'utilise pour initialiser AdminOrderService
  OrderProvider(AuthService authService) : _orderService = AdminOrderService(authService);
  
  // --- État de la liste de commandes ---
  List<AdminOrder> _orders = [];
  bool _isLoading = false;
  String? _error;

  // --- État des filtres ---
  DateTime _startDate = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  DateTime _endDate = DateTime.now().copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
  String _statusFilter = ''; // Correspond à 'Tous (sauf retours)'
  String _searchFilter = '';
  
  // --- Getters publics ---
  List<AdminOrder> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  String get statusFilter => _statusFilter;
  String get searchFilter => _searchFilter;


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
    if (_statusFilter == status) {
      _statusFilter = '';
    } else {
      _statusFilter = status;
    }
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
    } catch (e) {
      _error = 'Échec du chargement des commandes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
      notifyListeners();
      await loadOrders(); // puis recharger pour s'assurer de la cohérence
    } catch (e) {
      rethrow;
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
      
    } catch (e) {
      rethrow;
    }
  }

  // Méthode utilitaire pour l'assignation individuelle (si nécessaire)
  Future<void> assignOrder(int orderId, int deliverymanId) {
      return assignOrders([orderId], deliverymanId);
  }
}