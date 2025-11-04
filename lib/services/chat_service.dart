// lib/services/chat_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:wink_manager/models/conversation.dart';
import 'package:wink_manager/services/auth_service.dart';

/// Gère les requêtes API (HTTP/Dio) pour le module de Chat/Suivis.
/// Distingue du WebSocketService qui gère la connexion temps réel.
class ChatService {
  final AuthService _authService;
  final Dio _dio;

  ChatService(this._authService) : _dio = _authService.dio;

  /// Récupère la liste des conversations pour l'admin (onglet Suivis).
  Future<List<Conversation>> fetchConversations({
    required bool showArchived,
    required bool showUrgentOnly,
  }) async {
    try {
      final response = await _dio.get(
        '/suivis/conversations',
        queryParameters: {
          'showArchived': showArchived,
          'showUrgentOnly': showUrgentOnly,
        },
      );

      if (response.data is List) {
        final List<dynamic> body = response.data;
        return body
            .map((dynamic item) => Conversation.fromJson(item))
            .toList();
      } else {
        debugPrint('ChatService: fetchConversations a reçu une réponse non-List: ${response.data}');
        return [];
      }
    } on DioException catch (e) {
      if (kDebugMode) print('ChatService: Erreur fetchConversations: $e');
      throw Exception(e.response?.data['message'] ?? 'Erreur réseau (Conversations)');
    }
  }

  /// Récupère l'historique des messages d'une commande.
  /// Marque les messages comme lus côté serveur si [lastMessageId] est fourni.
  Future<List<Map<String, dynamic>>> fetchMessages(int orderId, {String? since, int? lastMessageId}) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (lastMessageId != null) {
        queryParameters['triggerRead'] = lastMessageId;
      }
      if (since != null) {
        queryParameters['since'] = since;
      }

      final response = await _dio.get(
        '/orders/$orderId/messages',
        queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
      );

      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else {
        debugPrint('ChatService: fetchMessages a reçu une réponse non-List: ${response.data}');
        return [];
      }
    } on DioException catch (e) {
      if (kDebugMode) print('ChatService: Erreur fetchMessages: $e');
      throw Exception(e.response?.data['message'] ?? 'Erreur réseau (Messages)');
    }
  }

  /// Envoie un nouveau message (Admin -> Livreur).
  Future<void> postMessage(int orderId, String content) async {
    try {
      await _dio.post(
        '/orders/$orderId/messages',
        data: {'message_content': content},
      );
      // Pas besoin de retourner le message, le WebSocket s'en chargera.
    } on DioException catch (e) {
      if (kDebugMode) print('ChatService: Erreur postMessage: $e');
      throw Exception(e.response?.data['message'] ?? 'Échec de l\'envoi du message.');
    }
  }

  /// Récupère les réponses rapides pour le rôle 'admin'.
  Future<List<String>> fetchQuickReplies() async {
    try {
      // Le backend filtre par rôle en utilisant le token
      final response = await _dio.get('/suivis/quick-replies');
      if (response.data is List) {
        return List<String>.from(response.data);
      } else {
        debugPrint('ChatService: fetchQuickReplies a reçu une réponse non-List: ${response.data}');
        return [];
      }
    } on DioException catch (e) {
      if (kDebugMode) print('ChatService: Erreur fetchQuickReplies: $e');
      throw Exception(e.response?.data['message'] ?? 'Erreur (Réponses rapides)');
    }
  }

  /// Récupère le compteur total de messages non lus pour l'admin.
  Future<int> fetchTotalUnreadCount() async {
    try {
      final response = await _dio.get('/suivis/unread-count');
      return (response.data['unreadCount'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      if (kDebugMode) print('ChatService: Erreur fetchTotalUnreadCount: $e');
      return 0; // Ne pas bloquer l'UI pour un compteur
    }
  }

  // --- Actions Admin (depuis le Chat) ---

  Future<void> reassignOrder(int orderId, int newDeliverymanId) async {
    try {
      await _dio.put(
        '/suivis/orders/$orderId/reassign-from-chat',
        data: {'newDeliverymanId': newDeliverymanId},
      );
    } on DioException catch (e) {
      if (kDebugMode) print('ChatService: Erreur reassignOrder: $e');
      throw Exception(e.response?.data['message'] ?? 'Échec de la réassignation.');
    }
  }

  Future<void> resetOrderStatus(int orderId) async {
    try {
      await _dio.put(
        '/suivis/orders/$orderId/reset-status-from-chat',
        // Le backend déduit l'adminID du token
      );
    } on DioException catch (e) {
      if (kDebugMode) print('ChatService: Erreur resetOrderStatus: $e');
      throw Exception(e.response?.data['message'] ?? 'Échec de la réinitialisation.');
    }
  }

  Future<void> toggleUrgency(int orderId, bool isUrgent) async {
    try {
      await _dio.put(
        '/suivis/orders/$orderId/toggle-urgency',
        data: {'is_urgent': isUrgent},
      );
    } on DioException catch (e) {
      if (kDebugMode) print('ChatService: Erreur toggleUrgency: $e');
      throw Exception(e.response?.data['message'] ?? 'Échec du changement d\'urgence.');
    }
  }
  
  // Note: La route /toggle-archive n'existe pas encore dans les fichiers fournis.
  // Nous l'ajoutons en anticipation de la logique de 'suivis.js'.
  Future<void> toggleArchive(int orderId, bool isArchived) async {
    try {
      // ATTENTION: Cette route n'est pas définie dans les fichiers .js fournis.
      // Elle est basée sur la logique vue dans 'suivis.js' (toggleArchiveBtn).
      // Le backend devra implémenter:
      // PUT /api/suivis/conversations/:orderId/toggle-archive
      await _dio.put(
        '/suivis/conversations/$orderId/toggle-archive',
        data: {'is_archived': isArchived},
      );
    } on DioException catch (e) {
      if (kDebugMode) print('ChatService: Erreur toggleArchive: $e');
      throw Exception(e.response?.data['message'] ?? 'Échec de l\'archivage.');
    }
  }
}