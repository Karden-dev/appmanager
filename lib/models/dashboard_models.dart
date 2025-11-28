// lib/models/dashboard_models.dart

class DashboardMetrics {
  final double caNet;
  final double totalExpenses;
  final double soldeNet;
  final double totalDeliveryFees;
  
  // Variations
  final double? caVariation;
  final double? expensesVariation;
  final double? soldeVariation;
  final double? deliveryFeesVariation;
  
  final double? ordersSentVariation;
  final double? deliveredVariation;
  final double? inProgressVariation; // (Sera ignoré par l'UI si besoin)
  final double? failedVariation;
  final double? qualityRateVariation; // NOUVEAU

  // Métriques opérationnelles
  final int totalSent;
  final int totalDelivered;
  final int totalInProgress;
  final int totalFailedCancelled;

  DashboardMetrics({
    required this.caNet,
    required this.totalExpenses,
    required this.soldeNet,
    required this.totalDeliveryFees,
    this.caVariation,
    this.expensesVariation,
    this.soldeVariation,
    this.deliveryFeesVariation,
    this.ordersSentVariation,
    this.deliveredVariation,
    this.inProgressVariation,
    this.failedVariation,
    this.qualityRateVariation,
    required this.totalSent,
    required this.totalDelivered,
    required this.totalInProgress,
    required this.totalFailedCancelled,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is int) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }
    
    double? toDoubleNullable(dynamic val) {
      if (val == null) return null;
      if (val is int) return val.toDouble();
      return double.tryParse(val.toString());
    }

    int toInt(dynamic val) {
      if (val == null) return 0;
      return int.tryParse(val.toString()) ?? 0;
    }

    return DashboardMetrics(
      caNet: toDouble(json['ca_net']),
      totalExpenses: toDouble(json['total_expenses']),
      soldeNet: toDouble(json['solde_net']),
      totalDeliveryFees: toDouble(json['total_delivery_fees']),
      
      caVariation: toDoubleNullable(json['ca_variation']),
      expensesVariation: toDoubleNullable(json['expenses_variation']),
      soldeVariation: toDoubleNullable(json['solde_variation']),
      deliveryFeesVariation: toDoubleNullable(json['delivery_fees_variation']),
      
      ordersSentVariation: toDoubleNullable(json['orders_sent_variation']),
      deliveredVariation: toDoubleNullable(json['delivered_variation']),
      // in_progress_variation peut être envoyé par le backend même si on ne l'affiche pas
      inProgressVariation: toDoubleNullable(json['in_progress_variation']),
      failedVariation: toDoubleNullable(json['failed_variation']),
      qualityRateVariation: toDoubleNullable(json['quality_rate_variation']),

      totalSent: toInt(json['total_sent']),
      totalDelivered: toInt(json['total_delivered']),
      totalInProgress: toInt(json['total_in_progress']),
      totalFailedCancelled: toInt(json['total_failed_cancelled']),
    );
  }

  factory DashboardMetrics.empty() {
    return DashboardMetrics(
      caNet: 0, totalExpenses: 0, soldeNet: 0, totalDeliveryFees: 0,
      totalSent: 0, totalDelivered: 0, totalInProgress: 0, totalFailedCancelled: 0,
    );
  }
}

class ShopRankingItem {
  final String shopName;
  final int ordersSentCount;
  final int ordersProcessedCount;
  final double totalDeliveryFeesGenerated;
  final double? feesVariation;

  ShopRankingItem({
    required this.shopName,
    required this.ordersSentCount,
    required this.ordersProcessedCount,
    required this.totalDeliveryFeesGenerated,
    this.feesVariation,
  });

  double get reliabilityRate {
    if (ordersSentCount == 0) return 0.0;
    return (ordersProcessedCount / ordersSentCount);
  }

  factory ShopRankingItem.fromJson(Map<String, dynamic> json) {
    return ShopRankingItem(
      shopName: json['shop_name'] ?? 'Inconnu',
      ordersSentCount: int.tryParse(json['orders_sent_count'].toString()) ?? 0,
      ordersProcessedCount: int.tryParse(json['orders_processed_count'].toString()) ?? 0,
      totalDeliveryFeesGenerated: double.tryParse(json['total_delivery_fees_generated'].toString()) ?? 0.0,
      feesVariation: json['fees_variation'] != null ? double.tryParse(json['fees_variation'].toString()) : null,
    );
  }
}

class DeliverymanRankingItem {
  final String name;
  final int deliveredCount;
  final int failedCount;
  final double? rankVariation;

  DeliverymanRankingItem({
    required this.name,
    required this.deliveredCount,
    required this.failedCount,
    this.rankVariation,
  });

  factory DeliverymanRankingItem.fromJson(Map<String, dynamic> json) {
    return DeliverymanRankingItem(
      name: json['deliveryman_name'] ?? 'Livreur',
      deliveredCount: int.tryParse(json['delivered_count'].toString()) ?? 0,
      failedCount: int.tryParse(json['failed_count'].toString()) ?? 0,
      rankVariation: json['rank_variation'] != null ? double.tryParse(json['rank_variation'].toString()) : null,
    );
  }
}

class DashboardData {
  final DashboardMetrics metrics;
  final List<ShopRankingItem> ranking;
  final List<DeliverymanRankingItem> deliverymanRanking;

  DashboardData({
    required this.metrics, 
    required this.ranking,
    required this.deliverymanRanking,
  });
  
  factory DashboardData.fromJson(Map<String, dynamic> json) {
    var shopList = json['ranking'] as List? ?? [];
    var riderList = json['deliverymanRanking'] as List? ?? [];

    return DashboardData(
      metrics: DashboardMetrics.fromJson(json['metrics'] ?? {}),
      ranking: shopList.map((i) => ShopRankingItem.fromJson(i)).toList(),
      deliverymanRanking: riderList.map((i) => DeliverymanRankingItem.fromJson(i)).toList(),
    );
  }
}