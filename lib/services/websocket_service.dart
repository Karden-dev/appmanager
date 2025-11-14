// lib/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:wink_manager/services/auth_service.dart';
// import 'package:wink_manager/services/notification_service.dart'; // <-- SUPPRIMÉ

/// Gère la connexion WebSocket persistante pour l'administrateur.
/// Écoute les événements globaux et les messages entrants.
class WebSocketService extends ChangeNotifier {
  // URL du serveur WebSocket (à adapter si nécessaire)
  static const String _wsBaseUrl = "wss://app.winkexpress.online";

  final AuthService _authService;
  // final NotificationService _notificationService; // <-- SUPPRIMÉ

  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;

  bool get isConnected => _isConnected;

  // Stream pour tous les messages bruts reçus (utilisé par ChatProvider)
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messagesStream => _messageController.stream;

  // Stream pour les événements de haut niveau (utilisé par ChatProvider)
  final StreamController<String> _eventController =
      StreamController<String>.broadcast();
  Stream<String> get eventStream => _eventController.stream;

  // ID de la conversation active pour éviter les notifications inutiles
  int? activeChatOrderId;

  // MODIFIÉ: Constructeur mis à jour
  WebSocketService(this._authService) {
    // Écoute les changements d'authentification pour se connecter/déconnecter
    _authService.addListener(onAuthStateChanged);
    // Tente la connexion initiale si déjà authentifié
    onAuthStateChanged();
  }

  // MODIFIÉ: Rendue publique pour être appelée par main.dart
  void onAuthStateChanged() {
    if (_authService.isAuthenticated && !_isConnected) {
      connect();
    } else if (!_authService.isAuthenticated && _isConnected) {
      disconnect();
    }
  }

  void connect() {
    if (_isConnected || _channel != null || !_authService.isAuthenticated) {
      debugPrint('WS (Admin): Connexion annulée (déjà connecté ou non authentifié).');
      return;
    }

    final String? token = _authService.token;
    if (token == null) {
      debugPrint('WS (Admin): Connexion échouée (Token non disponible).');
      return;
    }

    final wsUrl = Uri.parse('$_wsBaseUrl?token=$token');
    debugPrint('WS (Admin): Tentative de connexion...');

    try {
      _channel = WebSocketChannel.connect(wsUrl);
      _isConnected = true;
      _reconnectTimer?.cancel();
      notifyListeners();

      _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('WS (Admin): Erreur de connexion initiale: $e');
      _onError(e); // Gérer l'erreur comme une déconnexion
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close(1000, 'Déconnexion manuelle Admin');
    _isConnected = false;
    _channel = null;
    activeChatOrderId = null;
    notifyListeners();
    debugPrint('WS (Admin): Déconnexion effectuée.');
  }

  // --- Gestion des Événements du Stream ---

  void _onData(dynamic data) {
    try {
      final Map<String, dynamic> message = jsonDecode(data);
      final type = message['type'] as String?;
      final payload = message['payload'] as Map<String, dynamic>?;

      if (type == null) return;

      debugPrint('WS (Admin): Message reçu - Type: $type');

      // 1. Transférer le message brut au ChatProvider
      _messageController.add(message);

      // 2. Gérer les événements pour les mises à jour
      _handleInboundEvents(type, payload);
    } catch (e) {
      debugPrint('WS (Admin): Erreur de parsing du message: $e, Data: $data');
    }
  }

  void _onError(Object error, [StackTrace? stackTrace]) {
    debugPrint('WS (Admin): Erreur dans le stream: $error');
    if (_isConnected) {
      _isConnected = false;
      notifyListeners();
    }
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('WS (Admin): Connexion terminée par le serveur.');
    if (_isConnected) {
      _isConnected = false;
      notifyListeners();
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) _reconnectTimer!.cancel();
    // Ne pas reconnecter si l'utilisateur s'est déconnecté manuellement
    if (!_authService.isAuthenticated) return;

    debugPrint('WS (Admin): Reconnexion dans 5 secondes...');
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  // --- Gestion des Événements et Notifications ---

  // MODIFIÉ: Suppression de la logique de notification
  void _handleInboundEvents(String type, Map<String, dynamic>? payload) {
    // String? title; // <-- SUPPRIMÉ
    // String? body; // <-- SUPPRIMÉ
    // int notificationId = 0; // <-- SUPPRIMÉ

    switch (type) {
      // Événements qui déclenchent une mise à jour de la liste des conversations
      case 'NEW_ORDER_ASSIGNED':
      case 'ORDER_MARKED_URGENT':
      case 'ORDER_STATUS_UPDATE':
      case 'RETURN_RECEIVED_AT_HUB':
      case 'RETURN_GIVEN_TO_SHOP':
        _eventController.add('CONVERSATION_LIST_UPDATE');
        break;

      // Événement de nouveau message
      case 'NEW_MESSAGE':
        // notificationId = 1; // <-- SUPPRIMÉ
        final int? messageUserId = (payload?['user_id'] as num?)?.toInt();
        final int? messageOrderId = (payload?['order_id'] as num?)?.toInt();

        // Ne pas notifier l'admin s'il a envoyé le message lui-même
        // ou s'il regarde déjà cette conversation
        if (payload != null &&
            _authService.user?.id != null &&
            messageUserId != _authService.user!.id &&
            messageOrderId != activeChatOrderId) {
          // title = 'Nouveau Message (Cde #${payload['order_id']})'; // <-- SUPPRIMÉ
          // body = '${payload['user_name'] ?? 'Livreur'}: ${payload['message_content'] ?? '...'}'; // <-- SUPPRIMÉ
        } else {
          // Message reçu mais pas de notification (chat actif ou auto-envoyé)
        }
        // Toujours mettre à jour le compteur global
        _eventController.add('UNREAD_COUNT_UPDATE');
        break;

      // Événement de nouveau retour
      case 'NEW_RETURN_DECLARED':
        // notificationId = 2; // <-- SUPPRIMÉ
        // title = 'Nouveau Retour Déclaré'; // <-- SUPPRIMÉ
        // body = 'Livreur: ${payload?['rider_name'] ?? 'N/A'}\nCde: #${payload?['order_id'] ?? '?'}'; // <-- SUPPRIMÉ
        // Mettre à jour la liste des conversations (car le statut de la commande change)
        _eventController.add('CONVERSATION_LIST_UPDATE');
        // Mettre à jour les badges (car le compteur de retours change)
        _eventController.add('BADGE_COUNT_UPDATE'); 
        break;

      // Mettre à jour les badges (ex: Hub)
      case 'ORDER_READY_FOR_PICKUP':
      case 'ORDER_PICKED_UP_BY_RIDER':
        _eventController.add('BADGE_COUNT_UPDATE');
        break;

      // Mettre à jour le compteur de messages non lus
      case 'UNREAD_COUNT_UPDATE':
        _eventController.add('UNREAD_COUNT_UPDATE');
        break;
    }

    // Toute la logique d'appel à _notificationService.showNotification() est supprimée
  }

  // --- Actions sortantes ---

  void send(String type, {Map<String, dynamic>? payload}) {
    if (!_isConnected || _channel == null) {
      debugPrint('WS (Admin): Impossible d\'envoyer. Non connecté.');
      // Tenter une reconnexion
      if (_authService.isAuthenticated) connect();
      return;
    }
    try {
      final message = jsonEncode({'type': type, 'payload': payload});
      _channel!.sink.add(message);
    } catch (e) {
      debugPrint('WS (Admin): Erreur lors de l\'envoi du message: $e');
    }
  }

  void joinConversation(int orderId) {
    activeChatOrderId = orderId;
    send('JOIN_CONVERSATION', payload: {'orderId': orderId});
  }

  void leaveConversation(int orderId) {
    if (activeChatOrderId == orderId) {
      activeChatOrderId = null;
    }
    send('LEAVE_CONVERSATION', payload: {'orderId': orderId});
  }

  @override
  void dispose() {
    _authService.removeListener(onAuthStateChanged); // MODIFIÉ
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _eventController.close();
    super.dispose();
  }
}