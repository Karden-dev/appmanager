// lib/services/admin_order_service.dart

import 'package:dio/dio.dart'; 
import 'package:flutter/foundation.dart';
import 'package:wink_manager/models/admin_order.dart'; 
import 'package:wink_manager/models/shop.dart'; 
import 'package:wink_manager/services/auth_service.dart';
import 'package:intl/intl.dart'; 
import 'package:wink_manager/models/return_tracking.dart'; 

class AdminOrderService {
  final AuthService _authService;
  final Dio _dio; 

  AdminOrderService(this._authService) : _dio = _authService.dio; 

  /// 1. RÉCUPÉRER LES COMMANDES (fetchAdminOrders)
  // ... (Méthode inchangée)
  Future<List<AdminOrder>> fetchAdminOrders({
    required DateTime startDate,
    required DateTime endDate,
    required String statusFilter,
    required String searchFilter,
  }) async {
    try {
      final filters = {
        'startDate': DateFormat('yyyy-MM-dd').format(startDate),
        'endDate': DateFormat('yyyy-MM-dd').format(endDate),
        'status': statusFilter.isEmpty ? null : statusFilter,
        'search': searchFilter.isEmpty ? null : searchFilter,
      };

      final response = await _dio.get(
        '/orders', 
        queryParameters: filters,
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = response.data;
        return body.map((dynamic item) => AdminOrder.fromJson(item)).toList();
      } else {
        throw Exception('Échec du chargement des commandes: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        _authService.logout();
      }
      if (kDebugMode) {
        print('Erreur fetchAdminOrders: $e');
      }
      throw Exception(e.response?.data['message'] ?? 'Erreur réseau ou serveur: ${e.message}');
    }
  }
  
  /// 2. NOUVEAU : Récupère les commandes en attente de préparation/réception Hub
  // ... (Méthode inchangée)
  Future<List<AdminOrder>> fetchOrdersToPrepare() async {
     try {
      final response = await _dio.get('/orders/pending-preparation');
      
      if (response.statusCode == 200) {
        final List<dynamic> body = response.data;
        return body.map((dynamic item) => AdminOrder.fromJson(item)).toList();
      } else {
        throw Exception('Échec du chargement des commandes à préparer: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        _authService.logout();
      }
      if (kDebugMode) {
        print('Erreur fetchOrdersToPrepare: $e');
      }
      throw Exception(e.response?.data['message'] ?? 'Erreur réseau ou serveur: ${e.message}');
    }
  }
  
  /// 3. NOUVEAU : Marquer comme Prêt (PUT /orders/:id/ready)
  // ... (Méthode inchangée)
  Future<void> markOrderAsReady(int orderId) async {
     try {
      await _dio.put('/orders/$orderId/ready');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec du marquage comme prêt.');
    }
  }

  // NOUVELLE MÉTHODE : Récupère la liste des retours à gérer au Hub
  // ... (Méthode inchangée)
  Future<List<ReturnTracking>> fetchPendingReturns({
    String? status, 
    int? deliverymanId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final filters = {
        'status': status,
        'deliverymanId': deliverymanId,
        'startDate': startDate != null ? DateFormat('yyyy-MM-dd').format(startDate) : null,
        'endDate': endDate != null ? DateFormat('yyyy-MM-dd').format(endDate) : null,
      };
      
      final response = await _dio.get('/returns/pending-hub', queryParameters: filters);
      
      if (response.statusCode == 200) {
        final List<dynamic> body = response.data;
        return body.map((dynamic item) => ReturnTracking.fromJson(item)).toList();
      } else {
        throw Exception('Échec du chargement des retours: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        _authService.logout();
      }
      throw Exception(e.response?.data['message'] ?? 'Erreur réseau ou serveur: ${e.message}');
    }
  }
  
  // NOUVELLE MÉTHODE : Confirme la réception d'un retour au Hub
  // ... (Méthode inchangée)
  Future<void> confirmHubReception(int trackingId) async {
    try {
      await _dio.put('/returns/$trackingId/confirm-hub');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec de la confirmation de réception au Hub.');
    }
  }
  
  /// 4. RÉCUPÉRER UNE COMMANDE PAR ID (fetchOrderById)
  // ... (Méthode inchangée)
  Future<AdminOrder> fetchOrderById(int orderId) async {
    try {
      final response = await _dio.get(
        '/orders/$orderId', 
      );

      if (response.statusCode == 200) {
        return AdminOrder.fromJson(response.data);
      } else {
        throw Exception('Échec du chargement de la commande: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        _authService.logout();
      }
      throw Exception(e.response?.data['message'] ?? 'Erreur réseau ou serveur: ${e.message}');
    }
  }
  
  /// 5. RECHERCHE MARCHANDE DYNAMIQUE (searchShops)
  // ... (Méthode inchangée)
  Future<List<Shop>> searchShops(String query) async {
    try {
      final response = await _dio.get(
        '/shops',
        queryParameters: {'status': 'actif', 'search': query},
      );
      
      final List<dynamic> body = response.data;
      return body.map((dynamic item) => Shop.fromJson(item)).toList();
      
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Erreur searchShops: $e');
      }
      return []; 
    }
  }
  
  /// 6. FETCH LIVREURS ACTIFS (fetchActiveDeliverymen)
  // ... (Méthode inchangée)
  Future<List<Map<String, dynamic>>> fetchActiveDeliverymen(String query) async {
    try {
      final response = await _dio.get(
        '/deliverymen', 
        queryParameters: {'status': 'actif', 'search': query},
      );
      
      final List<dynamic> body = response.data;
      return body.map((dynamic item) => item as Map<String, dynamic>).toList();
      
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Erreur fetchActiveDeliverymen: $e');
      }
      return []; 
    }
  }

  /// 7. SAUVEGARDER COMMANDE (saveOrder)
  // --- CORRECTION : Renvoie AdminOrder pour récupérer le nouvel ID ---
  Future<AdminOrder> saveOrder(Map<String, dynamic> orderData, int? orderId) async {
     try {
      Response response;
      if (orderId == null) {
        // CRÉATION (POST)
        response = await _dio.post('/orders', data: orderData);
      } else {
        // MISE À JOUR (PUT)
        response = await _dio.put('/orders/$orderId', data: orderData);
      }
      // Renvoie la commande créée/mise à jour (contenant le vrai ID)
      return AdminOrder.fromJson(response.data);

    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec de la sauvegarde de la commande.');
    }
  }

  /// 8. SUPPRIMER COMMANDE
  // ... (Méthode inchangée)
  Future<void> deleteOrder(int orderId) async {
     try {
      await _dio.delete('/orders/$orderId');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec de la suppression.');
    }
  }

  /// 9. ASSIGNATION MULTIPLE (assignOrders)
  // ... (Méthode inchangée)
  Future<void> assignOrders(List<int> orderIds, int deliverymanId) async {
    try {
      for (final orderId in orderIds) {
         await _dio.put(
          '/orders/$orderId/assign',
          data: {'deliverymanId': deliverymanId},
         );
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec de l\'assignation.');
    }
  }

  /// 10. CHANGER STATUT
  // *** MODIFICATION : Ajout du paramètre followUpAt pour gérer les statuts de suivi ***
  Future<void> updateOrderStatus(
      int orderId, 
      String status, 
      {String? paymentStatus, 
      double? amountReceived,
      DateTime? followUpAt, // NOUVEAU PARAMÈTRE
      }) async {
    try {
      final payload = {
        'status': status,
        if (paymentStatus != null) 'payment_status': paymentStatus,
        if (amountReceived != null) 'amount_received': amountReceived,
        // NOUVEAU : Conversion de DateTime en String ISO 8601 pour l'API
        if (followUpAt != null) 'follow_up_at': followUpAt.toIso8601String(),
        // Note: Si followUpAt est null, il sera omis du payload, ce qui est correct.
      };
      await _dio.put(
        '/orders/$orderId/status',
        data: payload,
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec MAJ statut');
    }
  }
}