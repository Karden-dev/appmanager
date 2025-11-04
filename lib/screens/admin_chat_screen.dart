// lib/screens/admin_chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/admin_order.dart';
import 'package:wink_manager/models/deliveryman.dart';
import 'package:wink_manager/models/message.dart'; // <-- CORRECTION: 'package.wmf' -> 'package:wink_manager'
import 'package:wink_manager/models/conversation.dart'; // <-- AJOUTÉ: Import manquant
import 'package:wink_manager/providers/chat_provider.dart';
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/screens/admin_order_edit_screen.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/network_status_icon.dart';
import 'package:wink_manager/widgets/order_action_dialogs.dart'; // Pour showAssignDeliverymanDialog

/// Écran principal pour une conversation de chat (Suivi Admin)
class AdminChatScreen extends StatefulWidget {
  final int orderId;

  const AdminChatScreen({super.key, required this.orderId});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Sélectionne la conversation et charge les messages
      Provider.of<ChatProvider>(context, listen: false)
          .selectConversation(widget.orderId);
      _scrollToBottom(jump: true); // Saut initial
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // La désélection se fait dans admin_chat_list_screen.dart via Navigator.pop()
    super.dispose();
  }

  void _scrollToBottom({bool jump = false}) {
    // S'assure que le widget est construit et que le contrôleur est attaché
    if (_scrollController.hasClients) {
      final position = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(position);
      } else {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else {
      // Réessayer si le contrôleur n'est pas encore prêt
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  Future<void> _sendMessage(ChatProvider provider) async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    FocusScope.of(context).unfocus();

    try {
      await provider.sendMessage(content);
      // Le message s'ajoutera via le listener optimiste ou WebSocket
      _scrollToBottom();
    } catch (e) {
      _showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _addQuickReply(String reply) {
    _messageController.text =
        _messageController.text.isEmpty ? reply : '${_messageController.text} $reply';
    _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length));
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Écoute ChatProvider pour les mises à jour de la liste de messages
    final provider = context.watch<ChatProvider>();

    // Trouve la conversation (pour le header)
    final conversation = provider.conversations
        .firstWhere((c) => c.orderId == widget.orderId, orElse: () => Conversation( // <-- CORRIGÉ: Constructeur maintenant reconnu
            orderId: widget.orderId,
            isUrgent: false,
            isArchived: false,
            unreadCount: 0));

    // Met à jour le scroll à chaque build si de nouveaux messages arrivent
    if (provider.activeMessages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cde #${widget.orderId}', style: const TextStyle(fontSize: 18)),
            Text(
              '${conversation.shopName ?? '...'} | ${conversation.deliverymanName ?? '...'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          const NetworkStatusIcon(),
          // Menu d'actions admin (inspiré de suivis.html)
          _buildAdminActionsMenu(context, provider, conversation),
        ],
      ),
      body: Column(
        children: [
          // Corps du Chat (Messages)
          Expanded(
            child: _buildMessagesList(provider),
          ),
          // Réponses Rapides
          _buildQuickReplyArea(provider),
          // Champ de Saisie
          _buildInputArea(provider),
        ],
      ),
    );
  }

  /// Menu d'actions (3 points) dans l'AppBar
  Widget _buildAdminActionsMenu(BuildContext context, ChatProvider provider, Conversation conversation) { // <-- CORRIGÉ: 'Conversation' reconnu
    return PopupMenuButton<String>(
      onSelected: (value) =>
          _handleAdminAction(context, provider, value, conversation),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'toggle_urgent',
          child: ListTile(
            leading: Icon(
              conversation.isUrgent ? Icons.flag : Icons.flag_outlined,
              color: AppTheme.danger,
            ),
            title: Text(
                conversation.isUrgent ? 'Démarquer Urgent' : 'Marquer Urgent'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'reassign',
          child: ListTile(
            leading: Icon(Icons.delivery_dining_outlined),
            title: Text('Réassigner'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'edit_order',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Modifier Commande'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'reset_status',
          child: ListTile(
            leading: Icon(Icons.replay_outlined),
            title: Text('Réinitialiser Statut'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'toggle_archive',
          child: ListTile(
            leading: Icon(conversation.isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined),
            title: Text(conversation.isArchived ? 'Désarchiver' : 'Archiver'),
          ),
        ),
      ],
    );
  }

  /// Logique de gestion des actions admin
  void _handleAdminAction(BuildContext context, ChatProvider provider,
      String action, Conversation conversation) async { // <-- CORRIGÉ: 'Conversation' reconnu
    
    // CORRECTION (Lint): Capture des contextes avant l'await
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      switch (action) {
        case 'toggle_urgent':
          await provider.toggleActiveOrderUrgency();
          break;
        case 'toggle_archive':
          await provider.toggleActiveOrderArchive();
          if (mounted && !conversation.isArchived) {
            // Si on archive, on ferme l'écran
            navigator.pop();
          }
          break;
        case 'reassign':
          // Réutilise le dialogue d'assignation existant
          await showAssignDeliverymanDialog(context, widget.orderId);
          // Le provider (Chat/WS) mettra à jour la liste/header
          break;
        case 'edit_order':
          // Charge les détails complets de la commande
          final orderDetails =
              await orderProvider.fetchOrderById(widget.orderId);
              
          // CORRECTION (Lint): Vérifie 'mounted' avant d'utiliser le context/navigator
          if (mounted) {
            // Navigue vers l'écran d'édition existant
            navigator.push(
              MaterialPageRoute(
                builder: (_) => AdminOrderEditScreen(order: orderDetails),
              ),
            );
          }
          break;
        case 'reset_status':
          await provider.resetActiveOrderStatus();
          break;
      }
    } catch (e) {
      // CORRECTION (Lint): Utilise la variable 'scaffoldMessenger'
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.danger),
      );
    }
  }

  /// Affiche la liste des messages
  Widget _buildMessagesList(ChatProvider provider) {
    if (provider.isLoadingMessages && provider.activeMessages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.messagesError != null) {
      return Center(
          child: Text(provider.messagesError!,
              style: const TextStyle(color: AppTheme.danger)));
    }
    if (provider.activeMessages.isEmpty) {
      return const Center(
          child: Text('Aucun message.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      itemCount: provider.activeMessages.length,
      itemBuilder: (context, index) {
        final message = provider.activeMessages[index];
        // Appel au widget ChatBubble (à créer)
        return ChatBubble(message: message);
      },
    );
  }

  /// Affiche la barre de réponses rapides
  Widget _buildQuickReplyArea(ChatProvider provider) {
    if (provider.quickReplies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      color: Theme.of(context).dividerColor.withAlpha(50),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: provider.quickReplies
              .map((reply) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ActionChip(
                      label: Text(reply,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.secondaryColor)),
                      backgroundColor: Colors.white,
                      shape: StadiumBorder(
                          side: BorderSide(color: Theme.of(context).dividerColor)),
                      onPressed: () => _addQuickReply(reply),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  /// Affiche la barre de saisie de texte
  Widget _buildInputArea(ChatProvider provider) {
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            onPressed: () => _sendMessage(provider),
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

/// Widget dédié à l'affichage d'une bulle de chat
/// (Ce widget sera créé dans son propre fichier juste après)
class ChatBubble extends StatelessWidget {
  final Message message; // <-- CORRIGÉ: 'Message' maintenant reconnu
  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
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
            // CORRECTION (Lint): Remplace 'withAlpha(200)'
            color: AppTheme.accentColor.withOpacity(200 / 255), 
          ),
        ),
      );
    }

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isSent ? AppTheme.primaryLight : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(isSent ? 15 : 5),
            bottomRight: Radius.circular(isSent ? 5 : 15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                color: isSent ? AppTheme.secondaryColor : AppTheme.text,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                DateFormat('HH:mm').format(message.createdAt.toLocal()),
                style: TextStyle(
                  fontSize: 10,
                  color:
                      isSent ? Colors.grey.shade700 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}