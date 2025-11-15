// lib/models/message.dart

import 'package:flutter/foundation.dart'; // Pour kDebugMode

/// Modèle représentant un message individuel dans le chat.
/// (Identique à 'riderapp' pour la cohérence)
class Message {
  final int id;
  final int orderId;
  final int userId;
  final String userName;
  final String content;
  final String messageType; // 'user' or 'system'
  final DateTime createdAt;
  final bool isSentByMe; // Dérivé côté client

  Message({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.messageType,
    required this.createdAt,
    required this.isSentByMe,
  });

  // --- Mappeurs pour API JSON ---

  factory Message.fromJson(Map<String, dynamic> json, int currentUserId) {
    // Gestion robuste des types et valeurs null
    int parsedId = 0;
    try {
      parsedId = (json['id'] as num?)?.toInt() ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print("Erreur parsing message ID: $e, Data: ${json['id']}");
      }
    }

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) {
        print("Erreur parsing message date: $e, Data: ${json['created_at']}");
      }
      parsedDate = DateTime.now();
    }

    return Message(
      id: parsedId,
      orderId: (json['order_id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      userName: json['user_name'] as String? ?? 'Inconnu',
      content: json['message_content'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'user',
      createdAt: parsedDate,
      isSentByMe: ((json['user_id'] as num?)?.toInt() ?? -1) == currentUserId,
    );
  }

  // --- Mappeurs pour la Base de Données Locale (sqflite) ---

  /// Convertit l'objet Message en Map pour l'insertion DB.
  Map<String, dynamic> toMapForDb() {
    return {
      'id': id,
      'order_id': orderId,
      'user_id': userId,
      'user_name': userName,
      'content': content,
      'message_type': messageType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Crée un objet Message à partir d'un Map (ligne de DB).
  factory Message.fromMap(Map<String, dynamic> map, int currentUserId) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(
          map['created_at'] as String? ?? DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) {
        print("Erreur parsing DB date: $e, Data: ${map['created_at']}");
      }
      parsedDate = DateTime.now();
    }

    return Message(
      id: map['id'] as int? ?? 0,
      orderId: map['order_id'] as int? ?? 0,
      userId: map['user_id'] as int? ?? 0,
      userName: map['user_name'] as String? ?? 'Inconnu',
      content: map['content'] as String? ?? '',
      messageType: map['message_type'] as String? ?? 'user',
      createdAt: parsedDate,
      // Déterminé lors de la lecture
      isSentByMe: (map['user_id'] as int? ?? -1) == currentUserId,
    );
  }

  // --- AJOUT : Opérateurs d'égalité pour l'optimisation ---
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Message &&
      other.id == id &&
      other.orderId == orderId &&
      other.userId == userId &&
      other.userName == userName &&
      other.content == content &&
      other.messageType == messageType &&
      other.createdAt == createdAt &&
      other.isSentByMe == isSentByMe;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      orderId.hashCode ^
      userId.hashCode ^
      userName.hashCode ^
      content.hashCode ^
      messageType.hashCode ^
      createdAt.hashCode ^
      isSentByMe.hashCode;
  }
  // --- FIN AJOUT ---
}