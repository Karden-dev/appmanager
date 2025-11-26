// lib/services/cash_service.dart

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:wink_manager/models/cash_models.dart';
import 'package:wink_manager/models/user.dart';
import 'package:wink_manager/services/auth_service.dart';
import 'package:flutter/foundation.dart';

class CashService {
  final AuthService _authService;
  final Dio _dio;

  CashService(this._authService) : _dio = _authService.dio;

  // --- 1. Récupération des Métriques ---
  Future<CashMetrics> fetchMetrics({required DateTime startDate, required DateTime endDate}) async {
    final response = await _dio.get('/cash/metrics', queryParameters: {
      'startDate': DateFormat('yyyy-MM-dd').format(startDate),
      'endDate': DateFormat('yyyy-MM-dd').format(endDate),
    });
    return CashMetrics.fromJson(response.data);
  }

  // --- 2. Transactions (Dépenses / Décaissements) ---
  // MODIFIÉ : Ajout du paramètre search
  Future<List<CashTransaction>> fetchTransactions({
    required DateTime startDate,
    required DateTime endDate,
    String? type,
    String? search, // <-- AJOUT
  }) async {
    final response = await _dio.get('/cash/transactions', queryParameters: {
      'startDate': DateFormat('yyyy-MM-dd').format(startDate),
      'endDate': DateFormat('yyyy-MM-dd').format(endDate),
      if (type != null) 'type': type,
      if (search != null && search.isNotEmpty) 'search': search, // <-- AJOUT
    });
    return (response.data as List).map((e) => CashTransaction.fromJson(e)).toList();
  }

  // --- 3. Manquants (Shortfalls) ---
  // MODIFIÉ : Ajout du paramètre search
  Future<List<Shortfall>> fetchShortfalls({String? status, String? search}) async {
    final response = await _dio.get('/cash/shortfalls', queryParameters: {
      if (status != null) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search, // <-- AJOUT
    });
    return (response.data as List).map((e) => Shortfall.fromJson(e)).toList();
  }

  // --- 4. Catégories ---
  Future<List<ExpenseCategory>> fetchExpenseCategories() async {
    final response = await _dio.get('/cash/expense-categories');
    return (response.data as List).map((e) => ExpenseCategory.fromJson(e)).toList();
  }

  // --- 5. Résumé des Versements ---
  Future<List<RemittanceSummaryItem>> fetchRemittanceSummary({
    required DateTime startDate,
    required DateTime endDate,
    String? search, // Ajout optionnel si nécessaire pour le résumé
  }) async {
    final response = await _dio.get('/cash/remittance-summary', queryParameters: {
      'startDate': DateFormat('yyyy-MM-dd').format(startDate),
      'endDate': DateFormat('yyyy-MM-dd').format(endDate),
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return (response.data as List).map((e) => RemittanceSummaryItem.fromJson(e)).toList();
  }

  // --- 6. Détail Versement ---
  Future<List<RemittanceOrder>> fetchRemittanceDetails(int deliverymanId, DateTime startDate, DateTime endDate) async {
    try {
      final response = await _dio.get('/cash/remittance-details/$deliverymanId', queryParameters: {
        'date': DateFormat('yyyy-MM-dd').format(endDate),
      });
      
      final data = response.data;
      if (data is Map<String, dynamic> && data.containsKey('orders')) {
        final List<dynamic> ordersList = data['orders'];
        return ordersList.map((e) => RemittanceOrder.fromJson(e)).toList();
      } else if (data is List) {
        return data.map((e) => RemittanceOrder.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('CashService: Erreur fetchRemittanceDetails: $e');
      throw Exception('Impossible de charger les détails du versement.');
    }
  }

  // --- 7. Recherche Utilisateurs (Pour Bénéficiaire Dépense) ---
  Future<List<User>> searchUsers(String query) async {
    try {
      final response = await _dio.get('/users', queryParameters: {
        'search': query,
        'limit': 20, 
      });
      
      List<dynamic> usersList = [];
      
      if (response.data is List) {
        usersList = response.data;
      } else if (response.data is Map && response.data.containsKey('users')) {
         usersList = response.data['users'];
      } else if (response.data is Map && response.data.containsKey('data')) {
         usersList = response.data['data'];
      }

      return usersList.map((e) => User.fromJson(e)).toList();

    } catch (e) {
      debugPrint('CashService: Erreur searchUsers: $e');
      return [];
    }
  }

  // --- 8. Actions d'Écriture (CRUD) ---

  Future<void> createExpense(Map<String, dynamic> data) async {
    await _dio.post('/cash/expense', data: data);
  }

  Future<void> createWithdrawal(Map<String, dynamic> data) async {
    await _dio.post('/cash/withdrawal', data: data);
  }

  Future<void> updateTransaction(int id, double amount, String comment) async {
    await _dio.put('/cash/transactions/$id', data: {
      'amount': amount,
      'comment': comment,
    });
  }

  Future<void> deleteTransaction(int id) async {
    await _dio.delete('/cash/transactions/$id');
  }

  Future<void> createShortfall(int deliverymanId, double amount, String comment, DateTime date) async {
    await _dio.post('/cash/shortfalls', data: {
      'deliverymanId': deliverymanId,
      'amount': amount,
      'comment': comment,
      'date': DateFormat('yyyy-MM-dd HH:mm:ss').format(date),
    });
  }

  Future<void> updateShortfall(int id, double amount, String comment) async {
    await _dio.put('/cash/shortfalls/$id', data: {
      'amount': amount,
      'comment': comment,
    });
  }

  Future<void> deleteShortfall(int id) async {
    await _dio.delete('/cash/shortfalls/$id');
  }

  Future<void> settleShortfall(int id, double amount, DateTime date) async {
    await _dio.put('/cash/shortfalls/$id/settle', data: {
      'amountPaid': amount,
      'settlementDate': DateFormat('yyyy-MM-dd').format(date),
    });
  }

  Future<void> closeCash(DateTime date, double actualCash, String comment) async {
    await _dio.post('/cash/close-cash', data: {
      'closingDate': DateFormat('yyyy-MM-dd').format(date),
      'actualCash': actualCash,
      'comment': comment,
    });
  }

  Future<void> confirmRemittance({
    required int deliverymanId,
    required List<int> orderIds,
    required double amount,
    required DateTime date,
  }) async {
    await _dio.post('/cash/remittances/confirm', data: {
      'deliverymanId': deliverymanId,
      'orderIds': orderIds,
      'paidAmount': amount,
      'date': DateFormat('yyyy-MM-dd HH:mm:ss').format(date),
    });
  }
  
  Future<List<CashClosing>> fetchClosingHistory({required DateTime startDate, required DateTime endDate}) async {
     try {
       final response = await _dio.get('/cash/closing-history', queryParameters: {
        'startDate': DateFormat('yyyy-MM-dd').format(startDate),
        'endDate': DateFormat('yyyy-MM-dd').format(endDate),
       });
       return (response.data as List).map((e) => CashClosing.fromJson(e)).toList();
     } catch (e) {
       return [];
     }
  }
}