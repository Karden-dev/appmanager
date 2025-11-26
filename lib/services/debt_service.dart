// lib/services/debt_service.dart

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Pour kDebugMode
import 'package:wink_manager/models/debt.dart';
import 'package:wink_manager/services/auth_service.dart';

class DebtService {
  final AuthService _authService;
  final Dio _dio;

  DebtService(this._authService) : _dio = _authService.dio;

  /// Récupère la liste des créances avec filtres.
  /// Gère la distinction des paramètres de date selon le statut (Pending vs Paid).
  Future<List<Debt>> fetchDebts({
    required DateTime startDate,
    required DateTime endDate,
    String? status, // 'pending', 'paid', ou null pour tout
    String? search,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status != 'all') 'status': status,
      };

      final dateStrStart = DateFormat('yyyy-MM-dd').format(startDate);
      final dateStrEnd = DateFormat('yyyy-MM-dd').format(endDate);

      // LOGIQUE BACKEND :
      // Si on filtre par 'paid', le backend attend 'settledStartDate' / 'settledEndDate'
      // Sinon (pending ou tout), il utilise 'startDate' / 'endDate' (basé sur created_at)
      if (status == 'paid') {
        queryParams['settledStartDate'] = dateStrStart;
        queryParams['settledEndDate'] = dateStrEnd;
      } else {
        queryParams['startDate'] = dateStrStart;
        queryParams['endDate'] = dateStrEnd;
      }

      final response = await _dio.get('/debts', queryParameters: queryParams);

      if (response.statusCode == 200) {
        final List<dynamic> body = response.data;
        return body.map((dynamic item) => Debt.fromJson(item)).toList();
      } else {
        throw Exception('Erreur chargement dettes: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (kDebugMode) print('DebtService: Erreur fetchDebts: $e');
      // On laisse l'erreur remonter pour que le Repository bascule en mode Offline
      throw Exception(e.response?.data['message'] ?? 'Erreur réseau (Dettes)');
    }
  }

  /// Crée une nouvelle créance manuelle.
  Future<void> createDebt(Map<String, dynamic> debtData) async {
    try {
      // Le backend attend : shop_id, amount, type, comment, created_by, created_at
      // On s'assure que created_by est ajouté si manquant
      if (!debtData.containsKey('created_by')) {
        debtData['created_by'] = _authService.user?.id;
      }
      
      await _dio.post('/debts', data: debtData);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec création dette.');
    }
  }

  /// Met à jour une créance existante (Montant, Commentaire).
  Future<void> updateDebt(int id, double amount, String comment) async {
    try {
      await _dio.put(
        '/debts/$id',
        data: {
          'amount': amount,
          'comment': comment,
          'updated_by': _authService.user?.id,
        },
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec mise à jour dette.');
    }
  }

  /// Supprime une créance.
  Future<void> deleteDebt(int id) async {
    try {
      await _dio.delete('/debts/$id');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec suppression dette.');
    }
  }

  /// Règle une créance (Passe le statut à 'paid').
  Future<void> settleDebt(int id) async {
    try {
      // IMPORTANT : Le backend exige 'userId' dans le body pour cette route spécifique
      await _dio.put(
        '/debts/$id/settle',
        data: {'userId': _authService.user?.id},
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec du règlement.');
    }
  }
}