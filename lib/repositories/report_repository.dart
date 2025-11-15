// lib/repositories/report_repository.dart

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wink_manager/models/report_models.dart';
import 'package:wink_manager/repositories/order_repository.dart';
import 'package:wink_manager/services/database_service.dart';
import 'package:wink_manager/services/report_service.dart';

// *** CORRECTION : Le nom de la classe est maintenant correct ***
class ReportRepository {
  final ReportService _apiService;
  final DatabaseService _dbService;
  final OrderRepository _orderRepository;

  ReportRepository(this._apiService, this._dbService, this._orderRepository);

  /// Charge les bilans (Network-First, Cache-Fallback).
  Future<List<ReportSummary>> fetchReports(DateTime date) async {
    List<ReportSummary> reports = [];
    String? apiError;

    // 1. Tenter l'API
    try {
      reports = await _apiService.fetchReports(date);
      // Si succès, mettre à jour le cache en arrière-plan
      _cacheReports(reports, date);
      return reports;
    } catch (e) {
      apiError = e.toString().replaceFirst('Exception: ', '');
      if (kDebugMode) {
        print("ReportRepository: Échec API fetchReports. $apiError");
      }
    }

    // 2. Tenter le Cache (si l'API a échoué)
    try {
      reports = await _getReportsFromCache(date);
      if (reports.isNotEmpty) {
        if (kDebugMode) {
          print("ReportRepository: Données chargées du cache pour $date.");
        }
        return reports;
      }
    } catch (e) {
      if (kDebugMode) {
        print("ReportRepository: Échec chargement cache. $e");
      }
    }

    // 3. Échec total
    if (reports.isEmpty && apiError != null) {
      throw Exception(apiError);
    }
    return [];
  }

  /// Déclenche le traitement des frais de stockage (pass-through API).
  Future<String> processStorage(DateTime date) async {
    return _apiService.processStorage(date);
  }

  /// Déclenche le recalcul des bilans (pass-through API).
  Future<String> recalculateReports(DateTime date) async {
    return _apiService.recalculateReports(date);
  }

  /// Génère le texte à copier (logique offline/online).
  Future<String> generateReportStringForCopy(
      DateTime date, int shopId, bool isOnline) async {
    try {
      ReportDetailed details;

      if (isOnline) {
        details = await _apiService.fetchReportDetails(date, shopId);
      } else {
        details = await _generateReportDetailsFromCache(date, shopId);
      }

      // --- Logique de formatage (identique à celle du provider) ---
      final formatter =
          NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: 0);

      String formatAmount(double amount) {
        return '${formatter.format(amount)} FCFA';
      }

      final buffer = StringBuffer();
      final formattedDate = DateFormat('dd/MM/yyyy', 'fr_FR').format(date);

      buffer.writeln('*Rapport du :* $formattedDate');
      buffer.writeln('*Magasin :* ${details.shopName}\n');
      buffer.writeln('*--- DETAIL DES LIVRAISONS ---*\n');

      if (details.orders.isNotEmpty) {
        for (var (index, order) in details.orders.indexed) {
          final productsList = order.productsList.isEmpty
              ? 'Produit non spécifié'
              : order.productsList;
          final clientPhoneFormatted = order.customerPhone.length > 6
              ? '${order.customerPhone.substring(0, 6)}***'
              : 'N/A';
          final amountToDisplay = order.status == 'failed_delivery'
              ? order.amountReceived
              : order.articleAmount;

          buffer.writeln('*${index + 1})* Produit(s) : $productsList');
          buffer.writeln('   Quartier : ${order.deliveryLocation}');
          buffer.writeln('   Client : $clientPhoneFormatted');
          buffer.writeln('   Montant perçu : ${formatAmount(amountToDisplay)}');
          buffer.writeln(
              '   Frais de livraison : ${formatAmount(order.deliveryFee)}');
          if (order.status == 'failed_delivery') {
            buffer.writeln('   *Statut :* Livraison ratée');
          }
          buffer.writeln();
        }
      } else {
        buffer.writeln("Aucune livraison enregistrée pour cette journée.\n");
      }

      buffer.writeln('*--- RÉSUMÉ FINANCIER ---*');
      buffer.writeln(
          '*Total encaissement (Cash/Raté) :* ${formatAmount(details.totalRevenueArticles)}');

      if (details.totalDeliveryFees > 0) buffer.writeln('*Total Frais de livraison :* ${formatAmount(details.totalDeliveryFees)}');
      if (details.totalPackagingFees > 0) buffer.writeln('*Total Frais d\'emballage :* ${formatAmount(details.totalPackagingFees)}');
      if (details.totalStorageFees > 0) buffer.writeln('*Total Frais de stockage (jour) :* ${formatAmount(details.totalStorageFees)}');
      if (details.totalExpeditionFees > 0) buffer.writeln('*Total Frais d\'expédition :* ${formatAmount(details.totalExpeditionFees)}');
      if (details.previousDebts > 0) buffer.writeln('*Créances antérieures :* ${formatAmount(details.previousDebts)}');

      buffer.writeln('\n*MONTANT NET À VERSER :* ${formatAmount(details.amountToRemit)}');
      
      if (!isOnline) {
         buffer.writeln('\n_(Généré hors ligne. Les créances antérieures peuvent ne pas être incluses.)_');
      }

      return buffer.toString();

    } catch (e) {
      if (kDebugMode) print("Erreur generateReportStringForCopy: $e");
      throw Exception(e.toString().replaceFirst('Exception: ', 'Erreur copie: '));
    }
  }

  /// Reconstitution du rapport pour l'offline
  Future<ReportDetailed> _generateReportDetailsFromCache(DateTime date, int shopId) async {
    // 1. Trouver le résumé (Totals) depuis le cache des rapports
    final reports = await _getReportsFromCache(date);
    final summary = reports.firstWhere(
      (r) => r.shopId == shopId,
      orElse: () => throw Exception('Résumé du rapport non trouvé en cache.'),
    );

    // 2. Trouver les commandes (Détails) depuis l'OrderRepository
    final orderDetails = await _orderRepository.getOrdersFromDbByShopAndDate(shopId, date);

    // 3. Convertir AdminOrder en ReportDetailOrder (le modèle de l'API)
    final List<ReportDetailOrder> ordersForReport = orderDetails.map((adminOrder) {
      final productsList = adminOrder.items
          .map((item) => '${item.itemName} (${item.quantity})')
          .join(', ');

      return ReportDetailOrder(
        id: adminOrder.id,
        deliveryLocation: adminOrder.deliveryLocation,
        customerPhone: adminOrder.customerPhone,
        articleAmount: adminOrder.articleAmount,
        deliveryFee: adminOrder.deliveryFee,
        status: adminOrder.status,
        amountReceived: adminOrder.amountReceived ?? 0,
        productsList: productsList,
      );
    }).toList();
    
    // 4. Construire l'objet ReportDetailed
    return ReportDetailed(
      shopName: summary.shopName,
      totalRevenueArticles: summary.totalRevenueArticles,
      totalDeliveryFees: summary.totalDeliveryFees,
      totalPackagingFees: summary.totalPackagingFees,
      totalStorageFees: summary.totalStorageFees,
      totalExpeditionFees: summary.totalExpeditionFees,
      previousDebts: 0.0, // Non disponible hors ligne
      amountToRemit: summary.amountToRemit, // Montant SANS les créances
      orders: ordersForReport,
    );
  }

  // --- Logique de Cache (BDD) ---

  Future<void> _cacheReports(List<ReportSummary> reports, DateTime date) async {
    try {
      final db = await _dbService.database;
      final dateString = DateFormat('yyyy-MM-dd').format(date);

      await db.transaction((txn) async {
        await txn.delete(
          DatabaseService.tableReportsCache,
          where: 'report_date = ?',
          whereArgs: [dateString],
        );
        
        final batch = txn.batch();
        for (final report in reports) {
          batch.insert(
            DatabaseService.tableReportsCache,
            report.toMapForDb(date),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
      if (kDebugMode) print("ReportRepository: Cache mis à jour pour $dateString (${reports.length} éléments).");
    } catch (e) {
      if (kDebugMode) print("ReportRepository: Échec de la mise en cache. $e");
    }
  }

  Future<List<ReportSummary>> _getReportsFromCache(DateTime date) async {
    final db = await _dbService.database;
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseService.tableReportsCache,
      where: 'report_date = ?',
      whereArgs: [dateString],
    );

    if (kDebugMode) print("ReportRepository: Cache lu pour $dateString (${maps.length} éléments trouvés).");
    return maps.map((map) => ReportSummary.fromMap(map)).toList();
  }
}