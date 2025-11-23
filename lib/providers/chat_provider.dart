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

  // --- MODIFIÉ : Constantes de pagination ---
  static const int _kMessagesPerPage = 10;
  static const int _kConversationsPerPage = 10;

  // État de la liste des conversations
  List<Conversation> _conversations = [];
  bool _isLoadingConversations = false;
  String? _conversationError;
  int _totalUnreadCount = 0;
  bool _showArchived = false;
  bool _showUrgentOnly = false;
  String _searchQuery = '';
  // --- NOUVEAU : État de pagination des conversations ---
  int _conversationPage = 1;
  bool _isLoadingMoreConversations = false;
  bool _hasMoreConversations = true;
  // --- FIN NOUVEAU ---

  // État du chat actif
  int? _activeOrderId;
  List<Message> _activeMessages = [];
  bool _isLoadingMessages = false;
  String? _messagesError;
  List<String> _quickReplies = [];
  bool _isLoadingMoreMessages = false;
  bool _hasMoreMessages = true;

  StreamSubscription? _wsEventSubscription;
  StreamSubscription? _wsMessageSubscription;

  bool _isInitialized = false;

  // --- Getters ---
  List<Conversation> get conversations => _conversations;
  bool get isLoadingConversations => _isLoadingConversations;
  String? get conversationError => _conversationError;
  int get totalUnreadCount => _totalUnreadCount;
  bool get showArchived => _showArchived;
  bool get showUrgentOnly => _showUrgentOnly;
  String get searchQuery => _searchQuery;

  // --- NOUVEAU : Getters de pagination des conversations ---
  bool get isLoadingMoreConversations => _isLoadingMoreConversations;
  bool get hasMoreConversations => _hasMoreConversations;
  // --- FIN NOUVEAU ---

  // Getters du chat actif
  List<Message> get activeMessages => _activeMessages;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get messagesError => _messagesError;
  List<String> get quickReplies => _quickReplies;
  int? get activeOrderId => _activeOrderId;
  bool get isLoadingMoreMessages => _isLoadingMoreMessages;
  bool get hasMoreMessages => _hasMoreMessages;


  ChatProvider(
    this._authService,
    this._chatService,
    this._webSocketService,
    this._chatRepository,
  ) {
    if (_authService.isAuthenticated) {
      loadConversations(forceApi: false);
      updateTotalUnreadCount();
      loadQuickReplies();
    }
  }

  void _initializeListeners() {
    if (_isInitialized) return;
    _isInitialized = true;

    if (kDebugMode) print('ChatProvider: Initialisation des listeners WebSocket.');

    _wsEventSubscription?.cancel();
    _wsEventSubscription = null;

    _wsMessageSubscription?.cancel();
    _wsMessageSubscription =
        _webSocketService.messagesStream.listen((messageData) {
      if (messageData['type'] == 'NEW_MESSAGE' &&
          messageData['payload'] != null) {
        _handleNewMessage(messageData['payload']);
      }
    });
  }

  /// Gère un message WebSocket entrant de type 'NEW_MESSAGE'.
  Future<void> _handleNewMessage(Map<String, dynamic> payload) async {
    final int? currentUserId = _authService.user?.id;
    if (currentUserId == null) return;

    Message newMessage;
    try {
      newMessage = Message.fromJson(payload, currentUserId);
    } catch (e) {
      debugPrint('ChatProvider: Erreur parsing _handleNewMessage: $e');
      return;
    }

    bool conversationListUpdated = false;
    int? tempMessageIdToReplace;
    bool activeMessagesUpdated = false;

    // --- 1. MISE À JOUR DE LA LISTE DES CONVERSATIONS (En mémoire) ---
    List<Conversation> newConversationList = List.from(_conversations);
    final convIndex =
        newConversationList.indexWhere((c) => c.orderId == newMessage.orderId);

    Conversation? updatedConv; // Pour la sauvegarde cache

    if (convIndex != -1) {
      // La conversation existe, on la met à jour
      final oldConv = newConversationList[convIndex];
      int newUnreadCount = oldConv.unreadCount;
      bool isArchived = oldConv.isArchived;

      if (newMessage.orderId != _activeOrderId && !newMessage.isSentByMe) {
        newUnreadCount++;
        isArchived = false; // Un nouveau message désarchive
      }

      updatedConv = oldConv.copyWith(
        lastMessage: newMessage.content,
        lastMessageTime: newMessage.createdAt,
        unreadCount: newUnreadCount,
        isArchived: isArchived,
      );

      newConversationList[convIndex] = updatedConv;
      conversationListUpdated = true;
      
    } else {
      // La conversation n'est pas dans la liste (peut-être pas encore chargée par la pagination)
      if (newMessage.orderId != _activeOrderId && !newMessage.isSentByMe) {
        // Ajouter une conversation "stub" (partielle)
        updatedConv = Conversation(
          orderId: newMessage.orderId,
          customerPhone: null, 
          shopName: 'Nouvelle Conversation', // Sera mis à jour
          deliverymanName: null, 
          deliverymanPhone: null, 
          isUrgent: false,
          isArchived: false, 
          lastMessage: newMessage.content,
          lastMessageTime: newMessage.createdAt,
          unreadCount: 1,
        );
        // On l'insère au lieu de l'ajouter, pour le tri
        newConversationList.insert(0, updatedConv);
        conversationListUpdated = true;
        // On ne recharge pas tout, le tri s'en chargera.
      }
    }

    // --- 2. MISE À JOUR DU CHAT ACTIF (Si on le regarde) ---
    if (newMessage.orderId == _activeOrderId) {
      bool listChanged = false;
      List<Message> updatedList = List.from(_activeMessages);

      if (newMessage.isSentByMe) {
        final tempMessageIndex = updatedList.indexWhere(
            (m) => m.id > 999999999 && m.content == newMessage.content);

        if (tempMessageIndex != -1) {
          tempMessageIdToReplace = updatedList[tempMessageIndex].id;
          updatedList[tempMessageIndex] = newMessage;
          listChanged = true;
        } else if (!updatedList.any((m) => m.id == newMessage.id)) {
          updatedList.add(newMessage);
          listChanged = true;
        }
      } else {
        if (!updatedList.any((m) => m.id == newMessage.id)) {
          updatedList.add(newMessage);
          listChanged = true;
        }
      }

      if (listChanged) {
        updatedList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _activeMessages = updatedList;
        activeMessagesUpdated = true;
      }

      if (!newMessage.isSentByMe) {
        _markAsRead(newMessage.orderId, newMessage.id);
        
        final currentConvIndex =
            newConversationList.indexWhere((c) => c.orderId == newMessage.orderId);
        if (currentConvIndex != -1) {
            updatedConv = newConversationList[currentConvIndex].copyWith(unreadCount: 0);
            newConversationList[currentConvIndex] = updatedConv;
            conversationListUpdated = true;
        }
      }
    }

    // --- 3. TRIER ET ASSIGNER LA NOUVELLE LISTE ---
    if (conversationListUpdated) {
        // Tri en temps réel
        newConversationList.sort((a, b) {
          if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
          final timeA =
              a.lastMessageTime ?? DateTime.fromMicrosecondsSinceEpoch(0);
          final timeB =
              b.lastMessageTime ?? DateTime.fromMicrosecondsSinceEpoch(0);
          return timeB.compareTo(timeA);
        });

      _conversations = newConversationList; // Assignation de la nouvelle liste
    }

    // --- 4. MISE EN CACHE (Toujours) ---
    if (tempMessageIdToReplace != null) {
      await _chatRepository.replaceTempMessage(tempMessageIdToReplace, newMessage);
    } else {
      await _chatRepository.cacheSingleMessage(newMessage);
    }
    
    if (updatedConv != null) {
      await _chatRepository.cacheConversations([updatedConv]);
    }

    // --- 5. NOTIFICATION ---
    if (activeMessagesUpdated || conversationListUpdated) {
      notifyListeners();
    }
  }

  /// Marque les messages comme lus via l'API (met aussi à jour le compteur global).
  Future<void> _markAsRead(int orderId, int lastMessageId) async {
    final convIndex = _conversations.indexWhere((c) => c.orderId == orderId);
    Conversation? updatedConv;

    if (convIndex != -1 && _conversations[convIndex].unreadCount != 0) {
      List<Conversation> newList = List.from(_conversations);
      updatedConv = newList[convIndex].copyWith(unreadCount: 0);
      newList[convIndex] = updatedConv;
      _conversations = newList;
      notifyListeners(); 
    }
    
    try {
      await _chatService.fetchMessages(orderId, triggerRead: lastMessageId);
      updateTotalUnreadCount(); 
      
      if (updatedConv != null) {
        await _chatRepository.cacheConversations([updatedConv]);
      }
    } catch (e) {
      debugPrint("ChatProvider: Échec du marquage comme lu pour $orderId: $e");
    }
  }

  // --- Gestion de la Liste des Conversations (Cache-First) ---
  
  // --- MODIFIÉ : Ajout de la pagination (loadMore) ---
  Future<void> loadConversations({bool forceApi = false, bool loadMore = false}) async {
    
    // Protection contre les appels multiples
    if (loadMore && _isLoadingMoreConversations) return;
    if (!loadMore) _isLoadingConversations = true;
    if (loadMore) _isLoadingMoreConversations = true;
    
    _conversationError = null;

    // Gère la pagination
    if (loadMore) {
      _conversationPage++;
    } else {
      _conversationPage = 1;
      _hasMoreConversations = true; // Réinitialise
    }

    // Notifie le début du chargement
    if ((_conversations.isEmpty && !loadMore) || loadMore) {
      notifyListeners();
    }

    List<Conversation> newConversations = [];
    try {
      // 1. Charger le cache D'ABORD (rapide)
      if (!forceApi) {
        newConversations = await _chatRepository.getCachedConversations(
          showArchived: _showArchived,
          showUrgentOnly: _showUrgentOnly,
          page: _conversationPage, // <-- NOUVEAU
          limit: _kConversationsPerPage, // <-- NOUVEAU
        );

        if (loadMore) {
          _conversations.addAll(newConversations); // Ajoute à la liste
        } else {
          _conversations = newConversations; // Remplace la liste
        }

        // Si on charge depuis le cache, on suppose qu'il y a plus de pages
        // (sauf si le cache est vide)
        _hasMoreConversations = newConversations.isNotEmpty; 
        
        if (!loadMore) _isLoadingConversations = false;
        if (loadMore) _isLoadingMoreConversations = false;

        // 2. Démarrer les listeners après le premier chargement du cache
        if (!_isInitialized) {
          _initializeListeners();
        }
        
        notifyListeners(); // Afficher le cache immédiatement
      }

    } catch (e) {
      debugPrint("ChatProvider: Erreur fatale chargement cache: $e");
      _conversationError = "Erreur base de données locale: $e";
      if (!loadMore) _isLoadingConversations = false;
      if (loadMore) _isLoadingMoreConversations = false;
      notifyListeners();
      return;
    }

    // 3. Si on force l'API (pull-to-refresh) ou si on chargeait plus
    if (forceApi || loadMore) {
      try {
        final apiConversations = await _chatService.fetchConversations(
          showArchived: _showArchived,
          showUrgentOnly: _showUrgentOnly,
          page: _conversationPage, // <-- NOUVEAU
          limit: _kConversationsPerPage, // <-- NOUVEAU
        );
        
        // Si c'est un refresh (page 1), on vide le cache d'abord
        if (forceApi && !loadMore) {
          await _chatRepository.clearConversationCache();
        }
        
        // On sauvegarde les nouvelles conversations dans le cache
        await _chatRepository.cacheConversations(apiConversations);
    
        if (loadMore) {
          _conversations.addAll(apiConversations); // Ajoute à la liste
        } else {
          _conversations = apiConversations; // Remplace la liste
        }
        
        // On a atteint la fin si l'API renvoie moins d'items que demandé
        _hasMoreConversations = apiConversations.length == _kConversationsPerPage;
        _conversationError = null; 
      
      } catch (e) {
        if (_conversations.isNotEmpty) {
          debugPrint("ChatProvider: Échec rafraîchissement API, utilisation du cache. Erreur: $e");
        } else {
          _conversationError = e.toString().replaceFirst('Exception: ', '');
        }
        _hasMoreConversations = false; // En cas d'erreur, on arrête de paginer
      } finally {
        if (!loadMore) _isLoadingConversations = false;
        if (loadMore) _isLoadingMoreConversations = false;
        notifyListeners();
      }
    }
  }
  // --- FIN MODIFICATION ---

  // --- NOUVELLE MÉTHODE : Pour l'UI ---
  Future<void> loadMoreConversations() async {
    await loadConversations(forceApi: true, loadMore: true);
  }
  // --- FIN NOUVELLE MÉTHODE ---

  Future<void> updateTotalUnreadCount() async {
    try {
      _totalUnreadCount = await _chatService.fetchTotalUnreadCount();
    } catch (e) {
      debugPrint("ChatProvider: Échec updateTotalUnreadCount: $e");
    }
    notifyListeners();
  }

  Future<void> loadQuickReplies() async {
    try {
      _quickReplies = await _chatService.fetchQuickReplies();
    } catch (e) {
      debugPrint("ChatProvider: Échec loadQuickReplies: $e");
    }
    notifyListeners();
  }

  // --- Gestion des Filtres (Modifié pour rafraîchir Page 1) ---
  void setConversationSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleArchivedFilter() {
    _showArchived = !_showArchived;
    if (_showArchived) _showUrgentOnly = false;
    loadConversations(forceApi: true); // Recharge Page 1 depuis l'API
  }

  void toggleUrgentFilter() {
    _showUrgentOnly = !_showUrgentOnly;
    if (_showUrgentOnly) _showArchived = false;
    loadConversations(forceApi: true); // Recharge Page 1 depuis l'API
  }

  // --- Gestion du Chat Actif (Inchangé) ---
  
  Future<void> selectConversation(int orderId) async {
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
    _hasMoreMessages = true; 
    _isLoadingMoreMessages = false;
    notifyListeners();
    
    _webSocketService.joinConversation(orderId);

    try {
      final cachedMessages =
          await _chatRepository.getCachedMessages(
            orderId, 
            currentUserId,
            limit: _kMessagesPerPage
          );
      
      _activeMessages = cachedMessages;
      _isLoadingMessages = false;
      notifyListeners(); 

      final apiMessagesData = await _chatService.fetchMessages(
        orderId, 
        limit: _kMessagesPerPage
      );

      if (apiMessagesData.isNotEmpty) {
        final newMessages = apiMessagesData
            .map((m) => Message.fromJson(m, currentUserId))
            .toList();

        await _chatRepository.cacheMessages(newMessages); 
        newMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _activeMessages = newMessages; 
        _hasMoreMessages = newMessages.length == _kMessagesPerPage;
      } else if (cachedMessages.isEmpty) {
        _hasMoreMessages = false; 
      }
      
      _messagesError = null; 

      if (_activeMessages.isNotEmpty) {
        if (_activeMessages.last.userId != currentUserId) {
          _markAsRead(orderId, _activeMessages.last.id);
        }
      }
    } catch (e) {
      debugPrint("ChatProvider selectConversation Erreur: $e");
      if (_activeMessages.isEmpty) {
        _messagesError = e.toString().replaceFirst('Exception: ', '');
      }
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

  Future<void> loadMoreMessages() async {
    if (_isLoadingMoreMessages || !_hasMoreMessages || _activeOrderId == null || _activeMessages.isEmpty) {
      return;
    }

    final int? currentUserId = _authService.user?.id;
    if (currentUserId == null) return;

    _isLoadingMoreMessages = true;
    notifyListeners();

    try {
      final String oldestMessageTimestamp = _activeMessages.first.createdAt.toIso8601String();

      final apiMessagesData = await _chatService.fetchMessages(
        _activeOrderId!,
        limit: _kMessagesPerPage,
        before: oldestMessageTimestamp 
      );

      if (apiMessagesData.isNotEmpty) {
        final newMessages = apiMessagesData
            .map((m) => Message.fromJson(m, currentUserId))
            .toList();
        
        await _chatRepository.cacheMessages(newMessages); 

        _activeMessages.insertAll(0, newMessages);
        _hasMoreMessages = newMessages.length == _kMessagesPerPage;
      } else {
        _hasMoreMessages = false; 
      }
    } catch (e) {
      _messagesError = "Erreur de chargement de l'historique: ${e.toString().replaceFirst('Exception: ', '')}";
    } finally {
      _isLoadingMoreMessages = false;
      notifyListeners();
    }
  }


  Future<void> sendMessage(String content) async {
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

    _activeMessages = List.from(_activeMessages)..add(tempMessage);
    notifyListeners();

    await _chatRepository.cacheSingleMessage(tempMessage);

    try {
      await _chatService.postMessage(_activeOrderId!, content.trim());
    } catch (e) {
      _messagesError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  // --- Actions Admin sur le Chat Actif (Inchangé) ---
  Future<void> reassignActiveOrder(Deliveryman deliveryman) async {
    if (_activeOrderId == null) return;
    try {
      await _chatService.reassignOrder(_activeOrderId!, deliveryman.id);
    } catch (e) {
      throw Exception(
          'Échec réassignation: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> resetActiveOrderStatus() async {
    if (_activeOrderId == null) return;
    try {
      await _chatService.resetOrderStatus(_activeOrderId!);
    } catch (e) {
      throw Exception(
          'Échec réinitialisation: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> toggleActiveOrderUrgency() async {
    if (_activeOrderId == null) return;
    final conv =
        _conversations.firstWhere((c) => c.orderId == _activeOrderId);
    try {
      await _chatService.toggleUrgency(_activeOrderId!, !conv.isUrgent);
      loadConversations(forceApi: true); // Recharger la liste
    } catch (e) {
      throw Exception(
          'Échec urgence: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }
  
  Future<void> toggleActiveOrderArchive() async {
    if (_activeOrderId == null) return;
    final conv =
        _conversations.firstWhere((c) => c.orderId == _activeOrderId);
    try {
      await _chatService.toggleArchive(_activeOrderId!, !conv.isArchived);
      if (!conv.isArchived) {
        deselectConversation();
      }
      loadConversations(forceApi: true); // Recharger la liste
    } catch (e) {
      throw Exception(
          'Échec archivage: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  @override
  void dispose() {
    _wsEventSubscription?.cancel();
    _wsMessageSubscription?.cancel();
    _isInitialized = false; 
    super.dispose();
  }
}

// --- Extension 'ConversationCopyWith' ---
extension ConversationCopyWith on Conversation {
  Conversation copyWith({
    String? customerPhone,
    String? shopName,
    String? deliverymanName,
    String? deliverymanPhone,
    bool? isUrgent,
    bool? isArchived,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return Conversation(
      orderId: orderId,
      customerPhone: customerPhone ?? this.customerPhone,
      shopName: shopName ?? this.shopName,
      deliverymanName: deliverymanName ?? this.deliverymanName,
      deliverymanPhone: deliverymanPhone ?? this.deliverymanPhone,
      isUrgent: isUrgent ?? this.isUrgent,
      isArchived: isArchived ?? this.isArchived,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}