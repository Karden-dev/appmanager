// lib/models/return_tracking.dart
class ReturnTracking {
  final int trackingId; // ID de la ligne dans la table de suivi des retours
  final int orderId;
  final String deliverymanName;
  final String shopName;
  final String returnStatus; // Ex: 'return_declared', 'pending_return_to_hub', 'received_at_hub', 'returned_to_shop'
  final DateTime declarationDate;
  final String? comment; // Commentaire du livreur (peut être null)

  ReturnTracking({
    required this.trackingId,
    required this.orderId,
    required this.deliverymanName,
    required this.shopName,
    required this.returnStatus,
    required this.declarationDate,
    this.comment,
  });

  factory ReturnTracking.fromJson(Map<String, dynamic> json) {
    // Fonction utilitaire pour le parsing des dates de l'API
    DateTime? parseDate(dynamic dateString) {
      if (dateString is String && dateString.isNotEmpty) {
        // Convertit en DateTime et force la conversion en heure locale (toLocal)
        return DateTime.tryParse(dateString)?.toLocal();
      }
      return null;
    }

    // Le JSON des retours du backend utilise généralement des noms de colonnes SQL
    return ReturnTracking(
      trackingId: json['id'] as int,
      orderId: json['order_id'] as int,
      // Ces champs sont généralement des jointures (inclus dans la requête du modèle backend)
      deliverymanName: json['deliveryman_name'] as String? ?? 'N/A', 
      shopName: json['shop_name'] as String? ?? 'N/A',
      returnStatus: json['return_status'] as String,
      declarationDate: parseDate(json['declaration_date']) ?? DateTime.now(),
      comment: json['comment'] as String?,
    );
  }
  
  // Utile pour la reconstruction des objets lors de la mise à jour (ex: dans OrderProvider)
  ReturnTracking copyWith({
    int? trackingId,
    int? orderId,
    String? deliverymanName,
    String? shopName,
    String? returnStatus,
    DateTime? declarationDate,
    String? comment,
  }) {
    return ReturnTracking(
      trackingId: trackingId ?? this.trackingId,
      orderId: orderId ?? this.orderId,
      deliverymanName: deliverymanName ?? this.deliverymanName,
      shopName: shopName ?? this.shopName,
      returnStatus: returnStatus ?? this.returnStatus,
      declarationDate: declarationDate ?? this.declarationDate,
      comment: comment ?? this.comment,
    );
  }
}