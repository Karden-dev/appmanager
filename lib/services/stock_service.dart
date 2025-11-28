// lib/services/stock_service.dart

import 'package:dio/dio.dart';
import 'package:wink_manager/services/auth_service.dart';
import 'package:flutter/foundation.dart';

class StockService {
  final AuthService _authService;
  final Dio _dio;

  StockService(this._authService) : _dio = _authService.dio;

  // --- 1. GESTION DES VALIDATIONS (FLUX D'ENTRÉE) ---

  /// Récupère toutes les demandes d'entrée de stock en attente ("pending")
  /// Route: GET /api/stock/requests/pending
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final response = await _dio.get('/stock/requests/pending');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('StockService: Erreur getPendingRequests: $e');
      rethrow;
    }
  }

  /// Valide une demande d'entrée (Ajoute le stock réel)
  /// Route: PUT /api/stock/requests/:id/validate
  Future<void> validateRequest(int requestId, int validatedQuantity) async {
    try {
      await _dio.put(
        '/stock/requests/$requestId/validate',
        data: {'validated_quantity': validatedQuantity},
      );
    } catch (e) {
      debugPrint('StockService: Erreur validateRequest: $e');
      throw Exception('Impossible de valider la demande.');
    }
  }

  /// Rejette une demande d'entrée
  /// Route: PUT /api/stock/requests/:id/reject
  Future<void> rejectRequest(int requestId, String reason) async {
    try {
      await _dio.put(
        '/stock/requests/$requestId/reject',
        data: {'reason': reason},
      );
    } catch (e) {
      debugPrint('StockService: Erreur rejectRequest: $e');
      throw Exception('Impossible de rejeter la demande.');
    }
  }

  // --- 2. CONSULTATION (VUE GLOBALE) ---

  /// Récupère l'inventaire complet d'une boutique
  /// Route: GET /api/products/shop/:shopId
  Future<List<Map<String, dynamic>>> getShopInventory(int shopId) async {
    try {
      final response = await _dio.get('/products/shop/$shopId');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('StockService: Erreur getShopInventory: $e');
      return [];
    }
  }

  /// Récupère l'historique des mouvements d'un produit spécifique
  /// Route: GET /api/stock/movements/product/:productId
  Future<List<Map<String, dynamic>>> getProductHistory(int productId) async {
    try {
      final response = await _dio.get('/stock/movements/product/$productId');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('StockService: Erreur getProductHistory: $e');
      return [];
    }
  }
}