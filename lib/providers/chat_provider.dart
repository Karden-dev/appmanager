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
      // Au démarrage, on charge le cache (rapide)
      loadConversations(forceApi: false);
      // PUIS on demande une mise à jour API en arrière-plan
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
          break;
      }
    });

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
  /// Met à jour la liste des conversations ET le chat actif.
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

    // --- 1. MISE À JOUR DE LA LISTE DES CONVERSATIONS (admin_chat_list_screen.dart) ---
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

      // Tri pour remonter la conversation en haut
      newConversationList.sort((a, b) {
        if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
        final timeA =
            a.lastMessageTime ?? DateTime.fromMicrosecondsSinceEpoch(0);
        final timeB =
            b.lastMessageTime ?? DateTime.fromMicrosecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });

      _conversations = newConversationList;
      conversationListUpdated = true;
    } else {
      // La conversation n'est pas dans la liste
      if (newMessage.orderId != _activeOrderId && !newMessage.isSentByMe) {
         loadConversations(forceApi: true);
      }
    }

    // --- 2. MISE À JOUR DU CHAT ACTIF (admin_chat_screen.dart) ---
    if (newMessage.orderId == _activeOrderId) {
      bool listChanged = false;
      List<Message> updatedList = List.from(_activeMessages);

      if (newMessage.isSentByMe) {
        // Confirmation du serveur pour un message qu'on vient d'envoyer
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
        // Message reçu d'un autre
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
        // Marquer comme lu en arrière-plan
        _markAsRead(newMessage.orderId, newMessage.id);
        
        // Mettre à jour le compteur dans la liste des conversations
        if (convIndex != -1 && _conversations[convIndex].unreadCount > 0) {
           updatedConv = _conversations[convIndex].copyWith(unreadCount: 0);
           _conversations[convIndex] = updatedConv;
           conversationListUpdated = true;
        }
      }
    }

    // --- 3. MISE EN CACHE (Toujours) ---
    if (tempMessageIdToReplace != null) {
      // (Maintenant 'await' est sûr car la fonction existe)
      await _chatRepository.replaceTempMessage(tempMessageIdToReplace, newMessage);
    } else {
      await _chatRepository.cacheSingleMessage(newMessage);
    }
    
    if (updatedConv != null) {
      await _chatRepository.cacheConversations([updatedConv]);
    }


    // --- 4. NOTIFICATION ---
    if (activeMessagesUpdated || conversationListUpdated) {
      notifyListeners();
    }
  }

  /// Marque les messages comme lus via l'API (met aussi à jour le compteur global).
  Future<void> _markAsRead(int orderId, int lastMessageId) async {
    try {
      await _chatService.fetchMessages(orderId, lastMessageId: lastMessageId);
      updateTotalUnreadCount();

      final convIndex =
          _conversations.indexWhere((c) => c.orderId == orderId);
      if (convIndex != -1 && _conversations[convIndex].unreadCount != 0) {
        List<Conversation> newList = List.from(_conversations);
        final updatedConv = newList[convIndex].copyWith(unreadCount: 0);
        newList[convIndex] = updatedConv;
        _conversations = newList;
        notifyListeners();
        // Mettre à jour le cache DB en arrière-plan
        await _chatRepository.cacheConversations([updatedConv]);
      }
    } catch (e) {
      debugPrint("ChatProvider: Échec du marquage comme lu pour $orderId: $e");
    }
  }

  // --- Gestion de la Liste des Conversations (Cache-First) ---
  
  /// **LOGIQUE CACHE-FIRST AMÉLIORÉE**
  Future<void> loadConversations({bool forceApi = false}) async {
    _isLoadingConversations = true;
    _conversationError = null;

    if (_conversations.isEmpty) {
      notifyListeners();
    }

    List<Conversation> cachedConversations = [];
    try {
      // 2. Charger le cache D'ABORD (rapide)
      cachedConversations = await _chatRepository.getCachedConversations(
        showArchived: _showArchived,
        showUrgentOnly: _showUrgentOnly,
      );

      cachedConversations.sort((a, b) {
            if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
            final timeA = a.lastMessageTime ?? DateTime.fromMicrosecondsSinceEpoch(0);
            final timeB = b.lastMessageTime ?? DateTime.fromMicrosecondsSinceEpoch(0);
            return timeB.compareTo(timeA); 
      });

      _conversations = cachedConversations;
      if (!forceApi) {
        _isLoadingConversations = false;
      }
      notifyListeners(); // Afficher le cache immédiatement

    } catch (e) {
      debugPrint("ChatProvider: Erreur fatale chargement cache: $e");
      _conversationError = "Erreur base de données locale: $e";
      _isLoadingConversations = false;
      notifyListeners();
      return;
    }

    // 3. Si on force l'API (pull-to-refresh) ou si le cache était vide
    if (forceApi || cachedConversations.isEmpty) {
      try {
        final apiConversations = await _chatService.fetchConversations(
          showArchived: _showArchived,
          showUrgentOnly: _showUrgentOnly,
        );

        await _chatRepository.clearConversationCache();
        await _chatRepository.cacheConversations(apiConversations);

        apiConversations.sort((a, b) {
            if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
            final timeA = a.lastMessageTime ?? DateTime.fromMicrosecondsSinceEpoch(0);
            final timeB = b.lastMessageTime ?? DateTime.fromMicrosecondsSinceEpoch(0);
            return timeB.compareTo(timeA); 
        });

        _conversations = apiConversations;
        _conversationError = null; // Succès, on efface l'erreur
      
      } catch (e) {
        // **CORRECTION ERREUR RÉSEAU**
        if (_conversations.isNotEmpty) {
          debugPrint("ChatProvider: Échec rafraîchissement API, utilisation du cache. Erreur: $e");
        } else {
          _conversationError = e.toString().replaceFirst('Exception: ', '');
        }
      } finally {
        _isLoadingConversations = false;
        notifyListeners();
      }
    }
  }


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

  // --- Gestion des Filtres (Corrigé pour être rapide) ---
  void setConversationSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// **CORRECTION FILTRES LENTS**
  void toggleArchivedFilter() {
    _showArchived = !_showArchived;
    if (_showArchived) _showUrgentOnly = false;
    loadConversations(forceApi: false); // Recharge depuis le cache
  }

  /// **CORRECTION FILTRES LENTS**
  void toggleUrgentFilter() {
    _showUrgentOnly = !_showUrgentOnly;
    if (_showUrgentOnly) _showArchived = false;
    loadConversations(forceApi: false); // Recharge depuis le cache
  }

  // --- Gestion du Chat Actif ---
  
  /// **LOGIQUE CACHE-FIRST AMÉLIORÉE POUR LES MESSAGES**
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
    notifyListeners();
    
    _webSocketService.joinConversation(orderId);

    try {
      // 1. Charger le cache local d'abord
      final cachedMessages =
          await _chatRepository.getCachedMessages(orderId, currentUserId);
      _activeMessages = cachedMessages;
      _isLoadingMessages = false;
      notifyListeners(); // Affiche le cache

      // 2. Tenter de rafraîchir depuis l'API
      final apiMessagesData = await _chatService.fetchMessages(orderId);

      if (apiMessagesData.isNotEmpty) {
        final newMessages = apiMessagesData
            .map((m) => Message.fromJson(m, currentUserId))
            .toList();

        await _chatRepository.cacheMessages(newMessages); // Met à jour le cache
        newMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _activeMessages = newMessages; // Met à jour l'UI avec les données fraîches
      }
      
      _messagesError = null; // Succès, on efface une potentielle erreur

      // 3. Marquer comme lu (si nécessaire)
      if (_activeMessages.isNotEmpty) {
        if (_activeMessages.last.userId != currentUserId) {
          // Lancer en arrière-plan, ne pas bloquer l'UI
          _markAsRead(orderId, _activeMessages.last.id);
        }
      }
    } catch (e) {
      // Si TOUT échoue (cache ET/OU réseau)
      debugPrint("ChatProvider selectConversation Erreur: $e");
      // N'afficher l'erreur QUE si le cache est vide
      if (_activeMessages.isEmpty) {
        _messagesError = e.toString().replaceFirst('Exception: ', '');
      }
      // Si _activeMessages n'est pas vide, on affiche le cache (même s'il est vieux)
      // et on n'affiche PAS l'erreur réseau.
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

  /// Envoie un message dans le chat actif (logique optimiste).
  Future<void> sendMessage(String content) async {
    if (_activeOrderId == null || content.trim().isEmpty) return;
    if (_authService.user == null) return;

    final user = _authService.user!;

    // 1. Créer un message temporaire (ID > 999...)
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

    // 2. Afficher le message temporaire IMMÉDIATEMENT
    _activeMessages = List.from(_activeMessages)..add(tempMessage);
    notifyListeners();

    // 3. Sauvegarder le message temporaire en cache
    await _chatRepository.cacheSingleMessage(tempMessage);

    // 4. Envoyer à l'API (sans await)
    try {
      await _chatService.postMessage(_activeOrderId!, content.trim());
      // Le WebSocket (`_handleNewMessage`) s'occupera de remplacer le message
      // temporaire par le message réel du serveur.
    } catch (e) {
      _messagesError = e.toString().replaceFirst('Exception: ', '');
      // On pourrait marquer le message temporaire comme "échec" ici
      notifyListeners();
    }
  }

  // --- Actions Admin sur le Chat Actif ---
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
    } catch (e) {
      throw Exception(
          'Échec archivage: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  @override
  void dispose() {
    _wsEventSubscription?.cancel();
    _wsMessageSubscription?.cancel();
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