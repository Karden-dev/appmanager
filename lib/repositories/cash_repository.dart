// lib/repositories/cash_repository.dart

import 'package:flutter/foundation.dart';
import 'package:wink_manager/models/cash_models.dart';
import 'package:wink_manager/services/cash_service.dart';
import 'package:wink_manager/services/database_service.dart';
import 'package:wink_manager/models/user.dart'; // Assurez-vous d'avoir ce modèle importé

class CashRepository {
  final CashService _apiService;
  final DatabaseService _dbService;

  CashRepository(this._apiService, this._dbService);

  // --- MÉTRIQUES ---
  Future<CashMetrics> fetchMetrics(DateTime startDate, DateTime endDate) async {
    return await _apiService.fetchMetrics(startDate: startDate, endDate: endDate);
  }

  // --- TRANSACTIONS ---
  Future<List<CashTransaction>> fetchTransactions({
    required DateTime startDate,
    required DateTime endDate,
    String? type,
  }) async {
    return await _apiService.fetchTransactions(
      startDate: startDate,
      endDate: endDate,
      type: type,
    );
  }

  // --- MANQUANTS ---
  // Mise à jour pour supporter le filtre de statut (pour les détails)
  Future<List<Shortfall>> fetchShortfalls({String? status}) async {
    return await _apiService.fetchShortfalls(status: status);
  }
  
  // --- CATÉGORIES ---
  Future<List<ExpenseCategory>> fetchCategories() async {
    return await _apiService.fetchExpenseCategories();
  }

  // --- VERSEMENTS ---
  Future<List<RemittanceSummaryItem>> fetchRemittanceSummary({
    required DateTime startDate, 
    required DateTime endDate
  }) async {
    return await _apiService.fetchRemittanceSummary(startDate: startDate, endDate: endDate);
  }

  Future<List<RemittanceOrder>> fetchRemittanceDetails(int deliverymanId, DateTime startDate, DateTime endDate) async {
    return await _apiService.fetchRemittanceDetails(deliverymanId, startDate, endDate);
  }

  Future<void> confirmRemittance({
    required int deliverymanId, 
    required List<int> orderIds, 
    required double amount,
    required DateTime date,
  }) async {
    await _apiService.confirmRemittance(
      deliverymanId: deliverymanId, 
      orderIds: orderIds, 
      amount: amount,
      date: date
    );
  }

  // --- NOUVEAU : RECHERCHE UTILISATEURS (Pour Dépenses) ---
  Future<List<User>> searchUsers(String query) async {
    return await _apiService.searchUsers(query);
  }

  // --- ACTIONS D'ÉCRITURE (CRUD) ---

  Future<void> createExpense(Map<String, dynamic> data) async {
    await _apiService.createExpense(data);
  }

  Future<void> createWithdrawal(Map<String, dynamic> data) async {
    await _apiService.createWithdrawal(data);
  }

  // **Transactions : Mise à jour / Suppression**
  Future<void> updateTransaction(int id, double amount, String comment) async {
    await _apiService.updateTransaction(id, amount, comment);
  }

  Future<void> deleteTransaction(int id) async {
    await _apiService.deleteTransaction(id);
  }

  // **Manquants : Création / Mise à jour / Suppression / Règlement**
  Future<void> createShortfall(int deliverymanId, double amount, String comment, DateTime date) async {
    await _apiService.createShortfall(deliverymanId, amount, comment, date);
  }

  Future<void> updateShortfall(int id, double amount, String comment) async {
    await _apiService.updateShortfall(id, amount, comment);
  }

  Future<void> deleteShortfall(int id) async {
    await _apiService.deleteShortfall(id);
  }

  Future<void> settleShortfall(int id, double amount, DateTime date) async {
    await _apiService.settleShortfall(id, amount, date);
  }

  // --- CLÔTURE ---
  Future<void> closeCash(DateTime date, double actualCash, String comment) async {
    await _apiService.closeCash(date, actualCash, comment);
  }
  
  Future<List<CashClosing>> fetchClosingHistory(DateTime startDate, DateTime endDate) async {
     return await _apiService.fetchClosingHistory(startDate: startDate, endDate: endDate);
  }
}