// lib/providers/chat_provider.dart

import 'dart:async'; // <-- CORRECTION: 'dart.async' est devenu 'dart:async'
import 'package:flutter/foundation.dart';
import 'package:wink_manager/models/conversation.dart';
import 'package:wink_manager/models/message.dart';
import 'package:wink_manager/models/deliveryman.dart';
import 'package:wink_manager/services/auth_service.dart';
import 'package:wink_manager/services/chat_service.dart';
import 'package:wink_manager/services/websocket_service.dart';
import 'package:wink_manager/repositories/chat_repository.dart';

/// Provider central pour la gestion de l'état du module de Chat (Suivis).
class ChatProvider with ChangeNotifier {
  final AuthService _authService;
  final ChatService _chatService;
  final WebSocketService _webSocketService;
  final ChatRepository _chatRepository;

  // État de la liste principale des conversations
  List<Conversation> _conversations = [];
  bool _isLoadingConversations = false;
  String? _conversationError;
  int _totalUnreadCount = 0;

  // Filtres de la liste
  bool _showArchived = false;
  bool _showUrgentOnly = false;
  String _searchQuery = ''; // Note: Ce champ est utilisé par l'UI (Consumer)

  // État de la conversation active (écran de chat détaillé)
  int? _activeOrderId;
  List<Message> _activeMessages = [];
  bool _isLoadingMessages = false;
  String? _messagesError;
  List<String> _quickReplies = [];

  StreamSubscription? _wsEventSubscription; // <-- Maintenant reconnu
  StreamSubscription? _wsMessageSubscription; // <-- Maintenant reconnu

  // --- Getters ---
  List<Conversation> get conversations => _conversations;
  bool get isLoadingConversations => _isLoadingConversations;
  String? get conversationError => _conversationError;
  int get totalUnreadCount => _totalUnreadCount;
  bool get showArchived => _showArchived;
  bool get showUrgentOnly => _showUrgentOnly;

  List<Message> get activeMessages => _activeMessages;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get messagesError => _messagesError;
  List<String> get quickReplies => _quickReplies;
  int? get activeOrderId => _activeOrderId;
  String get searchQuery => _searchQuery; // Getter pour l'UI

  ChatProvider(
    this._authService,
    this._chatService,
    this._webSocketService,
    this._chatRepository,
  ) {
    if (_authService.isAuthenticated) {
      _initializeListeners();
      // Charge la liste des conversations et le compteur au démarrage
      loadConversations(forceApi: true);
      updateTotalUnreadCount();
      loadQuickReplies(); // Charge les réponses rapides
    }
  }

  /// Initialise les écouteurs sur les streams du WebSocketService.
  void _initializeListeners() {
    // Écoute les événements de haut niveau (ex: 'CONVERSATION_LIST_UPDATE')
    _wsEventSubscription?.cancel();
    _wsEventSubscription = _webSocketService.eventStream.listen((event) {
      if (kDebugMode) print('ChatProvider: Événement WS reçu: $event');
      switch (event) {
        case 'CONVERSATION_LIST_UPDATE':
        case 'ORDER_UPDATE':
          loadConversations(forceApi: true); // Force la synchro API
          break;
        case 'UNREAD_COUNT_UPDATE':
          updateTotalUnreadCount(); // Force la synchro API du compteur
          break;
        case 'BADGE_COUNT_UPDATE':
          // TODO: Déclencher une mise à jour des badges du Hub/Logistique (via un autre provider)
          break;
      }
    });

    // Écoute les messages entrants bruts
    _wsMessageSubscription?.cancel();
    _wsMessageSubscription =
        _webSocketService.messagesStream.listen((messageData) {
      if (messageData['type'] == 'NEW_MESSAGE' && messageData['payload'] != null) {
        _handleNewMessage(messageData['payload']);
      }
    });
  }

  /// Gère un message WebSocket entrant de type 'NEW_MESSAGE'.
  Future<void> _handleNewMessage(Map<String, dynamic> payload) async {
    final int? currentUserId = _authService.user?.id;
    if (currentUserId == null) return;

    try {
      final newMessage = Message.fromJson(payload, currentUserId);

      // 1. Mettre en cache le nouveau message
      await _chatRepository.cacheSingleMessage(newMessage);

      // 2. Mettre à jour l'UI si c'est le chat actif
      if (newMessage.orderId == _activeOrderId) {
        // Évite les doublons
        if (!_activeMessages.any((m) => m.id == newMessage.id)) {
          _activeMessages.add(newMessage);
          _activeMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          notifyListeners();
          
          // Marquer comme lu si le chat est actif
          if (newMessage.userId != currentUserId) {
            _markAsRead(newMessage.orderId, newMessage.id);
          }
        }
      }
    } catch (e) {
      debugPrint('ChatProvider: Erreur _handleNewMessage: $e');
    }
  }

  /// Marque les messages comme lus via l'API (met aussi à jour le compteur global).
  Future<void> _markAsRead(int orderId, int lastMessageId) async {
    try {
      // L'API (ChatService) gère le triggerRead ET met à jour les compteurs
      await _chatService.fetchMessages(orderId, lastMessageId: lastMessageId);
      // Mettre à jour le compteur global après le marquage
      updateTotalUnreadCount();
      // Mettre à jour le compteur de la conversation locale
      final convIndex = _conversations.indexWhere((c) => c.orderId == orderId);
      if (convIndex != -1) {
        _conversations[convIndex] = _conversations[convIndex].copyWith(unreadCount: 0);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("ChatProvider: Échec du marquage comme lu pour $orderId: $e");
    }
  }

  // --- Gestion de la Liste des Conversations ---

  Future<void> loadConversations({bool forceApi = false}) async {
    _isLoadingConversations = true;
    _conversationError = null;
    notifyListeners();

    try {
      // 1. Charger le cache
      final cachedConversations = await _chatRepository.getCachedConversations(
        showArchived: _showArchived,
        showUrgentOnly: _showUrgentOnly,
      );
      if (cachedConversations.isNotEmpty || !forceApi) {
        _conversations = cachedConversations;
        _isLoadingConversations = false;
        notifyListeners();
      }

      // 2. Si forcé ou cache vide, fetch API
      if (forceApi || cachedConversations.isEmpty) {
        final apiConversations = await _chatService.fetchConversations(
          showArchived: _showArchived,
          showUrgentOnly: _showUrgentOnly,
        );

        // 3. Mettre à jour le cache
        if (forceApi) {
          // Si on force, on vide l'ancien cache de cette vue
          await _chatRepository.clearConversationCache();
        }
        await _chatRepository.cacheConversations(apiConversations);

        // 4. Mettre à jour l'état
        _conversations = apiConversations;
      }
    } catch (e) {
      _conversationError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  /// Met à jour le compteur global de messages non lus.
  Future<void> updateTotalUnreadCount() async {
    try {
      _totalUnreadCount = await _chatService.fetchTotalUnreadCount();
    } catch (e) {
      debugPrint("ChatProvider: Échec updateTotalUnreadCount: $e");
      // Ne pas écraser le compteur existant en cas d'erreur réseau
    }
    notifyListeners();
  }

  /// Charge les réponses rapides (via cache ou API).
  Future<void> loadQuickReplies() async {
    try {
      _quickReplies = await _chatService.fetchQuickReplies();
    } catch (e) {
      debugPrint("ChatProvider: Échec loadQuickReplies: $e");
    }
    notifyListeners();
  }

  // --- Gestion des Filtres ---

  void setConversationSearch(String query) {
    _searchQuery = query;
    // Le filtrage par recherche se fait côté UI (admin_chat_list_screen)
    notifyListeners();
  }

  void toggleArchivedFilter() {
    _showArchived = !_showArchived;
    if (_showArchived) _showUrgentOnly = false; // Exclusif
    loadConversations(forceApi: true);
  }

  void toggleUrgentFilter() {
    _showUrgentOnly = !_showUrgentOnly;
    if (_showUrgentOnly) _showArchived = false; // Exclusif
    loadConversations(forceApi: true);
  }

  // --- Gestion du Chat Actif ---

  /// Sélectionne une conversation, charge les messages (cache + delta API).
  Future<void> selectConversation(int orderId) async {
    final int? currentUserId = _authService.user?.id;
    if (currentUserId == null) return;

    // Si on clique sur la même conversation, ne rien faire
    if (_activeOrderId == orderId) return;

    // Quitte l'ancienne conversation WebSocket
    if (_activeOrderId != null) {
      _webSocketService.leaveConversation(_activeOrderId!);
    }

    _activeOrderId = orderId;
    _isLoadingMessages = true;
    _messagesError = null;
    _activeMessages = [];
    notifyListeners();

    // Joint la nouvelle conversation WebSocket
    _webSocketService.joinConversation(orderId);

    try {
      // 1. Charger le cache local
      final cachedMessages = await _chatRepository.getCachedMessages(orderId, currentUserId);
      _activeMessages = cachedMessages;
      _isLoadingMessages = false;
      notifyListeners();
      
      // 2. Déterminer le dernier message local pour le delta
      final latestTimestamp = await _chatRepository.getLatestMessageTimestamp(orderId);

      // 3. Fetch les messages plus récents (delta)
      final apiMessagesData = await _chatService.fetchMessages(orderId, since: latestTimestamp);

      if (apiMessagesData.isNotEmpty) {
        final newMessages = apiMessagesData
            .map((m) => Message.fromJson(m, currentUserId))
            .toList();

        // 4. Mettre en cache les nouveaux messages
        await _chatRepository.cacheMessages(newMessages);

        // 5. Fusionner avec l'UI
        final newMessagesToAdd = newMessages.where((msg) => !_activeMessages.any((m) => m.id == msg.id)).toList();
        _activeMessages.addAll(newMessagesToAdd);
        _activeMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      
      // 6. Marquer comme lu (après synchro)
      if (_activeMessages.isNotEmpty) {
         if (_activeMessages.last.userId != currentUserId) {
            await _markAsRead(orderId, _activeMessages.last.id);
         }
      }

    } catch (e) {
      _messagesError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  void deselectConversation() {
    if (_activeOrderId != null) {
      _webSocketService.leaveConversation(_activeOrderId!);
      _activeOrderId = null;
      _activeMessages = [];
      notifyListeners();
    }
  }

  /// Envoie un message dans le chat actif.
  Future<void> sendMessage(String content) async {
    if (_activeOrderId == null || content.trim().isEmpty) return;
    
    try {
      // Envoyer à l'API
      await _chatService.postMessage(_activeOrderId!, content.trim());
      // Le WebSocket (écouté par _handleNewMessage) recevra le message
      // et l'ajoutera au cache et à l'UI.
    } catch (e) {
      _messagesError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  // --- Actions Admin sur le Chat Actif ---

  Future<void> reassignActiveOrder(Deliveryman deliveryman) async {
    if (_activeOrderId == null) return;
    try {
      await _chatService.reassignOrder(_activeOrderId!, deliveryman.id);
      // La mise à jour de l'UI (message système) viendra du WebSocket
    } catch (e) {
      throw Exception('Échec réassignation: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> resetActiveOrderStatus() async {
    if (_activeOrderId == null) return;
    try {
      await _chatService.resetOrderStatus(_activeOrderId!);
    } catch (e) {
      throw Exception('Échec réinitialisation: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> toggleActiveOrderUrgency() async {
    if (_activeOrderId == null) return;
    final conv = _conversations.firstWhere((c) => c.orderId == _activeOrderId);
    try {
      await _chatService.toggleUrgency(_activeOrderId!, !conv.isUrgent);
    } catch (e) {
      throw Exception('Échec urgence: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }
  
  Future<void> toggleActiveOrderArchive() async {
    if (_activeOrderId == null) return;
    final conv = _conversations.firstWhere((c) => c.orderId == _activeOrderId);
    try {
      await _chatService.toggleArchive(_activeOrderId!, !conv.isArchived);
      // Si archivé, fermer le chat actif
      if (!conv.isArchived) {
        deselectConversation();
      }
    } catch (e) {
      throw Exception('Échec archivage: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }


  @override
  void dispose() {
    _wsEventSubscription?.cancel();
    _wsMessageSubscription?.cancel();
    super.dispose();
  }
}

// Extension pour 'copyWith' sur Conversation (utile pour mettre à jour 'unreadCount')
extension ConversationCopyWith on Conversation {
  Conversation copyWith({
    int? unreadCount,
  }) {
    return Conversation(
      orderId: orderId,
      customerPhone: customerPhone,
      shopName: shopName,
      deliverymanName: deliverymanName,
      isUrgent: isUrgent,
      isArchived: isArchived,
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}