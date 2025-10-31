// lib/models/order_history_item.dart

import 'package:flutter/foundation.dart';

// Helper de parsing (similaire aux autres modèles)
DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      if (kDebugMode) {
        print("Erreur parsing OrderHistoryItem date: $e, Data: $value");
      }
      return null;
    }
  }
  return null;
}

class OrderHistoryItem {
  final int id;
  final String action;
  final String? userName;
  final DateTime? createdAt;

  OrderHistoryItem({
    required this.id,
    required this.action,
    this.userName,
    this.createdAt,
  });

  factory OrderHistoryItem.fromJson(Map<String, dynamic> json) {
    return OrderHistoryItem(
      id: json['id'] as int? ?? 0,
      action: json['action'] as String? ?? 'N/A',
      userName: json['user_name'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }
}