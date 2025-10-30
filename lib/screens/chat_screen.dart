// lib/screens/chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/database_helper.dart'; // <-- NOUVEL IMPORT

class ChatScreen extends StatefulWidget {
  final Order order;

  const ChatScreen({super.key, required this.order});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];
  List<String> _quickReplies = [];
  // Le flag de chargement initial change pour refléter la lecture locale + API
  bool _isLoadingMessages = true; 
  bool _isLoadingQuickReplies = true;
  String? _errorMessage;
  int? _currentUserId;

  WebSocketService? _webSocketService;
  StreamSubscription? _messageSubscription;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance; // <-- Instance du Helper DB

  @override
  void initState() {
    super.initState();
    _currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.id;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _webSocketService = Provider.of<WebSocketService?>(context, listen: false);
      if (_webSocketService == null || _currentUserId == null) {
        if(mounted){
          setState(() {
            _isLoadingMessages = false;
            _errorMessage = "Service de communication indisponible.";
          });
        }
        return;
      }
      
      // Définit le chat actif
      _webSocketService!.activeChatOrderId = widget.order.id;

      _webSocketService!.joinConversation(widget.order.id);
      // **MODIFIÉ: Charge les messages d'abord depuis le cache, puis synchronise**
      _loadInitialMessagesAndSync();
      _loadQuickReplies();
      _messageSubscription = _webSocketService!.messagesStream.listen(_handleNewMessage);
    });
  }

  // **MODIFIÉ: Nouvelle méthode pour charger du cache et synchroniser**
  Future<void> _loadInitialMessagesAndSync() async {
    if (_currentUserId == null) return;

    // 1. Chargement Instantané depuis la base locale
    final localMessages = await _dbHelper.getMessages(widget.order.id, _currentUserId!);
    if (mounted) {
      setState(() {
        _messages = localMessages;
        _isLoadingMessages = localMessages.isEmpty; // Garde le spinner si le cache est vide
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    
    // 2. Détermination du point de synchronisation (Dernier message local)
    final latestTimestamp = await _dbHelper.getLatestMessageTimestamp(widget.order.id);

    // 3. Synchronisation avec l'API (Charge UNIQUEMENT les messages après ce timestamp)
    //    Si latestTimestamp est null, l'API renverra tout l'historique (ou selon sa propre pagination)
    await _syncMessagesFromApi(latestTimestamp);
  }


  Future<void> _syncMessagesFromApi(String? sinceTimestamp) async {
    if (_webSocketService == null || _currentUserId == null) return;

    // Si on a affiché le cache, le spinner disparaît. On peut l'afficher discrètement si besoin.
    if (mounted && _messages.isEmpty) { // Si le cache était vide
        setState(() { _isLoadingMessages = true; _errorMessage = null; });
    }

    try {
      // L'API est appelée avec le paramètre 'since' (s'il existe)
      final messagesData = await _webSocketService!.fetchMessages(widget.order.id, since: sinceTimestamp);
      
      if (messagesData.isNotEmpty) {
        // Convertit les données API en objets Message
        final newMessages = messagesData.map((m) => Message.fromJson(m, _currentUserId!)).toList();
        
        // 4. Sauvegarde en DB et mise à jour de l'UI
        await _dbHelper.insertMessages(newMessages);

        if (mounted) {
          setState(() {
             // Fusionne les messages locaux avec les nouveaux (en filtrant les doublons si l'API a renvoyé des messages déjà en cache)
             final newMessagesToAdd = newMessages.where((msg) => !_messages.any((m) => m.id == msg.id)).toList();
             if (newMessagesToAdd.isNotEmpty) {
                _messages.addAll(newMessagesToAdd);
                _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Re-trie
             }
             
             // Marque comme lu le plus récent message synchronisé
             _markAsReadIfNeeded(newMessages.last.id);
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
        // Si le cache était non vide, l'erreur API n'est pas bloquante.
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMessages = false; // Le chargement est terminé
        });
      }
    }
  }


  void _handleNewMessage(Map<String, dynamic> messageData) {
    if (messageData['type'] == 'NEW_MESSAGE' && messageData['payload'] != null) {
      final payload = messageData['payload'] as Map<String, dynamic>;
      if (payload['order_id'] == widget.order.id && _currentUserId != null) {
        final newMessage = Message.fromJson(payload, _currentUserId!);
        
        // 5. Sauvegarde du nouveau message WS en DB
        _dbHelper.insertMessage(newMessage); // N'attend pas le Future
        
        if (!_messages.any((m) => m.id == newMessage.id)) {
           if (mounted) {
             setState(() {
               _messages.add(newMessage);
               _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
             });
              // 6. Marque le message comme lu (l'API le fera, on n'a plus besoin de le faire deux fois)
              _markAsReadIfNeeded(newMessage.id);
             WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
           }
        }
      }
    } else if (messageData['type'] == 'ERROR') {
       _showErrorSnackbar(messageData['message'] as String? ?? 'Erreur WebSocket');
    }
  }

  // **MODIFIÉ: Le marquage comme lu se fait toujours via l'API, car il gère
  // la table message_read_status côté serveur et met à jour le compteur global.**
  Future<void> _markAsReadIfNeeded(int lastMessageId) async {
    if (mounted && _webSocketService != null && _currentUserId != null) {
      try {
        // Appelle l'API GET qui marque comme lu et met à jour le compteur global
        await _webSocketService!.fetchMessages(widget.order.id, lastMessageId: lastMessageId);
      } catch (e) {
        debugPrint("Erreur lors du marquage comme lu: $e");
      }
    }
  }


  Future<void> _loadQuickReplies() async {
    if (_webSocketService == null) return;
    if (mounted) {
      setState(() { _isLoadingQuickReplies = true; });
    }
    // TODO: Implémenter le cache SharedPrefs ici plus tard (Step 5)
    try {
      final replies = await _webSocketService!.fetchQuickReplies();
      if (mounted) {
        setState(() {
          _quickReplies = replies;
          _isLoadingQuickReplies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoadingQuickReplies = false; });
        _showErrorSnackbar('Erreur chargement réponses rapides.');
      }
    }
  }

  @override
  void dispose() {
    _webSocketService?.leaveConversation(widget.order.id);

    if (_webSocketService != null && _webSocketService!.activeChatOrderId == widget.order.id) {
      _webSocketService!.activeChatOrderId = null;
    }

    _messageSubscription?.cancel();
    
    _scrollController.dispose();
    _messageController.dispose();
    
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
       Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
             _scrollController.animateTo(
               _scrollController.position.maxScrollExtent,
               duration: const Duration(milliseconds: 300),
               curve: Curves.easeOut,
             );
          }
       });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _webSocketService == null) return;

    _messageController.clear();

    // 7. Mise à jour Optimiste locale ET sauvegarde DB (pour le offline si l'API échoue)
    final tempId = -DateTime.now().millisecondsSinceEpoch; // ID temporaire négatif
    final optimisticMessage = Message(
      id: tempId,
      orderId: widget.order.id,
      userId: _currentUserId!,
      userName: Provider.of<AuthService>(context, listen: false).currentUser?.name ?? 'Moi',
      content: text,
      messageType: 'user',
      createdAt: DateTime.now(),
      isSentByMe: true,
    );

    // 7a. Mise à jour Optimiste UI
    if (mounted) {
      setState(() {
        _messages.add(optimisticMessage);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    try {
      // 7b. Envoi API (le WS renverra la version finale si succès)
      await _webSocketService!.sendMessage(widget.order.id, text);
      
      // 7c. Si succès, on efface le message optimiste (le WS le remplacera)
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == tempId);
        });
      }
      
    } catch (e) {
      // 7d. Si échec, on met à jour l'UI (le message pessimiste reste, mais on l'indique)
      _showErrorSnackbar('Échec d\'envoi: ${e.toString().replaceFirst("Exception: ","")}');
      if (mounted) {
         setState(() {
            // Optionnel: marquer le message comme échoué (via une propriété si le modèle le permet)
            // Pour l'instant, on laisse le message non-supprimé et on compte sur le snackbar
         });
      }
    }
  }

  void _addQuickReply(String reply) {
    _messageController.text = _messageController.text.isEmpty ? reply : '${_messageController.text} $reply';
    _messageController.selection = TextSelection.fromPosition(TextPosition(offset: _messageController.text.length));
  }

  void _requestModification() {
    const prefix = "Demande de modification : ";
    const detailedMessage = "$prefix Veuillez préciser ici l'erreur (client, adresse, articles, montant...).";

    _messageController.text = detailedMessage;
    _messageController.selection = TextSelection.fromPosition(const TextPosition(offset: prefix.length));

    _showInfoSnackbar('Précisez la modification et envoyez.');
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
      );
    }
  }

  void _showInfoSnackbar(String message) {
     if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Précisez la modification et envoyez.'), duration: Duration(seconds: 3)),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat - CDE #${widget.order.id}'),
        actions: [
          TextButton.icon(
            onPressed: _requestModification,
            icon: const Icon(Icons.edit_note, color: Colors.white),
            label: const Text('Demander Modif.', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.danger)))
                    : _messages.isEmpty
                        ? const Center(child: Text('Aucun message dans cette conversation.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              return _buildMessageBubble(context, message);
                            },
                          ),
          ),
          _buildQuickReplyArea(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Message message) {
    final isSent = message.isSentByMe;
    final isSystem = message.messageType == 'system';

    if (isSystem) {
      return Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message.content,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: AppTheme.accentColor.withAlpha(200),
          ),
        ),
      );
    }

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isSent ? AppTheme.primaryColor.withAlpha(230) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(isSent ? 15 : 5),
            bottomRight: Radius.circular(isSent ? 5 : 15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isSent)
              Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  message.userName,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            Text(
              message.content,
              style: TextStyle(
                color: isSent ? Colors.white : AppTheme.secondaryColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                DateFormat('HH:mm').format(message.createdAt.toLocal()),
                style: TextStyle(
                  fontSize: 10,
                  color: isSent ? Colors.white.withAlpha(178) : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReplyArea() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      color: Theme.of(context).dividerColor.withAlpha(50),
      child: _isLoadingQuickReplies
          ? const SizedBox(height: 36, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
          : _quickReplies.isEmpty
              ? const SizedBox(height: 36, child: Center(child: Text('...', style: TextStyle(color: Colors.grey))))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickReplies.map((reply) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ActionChip(
                        label: Text(reply, style: const TextStyle(fontSize: 12, color: AppTheme.secondaryColor)),
                        backgroundColor: Colors.white,
                        shape: StadiumBorder(side: BorderSide(color: Theme.of(context).dividerColor)),
                        onPressed: () => _addQuickReply(reply),
                      ),
                    )).toList(),
                  ),
                ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Theme.of(context).dividerColor.withAlpha(50),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Écrire un message...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                 focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _sendMessage,
            mini: true,
            backgroundColor: AppTheme.primaryColor,
            elevation: 0,
            child: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}