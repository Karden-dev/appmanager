import 'package:flutter/foundation.dart';

// Helpers de parsing (similaires à ceux de lib/models/order.dart)
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  if (kDebugMode) {
    print("Avertissement _parseInt (OrderItem): Type inattendu - ${value.runtimeType} / $value");
  }
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  if (kDebugMode) {
    print("Avertissement _parseDouble (OrderItem): Type inattendu - ${value.runtimeType} / $value");
  }
  return null;
}

class OrderItem {
  final int? id;
  final String itemName;
  final int quantity;
  final double amount; // C'est le montant total pour la ligne (quantité * prix unitaire)

  OrderItem({
    this.id,
    required this.itemName,
    required this.quantity,
    required this.amount,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: _parseInt(json['id']),
      itemName: json['item_name'] as String? ?? 'N/A',
      quantity: _parseInt(json['quantity']) ?? 1,
      amount: _parseDouble(json['amount']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_name': itemName,
      'quantity': quantity,
      'amount': amount,
    };
  }
}