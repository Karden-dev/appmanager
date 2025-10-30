// lib/models/admin_order.dart

import 'package:flutter/foundation.dart';
import 'package:wink_manager/models/order_item.dart';
// AJOUT: Import du nouveau modèle d'historique
import 'package:wink_manager/models/order_history_item.dart';

// Helpers de parsing
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  if (kDebugMode) {
    print("Avertissement _parseInt (AdminOrder): Type inattendu - ${value.runtimeType} / $value");
  }
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  if (kDebugMode) {
    print("Avertissement _parseDouble (AdminOrder): Type inattendu - ${value.runtimeType} / $value");
  }
  return null;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      if (kDebugMode) {
        print("Erreur parsing AdminOrder date: $e, Data: $value");
      }
      return null;
    }
  }
  return null;
}

class AdminOrder {
  final int id;
  final String shopName;
  final String? deliverymanName;
  final String? customerName;
  final String customerPhone;
  final String deliveryLocation;
  final double articleAmount;
  final double deliveryFee;
  final double expeditionFee;
  final String status;
  final String paymentStatus;
  final DateTime createdAt;
  final DateTime? pickedUpByRiderAt;
  final List<OrderItem> items;
  // AJOUT: Liste pour l'historique
  final List<OrderHistoryItem> history;
  // AJOUT: Montant à verser (calculé dans order.model.js)
  final double payoutAmount; // Correspond à 'remittance_amount' ou un calcul similaire

  AdminOrder({
    required this.id,
    required this.shopName,
    this.deliverymanName,
    this.customerName,
    required this.customerPhone,
    required this.deliveryLocation,
    required this.articleAmount,
    required this.deliveryFee,
    required this.expeditionFee,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.pickedUpByRiderAt,
    required this.items,
    required this.history, // AJOUT
    required this.payoutAmount, // AJOUT
  });

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    var itemsList = <OrderItem>[];
    if (json['items'] != null && json['items'] is List) {
      itemsList = (json['items'] as List)
          .map((itemJson) => OrderItem.fromJson(itemJson))
          .toList();
    }
    
    // AJOUT: Parsing de l'historique
    var historyList = <OrderHistoryItem>[];
    if (json['history'] != null && json['history'] is List) {
      historyList = (json['history'] as List)
          .map((historyJson) => OrderHistoryItem.fromJson(historyJson))
          .toList();
    }
    
    // AJOUT: Calcul simple du "payoutAmount" (Montant à verser)
    // Cette logique est basée sur 'orders.html'
    double payout = 0;
    String status = json['status'] as String? ?? 'unknown';
    String paymentStatus = json['payment_status'] as String? ?? 'unknown';
    double articleAmount = _parseDouble(json['article_amount']) ?? 0.0;
    double deliveryFee = _parseDouble(json['delivery_fee']) ?? 0.0;
    double expeditionFee = _parseDouble(json['expedition_fee']) ?? 0.0;
    double amountReceived = _parseDouble(json['amount_received']) ?? 0.0;

    if (status == 'delivered') {
      if (paymentStatus == 'cash') {
        payout = articleAmount - deliveryFee - expeditionFee;
      } else if (paymentStatus == 'paid_to_supplier') {
        payout = -deliveryFee - expeditionFee;
      }
    } else if (status == 'failed_delivery') {
      payout = amountReceived - deliveryFee - expeditionFee;
    }
    // --- Fin Calcul Payout ---

    return AdminOrder(
      id: _parseInt(json['id']) ?? 0,
      shopName: json['shop_name'] as String? ?? 'N/A',
      deliverymanName: json['deliveryman_name'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String? ?? 'N/A',
      deliveryLocation: json['delivery_location'] as String? ?? 'N/A',
      articleAmount: articleAmount,
      deliveryFee: deliveryFee,
      expeditionFee: expeditionFee,
      status: status,
      paymentStatus: paymentStatus,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      pickedUpByRiderAt: _parseDate(json['picked_up_by_rider_at']),
      items: itemsList,
      history: historyList, // AJOUT
      payoutAmount: payout, // AJOUT
    );
  }
}