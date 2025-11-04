// lib/providers/chat_provider.dart

import 'dart:async'; 
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

  // ... (propriétés inchangées) ...
  List<Conversation> _conversations = [];
  bool _isLoadingConversations = false;
  String? _conversationError;
  int _totalUnreadCount = 0;
  bool _showArchived = false;
  bool _showUrgentOnly = false;
  String _searchQuery = ''; 
  int? _activeOrderId;
  List<Message> _activeMessages = [];
  bool _isLoadingMessages = false;
  String? _messagesError;
  List<String> _quickReplies = [];
  StreamSubscription? _wsEventSubscription; 
  StreamSubscription? _wsMessageSubscription; 

  // --- Getters ---
  // ... (getters inchangés) ...
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
  String get searchQuery => _searchQuery; 

  ChatProvider(
    this._authService,
    this._chatService,
    this._webSocketService,
    this._chatRepository,
  ) {
    if (_authService.isAuthenticated) {
      _initializeListeners();
      loadConversations(forceApi: true);
      updateTotalUnreadCount();
      loadQuickReplies(); 
    }
  }

  void _initializeListeners() {
    _wsEventSubscription?.cancel();
    _wsEventSubscription = _webSocketService.eventStream.listen((event) {
      if (kDebugMode) print('ChatProvider: Événement WS reçu: $event');
      switch (event) {
        case 'CONVERSATION_LIST_UPDATE':
        case 'ORDER_UPDATE':
          loadConversations(forceApi: true); 
          break;
        case 'UNREAD_COUNT_UPDATE':
          updateTotalUnreadCount(); 
          break;
        case 'BADGE_COUNT_UPDATE':
          // TODO: Déclencher une mise à jour des badges du Hub/Logistique (via un autre provider)
          break;
      }
    });

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

      // --- CORRECTION BUG RÉCEPTION INSTANTANÉE ---
      // 1. Mettre à jour l'UI instantanément (AVANT le await)
      if (newMessage.orderId == _activeOrderId) {
        bool listChanged = false;
        List<Message> updatedList = List<Message>.from(_activeMessages);

        if (newMessage.isSentByMe) {
          // C'est une confirmation de serveur pour un message envoyé
          final tempMessageIndex = updatedList.indexWhere(
            (m) => m.id > 999999999 && m.content == newMessage.content
          );

          if (tempMessageIndex != -1) {
            updatedList[tempMessageIndex] = newMessage;
            listChanged = true;
          } else if (!updatedList.any((m) => m.id == newMessage.id)) {
            updatedList.add(newMessage);
            listChanged = true;
          }

        } else {
          // C'est un message REÇU d'un autre
          if (!updatedList.any((m) => m.id == newMessage.id)) {
            updatedList.add(newMessage);
            listChanged = true;
          }
        }
        
        if (listChanged) {
          updatedList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          _activeMessages = updatedList; 
          notifyListeners(); // <-- Appel instantané !
        }
          
        if (!newMessage.isSentByMe) {
          // Le marquage comme lu peut aussi être asynchrone
          _markAsRead(newMessage.orderId, newMessage.id);
        }
      }

      // 2. Mettre en cache le message en arrière-plan (APRES l'update UI)
      await _chatRepository.cacheSingleMessage(newMessage);
      // --- FIN CORRECTION ---

    } catch (e) {
      debugPrint('ChatProvider: Erreur _handleNewMessage: $e');
    }
  }

  /// Marque les messages comme lus via l'API (met aussi à jour le compteur global).
  Future<void> _markAsRead(int orderId, int lastMessageId) async {
    // ... (méthode inchangée) ...
    try {
      await _chatService.fetchMessages(orderId, lastMessageId: lastMessageId);
      updateTotalUnreadCount();
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
    // ... (méthode inchangée) ...
    _isLoadingConversations = true;
    _conversationError = null;
    notifyListeners();
    try {
      final cachedConversations = await _chatRepository.getCachedConversations(
        showArchived: _showArchived,
        showUrgentOnly: _showUrgentOnly,
      );
      if (cachedConversations.isNotEmpty || !forceApi) {
        _conversations = cachedConversations;
        _isLoadingConversations = false;
        notifyListeners();
      }
      if (forceApi || cachedConversations.isEmpty) {
        final apiConversations = await _chatService.fetchConversations(
          showArchived: _showArchived,
          showUrgentOnly: _showUrgentOnly,
        );
        if (forceApi) {
          await _chatRepository.clearConversationCache();
        }
        await _chatRepository.cacheConversations(apiConversations);
        _conversations = apiConversations;
      }
    } catch (e) {
      _conversationError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<void> updateTotalUnreadCount() async {
    // ... (méthode inchangée) ...
    try {
      _totalUnreadCount = await _chatService.fetchTotalUnreadCount();
    } catch (e) {
      debugPrint("ChatProvider: Échec updateTotalUnreadCount: $e");
    }
    notifyListeners();
  }

  Future<void> loadQuickReplies() async {
    // ... (méthode inchangée) ...
    try {
      _quickReplies = await _chatService.fetchQuickReplies();
    } catch (e) {
      debugPrint("ChatProvider: Échec loadQuickReplies: $e");
    }
    notifyListeners();
  }

  // --- Gestion des Filtres ---
  // ... (méthodes inchangées) ...
  void setConversationSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }
  void toggleArchivedFilter() {
    _showArchived = !_showArchived;
    if (_showArchived) _showUrgentOnly = false; 
    loadConversations(forceApi: true);
  }
  void toggleUrgentFilter() {
    _showUrgentOnly = !_showUrgentOnly;
    if (_showUrgentOnly) _showArchived = false; 
    loadConversations(forceApi: true);
  }


  // --- Gestion du Chat Actif ---
  Future<void> selectConversation(int orderId) async {
    // ... (méthode inchangée) ...
    final int? currentUserId = _authService.user?.id;
    if (currentUserId == null) return;
    if (_activeOrderId == orderId) return;
    if (_activeOrderId != null) {
      _webSocketService.leaveConversation(_activeOrderId!);
    }
    _activeOrderId = orderId;
    _isLoadingMessages = true;
    _messagesError = null;
    _activeMessages = [];
    notifyListeners();
    _webSocketService.joinConversation(orderId);
    try {
      final cachedMessages = await _chatRepository.getCachedMessages(orderId, currentUserId);
      _activeMessages = cachedMessages;
      _isLoadingMessages = false;
      notifyListeners();
      
      final latestTimestamp = await _chatRepository.getLatestMessageTimestamp(orderId);
      final apiMessagesData = await _chatService.fetchMessages(orderId, since: latestTimestamp);
      if (apiMessagesData.isNotEmpty) {
        final newMessages = apiMessagesData
            .map((m) => Message.fromJson(m, currentUserId))
            .toList();
        await _chatRepository.cacheMessages(newMessages);
        final newMessagesToAdd = newMessages.where((msg) => !_activeMessages.any((m) => m.id == msg.id)).toList();
        _activeMessages = List<Message>.from(_activeMessages)..addAll(newMessagesToAdd);
        _activeMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
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
    // ... (méthode inchangée) ...
    if (_activeOrderId != null) {
      _webSocketService.leaveConversation(_activeOrderId!);
      _activeOrderId = null;
      _activeMessages = [];
      notifyListeners();
    }
  }

  /// Envoie un message dans le chat actif.
  Future<void> sendMessage(String content) async {
    // ... (méthode de mise à jour optimiste, inchangée) ...
    if (_activeOrderId == null || content.trim().isEmpty) return;
    if (_authService.user == null) return;

    final user = _authService.user!;

    final tempMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch, 
      orderId: _activeOrderId!,
      userId: user.id,
      userName: user.name,
      content: content.trim(),
      messageType: 'user',
      createdAt: DateTime.now(),
      isSentByMe: true,
    );

    _activeMessages = List<Message>.from(_activeMessages)..add(tempMessage);
    notifyListeners();

    try {
      await _chatService.postMessage(_activeOrderId!, content.trim());
    } catch (e) {
      _messagesError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  // --- Actions Admin sur le Chat Actif ---
  // ... (méthodes inchangées) ...
  Future<void> reassignActiveOrder(Deliveryman deliveryman) async {
    if (_activeOrderId == null) return;
    try {
      await _chatService.reassignOrder(_activeOrderId!, deliveryman.id);
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

// ... (Extension 'ConversationCopyWith' inchangée) ...
extension ConversationCopyWith on Conversation {
  Conversation copyWith({
    int? unreadCount,
  }) {
    return Conversation(
      orderId: orderId,
      customerPhone: customerPhone,
      shopName: shopName,
      deliverymanName: deliverymanName,
      deliverymanPhone: deliverymanPhone, // Assure-toi que c'est là
      isUrgent: isUrgent,
      isArchived: isArchived,
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}