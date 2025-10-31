// lib/models/return_tracking.dart
import 'package:flutter/foundation.dart'; // Pour kDebugMode
import 'package:intl/intl.dart';

// Helper de parsing (inchangé)
DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      if (kDebugMode) {
        print("Erreur parsing ReturnTracking date: $e, Data: $value");
      }
      return null;
    }
  }
  return null;
}

class ReturnTracking {
  final int trackingId;
  final int orderId;
  final String shopName;
  final String deliverymanName;
  final String returnStatus; // pending_return_to_hub, received_at_hub, returned_to_shop
  final DateTime declarationDate;
  final DateTime? hubReceptionDate;
  final String? comment;

  ReturnTracking({
    required this.trackingId,
    required this.orderId,
    required this.shopName,
    required this.deliverymanName,
    required this.returnStatus,
    required this.declarationDate,
    this.hubReceptionDate,
    this.comment,
  });

  factory ReturnTracking.fromJson(Map<String, dynamic> json) {
    return ReturnTracking(
      trackingId: json['tracking_id'] as int? ?? 0,
      orderId: json['order_id'] as int? ?? 0,
      shopName: json['shop_name'] as String? ?? 'N/A',
      deliverymanName: json['deliveryman_name'] as String? ?? 'N/A',
      returnStatus: json['return_status'] as String? ?? 'unknown',
      declarationDate: _parseDate(json['declaration_date']) ?? DateTime.now(),
      hubReceptionDate: _parseDate(json['hub_reception_date']),
      comment: json['comment'] as String?,
    );
  }
}

// Map de traduction locale pour l'UI
const Map<String, String> returnStatusTranslations = {
  'pending_return_to_hub': 'En attente Hub',
  'received_at_hub': 'Confirmé Hub',
  'returned_to_shop': 'Retourné Marchand',
};