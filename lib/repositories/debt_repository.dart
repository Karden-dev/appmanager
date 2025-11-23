// lib/repositories/debt_repository.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wink_manager/models/debt.dart';
import 'package:wink_manager/services/database_service.dart';
import 'package:wink_manager/services/debt_service.dart';

class DebtRepository {
  final DebtService _apiService;
  final DatabaseService _dbService;

  static const int _kItemsPerPage = 10;

  DebtRepository(this._apiService, this._dbService);

  /// Récupère les dettes (Cache-First)
  Future<List<Debt>> fetchDebts({
    required DateTime startDate,
    required DateTime endDate,
    String? status,
    String? search,
    required int page,
  }) async {
    try {
      // 1. Tenter l'API
      final apiDebts = await _apiService.fetchDebts(
        startDate: startDate,
        endDate: endDate,
        status: status,
        search: search,
      );

      // 2. Mise à jour du cache
      await _syncDebtsToDb(apiDebts);

    } on DioException catch (e) {
      if (kDebugMode) {
        print('DebtRepository: Mode Offline ou Erreur API. ${e.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DebtRepository: Erreur inconnue. $e');
      }
    }

    // 3. Lecture depuis le cache
    return _getDebtsFromDb(
      startDate: startDate,
      endDate: endDate,
      status: status,
      search: search,
      page: page,
      limit: _kItemsPerPage,
    );
  }

  // --- Actions ---

  Future<void> createDebt(Map<String, dynamic> debtData) async {
    await _apiService.createDebt(debtData);
  }

  Future<void> updateDebt(int id, double amount, String comment) async {
    await _apiService.updateDebt(id, amount, comment);
    final db = await _dbService.database;
    await db.update(
      DatabaseService.tableDebtsCache,
      {'amount': amount, 'comment': comment},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDebt(int id) async {
    await _apiService.deleteDebt(id);
    final db = await _dbService.database;
    await db.delete(
      DatabaseService.tableDebtsCache,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> settleDebt(int id) async {
    await _apiService.settleDebt(id);
    final db = await _dbService.database;
    // On formate la date de règlement avec un espace pour la cohérence
    final nowStr = DateTime.now().toIso8601String().replaceAll('T', ' ');
    await db.update(
      DatabaseService.tableDebtsCache,
      {
        'status': 'paid',
        'settled_at': nowStr,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Helpers DB & Stats (CORRIGÉ STRICT) ---

  Future<List<Debt>> getAllDebtsForStats({
      required DateTime startDate,
      required DateTime endDate,
      String? search,
  }) async {
    final db = await _dbService.database;
    // On charge tout le cache pour filtrer précisément en Dart
    final maps = await db.query(DatabaseService.tableDebtsCache);
    final allDebts = maps.map((e) => Debt.fromMap(e)).toList();
    
    // Conversion des dates de filtre en format string YYYY-MM-DD pour comparaison stricte
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);

    return allDebts.where((d) {
      // 1. Filtre Recherche
      if (search != null && search.isNotEmpty) {
        if (!d.shopName.toLowerCase().contains(search.toLowerCase())) return false;
      }

      // 2. Filtre Date
      bool inDateRange = false;
      
      if (d.status == 'paid') {
         // Pour les PAYÉS : On veut ceux payés DANS la période exacte
         if (d.settledAt != null) {
             final paidStr = DateFormat('yyyy-MM-dd').format(d.settledAt!);
             inDateRange = (paidStr.compareTo(startStr) >= 0 && paidStr.compareTo(endStr) <= 0);
         }
      } else {
         // CORRECTION ICI : Filtrage STRICT pour les "En attente" (comme le Web)
         // On ne prend que ce qui a été créé ENTRE date début et date fin.
         final createdStr = DateFormat('yyyy-MM-dd').format(d.createdAt);
         inDateRange = (createdStr.compareTo(startStr) >= 0 && createdStr.compareTo(endStr) <= 0);
      }

      return inDateRange;
    }).toList();
  }
  
  Future<void> _syncDebtsToDb(List<Debt> debts) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final debt in debts) {
        final map = debt.toMapForDb();
        
        // Remplacement 'T' par ' ' pour compatibilité SQLite
        if (map['created_at'] is String) {
          map['created_at'] = (map['created_at'] as String).replaceAll('T', ' ');
        }
        if (map['settled_at'] is String) {
          map['settled_at'] = (map['settled_at'] as String).replaceAll('T', ' ');
        }

        batch.insert(
          DatabaseService.tableDebtsCache,
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Debt>> _getDebtsFromDb({
    required DateTime startDate,
    required DateTime endDate,
    String? status,
    String? search,
    required int page,
    required int limit,
  }) async {
    final db = await _dbService.database;
    
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);
    
    final startStrFull = '$startStr 00:00:00';
    final endStrFull = '$endStr 23:59:59';

    if (status == 'paid') {
       // Pour l'historique
       whereClauses.add('settled_at BETWEEN ? AND ?');
    } else {
       // CORRECTION ICI : Pour la liste principale "En attente", on applique le filtre STRICT
       whereClauses.add('created_at BETWEEN ? AND ?');
    }
    whereArgs.addAll([startStrFull, endStrFull]);

    if (status != null && status != 'all') {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }

    if (search != null && search.isNotEmpty) {
      whereClauses.add('shop_name LIKE ?');
      whereArgs.add('%$search%');
    }

    final offset = (page - 1) * limit;

    final maps = await db.query(
      DatabaseService.tableDebtsCache,
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((e) => Debt.fromMap(e)).toList();
  }
}