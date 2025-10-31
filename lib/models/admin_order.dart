// lib/models/admin_order.dart

import 'package:flutter/foundation.dart';
import 'package:wink_manager/models/order_item.dart';
import 'package:wink_manager/models/order_history_item.dart';

// Helpers de parsing (inchangés)
int? _parseInt(dynamic value) {
// ... (Implémentation inchangée)
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
// ... (Implémentation inchangée)
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
// ... (Implémentation inchangée)
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
  final int? deliverymanId; // <-- AJOUTÉ: ID du livreur
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
  final List<OrderHistoryItem> history;
  final double? amountReceived; 

  AdminOrder({
    required this.id,
    required this.shopName,
    this.deliverymanId, // <-- AJOUTÉ
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
    required this.history,
    this.amountReceived, 
  });

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    var itemsList = <OrderItem>[];
    if (json['items'] != null && json['items'] is List) {
      itemsList = (json['items'] as List)
          .map((itemJson) => OrderItem.fromJson(itemJson))
          .toList();
    }

    var historyList = <OrderHistoryItem>[];
    if (json['history'] != null && json['history'] is List) {
      historyList = (json['history'] as List)
          .map((historyJson) => OrderHistoryItem.fromJson(historyJson))
          .toList();
    }

    return AdminOrder(
      id: _parseInt(json['id']) ?? 0,
      shopName: json['shop_name'] as String? ?? 'N/A',
      deliverymanId: _parseInt(json['deliveryman_id']), // <-- AJOUTÉ: Récupère l'ID
      deliverymanName: json['deliveryman_name'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String? ?? 'N/A',
      deliveryLocation: json['delivery_location'] as String? ?? 'N/A',
      articleAmount: _parseDouble(json['article_amount']) ?? 0.0,
      deliveryFee: _parseDouble(json['delivery_fee']) ?? 0.0,
      expeditionFee: _parseDouble(json['expedition_fee']) ?? 0.0,
      status: json['status'] as String? ?? 'unknown',
      paymentStatus: json['payment_status'] as String? ?? 'unknown',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      pickedUpByRiderAt: _parseDate(json['picked_up_by_rider_at']),
      items: itemsList,
      history: historyList,
      amountReceived: _parseDouble(json['amount_received']),
    );
  }
}