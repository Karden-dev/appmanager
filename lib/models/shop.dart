import 'package:flutter/foundation.dart';

// --- Helpers de Parsing ---
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      if (kDebugMode) print("Erreur parsing date Shop: $e");
      return null;
    }
  }
  return null;
}

class Shop {
  final int id;
  final String name;
  final String phoneNumber;
  final String status; // 'actif' ou 'inactif'
  
  // Options de facturation
  final bool billPackaging;
  final bool billStorage;
  final double packagingPrice;
  final double storagePrice;
  
  final DateTime? createdAt;

  Shop({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.status = 'actif',
    this.billPackaging = false,
    this.billStorage = false,
    this.packagingPrice = 0.0,
    this.storagePrice = 0.0,
    this.createdAt,
  });

  // Factory pour créer depuis le JSON de l'API
  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: _parseInt(json['id']) ?? 0,
      name: json['name'] as String? ?? 'N/A',
      phoneNumber: json['phone_number'] as String? ?? 'N/A',
      status: json['status'] as String? ?? 'actif',
      // Conversion int (0/1) vers bool
      billPackaging: (json['bill_packaging'] == 1 || json['bill_packaging'] == true),
      billStorage: (json['bill_storage'] == 1 || json['bill_storage'] == true),
      packagingPrice: _parseDouble(json['packaging_price']),
      storagePrice: _parseDouble(json['storage_price']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  // Factory pour créer depuis la DB locale (SQLite)
  factory Shop.fromMap(Map<String, dynamic> map) {
    return Shop(
      id: map['id'] as int,
      name: map['name'] as String,
      phoneNumber: map['phone_number'] as String,
      status: map['status'] as String,
      billPackaging: (map['bill_packaging'] as int) == 1,
      billStorage: (map['bill_storage'] as int) == 1,
      packagingPrice: map['packaging_price'] as double,
      storagePrice: map['storage_price'] as double,
      createdAt: _parseDate(map['created_at']),
    );
  }

  // Conversion vers Map pour sauvegarde SQLite
  Map<String, dynamic> toMapForDb() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'status': status,
      'bill_packaging': billPackaging ? 1 : 0,
      'bill_storage': billStorage ? 1 : 0,
      'packaging_price': packagingPrice,
      'storage_price': storagePrice,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}