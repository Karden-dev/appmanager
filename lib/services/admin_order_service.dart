// lib/services/admin_order_service.dart

import 'package:dio/dio.dart'; 
import 'package:flutter/foundation.dart';
// CORRECTION: Importation de AdminOrder restaurée, elle est nécessaire.
import 'package:wink_manager/models/admin_order.dart'; 
import 'package:wink_manager/models/shop.dart'; 
import 'package:wink_manager/services/auth_service.dart';
import 'package:intl/intl.dart'; 

class AdminOrderService {
  final AuthService _authService;
  final Dio _dio; // Utilisation de l'instance Dio authentifiée

  // CORRECTION CLÉ: Le constructeur doit accepter l'AuthService.
  AdminOrderService(this._authService) : _dio = _authService.dio; 

  /// 1. RÉCUPÉRER LES COMMANDES (fetchAdminOrders)
  Future<List<AdminOrder>> fetchAdminOrders({
    required DateTime startDate,
    required DateTime endDate,
    required String statusFilter,
    required String searchFilter,
  }) async {
    try {
      // Construction des filtres pour l'API
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
        // Cette ligne a besoin de 'AdminOrder.fromJson'
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
  
  // --- AJOUT: NOUVELLE FONCTION (La méthode manquante) ---
  /// 1.5. RÉCUPÉRER UNE COMMANDE PAR ID (pour l'écran de détails)
  /// Appelle GET /api/orders/:id
  Future<AdminOrder> fetchOrderById(int orderId) async {
    try {
      // L'API /api/orders/:id retourne tous les détails, y compris l'historique
      // (vérifié dans webapp/src/models/order.model.js -> findById)
      final response = await _dio.get('/orders/$orderId');
      
      if (response.statusCode == 200) {
        // Le modèle AdminOrder.fromJson s'occupera de parser l'historique
        return AdminOrder.fromJson(response.data);
      } else {
        throw Exception('Échec du chargement des détails: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        _authService.logout();
      }
      if (kDebugMode) {
        print('Erreur fetchOrderById: $e');
      }
      throw Exception(e.response?.data['message'] ?? 'Erreur réseau ou serveur: ${e.message}');
    }
  }
  // --- FIN AJOUT ---

  /// 2. RECHERCHE MARCHANDE DYNAMIQUE (searchShops)
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
  
  /// 3. FETCH LIVREURS ACTIFS (fetchActiveDeliverymen)
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

  /// 4. SAUVEGARDER COMMANDE (saveOrder)
  Future<void> saveOrder(Map<String, dynamic> orderData, int? orderId) async {
     try {
      if (orderId == null) {
        // Création (POST)
        await _dio.post('/orders', data: orderData);
      } else {
        // Mise à jour (PUT)
        await _dio.put('/orders/$orderId', data: orderData);
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec de la sauvegarde de la commande.');
    }
  }

  /// 5. SUPPRIMER COMMANDE
  Future<void> deleteOrder(int orderId) async {
     try {
      await _dio.delete('/orders/$orderId');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec de la suppression.');
    }
  }

  /// 6. ASSIGNATION MULTIPLE (assignOrders)
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

  /// 7. CHANGER STATUT
  Future<void> updateOrderStatus(
      int orderId, String status, {String? paymentStatus, double? amountReceived}) async {
    try {
      final payload = {
        'status': status,
        if (paymentStatus != null) 'payment_status': paymentStatus,
        if (amountReceived != null) 'amount_received': amountReceived,
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