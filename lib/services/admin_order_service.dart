// lib/services/admin_order_service.dart

// Imports nécessaires pour ce service
// import 'dart:convert'; // RETIRÉ (Inutilisé)
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
// import 'package:flutter/foundation.dart'; // RETIRÉ (Inutilisé)

// Imports des modèles de données
import 'package:wink_manager/models/admin_order.dart';
import 'package:wink_manager/models/return_tracking.dart';
import 'package:wink_manager/models/shop.dart';
// import 'package:wink_manager/models/user.dart'; // RETIRÉ (Inutilisé)

// Import du service d'authentification pour récupérer Dio
import 'package:wink_manager/services/auth_service.dart';

// DÉFINITION DE LA CLASSE
class AdminOrderService {
  
  // URL de base de l'API
  static const String _apiBaseUrl = "https://app.winkexpress.online/api";
  static const String _apiOrdersBaseUrl = "$_apiBaseUrl/orders";
  static const String _apiReturnsBaseUrl = "$_apiBaseUrl/returns";
  static const String _apiShopsBaseUrl = "$_apiBaseUrl/shops";
  static const String _apiDeliverymenBaseUrl = "$_apiBaseUrl/users"; 

  final Dio _dio;

  // Le service prend AuthService pour obtenir le Dio déjà configuré (avec token)
  AdminOrderService(AuthService authService) : _dio = authService.dio;
  
  // --- Fonctions de Lecture (READ) ---

  /// 1. GET /api/orders
  Future<List<AdminOrder>> fetchAdminOrders({
    required DateTime startDate,
    required DateTime endDate,
    String statusFilter = '',
    String searchFilter = '',
  }) async {
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    try {
      final response = await _dio.get(
        _apiOrdersBaseUrl,
        queryParameters: {
          'startDate': formatter.format(startDate),
          'endDate': formatter.format(endDate),
          'status': statusFilter,
          'search': searchFilter,
        },
      );
      final List<dynamic> data = response.data;
      return data.map((json) => AdminOrder.fromJson(json)).toList();
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec du chargement des commandes.';
      throw Exception(message);
    }
  }

  /// 2. GET /api/orders/:id
  Future<AdminOrder> fetchOrderById(int orderId) async {
    try {
      final response = await _dio.get('$_apiOrdersBaseUrl/$orderId');
      return AdminOrder.fromJson(response.data);
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec du chargement des détails.';
      throw Exception(message);
    }
  }
  
  /// 3. GET /api/shops?search=query
  Future<List<Shop>> searchShops(String query) async {
    try {
      // Filtrer par 'actif' par défaut pour les nouvelles commandes
      final response = await _dio.get(_apiShopsBaseUrl, queryParameters: {'search': query, 'status': 'actif'});
      final List<dynamic> data = response.data;
      return data.map((json) => Shop.fromJson(json)).toList();
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec de la recherche de marchands.';
      throw Exception(message);
    }
  }
  
  /// 4. GET /api/users?role=deliveryman&status=actif
  Future<List<Map<String, dynamic>>> fetchActiveDeliverymen(String query) async {
    try {
      final response = await _dio.get(
        _apiDeliverymenBaseUrl, 
        queryParameters: {
          'role': 'deliveryman', // Filtre requis par l'API
          'status': 'actif',
          'search': query
        }
      );
      final List<dynamic> data = response.data;
      // Retourne le Map brut car le provider se charge de le mapper
      return List<Map<String, dynamic>>.from(data);
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec du chargement des livreurs.';
      throw Exception(message);
    }
  }

  /// 5. GET /api/orders/pending-preparation
  Future<List<AdminOrder>> fetchPreparationOrders() async {
    try {
      final response = await _dio.get('$_apiOrdersBaseUrl/pending-preparation');
      final List<dynamic> data = response.data;
      return data.map((json) => AdminOrder.fromJson(json)).toList();
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec du chargement de la préparation.';
      throw Exception(message);
    }
  }
  
  /// 6. GET /api/returns/pending-hub
  Future<List<ReturnTracking>> fetchPendingReturns(Map<String, dynamic> filters) async {
    try {
      final response = await _dio.get(
        '$_apiReturnsBaseUrl/pending-hub', 
        queryParameters: {
          'status': filters['status'],
          'deliverymanId': filters['deliverymanId'],
          'startDate': filters['startDate'], // Formaté par le provider
          'endDate': filters['endDate'], // Formaté par le provider
        },
      );
      final List<dynamic> data = response.data;
      
      return data.map((json) => ReturnTracking.fromJson(json)).toList();
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec du chargement des retours.';
      throw Exception(message);
    }
  }

  // --- Fonctions d'Écriture/Action (WRITE) ---

  /// 7. POST/PUT /api/orders
  Future<void> saveOrder(Map<String, dynamic> orderData, int? orderId) async {
    try {
      if (orderId == null) {
        // Création
        await _dio.post(_apiOrdersBaseUrl, data: orderData);
      } else {
        // Modification
        await _dio.put('$_apiOrdersBaseUrl/$orderId', data: orderData);
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec de la sauvegarde de la commande.';
      throw Exception(message);
    }
  }

  /// 8. DELETE /api/orders/:id
  Future<void> deleteOrder(int orderId) async {
    try {
      await _dio.delete('$_apiOrdersBaseUrl/$orderId');
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec de la suppression.';
      throw Exception(message);
    }
  }
  
  /// 9. PUT /api/orders/:id/status
  Future<void> updateOrderStatus(int orderId, String status, {String? paymentStatus, double? amountReceived}) async {
    try {
      final payload = { 
        'status': status, 
        if (paymentStatus != null) 'payment_status': paymentStatus,
        if (amountReceived != null) 'amount_received': amountReceived,
      };
      await _dio.put('$_apiOrdersBaseUrl/$orderId/status', data: payload);
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec de la mise à jour du statut.';
      throw Exception(message);
    }
  }

  /// 10. POST /api/orders/assign-bulk (MÉTHODE GROUPÉE)
  Future<void> assignOrders(List<int> orderIds, int deliverymanId) async {
    try {
      // Le backend attend: { "orderIds": [1, 2, 3], "deliverymanId": 5 }
      final payload = { 
        'orderIds': orderIds,
        'deliverymanId': deliverymanId 
      };
      // Utilisation de la route groupée pour la performance
      await _dio.post('$_apiOrdersBaseUrl/assign-bulk', data: payload);
      
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec de l\'assignation des commandes.';
      throw Exception(message);
    }
  }
  
  /// 11. PUT /api/orders/:id/ready
  Future<void> markAsReady(int orderId) async {
    try {
      // L'API attend un body vide pour cette action PUT
      await _dio.put('$_apiOrdersBaseUrl/$orderId/ready');
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec du marquage comme prêt.';
      throw Exception(message);
    }
  }
  
  /// 12. PUT /api/returns/:trackingId/confirm-hub
  Future<void> confirmHubReception(int trackingId) async {
    try {
      // L'API attend un body vide pour cette action PUT
      await _dio.put('$_apiReturnsBaseUrl/$trackingId/confirm-hub');
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec de la confirmation du retour.';
      throw Exception(message);
    }
  }
}