// lib/services/order_service.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart'; // Ajouté pour debugPrint

import '../models/order.dart';
import '../models/user.dart';
import '../models/rider_cash_details.dart';
import '../models/sync_request.dart';
import 'package:wink_rider_app/services/sync_service.dart';

// --- NOUVEAU HELPER ---
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  if (kDebugMode) {
    print("Avertissement _parseInt (OrderService): Type inattendu reçu - ${value.runtimeType} / Value: $value");
  }
  return null;
}
// --- FIN HELPER ---


class OrderService {
  final Dio _dio;
  final User _currentUser;
  final SyncService _syncService;

  static const String _apiBaseUrl = "https://app.winkexpress.online/api/rider";
  static const String _apiOrdersBaseUrl = "https://app.winkexpress.online/api/orders"; // Pour updateStatus etc.

  final Map<String, List<Order>> _orderCache = {};
  DateTime? _lastCacheUpdateTime;
  final Duration _cacheDuration = const Duration(minutes: 2); 

  OrderService(this._dio, this._currentUser, this._syncService);

  final statusTranslations = {
    'pending': 'En attente',
    'in_progress': 'Assignée',
    'ready_for_pickup': 'Prête à prendre',
    'en_route': 'En route',
    'delivered': 'Livrée',
    'cancelled': 'Annulée',
    'failed_delivery': 'Livraison ratée',
    'reported': 'À relancer',
    'return_declared': 'Retour déclaré',
    'returned': 'Retournée'
  };

  Future<List<Order>> fetchRiderOrders({
    required List<String> statuses,
    String? startDate,
    String? endDate,
    String? search,
  }) async {
    final cacheKey = _generateCacheKey(statuses: statuses, startDate: startDate, endDate: endDate, search: search);
    final now = DateTime.now();

    if (_orderCache.containsKey(cacheKey) && _lastCacheUpdateTime != null && now.difference(_lastCacheUpdateTime!) < _cacheDuration) {
      debugPrint("OrderService: Utilisation du cache pour la clé '$cacheKey'");
      return _orderCache[cacheKey]!;
    }

    debugPrint("OrderService: Appel API pour la clé '$cacheKey'");
    try {
      final response = await _dio.get(
        '$_apiBaseUrl/orders',
        queryParameters: {
          'status': statuses,
          'startDate': startDate,
          'endDate': endDate,
          'search': search,
          'deliverymanId': _currentUser.id, 
        },
      );

      final List<Order> orders = (response.data as List)
          .map((json) => Order.fromJson(json))
          .toList();

      _orderCache[cacheKey] = orders;
      _lastCacheUpdateTime = now; 

      return orders;

    } on DioException catch (e) {
      String message = e.response?.data['message'] ?? 'Échec de la récupération des commandes.';
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        if (_orderCache.containsKey(cacheKey)) {
           debugPrint("OrderService: Erreur réseau, retour du cache expiré pour '$cacheKey'");
           return _orderCache[cacheKey]!;
        }
      }
      throw Exception(message);
    } catch (e) {
       if (_orderCache.containsKey(cacheKey)) {
          debugPrint("OrderService: Erreur inattendue, retour du cache expiré pour '$cacheKey'");
          return _orderCache[cacheKey]!;
       }
       throw Exception("Erreur inconnue lors de la récupération des commandes.");
    }
  }

  String _generateCacheKey({
    required List<String> statuses,
    String? startDate,
    String? endDate,
    String? search,
  }) {
    final sortedStatuses = List<String>.from(statuses)..sort();
    return '${sortedStatuses.join(',')}|${startDate ?? 'null'}|${endDate ?? 'null'}|${search ?? 'null'}';
  }

  void invalidateOrderCache() {
    debugPrint("OrderService: Cache des commandes invalidé.");
    _orderCache.clear();
    _lastCacheUpdateTime = null;
  }

  Future<Map<String, int>> fetchOrderCounts() async {
    try {
      final response = await _dio.get('$_apiBaseUrl/counts'); 

      final Map<String, dynamic> data = response.data;
      
      // *** CORRECTION ICI ***
      // Utilise le helper _parseInt pour convertir la valeur en toute sécurité
      return data.map((key, value) => MapEntry(key, _parseInt(value) ?? 0));
      // **********************

    } on DioException catch (e) {
       String message = e.response?.data['message'] ?? 'Échec de la récupération des compteurs.';
       throw Exception(message);
    }
  }

  Future<void> _handleOfflineRequest(String url, String method, Map<String, dynamic> payload, String baseErrorMessage) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (![ConnectivityResult.wifi, ConnectivityResult.mobile, ConnectivityResult.ethernet].contains(connectivityResult)) {
      final request = SyncRequest(
        url: url,
        method: method,
        payload: jsonEncode(payload),
        token: _currentUser.token,
      );
      await _syncService.addRequest(request);
      invalidateOrderCache();
      throw Exception("Hors ligne. Action mise en file d'attente. Elle sera synchronisée dès que la connexion sera rétablie.");
    }
    throw Exception(baseErrorMessage);
  }

  Future<void> confirmPickup(int orderId) async {
    final String url = '$_apiBaseUrl/orders/$orderId/confirm-pickup-rider';
    try {
      await _dio.put(url);
      invalidateOrderCache(); 
    } on DioException catch (e) {
      final baseErrorMessage = e.response?.data['message'] ?? 'Échec de la confirmation de récupération.';
      await _handleOfflineRequest(url, 'PUT', {}, baseErrorMessage);
    }
  }

  Future<void> startDelivery(int orderId) async {
    final String url = '$_apiBaseUrl/orders/$orderId/start-delivery';
    try {
      await _dio.put(url);
      invalidateOrderCache(); 
    } on DioException catch (e) {
      final baseErrorMessage = e.response?.data['message'] ?? 'Échec du démarrage de la course.';
      await _handleOfflineRequest(url, 'PUT', {}, baseErrorMessage);
    }
  }

  Future<void> updateOrderStatus({
    required int orderId,
    required String status,
    String? paymentStatus,
    double? amountReceived
  }) async {
    final String url = "$_apiOrdersBaseUrl/$orderId/status";
    final payload = {
      'status': status,
      'payment_status': paymentStatus,
      'amount_received': amountReceived,
      'userId': _currentUser.id, 
    };

    try {
      await _dio.put(url, data: payload);
      invalidateOrderCache(); 
    } on DioException catch (e) {
      final baseErrorMessage = e.response?.data['message'] ?? 'Échec de la mise à jour du statut.';
      await _handleOfflineRequest(url, 'PUT', payload, baseErrorMessage);
    }
  }

  Future<void> declareReturn(int orderId) async {
    final String url = "$_apiOrdersBaseUrl/$orderId/declare-return";
    final payload = {
        'comment': 'Déclaré depuis app Flutter',
        'userId': _currentUser.id, 
    };

    try {
      await _dio.post(url, data: payload);
      invalidateOrderCache(); 
    } on DioException catch (e) {
      final baseErrorMessage = e.response?.data['message'] ?? 'Échec de la déclaration de retour.';
      await _handleOfflineRequest(url, 'POST', payload, baseErrorMessage);
    }
  }

  Future<RiderCashDetails> fetchRiderCashDetails(DateTime date) async {
    try {
      final response = await _dio.get(
        '$_apiBaseUrl/cash-details',
        queryParameters: {
          'date': DateFormat('yyyy-MM-dd').format(date),
        },
      );

      return RiderCashDetails.fromJson(response.data);

    } on DioException catch (e) {
      String message = e.response?.data['message'] ?? 'Échec de la récupération de la caisse.';
      throw Exception(message);
    } catch (e) {
      throw Exception("Une erreur inattendue est survenue lors du chargement de la caisse.");
    }
  }
}