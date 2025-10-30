// lib/models/rider_cash_details.dart

import 'package:flutter/foundation.dart'; // Pour kDebugMode
import 'package:intl/intl.dart';
import 'package:flutter/material.dart'; // Import pour Color
import '../utils/app_theme.dart';     // Import pour AppTheme

// --- Helpers privés pour le parsing robuste (au niveau du fichier) ---
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  if (kDebugMode) {
    print("Avertissement _parseInt (cash_details): Type inattendu reçu - ${value.runtimeType} / Value: $value");
  }
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  if (kDebugMode) {
    print("Avertissement _parseDouble (cash_details): Type inattendu reçu - ${value.runtimeType} / Value: $value");
  }
  return null;
}

DateTime _parseDateTime(dynamic value) {
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      if (kDebugMode) {
        print("Erreur parsing DateTime (cash_details): $e, Data: $value");
      }
    }
  }
  if (kDebugMode) {
     print("Avertissement _parseDateTime (cash_details): Type inattendu reçu - ${value?.runtimeType} / Value: $value");
  }
  // Retourne une date par défaut en cas d'échec ou de type invalide
  return DateTime.now();
}
// --- Fin des Helpers ---


// Modèle pour le résumé
class CashSummary {
  final double amountExpected;
  final double amountConfirmed;
  final double totalExpenses;

  CashSummary({
    required this.amountExpected,
    required this.amountConfirmed,
    required this.totalExpenses,
  });

  factory CashSummary.fromJson(Map<String, dynamic> json) {
    return CashSummary(
      // Utilisation des helpers robustes
      amountExpected: _parseDouble(json['amountExpected']) ?? 0.0,
      amountConfirmed: _parseDouble(json['amountConfirmed']) ?? 0.0,
      totalExpenses: _parseDouble(json['totalExpenses']) ?? 0.0,
    );
  }
}

// Modèle de base pour une transaction
abstract class CashTransaction {
  final String type;
  final DateTime eventDate;
  final double amount;
  final String status;
  final int id;

  CashTransaction({
    required this.id,
    required this.type,
    required this.eventDate,
    required this.amount,
    required this.status,
  });

  static CashTransaction fromJson(Map<String, dynamic> json) {
    String type = json['type'] as String? ?? 'unknown'; // Assurer que type est une String
    switch (type) {
      case 'order':
        return OrderTransaction.fromJson(json);
      case 'expense':
        return ExpenseTransaction.fromJson(json);
      case 'shortfall':
        return ShortfallTransaction.fromJson(json);
      default:
         debugPrint('Unknown transaction type encountered: $type');
         return UnknownTransaction.fromJson(json);
    }
  }
}

// Modèle pour une transaction de type Commande
class OrderTransaction extends CashTransaction {
  final int orderId;
  final String? shopName;
  final String? itemsList;
  final String? deliveryLocation;
  final String? customerName;
  final String? customerPhone;
  final String remittanceStatus;
  final double confirmedAmount;

  OrderTransaction({
    required super.id,
    required super.eventDate,
    required super.amount,
    required super.status,
    required this.orderId,
    this.shopName,
    this.itemsList,
    this.deliveryLocation,
    this.customerName,
    this.customerPhone,
    required this.remittanceStatus,
    required this.confirmedAmount,
  }) : super(type: 'order');

  factory OrderTransaction.fromJson(Map<String, dynamic> json) {
    // Utilisation des helpers robustes
    int orderIdentifier = _parseInt(json['id']) ?? _parseInt(json['tracking_number']) ?? 0;
    return OrderTransaction(
      id: orderIdentifier,
      eventDate: _parseDateTime(json['event_date']),
      amount: _parseDouble(json['article_amount']) ?? 0.0, // article_amount ajusté
      status: json['status'] as String? ?? 'unknown', // Statut global de la commande
      orderId: orderIdentifier,
      shopName: json['shop_name'] as String?,
      itemsList: json['items_list'] as String?,
      deliveryLocation: json['delivery_location'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      remittanceStatus: json['remittance_status'] as String? ?? 'pending',
      confirmedAmount: _parseDouble(json['confirmedAmount']) ?? 0.0,
    );
  }
}

// Modèle pour une transaction de type Dépense
class ExpenseTransaction extends CashTransaction {
  final String? comment;

  ExpenseTransaction({
    required super.id,
    required super.eventDate,
    required super.amount,
    required super.status,
    this.comment,
  }) : super(type: 'expense');

  factory ExpenseTransaction.fromJson(Map<String, dynamic> json) {
    // Utilisation des helpers robustes
    return ExpenseTransaction(
      id: _parseInt(json['id']) ?? 0,
      eventDate: _parseDateTime(json['event_date']),
      amount: _parseDouble(json['amount']) ?? 0.0,
      status: json['status'] as String? ?? 'unknown',
      comment: json['comment'] as String?,
    );
  }
}

// Modèle pour une transaction de type Manquant
class ShortfallTransaction extends CashTransaction {
  final String? comment;

  ShortfallTransaction({
    required super.id,
    required super.eventDate,
    required super.amount,
    required super.status,
    this.comment,
  }) : super(type: 'shortfall');

  factory ShortfallTransaction.fromJson(Map<String, dynamic> json) {
    // Utilisation des helpers robustes
    return ShortfallTransaction(
      id: _parseInt(json['id']) ?? 0,
      eventDate: _parseDateTime(json['event_date']),
      amount: _parseDouble(json['amount']) ?? 0.0,
      status: json['status'] as String? ?? 'unknown',
      comment: json['comment'] as String?,
    );
  }
}

// Classe pour gérer les types de transactions inconnus
class UnknownTransaction extends CashTransaction {
   final Map<String, dynamic> originalData;

   UnknownTransaction({
    required super.id,
    required super.eventDate,
    required super.amount,
    required super.status,
    required this.originalData,
  }) : super(type: 'unknown');

   factory UnknownTransaction.fromJson(Map<String, dynamic> json) {
     // Utilisation des helpers robustes
     return UnknownTransaction(
       id: _parseInt(json['id']) ?? 0,
       eventDate: _parseDateTime(json['event_date']),
       amount: _parseDouble(json['amount']) ?? 0.0,
       status: json['status'] as String? ?? 'unknown',
       originalData: json,
     );
   }
}

// Modèle global pour la réponse de l'API
class RiderCashDetails {
  final CashSummary summary;
  final List<CashTransaction> transactions;

  RiderCashDetails({required this.summary, required this.transactions});

  factory RiderCashDetails.fromJson(Map<String, dynamic> json) {
    final summaryData = json['summary'] as Map<String, dynamic>? ?? {};
    final transactionsData = json['transactions'] as List<dynamic>? ?? [];

    return RiderCashDetails(
      summary: CashSummary.fromJson(summaryData),
      transactions: transactionsData
          .map((item) {
              // Vérifie que item est bien un Map avant de parser
              if (item is Map<String, dynamic>) {
                 try {
                   return CashTransaction.fromJson(item);
                 } catch (e) {
                    debugPrint("Erreur parsing transaction item: $e, Data: $item");
                    return UnknownTransaction.fromJson(item);
                 }
              } else {
                 debugPrint("Item de transaction inattendu (pas un Map): $item");
                 // Crée un UnknownTransaction avec des données vides pour éviter un crash
                 return UnknownTransaction.fromJson({});
              }
          })
          .toList(),
    );
  }
}

// --- Fonctions utilitaires de formatage (restent inchangées) ---
final currencyFormatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
final dateFormatter = DateFormat('dd/MM/yyyy', 'fr_FR');
final dateTimeFormatter = DateFormat('dd/MM HH:mm', 'fr_FR');

String formatTransactionAmount(double amount, String type) {
  bool isNegative = type == 'expense' || type == 'shortfall' || (type == 'order' && amount < 0);
  String formatted = currencyFormatter.format(amount.abs());
  return isNegative ? '- $formatted' : formatted;
}

Color getTransactionAmountColor(double amount, String type) {
   bool isNegative = type == 'expense' || type == 'shortfall' || (type == 'order' && amount < 0);
   if (type == 'order' && !isNegative) return AppTheme.primaryColor;
   if (type == 'expense' || (type == 'order' && isNegative)) return Colors.orange.shade800;
   if (type == 'shortfall') return AppTheme.danger;
   return Colors.grey.shade700;
}