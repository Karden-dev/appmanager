// lib/services/shop_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/services/auth_service.dart';

class ShopService {
  final AuthService _authService;
  final Dio _dio;

  ShopService(this._authService) : _dio = _authService.dio;

  /// Récupère la liste des marchands avec filtres optionnels.
  /// Utilisé pour remplir le tableau.
  Future<List<Shop>> fetchShops({String? search, String? status}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final response = await _dio.get('/shops', queryParameters: queryParams);

      if (response.statusCode == 200) {
        final List<dynamic> body = response.data;
        return body.map((dynamic item) => Shop.fromJson(item)).toList();
      } else {
        throw Exception('Erreur chargement marchands: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (kDebugMode) print('ShopService: Erreur fetchShops: $e');
      throw Exception(e.response?.data['message'] ?? 'Erreur réseau (Marchands)');
    }
  }

  /// Récupère les statistiques GLOBALES (Total, Actif, Inactif).
  /// Appelle la route dédiée '/shops/stats' pour avoir les chiffres exacts du serveur.
  Future<Map<String, int>> fetchShopStats() async {
    try {
      final response = await _dio.get('/shops/stats');
      
      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'total': (data['total'] as num?)?.toInt() ?? 0,
          'active': (data['active'] as num?)?.toInt() ?? 0,
          'inactive': (data['inactive'] as num?)?.toInt() ?? 0,
        };
      } else {
        throw Exception('Erreur chargement stats: ${response.statusCode}');
      }
    } on DioException catch (e) {
       if (kDebugMode) print('ShopService: Erreur fetchShopStats: $e');
       // On relance l'exception pour permettre au Repository de basculer en mode offline
       throw Exception(e.response?.data['message'] ?? 'Erreur réseau (Stats)');
    }
  }

  /// Récupère un marchand spécifique par ID.
  Future<Shop> fetchShopById(int id) async {
    try {
      final response = await _dio.get('/shops/$id');
      return Shop.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Erreur récupération marchand');
    }
  }

  /// Crée un nouveau marchand.
  Future<void> createShop(Map<String, dynamic> shopData) async {
    try {
      await _dio.post('/shops', data: shopData);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec création marchand');
    }
  }

  /// Met à jour un marchand existant.
  Future<void> updateShop(int id, Map<String, dynamic> shopData) async {
    try {
      await _dio.put('/shops/$id', data: shopData);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec mise à jour marchand');
    }
  }

  /// Change le statut d'un marchand (Actif/Inactif).
  Future<void> updateShopStatus(int id, String status) async {
    try {
      await _dio.put('/shops/$id/status', data: {'status': status});
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec changement statut');
    }
  }
}