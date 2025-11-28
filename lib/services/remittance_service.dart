// lib/services/remittance_service.dart

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:wink_manager/models/remittance.dart';
import 'package:wink_manager/services/auth_service.dart';

class RemittanceService {
  final AuthService _authService;
  final Dio _dio;

  RemittanceService(this._authService) : _dio = _authService.dio;

  // Récupérer la liste et les stats (appelée par le Repository)
  Future<({List<Remittance> remittances, RemittanceStats stats})> fetchRemittances({
    required DateTime date,
    String? status,
    String? search,
  }) async {
    try {
      final response = await _dio.get(
        '/remittances',
        queryParameters: {
          'date': DateFormat('yyyy-MM-dd').format(date),
          if (status != null && status != 'all') 'status': status,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );

      final data = response.data;
      final List<dynamic> list = data['remittances'] ?? [];
      final statsJson = data['stats'] ?? {};

      return (
        remittances: list.map((e) => Remittance.fromJson(e)).toList(),
        stats: RemittanceStats.fromJson(statsJson),
      );
    } catch (e) {
      // Renvoie l'erreur pour la gestion du mode hors ligne par le Repository
      throw Exception('Erreur chargement versements: $e');
    }
  }

  // Marquer comme payé
  Future<void> markAsPaid(int remittanceId) async {
    try {
      await _dio.put(
        '/remittances/$remittanceId/pay',
        data: {'userId': _authService.user?.id},
      );
    } catch (e) {
      throw Exception('Erreur paiement versement #$remittanceId: $e');
    }
  }

  // --- MISE À JOUR : Mettre à jour les infos de paiement du marchand ---
  // (Implémente la fonctionnalité d'édition demandée, comme sur la version web)
  Future<void> updateShopPaymentDetails(int shopId, String name, String phone, String operator) async {
    try {
      await _dio.put(
        '/remittances/shop-details/$shopId',
        data: {
          'payment_name': name,
          'phone_number_for_payment': phone,
          'payment_operator': operator,
        },
      );
    } catch (e) {
      throw Exception('Erreur mise à jour infos: $e');
    }
  }
}