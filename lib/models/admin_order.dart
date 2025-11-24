// lib/models/admin_order.dart
import 'package:wink_manager/models/order_history_item.dart';
import 'package:wink_manager/models/order_item.dart';


// --- Helpers de Parsing ---
// (Ces helpers doivent être présents dans ce fichier ou importés)

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
  // Gestion spécifique si le backend envoie un objet Date
  if (value is Map && value.containsKey('_seconds')) {
    return DateTime.fromMillisecondsSinceEpoch(value['_seconds'] * 1000);
  }
  return null;
}
// --- Fin Helpers ---


class AdminOrder {
  final int id;
  // *** CORRECTION : Ajout de shopId ***
  final int shopId;
  final String shopName;
  final int? deliverymanId;
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
  final double? amountReceived;
  final List<OrderItem> items;
  final List<OrderHistoryItem> history;
  final bool isSynced;
  // *** NOUVEAU : Ajout du champ de suivi ***
  final DateTime? followUpAt; 

  AdminOrder({
    required this.id,
    // *** CORRECTION : Ajout de shopId ***
    required this.shopId,
    required this.shopName,
    this.deliverymanId,
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
    this.amountReceived,
    required this.items,
    required this.history,
    this.isSynced = true,
    // *** NOUVEAU : Ajout de followUpAt au constructeur ***
    this.followUpAt,
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
      id: _parseInt(json['id']),
      // *** CORRECTION : Ajout de shopId depuis l'API ***
      // Assurez-vous que l'API renvoie bien 'shop_id'
      shopId: _parseInt(json['shop_id']), 
      shopName: json['shop_name'] as String? ?? 'N/A',
      deliverymanId: _parseInt(json['deliveryman_id']),
      deliverymanName: json['deliveryman_name'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String? ?? 'N/A',
      deliveryLocation: json['delivery_location'] as String? ?? 'N/A',
      articleAmount: _parseDouble(json['article_amount']),
      deliveryFee: _parseDouble(json['delivery_fee']),
      expeditionFee: _parseDouble(json['expedition_fee']),
      status: json['status'] as String? ?? 'unknown',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      pickedUpByRiderAt: _parseDate(json['picked_up_by_rider_at']),
      amountReceived: _parseDouble(json['amount_received']),
      items: itemsList,
      history: historyList,
      isSynced: true, // Si ça vient de l'API, c'est synchronisé
      // *** NOUVEAU : Parsing de followUpAt ***
      followUpAt: _parseDate(json['follow_up_at']),
    );
  }
}