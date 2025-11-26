// lib/repositories/remittance_repository.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wink_manager/models/remittance.dart';
import 'package:wink_manager/services/database_service.dart';
import 'package:wink_manager/services/remittance_service.dart';

class RemittanceRepository {
  final RemittanceService _apiService;
  final DatabaseService _dbService;
  
  static const int _kItemsPerPage = 5; 

  RemittanceRepository(this._apiService, this._dbService);

  // --- LOGIQUE DE LECTURE (Cache-First) ---
  
  Future<({List<Remittance> remittances, RemittanceStats stats})> fetchRemittances({
    required DateTime date,
    required int page,
    String? status,
    String? search,
  }) async {
    try {
      // 1. Appel API
      final apiData = await _apiService.fetchRemittances(
        date: date,
        status: status,
        search: search,
      );

      // 2. Mise à jour du cache (Seulement si on est sur la page 1)
      if (page == 1) {
        await _syncRemittancesToDb(apiData.remittances, date);
      }
      
      // 3. Lecture depuis le cache (Source de vérité)
      final localRemittances = await _getRemittancesFromDb(
        date: date,
        page: page,
        limit: _kItemsPerPage,
        status: status,
        search: search,
      );
      
      return (remittances: localRemittances, stats: apiData.stats);

    } on DioException catch (e) {
      if (kDebugMode) {
        print('RemittanceRepository: Mode Offline. ${e.message}');
      }
      // Fallback: Lecture cache uniquement
      final localRemittances = await _getRemittancesFromDb(
        date: date,
        page: page,
        limit: _kItemsPerPage,
        status: status,
        search: search,
      );
      
      return (remittances: localRemittances, stats: RemittanceStats());
    } catch (e) {
       if (kDebugMode) {
        print('RemittanceRepository: Erreur Inconnue. $e');
       }
       rethrow;
    }
  }

  // --- LOGIQUE D'ÉCRITURE ---

  Future<void> markAsPaid(int remittanceId) async {
    try {
      await _apiService.markAsPaid(remittanceId);
      
      final db = await _dbService.database;
      await db.update(
        DatabaseService.tableRemittancesCache, 
        {'status': 'paid', 'payment_date': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [remittanceId]
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateShopPaymentDetails(
      int shopId, String name, String phone, String operator) async {
    try {
      await _apiService.updateShopPaymentDetails(shopId, name, phone, operator);
      
      final db = await _dbService.database;
      await db.update(
        DatabaseService.tableRemittancesCache, 
        {
          'payment_name': name,
          'phone_number_for_payment': phone,
          'payment_operator': operator,
        },
        where: 'shop_id = ?', whereArgs: [shopId]
      );
    } catch (e) {
      rethrow;
    }
  }


  // --- HELPERS DB (CORRIGÉS) ---

  Future<void> _syncRemittancesToDb(List<Remittance> apiRemittances, DateTime date) async {
    final db = await _dbService.database;
    // Formatage strict pour la clé de date (YYYY-MM-DD)
    final dateString = DateFormat('yyyy-MM-dd').format(date);

    await db.transaction((txn) async {
      // 1. Nettoyage pour cette date spécifique
      await txn.delete(
        DatabaseService.tableRemittancesCache,
        where: 'remittance_date = ?',
        whereArgs: [dateString],
      );
      
      // 2. Insertion avec FORÇAGE du format de date
      final batch = txn.batch();
      for (final rem in apiRemittances) {
        final map = rem.toMapForDb();
        // CORRECTION CRITIQUE : On écrase la date ISO par la date courte pour correspondre à la recherche
        map['remittance_date'] = dateString; 
        
        batch.insert(
          DatabaseService.tableRemittancesCache, 
          map, 
          conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
      await batch.commit(noResult: true);
    });
    if (kDebugMode) print('RemittanceRepository: Cache synchronisé pour $dateString.');
  }

  Future<List<Remittance>> _getRemittancesFromDb({
    required DateTime date,
    required int page,
    required int limit,
    String? status,
    String? search,
  }) async {
    final db = await _dbService.database;
    // Utilisation du même format strict pour la recherche
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    
    List<String> whereClauses = ['remittance_date = ?'];
    List<dynamic> whereArgs = [dateString];

    if (status != null && status != 'all') {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }
    
    if (search != null && search.isNotEmpty) {
      final query = '%$search%';
      whereClauses.add('(shop_name LIKE ? OR phone_number_for_payment LIKE ?)');
      whereArgs.addAll([query, query]);
    }

    final int offset = (page - 1) * limit;

    final maps = await db.query(
      DatabaseService.tableRemittancesCache,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'status DESC, shop_name ASC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => Remittance.fromMap(map)).toList();
  }
}