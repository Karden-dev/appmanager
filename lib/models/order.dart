// lib/models/order.dart

import 'package:flutter/foundation.dart'; // Pour kDebugMode

// --- Helpers privés pour le parsing robuste ---
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  if (kDebugMode) {
    print("Avertissement _parseInt (Order): Type inattendu reçu - ${value.runtimeType} / Value: $value");
  }
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  if (kDebugMode) {
    print("Avertissement _parseDouble (Order): Type inattendu reçu - ${value.runtimeType} / Value: $value");
  }
  return null;
}
// --- Fin des Helpers ---


class OrderItem {
  final String itemName;
  final int quantity;
  final double amount; // Montant unitaire

  OrderItem({
    required this.itemName,
    required this.quantity,
    required this.amount,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemName: json['item_name'] as String? ?? 'N/A',
      quantity: _parseInt(json['quantity']) ?? 0, // Utilise helper
      amount: _parseDouble(json['amount']) ?? 0.0,   // Utilise helper
    );
  }
}

class Order {
  final int id;
  final String shopName;
  final String? deliverymanName;
  final String? customerName;
  final String customerPhone;
  final String deliveryLocation;
  final double articleAmount;
  final double deliveryFee;
  final String status;
  final String paymentStatus;
  final DateTime createdAt;
  final double? amountReceived;
  final int unreadCount;
  final bool isUrgent;
  final String? itemsList;
  final bool isPickedUp;

  static const List<String> unprocessedStatuses = [
    'pending', 'in_progress', 'ready_for_pickup', 'en_route', 'reported', 'return_declared'
  ];

  Order({
    required this.id,
    required this.shopName,
    this.deliverymanName,
    this.customerName,
    required this.customerPhone,
    required this.deliveryLocation,
    required this.articleAmount,
    required this.deliveryFee,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.amountReceived,
    required this.unreadCount,
    required this.isUrgent,
    this.itemsList,
    required this.isPickedUp,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) {
        print("Erreur parsing Order date: $e, Data: ${json['created_at']}");
      }
      parsedDate = DateTime.now();
    }

    // *** UTILISATION DES HELPERS ICI ***
    return Order(
      id: _parseInt(json['id']) ?? 0, // <- Modifié
      shopName: json['shop_name'] as String? ?? 'N/A',
      deliverymanName: json['deliveryman_name'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String? ?? 'N/A',
      deliveryLocation: json['delivery_location'] as String? ?? 'N/A',
      articleAmount: _parseDouble(json['article_amount']) ?? 0.0, // <- Modifié
      deliveryFee: _parseDouble(json['delivery_fee']) ?? 0.0,     // <- Modifié
      status: json['status'] as String? ?? 'unknown',
      paymentStatus: json['payment_status'] as String? ?? 'unknown',
      createdAt: parsedDate,
      amountReceived: _parseDouble(json['amount_received']),      // <- Modifié
      unreadCount: _parseInt(json['unread_count']) ?? 0,          // <- Modifié
      isUrgent: (_parseInt(json['is_urgent']) ?? 0) == 1,         // <- Modifié
      itemsList: json['items_list'] as String?,
      isPickedUp: json['picked_up_by_rider_at'] != null,
    );
    // **********************************
  }

  double get amountToCollect => articleAmount;

  int compareToForToday(Order other) {
    final aIsUnprocessed = unprocessedStatuses.contains(status);
    final bIsUnprocessed = unprocessedStatuses.contains(other.status);

    if (aIsUnprocessed && !bIsUnprocessed) return -1;
    if (!aIsUnprocessed && bIsUnprocessed) return 1;

    if (aIsUnprocessed && bIsUnprocessed) {
      final aIsReadyNotPickedUp = status == 'ready_for_pickup' && !isPickedUp;
      final bIsReadyNotPickedUp = other.status == 'ready_for_pickup' && !other.isPickedUp;

      if (aIsReadyNotPickedUp && !bIsReadyNotPickedUp) return -1;
      if (!aIsReadyNotPickedUp && bIsReadyNotPickedUp) return 1;

      if (isUrgent != other.isUrgent) return isUrgent ? -1 : 1;
    }
    return createdAt.compareTo(other.createdAt);
  }
}