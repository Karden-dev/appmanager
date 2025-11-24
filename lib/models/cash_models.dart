// lib/models/cash_models.dart

import 'package:intl/intl.dart';

// --- Helpers de Parsing ---
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value.replaceAll(' ', 'T'));
  }
  return null;
}
// --- Fin Helpers ---


class ExpenseCategory {
  final int id;
  final String name;

  ExpenseCategory({required this.id, required this.name});

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: _parseInt(json['id']),
      name: json['name'] as String? ?? 'N/A',
    );
  }
}

class CashTransaction {
  final int id;
  final int userId;
  final String userName; 
  final String type; 
  final int? categoryId;
  final String? categoryName; 
  final double amount; 
  final String? comment;
  final String status; 
  final DateTime createdAt;
  final int? validatedBy;
  final String? validatedByName; 
  final DateTime? validatedAt;

  CashTransaction({
    required this.id, required this.userId, required this.userName, required this.type,
    this.categoryId, this.categoryName, required this.amount, this.comment,
    required this.status, required this.createdAt, this.validatedBy,
    this.validatedByName, this.validatedAt,
  });

  factory CashTransaction.fromJson(Map<String, dynamic> json) {
    return CashTransaction(
      id: _parseInt(json['id']),
      userId: _parseInt(json['user_id']),
      userName: json['user_name'] as String? ?? 'N/A',
      type: json['type'] as String? ?? 'expense',
      categoryId: _parseInt(json['category_id']),
      categoryName: json['category_name'] as String?,
      amount: _parseDouble(json['amount']), 
      comment: json['comment'] as String?,
      status: json['status'] as String? ?? 'confirmed',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      validatedBy: _parseInt(json['validated_by']),
      validatedByName: json['validated_by_name'] as String?,
      validatedAt: _parseDate(json['validated_at']),
    );
  }
  
  Map<String, dynamic> toMapForDb() {
    return {
      'id': id, 'user_id': userId, 'user_name': userName, 'type': type,
      'category_id': categoryId, 'category_name': categoryName, 'amount': amount,
      'comment': comment, 'status': status,
      'created_at': createdAt.toIso8601String().replaceAll('T', ' '),
      'validated_by': validatedBy, 'validated_by_name': validatedByName,
      'validated_at': validatedAt?.toIso8601String().replaceAll('T', ' '),
    };
  }

  factory CashTransaction.fromMap(Map<String, dynamic> map) {
    return CashTransaction.fromJson(map);
  }
}

class Shortfall {
  final int id;
  final int deliverymanId;
  final String deliverymanName;
  final double amount;
  final String? comment;
  final String status; 
  final DateTime createdAt;
  final DateTime? settledAt;

  Shortfall({
    required this.id, required this.deliverymanId, required this.deliverymanName,
    required this.amount, this.comment, required this.status, 
    required this.createdAt, this.settledAt,
  });

  factory Shortfall.fromJson(Map<String, dynamic> json) {
    return Shortfall(
      id: _parseInt(json['id']),
      deliverymanId: _parseInt(json['deliveryman_id']),
      deliverymanName: json['deliveryman_name'] as String? ?? 'N/A',
      amount: _parseDouble(json['amount']),
      comment: json['comment'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      settledAt: _parseDate(json['settled_at']),
    );
  }
  
  Map<String, dynamic> toMapForDb() {
    return {
      'id': id, 'deliveryman_id': deliverymanId, 'deliveryman_name': deliverymanName,
      'amount': amount, 'comment': comment, 'status': status,
      'created_at': createdAt.toIso8601String().replaceAll('T', ' '),
      'settled_at': settledAt?.toIso8601String().replaceAll('T', ' '),
    };
  }

  factory Shortfall.fromMap(Map<String, dynamic> map) {
    return Shortfall.fromJson(map);
  }
}

// --- MODIFICATION : Ajout des champs manquants pour le calcul complet ---
class CashMetrics {
  final double montantEnCaisse;
  final double totalCollected;      // "encaisser"
  final double totalExpenses;       // "depenses"
  final double totalWithdrawals;    // "decaissements"
  final double creancesRemboursees; // "creances_remboursees"
  final double creancesNonRemboursees; // "creances_non_remboursees" (NOUVEAU)
  final double manquantsRembourses;    // "manquants_rembourses"
  final double manquantsNonRembourses; // "manquants_non_remboursees" (NOUVEAU)

  CashMetrics({
    this.montantEnCaisse = 0, 
    this.totalCollected = 0, 
    this.totalExpenses = 0,
    this.totalWithdrawals = 0, 
    this.creancesRemboursees = 0, 
    this.creancesNonRemboursees = 0,
    this.manquantsRembourses = 0,
    this.manquantsNonRembourses = 0,
  });

  factory CashMetrics.fromJson(Map<String, dynamic> json) {
    return CashMetrics(
      montantEnCaisse: _parseDouble(json['montant_en_caisse']),
      totalCollected: _parseDouble(json['encaisser']),
      totalExpenses: _parseDouble(json['depenses']),
      totalWithdrawals: _parseDouble(json['decaissements']),
      creancesRemboursees: _parseDouble(json['creances_remboursees']),
      creancesNonRemboursees: _parseDouble(json['creances_non_remboursees']),
      manquantsRembourses: _parseDouble(json['manquants_rembourses']),
      manquantsNonRembourses: _parseDouble(json['manquants_non_remboursees']),
    );
  }
}

class RemittanceSummaryItem {
  final int userId;
  final String userName;
  final int pendingCount;
  final double pendingAmount;
  final int confirmedCount;
  final double confirmedAmount;

  RemittanceSummaryItem({
    required this.userId, required this.userName, required this.pendingCount,
    required this.pendingAmount, required this.confirmedCount, required this.confirmedAmount,
  });

  factory RemittanceSummaryItem.fromJson(Map<String, dynamic> json) {
    return RemittanceSummaryItem(
      userId: _parseInt(json['user_id']),
      userName: json['user_name'] as String? ?? 'N/A',
      pendingCount: _parseInt(json['pending_count']),
      pendingAmount: _parseDouble(json['pending_amount']),
      confirmedCount: _parseInt(json['confirmed_count']),
      confirmedAmount: _parseDouble(json['confirmed_amount']),
    );
  }
}

class CashClosing {
  final int id;
  final DateTime closingDate;
  final double expectedCash;
  final double actualCashCounted;
  final double difference;
  final String? closedByUserName;
  final String? comment;

  CashClosing({
    required this.id, required this.closingDate, required this.expectedCash,
    required this.actualCashCounted, required this.difference,
    this.closedByUserName, this.comment,
  });

  factory CashClosing.fromJson(Map<String, dynamic> json) {
    return CashClosing(
      id: _parseInt(json['id']),
      closingDate: _parseDate(json['closing_date']) ?? DateTime.now(),
      expectedCash: _parseDouble(json['expected_cash']),
      actualCashCounted: _parseDouble(json['actual_cash_counted']),
      difference: _parseDouble(json['difference']),
      closedByUserName: json['closed_by_user_name'] as String?,
      comment: json['comment'] as String?,
    );
  }
}

class RemittanceOrder {
  final int orderId;
  final String customerPhone;
  final String deliveryLocation;
  final String itemNames;
  final double expectedAmount; 
  final String status; 
  final String? shopName; 

  RemittanceOrder({
    required this.orderId,
    required this.customerPhone,
    required this.deliveryLocation,
    required this.itemNames,
    required this.expectedAmount,
    required this.status,
    this.shopName,
  });

  factory RemittanceOrder.fromJson(Map<String, dynamic> json) {
    return RemittanceOrder(
      orderId: _parseInt(json['order_id']),
      customerPhone: json['customer_phone'] as String? ?? '',
      deliveryLocation: json['delivery_location'] as String? ?? '',
      itemNames: json['item_names'] as String? ?? 'Non spécifié',
      expectedAmount: _parseDouble(json['expected_amount']),
      status: json['remittance_status'] as String? ?? 'pending',
      shopName: json['shop_name'] as String?,
    );
  }
}