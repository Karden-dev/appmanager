// lib/repositories/shop_repository.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/services/database_service.dart';
import 'package:wink_manager/services/shop_service.dart';

class ShopRepository {
  final ShopService _apiService;
  final DatabaseService _dbService;

  ShopRepository(this._apiService, this._dbService);

  /// Récupère la liste des marchands (Cache-First ou Network-First selon la logique choisie).
  /// Ici : On tente l'API, on met à jour la DB, puis on lit la DB.
  Future<List<Shop>> fetchShops({String? search, String? status}) async {
    try {
      // 1. Appel API
      final apiShops = await _apiService.fetchShops(search: search, status: status);
      
      // 2. Mise à jour du cache local
      // On ne vide pas toute la table, on met à jour ou insère les nouveaux/modifiés
      // Si on voulait une synchro parfaite (suppression des obsolètes), il faudrait une logique plus complexe
      // ou un 'deleteAll' si on est sûr de tout recharger.
      // Pour l'instant, on fait un upsert (insert or replace).
      await _syncShopsToDb(apiShops);

    } on DioException catch (e) {
      if (kDebugMode) {
        print('ShopRepository: Mode Offline ou Erreur API. ${e.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ShopRepository: Erreur inconnue. $e');
      }
    }

    // 3. Lecture depuis la BDD locale (Source de vérité pour l'UI)
    return _getShopsFromDb(search: search, status: status);
  }

  /// Récupère les statistiques (Direct API pour l'instant, pas de cache DB pour les stats simples)
  Future<Map<String, int>> fetchStats() async {
    try {
      return await _apiService.fetchShopStats();
    } catch (e) {
      // En cas d'erreur (offline), on pourrait calculer les stats locales depuis la DB
      // Pour l'instant on retourne des zéros ou on relance l'erreur selon le besoin.
      if (kDebugMode) print("ShopRepository: Erreur fetchStats: $e");
      // Tentative de calcul local en fallback
      return _calculateLocalStats(); 
    }
  }

  // --- Actions d'Écriture ---

  Future<void> createShop(Map<String, dynamic> shopData) async {
    await _apiService.createShop(shopData);
    // Idéalement, on rechargerait la liste ou on ajouterait l'item en local ici
  }

  Future<void> updateShop(int id, Map<String, dynamic> shopData) async {
    await _apiService.updateShop(id, shopData);
    // Mise à jour locale optimiste ou rechargement nécessaire ensuite
  }

  Future<void> updateShopStatus(int id, String status) async {
    await _apiService.updateShopStatus(id, status);
    
    // Mise à jour locale immédiate pour réactivité
    final db = await _dbService.database;
    await db.update(
      DatabaseService.tableShops,
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Helpers DB ---

  Future<void> _syncShopsToDb(List<Shop> shops) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final shop in shops) {
        batch.insert(
          DatabaseService.tableShops,
          shop.toMapForDb(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Shop>> _getShopsFromDb({String? search, String? status}) async {
    final db = await _dbService.database;
    
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (search != null && search.isNotEmpty) {
      whereClauses.add('(name LIKE ? OR phone_number LIKE ?)');
      whereArgs.addAll(['%$search%', '%$search%']);
    }

    if (status != null && status != 'all') {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }

    final maps = await db.query(
      DatabaseService.tableShops,
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );

    return maps.map((map) => Shop.fromMap(map)).toList();
  }
  
  Future<Map<String, int>> _calculateLocalStats() async {
    final db = await _dbService.database;
    final total = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseService.tableShops}')) ?? 0;
    final active = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM ${DatabaseService.tableShops} WHERE status = 'actif'")) ?? 0;
    
    return {
      'total': total,
      'active': active,
      'inactive': total - active,
    };
  }
}