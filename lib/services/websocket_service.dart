// lib/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- NOUVEL IMPORT

import '../models/user.dart';
import 'notification_service.dart';

// Helper de parsing
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}


class WebSocketService extends ChangeNotifier {
  static const String _wsBaseUrl = "wss://app.winkexpress.online";
  static const String _apiBaseUrl = "https://app.winkexpress.online/api";
  static const String _quickRepliesKey = 'quick_replies_cache'; // <-- CLÉ CACHE
  // Cache les réponses pour une heure (3600 secondes)
  static const Duration _cacheDuration = Duration(hours: 1); 


  final Dio _dio;
  final NotificationService _notificationService;
  User? _currentUser;

  WebSocketChannel? _channel;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messagesStream => _messageController.stream;

  // ID de la CDE actuellement affichée dans ChatScreen
  int? activeChatOrderId;

  final StreamController<String> _eventController =
      StreamController<String>.broadcast();
  Stream<String> get eventStream => _eventController.stream;

  WebSocketService(this._dio, this._notificationService);

  // --- Gestion de la Connexion ---

  void connect(User user) {
    if (_isConnected && _channel != null) {
      debugPrint('WS: Déjà connecté.');
      _currentUser = user;
      return;
    }

    _currentUser = user;
    final token = user.token;

    try {
      final wsUrl = Uri.parse('$_wsBaseUrl?token=$token');

      _channel = WebSocketChannel.connect(wsUrl);
      _isConnected = true;
      notifyListeners();

      _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );

      debugPrint('WS: Tentative de connexion...');

    } catch (e) {
      debugPrint('WS: Erreur de connexion: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  void disconnect() {
    _channel?.sink.close(1000, 'Déconnexion manuelle');
    _isConnected = false;
    _channel = null;
    activeChatOrderId = null;
    notifyListeners();
    debugPrint('WS: Déconnexion effectuée.');
  }

  // --- Gestion des Événements du Stream ---

  void _onData(dynamic data) {
    debugPrint('WS: Raw data received: $data');
    try {
      final Map<String, dynamic> message = jsonDecode(data);
      final type = message['type'] as String?;
      final payload = message['payload'] as Map<String, dynamic>?;

      if (type == null) return;

      debugPrint('WS: Message reçu parsé - Type: $type');
      _messageController.add(message);
      _handleInboundEvents(type, payload);

    } catch (e) {
      debugPrint('WS: Erreur de parsing du message: $e, Data: $data');
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    debugPrint('WS: Erreur dans le stream: $error');
    _isConnected = false;
    notifyListeners();
    if (_currentUser != null) {
      Future.delayed(const Duration(seconds: 5), () => connect(_currentUser!));
    }
  }

  void _onDone() {
    debugPrint('WS: Connexion terminée par le serveur.');
    _isConnected = false;
    notifyListeners();
    if (_currentUser != null) {
      Future.delayed(const Duration(seconds: 5), () => connect(_currentUser!));
    }
  }

  void _handleInboundEvents(String type, Map<String, dynamic>? payload) {
    String? title;
    String? body;
    int notificationId = 0;

    debugPrint('WS: Handling inbound event - Type: $type, Payload: $payload');
    debugPrint('WS: Active chat ID is: $activeChatOrderId');

    switch (type) {
      case 'NEW_ORDER_ASSIGNED':
        notificationId = 1;
        title = 'Nouvelle Commande Assignée !';
        body = 'Commande #${payload?['order_id'] ?? '?'} (${payload?['shop_name'] ?? 'N/A'}) est prête pour vous.';
        _eventController.add('ORDER_UPDATE');
        break;

      case 'ORDER_MARKED_URGENT':
         notificationId = 2;
         title = 'URGENCE !';
         body = 'Commande #${payload?['order_id'] ?? '?'} marquée comme URGENTE par l\'admin.';
         _eventController.add('ORDER_UPDATE');
         break;

      case 'REMITTANCE_CONFIRMED':
         notificationId = 3;
         title = 'Versement Confirmé !';
         body = 'Votre versement a été confirmé par l\'administrateur.';
         _eventController.add('REMITTANCE_UPDATE');
         break;

      case 'NEW_MESSAGE':
        notificationId = 4;
        final int? messageUserId = _parseInt(payload?['user_id']);
        final int? messageOrderId = _parseInt(payload?['order_id']);
        
        debugPrint('WS: Handling NEW_MESSAGE from user $messageUserId (current user: ${_currentUser?.id}) for order $messageOrderId');

        // Condition pour notifier :
        if (payload != null &&
            _currentUser != null &&
            messageUserId != _currentUser!.id &&
            messageOrderId != activeChatOrderId) 
        {
            title = 'Nouveau Message !';
            body = '${payload['user_name'] as String? ?? 'Admin'}: ${payload['message_content'] as String? ?? '...'}';
            debugPrint('WS: Triggering notification for received message (chat non actif).');
        } else {
            debugPrint('WS: Skipping notification (self-sent or chat is active).');
            title = null;
            body = null;
        }
        _eventController.add('UNREAD_COUNT_UPDATE');
        break;

      case 'ORDER_READY_FOR_PICKUP':
        notificationId = 5;
        title = 'Colis Prêt !';
        body = 'Commande #${payload?['order_id'] ?? '?'} (${payload?['shop_name'] ?? 'N/A'}) est prête à être récupérée.';
        _eventController.add('ORDER_UPDATE');
        break;

      case 'ORDER_STATUS_UPDATE':
      case 'CONVERSATION_LIST_UPDATE':
        _eventController.add('ORDER_UPDATE');
        break;

      default:
        debugPrint('WS: Event type "$type" not handled for notifications.');
        return;
    }

    if (title != null && body != null) {
      _notificationService.showNotification(
        notificationId,
        title,
        body,
        payload: payload != null ? jsonEncode(payload) : null,
      );
    }
  }


  // --- Autres méthodes ---

  void send(String type, {Map<String, dynamic>? payload}) {
     if (!_isConnected || _channel == null) {
      debugPrint('WS: Impossible d\'envoyer. Non connecté.');
      return;
    }
    final message = jsonEncode({'type': type, 'payload': payload});
    _channel!.sink.add(message);
  }

  void joinConversation(int orderId) {
    send('JOIN_CONVERSATION', payload: {'orderId': orderId});
  }

  void leaveConversation(int orderId) {
    send('LEAVE_CONVERSATION', payload: {'orderId': orderId});
  }

  Future<void> sendMessage(int orderId, String content) async {
     try {
      await _dio.post(
        '$_apiBaseUrl/orders/$orderId/messages',
        data: {'message_content': content},
      );
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec de l\'envoi du message.';
      throw Exception(message);
    }
  }

  /// **MODIFIÉ**: Ajout du paramètre 'since' pour la synchronisation de l'historique du chat.
  Future<List<Map<String, dynamic>>> fetchMessages(int orderId, {String? since, int? lastMessageId}) async {
     try {
      final queryParameters = <String, dynamic>{};
      if (lastMessageId != null) {
        queryParameters['triggerRead'] = lastMessageId;
      }
      // **NOUVELLE LOGIQUE POUR LE CACHE/SYNCHRO DELTA**
      if (since != null) {
         queryParameters['since'] = since;
      }

      final response = await _dio.get(
        '$_apiBaseUrl/orders/$orderId/messages',
        queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
      );
      if (response.data is List) {
         return List<Map<String, dynamic>>.from(response.data);
      } else {
         debugPrint('WS: fetchMessages a reçu une réponse non-List: ${response.data}');
         return [];
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec du chargement de l\'historique.';
      throw Exception(message);
    } catch (e) {
       debugPrint('WS: Erreur inattendue dans fetchMessages: $e');
       throw Exception('Erreur lors de la récupération des messages.');
    }
  }

  /// **MODIFIÉ**: Ajout de la logique de cache via SharedPreferences.
  Future<List<String>> fetchQuickReplies() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_quickRepliesKey);

    // 1. Vérifie le cache local
    if (cachedData != null) {
      try {
        final decoded = jsonDecode(cachedData) as Map<String, dynamic>;
        final timestamp = DateTime.parse(decoded['timestamp'] as String);
        final replies = List<String>.from(decoded['replies'] as List<dynamic>);

        if (DateTime.now().difference(timestamp) < _cacheDuration) {
          debugPrint('WS: Quick Replies servies depuis le cache.');
          return replies; // Cache valide
        }
        debugPrint('WS: Cache Quick Replies expiré.');

      } catch (e) {
        debugPrint('WS: Erreur de parsing du cache Quick Replies: $e');
      }
    }

    // 2. Fetch API si pas de cache ou cache invalide/expiré
    try {
      final response = await _dio.get('$_apiBaseUrl/suivis/quick-replies');
      if (response.data is List) {
        final List<String> freshReplies = List<String>.from(response.data);
        
        // 3. Sauvegarde le résultat frais dans le cache
        final dataToCache = {
          'timestamp': DateTime.now().toIso8601String(),
          'replies': freshReplies,
        };
        await prefs.setString(_quickRepliesKey, jsonEncode(dataToCache));

        return freshReplies;
      } else {
        debugPrint('WS: fetchQuickReplies a reçu une réponse non-List: ${response.data}');
        return [];
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec du chargement des réponses rapides.';
      throw Exception(message);
    } catch (e) {
      debugPrint('WS: Erreur inattendue dans fetchQuickReplies: $e');
      throw Exception('Erreur lors de la récupération des réponses rapides.');
    }
  }
}