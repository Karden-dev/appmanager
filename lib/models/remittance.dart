// lib/models/remittance.dart


// --- Helpers de Parsing (simples) ---

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
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

/// Modèle pour un versement individuel
class Remittance {
  final int id;
  final int shopId;
  final String shopName;
  final String? paymentName;
  final String? phoneNumberForPayment;
  final String? paymentOperator;
  final double grossAmount;
  final double debtsConsolidated;
  final double netAmount; 
  final String status; 
  final DateTime? remittanceDate;
  final DateTime? paymentDate;

  Remittance({
    required this.id,
    required this.shopId,
    required this.shopName,
    this.paymentName,
    this.phoneNumberForPayment,
    this.paymentOperator,
    required this.grossAmount,
    required this.debtsConsolidated,
    required this.netAmount,
    required this.status,
    this.remittanceDate,
    this.paymentDate,
  });

  factory Remittance.fromJson(Map<String, dynamic> json) {
    return Remittance(
      id: _parseInt(json['id']),
      shopId: _parseInt(json['shop_id']),
      shopName: json['shop_name'] as String? ?? 'Inconnu',
      paymentName: json['payment_name'] as String?,
      phoneNumberForPayment: json['phone_number_for_payment'] as String?,
      paymentOperator: json['payment_operator'] as String?,
      grossAmount: _parseDouble(json['gross_amount']),
      debtsConsolidated: _parseDouble(json['debts_consolidated']),
      netAmount: _parseDouble(json['net_amount']),
      status: json['status'] as String? ?? 'pending',
      remittanceDate: _parseDate(json['remittance_date']),
      paymentDate: _parseDate(json['payment_date']),
    );
  }
  
  // --- Méthodes pour la base de données locale (Cache) ---
  
  factory Remittance.fromMap(Map<String, dynamic> map) {
    return Remittance(
      id: map['id'] as int,
      shopId: map['shop_id'] as int,
      shopName: map['shop_name'] as String,
      paymentName: map['payment_name'] as String?,
      phoneNumberForPayment: map['phone_number_for_payment'] as String?,
      paymentOperator: map['payment_operator'] as String?,
      grossAmount: map['gross_amount'] as double,
      debtsConsolidated: map['debts_consolidated'] as double,
      netAmount: map['net_amount'] as double,
      status: map['status'] as String,
      remittanceDate: _parseDate(map['remittance_date']),
      paymentDate: _parseDate(map['payment_date']),
    );
  }

  Map<String, dynamic> toMapForDb() {
    return {
      'id': id,
      'shop_id': shopId,
      'shop_name': shopName,
      'payment_name': paymentName,
      'phone_number_for_payment': phoneNumberForPayment,
      'payment_operator': paymentOperator,
      'gross_amount': grossAmount,
      'debts_consolidated': debtsConsolidated,
      'net_amount': netAmount,
      'status': status,
      'remittance_date': remittanceDate?.toIso8601String(),
      'payment_date': paymentDate?.toIso8601String(),
    };
  }
}

/// Modèle pour les statistiques globales des versements
class RemittanceStats {
  final double orangeMoneyTotal;
  final int orangeMoneyTransactions;
  final double mtnMoneyTotal;
  final int mtnMoneyTransactions;
  final double totalAmount;

  RemittanceStats({
    this.orangeMoneyTotal = 0,
    this.orangeMoneyTransactions = 0,
    this.mtnMoneyTotal = 0,
    this.mtnMoneyTransactions = 0,
    this.totalAmount = 0,
  });

  factory RemittanceStats.fromJson(Map<String, dynamic> json) {
    return RemittanceStats(
      orangeMoneyTotal: _parseDouble(json['orangeMoneyTotal']),
      orangeMoneyTransactions: _parseInt(json['orangeMoneyTransactions']),
      mtnMoneyTotal: _parseDouble(json['mtnMoneyTotal']),
      mtnMoneyTransactions: _parseInt(json['mtnMoneyTransactions']),
      totalAmount: _parseDouble(json['totalAmount']),
    );
  }
}