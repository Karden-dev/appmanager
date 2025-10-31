// lib/models/admin_order.dart

import 'package:flutter/foundation.dart';
import 'package:wink_manager/models/order_item.dart';
import 'package:wink_manager/models/order_history_item.dart';
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/models/user.dart';

// CORRECTION: _parseInt a été supprimé (Sévérité 4)

// Helper de parsing (utilisé)
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

// CORRECTION: _parseDate a été supprimé (Sévérité 4)
// (La logique de parsing est gérée localement dans fromJson)

class AdminOrder {
  final int id;
  final String trackingNumber;
  final String status;
  final String paymentStatus;
  final double totalAmount; // Montant des articles (articleAmount)
  final double deliveryFee;
  final double? expeditionFee; 
  
  // Noms du client et du lieu
  final String clientName;
  final String clientPhone;
  final String clientAddress;
  final String clientCity;
  final String? notes; 
  final bool isRelaunch;
  
  // Champs ajoutés pour le Hub Logistique et la lisibilité
  final String? deliverymanName; 
  final DateTime? preparedAt;     
  final String? preparedByName;   
  
  // NOUVEAU CHAMP : Heure de ramassage par le livreur
  final DateTime? pickedUpByRiderAt;
  
  // Champs pour le règlement (payoutAmount est généralement calculé)
  final double? payoutAmount; 
  
  // Objets imbriqués
  final Shop shop; 
  final User? deliveryman; 
  
  // Listes d'objets
  final List<OrderItem> items;
  final List<OrderHistoryItem> history;

  // Champs de date
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deliveryDate; 

  AdminOrder({
    required this.id,
    required this.trackingNumber,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    required this.deliveryFee,
    this.expeditionFee,
    required this.clientName,
    required this.clientPhone,
    required this.clientAddress,
    required this.clientCity,
    this.notes,
    required this.isRelaunch,
    required this.shop,
    this.deliveryman,
    required this.items,
    required this.history,
    required this.createdAt,
    required this.updatedAt,
    this.deliveryDate,
    this.preparedAt,
    this.preparedByName,
    this.deliverymanName,
    // Nouveaux champs
    this.pickedUpByRiderAt,
    this.payoutAmount,
  });

  // Getter utilitaire pour le montant à payer au marchand (payoutCalculatedAmount)
  double get payoutCalculatedAmount {
    // CORRECTION (L82): Supprime les vérifications '??' redondantes
    // totalAmount et deliveryFee sont non-nullable.
    return payoutAmount ?? (totalAmount - deliveryFee);
  }

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    // Helper de date local (remplace _parseDate)
    DateTime? parseDate(dynamic dateString) {
      if (dateString is String && dateString.isNotEmpty) {
        return DateTime.tryParse(dateString)?.toLocal();
      }
      return null;
    }

    // Extraction des montants avec vérification de type
    final double articleAmount = _parseDouble(json['totalAmount'] ?? json['article_amount']) ?? 0.0;
    final double deliveryFee = _parseDouble(json['deliveryFee'] ?? json['delivery_fee']) ?? 0.0;
    final double? expeditionFee = _parseDouble(json['expeditionFee'] ?? json['expedition_fee']);
    
    // Tentative de lecture des objets imbriqués (pour la vue détaillée)
    final Map<String, dynamic>? shopJson = json['Shop'] as Map<String, dynamic>?;
    final Map<String, dynamic>? deliverymanJson = json['Deliveryman'] as Map<String, dynamic>?;
    
    final itemsList = json['OrderItems'] as List<dynamic>? ?? [];
    final historyList = json['OrderHistories'] as List<dynamic>? ?? [];

    // Gère à la fois json['Deliveryman'] (détails) et json['deliveryman_name'] (liste)
    final String? deliverymanName = (deliverymanJson != null)
        ? (deliverymanJson['name'] as String?)
        : (json['deliveryman_name'] as String?); // Fallback pour la vue liste

    // Gère à la fois json['Shop'] (détails) et json['shop_name'] (liste)
    Shop shop;
    if (shopJson != null) {
      // Format 1: Objet imbriqué (Vue détaillée)
      shop = Shop.fromJson(shopJson);
    } else {
      // Format 2: Champs plats (Vue Liste) - Construction manuelle
      shop = Shop(
        id: (json['shop_id'] as int?) ?? 0, // shop_id est plat
        name: json['shop_name'] as String? ?? 'Marchand inconnu', // shop_name est plat
        // Fournit des valeurs par défaut pour les champs non-nul requis
        phone: json['shop_phone'] as String? ?? '', 
        address: '', 
      );
    }

    final double? apiPayoutAmount = _parseDouble(json['payout_amount']);

    return AdminOrder(
      id: json['id'] as int,
      trackingNumber: json['tracking_number'] as String? ?? json['id'].toString(),
      status: json['status'] as String? ?? 'pending',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      totalAmount: articleAmount,
      deliveryFee: deliveryFee,
      expeditionFee: expeditionFee,
      
      // Mappage des champs client (gère les deux formats)
      clientName: json['client_name'] as String? ?? json['customer_name'] as String? ?? 'N/A',
      clientPhone: json['client_phone'] as String? ?? json['customer_phone'] as String? ?? 'N/A',
      clientAddress: json['client_address'] as String? ?? json['delivery_location'] as String? ?? 'N/A',
      clientCity: json['client_city'] as String? ?? 'N/A',
      notes: json['notes'] as String?,
      
      isRelaunch: json['is_relaunch'] as bool? ?? false,
      
      shop: shop, // Utilise le 'shop' corrigé
      deliveryman: deliverymanJson != null 
          ? User.fromJson(deliverymanJson) 
          : null,
      
      items: itemsList
          .map((itemJson) => OrderItem.fromJson(itemJson as Map<String, dynamic>))
          .toList(),
      history: historyList
          .map((historyJson) => OrderHistoryItem.fromJson(historyJson as Map<String, dynamic>))
          .toList(),

      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updated_at']) ?? DateTime.now(),
      deliveryDate: parseDate(json['delivery_date']),
      
      // CHAMPS SPÉCIFIQUES
      preparedAt: parseDate(json['prepared_at']),
      preparedByName: json['prepared_by_name'] as String?,
      deliverymanName: deliverymanName, // Utilise le 'deliverymanName' corrigé
      
      pickedUpByRiderAt: parseDate(json['picked_up_by_rider_at']), 
      payoutAmount: apiPayoutAmount, 
    );
  }
}