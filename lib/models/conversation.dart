// lib/models/conversation.dart

import 'package:flutter/foundation.dart';

// --- Helpers de parsing (similaires aux autres modèles) ---
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      if (kDebugMode) {
        print("Erreur parsing Conversation date: $e, Data: $value");
      }
      return null;
    }
  }
  return null;
}

/// Modèle représentant un item dans la liste des conversations (écran Suivis Admin).
class Conversation {
  final int orderId;
  final String? customerPhone;
  final String? shopName;
  final String? deliverymanName;
  final String? deliverymanPhone; // <-- AJOUTÉ
  final bool isUrgent;
  final bool isArchived;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  Conversation({
    required this.orderId,
    this.customerPhone,
    this.shopName,
    this.deliverymanName,
    this.deliverymanPhone, // <-- AJOUTÉ
    required this.isUrgent,
    required this.isArchived,
    this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
  });

  /// Crée une instance depuis un JSON (API)
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      orderId: _parseInt(json['order_id']) ?? 0,
      customerPhone: json['customer_phone'] as String?,
      shopName: json['shop_name'] as String?,
      deliverymanName: json['deliveryman_name'] as String?,
      deliverymanPhone: json['deliveryman_phone'] as String?, // <-- AJOUTÉ
      isUrgent: (_parseInt(json['is_urgent']) ?? 0) == 1,
      isArchived: (_parseInt(json['is_archived']) ?? 0) == 1,
      lastMessage: json['last_message'] as String?,
      lastMessageTime: _parseDate(json['last_message_time']),
      unreadCount: _parseInt(json['unread_count']) ?? 0,
    );
  }

  /// Crée une instance depuis un Map (Base de données locale)
  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      orderId: map['order_id'] as int,
      customerPhone: map['customer_phone'] as String?,
      shopName: map['shop_name'] as String?,
      deliverymanName: map['deliveryman_name'] as String?,
      deliverymanPhone: map['deliveryman_phone'] as String?, // <-- AJOUTÉ
      isUrgent: (map['is_urgent'] as int? ?? 0) == 1,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      lastMessage: map['last_message'] as String?,
      lastMessageTime: _parseDate(map['last_message_time']),
      unreadCount: (map['unread_count'] as int? ?? 0),
    );
  }

  /// Convertit l'instance en Map pour la base de données locale
  Map<String, dynamic> toMapForDb() {
    return {
      'order_id': orderId,
      'customer_phone': customerPhone,
      'shop_name': shopName,
      'deliveryman_name': deliverymanName,
      'deliveryman_phone': deliverymanPhone, // <-- AJOUTÉ
      'is_urgent': isUrgent ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'unread_count': unreadCount,
    };
  }
  
  // --- AJOUT : Opérateurs d'égalité pour l'optimisation ---
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Conversation &&
      other.orderId == orderId &&
      other.customerPhone == customerPhone &&
      other.shopName == shopName &&
      other.deliverymanName == deliverymanName &&
      other.deliverymanPhone == deliverymanPhone && // <-- AJOUTÉ
      other.isUrgent == isUrgent &&
      other.isArchived == isArchived &&
      other.lastMessage == lastMessage &&
      other.lastMessageTime == lastMessageTime &&
      other.unreadCount == unreadCount;
  }

  @override
  int get hashCode {
    return orderId.hashCode ^
      customerPhone.hashCode ^
      shopName.hashCode ^
      deliverymanName.hashCode ^
      deliverymanPhone.hashCode ^ // <-- AJOUTÉ
      isUrgent.hashCode ^
      isArchived.hashCode ^
      lastMessage.hashCode ^
      lastMessageTime.hashCode ^
      unreadCount.hashCode;
  }

  String? get deliveryMangerPhone => null;
  // --- FIN AJOUT ---
}