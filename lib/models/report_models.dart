// lib/models/report_models.dart
import 'package:intl/intl.dart';

// --- Helpers de Parsing (similaires à AdminOrder) ---

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
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Modèle pour les 4 cartes de statistiques en haut de l'écran.
class ReportStatCards {
  final int activeMerchants;
  final double totalPackaging;
  final double totalStorage;
  final double totalDebt;
  final double totalAmountToRemit;

  ReportStatCards({
    this.activeMerchants = 0,
    this.totalPackaging = 0,
    this.totalStorage = 0,
    this.totalDebt = 0,
    this.totalAmountToRemit = 0,
  });
}

/// Modèle pour une ligne de rapport (utilisé par chaque carte de la liste).
/// Basé sur `findReportsByDate` dans `report.model.js`.
class ReportSummary {
  final int shopId;
  final String shopName;
  final int totalOrdersSent;
  final int totalOrdersDelivered;
  final double totalRevenueArticles;
  final double totalDeliveryFees;
  final double totalExpeditionFees;
  final double totalPackagingFees;
  final double totalStorageFees;
  final double amountToRemit;

  ReportSummary({
    required this.shopId,
    required this.shopName,
    required this.totalOrdersSent,
    required this.totalOrdersDelivered,
    required this.totalRevenueArticles,
    required this.totalDeliveryFees,
    required this.totalExpeditionFees,
    required this.totalPackagingFees,
    required this.totalStorageFees,
    required this.amountToRemit,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      shopId: _parseInt(json['shop_id']),
      shopName: json['shop_name'] as String? ?? 'N/A',
      totalOrdersSent: _parseInt(json['total_orders_sent']),
      totalOrdersDelivered: _parseInt(json['total_orders_delivered']),
      totalRevenueArticles: _parseDouble(json['total_revenue_articles']),
      totalDeliveryFees: _parseDouble(json['total_delivery_fees']),
      totalExpeditionFees: _parseDouble(json['total_expedition_fees']),
      totalPackagingFees: _parseDouble(json['total_packaging_fees']),
      totalStorageFees: _parseDouble(json['total_storage_fees']),
      amountToRemit: _parseDouble(json['amount_to_remit']),
    );
  }

  // *** MÉTHODES POUR LE CACHE BDD ***
  factory ReportSummary.fromMap(Map<String, dynamic> map) {
    return ReportSummary(
      shopId: _parseInt(map['shop_id']),
      shopName: map['shop_name'] as String? ?? 'N/A',
      totalOrdersSent: _parseInt(map['total_orders_sent']),
      totalOrdersDelivered: _parseInt(map['total_orders_delivered']),
      totalRevenueArticles: _parseDouble(map['total_revenue_articles']),
      totalDeliveryFees: _parseDouble(map['total_delivery_fees']),
      totalExpeditionFees: _parseDouble(map['total_expedition_fees']),
      totalPackagingFees: _parseDouble(map['total_packaging_fees']),
      totalStorageFees: _parseDouble(map['total_storage_fees']),
      amountToRemit: _parseDouble(map['amount_to_remit']),
    );
  }

  Map<String, dynamic> toMapForDb(DateTime reportDate) {
    return {
      'report_date': DateFormat('yyyy-MM-dd').format(reportDate),
      'shop_id': shopId,
      'shop_name': shopName,
      'total_orders_sent': totalOrdersSent,
      'total_orders_delivered': totalOrdersDelivered,
      'total_revenue_articles': totalRevenueArticles,
      'total_delivery_fees': totalDeliveryFees,
      'total_expedition_fees': totalExpeditionFees,
      'total_packaging_fees': totalPackagingFees,
      'total_storage_fees': totalStorageFees,
      'amount_to_remit': amountToRemit,
    };
  }
  // *** FIN MÉTHODES CACHE ***

  // Helper de formatage
  static String formatAmount(double amount) {
    return NumberFormat.currency(
            locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0)
        .format(amount);
  }
}

/// Modèle pour les détails d'une commande (pour l'action "Copier").
/// Basé sur `findDetailedReport` (sous-objet 'orders').
class ReportDetailOrder {
  final int id;
  final String deliveryLocation;
  final String customerPhone;
  final double articleAmount;
  final double deliveryFee;
  final String status;
  final double amountReceived;
  final String productsList; // C'est une chaîne concaténée par le backend

  ReportDetailOrder({
    required this.id,
    required this.deliveryLocation,
    required this.customerPhone,
    required this.articleAmount,
    required this.deliveryFee,
    required this.status,
    required this.amountReceived,
    required this.productsList,
  });

  factory ReportDetailOrder.fromJson(Map<String, dynamic> json) {
    return ReportDetailOrder(
      id: _parseInt(json['id']),
      deliveryLocation: json['delivery_location'] as String? ?? 'N/A',
      customerPhone: json['customer_phone'] as String? ?? 'N/A',
      articleAmount: _parseDouble(json['article_amount']),
      deliveryFee: _parseDouble(json['delivery_fee']),
      status: json['status'] as String? ?? 'unknown',
      amountReceived: _parseDouble(json['amount_received']),
      productsList: json['products_list'] as String? ?? 'Produit non spécifié',
    );
  }
}

/// Modèle pour la réponse complète de l'API de détail (pour l'action "Copier").
/// Basé sur `findDetailedReport` (objet racine).
class ReportDetailed {
  final String shopName;
  final double totalRevenueArticles;
  final double totalDeliveryFees;
  final double totalPackagingFees;
  final double totalStorageFees;
  final double totalExpeditionFees;
  final double previousDebts;
  final double amountToRemit;
  final List<ReportDetailOrder> orders;

  ReportDetailed({
    required this.shopName,
    required this.totalRevenueArticles,
    required this.totalDeliveryFees,
    required this.totalPackagingFees,
    required this.totalStorageFees,
    required this.totalExpeditionFees,
    required this.previousDebts,
    required this.amountToRemit,
    required this.orders,
  });

  factory ReportDetailed.fromJson(Map<String, dynamic> json) {
    var ordersList = <ReportDetailOrder>[];
    if (json['orders'] != null && json['orders'] is List) {
      ordersList = (json['orders'] as List)
          .map((itemJson) => ReportDetailOrder.fromJson(itemJson))
          .toList();
    }
    
    return ReportDetailed(
      shopName: json['shop_name'] as String? ?? 'N/A',
      totalRevenueArticles: _parseDouble(json['total_revenue_articles']),
      totalDeliveryFees: _parseDouble(json['total_delivery_fees']),
      totalPackagingFees: _parseDouble(json['total_packaging_fees']),
      totalStorageFees: _parseDouble(json['total_storage_fees']),
      totalExpeditionFees: _parseDouble(json['total_expedition_fees']),
      previousDebts: _parseDouble(json['previous_debts']),
      amountToRemit: _parseDouble(json['amount_to_remit']),
      orders: ordersList,
    );
  }
}