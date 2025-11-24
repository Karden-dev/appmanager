
// --- Helpers de Parsing ---

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
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      return null;
    }
  }
  return null;
}

class Debt {
  final int id;
  final int shopId;
  final String shopName;
  final double amount;
  final String type; // 'daily_balance', 'storage_fee', 'packaging', 'expedition', 'other'
  final String status; // 'pending', 'paid'
  final String? comment;
  final DateTime createdAt;
  final DateTime? settledAt;

  Debt({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.amount,
    required this.type,
    required this.status,
    this.comment,
    required this.createdAt,
    this.settledAt,
  });

  // Factory pour créer une instance depuis le JSON de l'API
  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: _parseInt(json['id']),
      shopId: _parseInt(json['shop_id']),
      shopName: json['shop_name'] as String? ?? 'Inconnu',
      amount: _parseDouble(json['amount']),
      type: json['type'] as String? ?? 'other',
      status: json['status'] as String? ?? 'pending',
      comment: json['comment'] as String?,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      settledAt: _parseDate(json['settled_at']),
    );
  }

  // Factory pour créer une instance depuis la base de données locale (SQLite)
  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'] as int,
      shopId: map['shop_id'] as int,
      shopName: map['shop_name'] as String,
      amount: map['amount'] as double,
      type: map['type'] as String,
      status: map['status'] as String,
      comment: map['comment'] as String?,
      createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
      settledAt: _parseDate(map['settled_at']),
    );
  }

  // Convertit l'instance en Map pour la sauvegarde locale
  Map<String, dynamic> toMapForDb() {
    return {
      'id': id,
      'shop_id': shopId,
      'shop_name': shopName,
      'amount': amount,
      'type': type,
      'status': status,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'settled_at': settledAt?.toIso8601String(),
    };
  }
}