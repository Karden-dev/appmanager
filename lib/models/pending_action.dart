// lib/models/pending_action.dart

import 'dart:convert';

/// Types d'actions possibles à synchroniser.
enum SyncActionType {
  createOrder,
  updateOrder,
  assignOrder,
  updateStatus,
  markAsReady,
  confirmHubReception,
  deleteOrder
}

class PendingAction {
  final int? id; // ID local de l'action dans la file d'attente
  final SyncActionType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;

  PendingAction({
    this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
  });

  // Pour la base de données
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name, // Stocke l'enum par son nom (ex: 'createOrder')
      'payload': jsonEncode(payload), // Stocke le payload en JSON
      'created_at': createdAt.toIso8601String(),
      'attempts': attempts,
    };
  }

  // Depuis la base de données
  factory PendingAction.fromMap(Map<String, dynamic> map) {
    return PendingAction(
      id: map['id'] as int?,
      type: SyncActionType.values
          .firstWhere((e) => e.name == map['type'], orElse: () => SyncActionType.updateOrder), // Valeur par défaut sûre
      payload: jsonDecode(map['payload']) as Map<String, dynamic>,
      createdAt: DateTime.parse(map['created_at']),
      attempts: map['attempts'] as int,
    );
  }
}