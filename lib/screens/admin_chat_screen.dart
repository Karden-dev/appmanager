// lib/screens/admin_chat_screen.dart

import 'dart:async'; 
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wink_manager/models/message.dart';
import 'package:wink_manager/models/conversation.dart';
import 'package:wink_manager/providers/chat_provider.dart';
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/screens/admin_order_edit_screen.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/network_status_icon.dart';
import 'package:wink_manager/widgets/order_action_dialogs.dart';
import 'package:wink_manager/widgets/chat_bubble.dart';

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

  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false)
          .selectConversation(widget.orderId);
      _scrollToBottom(jump: true); // Jump initial
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Déclenche le chargement de l'historique
  void _onScroll() {
    final provider = context.read<ChatProvider>();
    if (_scrollController.position.pixels ==
            _scrollController.position.minScrollExtent &&
        !provider.isLoadingMoreMessages &&
        provider.hasMoreMessages) {
      provider.loadMoreMessages();
    }
  }

  void _onTextChanged() {
    if (mounted) {
      final bool hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _isTyping) {
        setState(() {
          _isTyping = hasText;
        });
      }
    }
  }

  // Logique de scroll (inchangée)
  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      }
    });
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    context.read<ChatProvider>().sendMessage(content);

    _messageController.clear();
    FocusScope.of(context).unfocus();
  }

  void _addQuickReply(String reply) {
    _messageController.text =
        _messageController.text.isEmpty ? reply : '${_messageController.text} $reply';
    _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length));
  }

  // (Logique des snackbars et appels inchangée)
  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: message.contains('copié')
              ? Colors.green
              : AppTheme.danger,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }
  Future<void> _launchURL(Uri uri) async {
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Impossible d\'ouvrir $uri'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  void _callNumber(String? phoneNumber, String label) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showErrorSnackbar('Numéro de téléphone ($label) non disponible.');
      return;
    }
    final cleanedPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    _launchURL(Uri(scheme: 'tel', path: cleanedPhone));
  }
  void _copyToClipboard(String text, String label) {
    if (text.isEmpty) {
      _showErrorSnackbar('$label non disponible.');
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    _showErrorSnackbar('$label copié dans le presse-papiers.');
  }
  void _showCallOptions(BuildContext context, Conversation conversation) {
    final bool canCallDeliveryman = conversation.deliverymanPhone != null &&
        conversation.deliverymanPhone!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading:
                    Icon(Icons.person_outline, color: AppTheme.primaryColor),
                title: const Text('Appeler le Client'),
                subtitle:
                    Text(conversation.customerPhone ?? 'Numéro non disponible'),
                onTap: () {
                  Navigator.pop(ctx);
                  _callNumber(conversation.customerPhone, 'Client');
                },
              ),
              ListTile(
                leading: Icon(Icons.delivery_dining_outlined,
                    color: canCallDeliveryman
                        ? AppTheme.secondaryColor
                        : Colors.grey),
                title: const Text('Appeler le Livreur'),
                subtitle: Text(canCallDeliveryman
                    ? conversation.deliverymanPhone!
                    : 'Numéro non disponible'),
                enabled: canCallDeliveryman,
                onTap: () {
                  Navigator.pop(ctx);
                  _callNumber(conversation.deliverymanPhone, 'Livreur');
                },
              ),
            ],
          ),
        );
      },
    );
  }
  // (Fin de la logique des snackbars et appels)

  @override
  Widget build(BuildContext context) {
    final providerForActions = context.read<ChatProvider>();

    final appBar = PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Selector<ChatProvider, Conversation>(
        selector: (_, provider) => provider.conversations.firstWhere(
            (c) => c.orderId == widget.orderId,
            orElse: () => Conversation(
                orderId: widget.orderId,
                isUrgent: false,
                isArchived: false,
                unreadCount: 0)),
        builder: (context, conversation, _) {
          return AppBar(
            centerTitle: false,
            titleSpacing: 0.0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _copyToClipboard(
                      conversation.orderId.toString(), 'ID Commande'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- MODIFIÉ (Demande n°3) : "Cde " supprimé ---
                      Text('#${widget.orderId}',
                          style: const TextStyle(fontSize: 18)),
                      // --- FIN MODIFICATION ---
                      const SizedBox(width: 8),
                      Icon(Icons.copy_outlined,
                          size: 14, color: Colors.white.withAlpha(180)),
                    ],
                  ),
                ),
                Text(
                  '${conversation.shopName ?? '...'} | ${conversation.deliverymanName ?? '...'}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w400),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              const NetworkStatusIcon(),
              IconButton(
                icon: const Icon(Icons.call_outlined),
                tooltip: 'Appeler...',
                color: Colors.white,
                onPressed: () => _showCallOptions(context, conversation),
              ),
              IconButton(
                icon: const Icon(Icons.contact_phone_outlined),
                tooltip: 'Copier N° Client',
                iconSize: 22,
                onPressed: () => _copyToClipboard(
                    conversation.customerPhone ?? '', 'Numéro de téléphone'),
              ),
              _buildAdminActionsMenu(context, providerForActions, conversation),
            ],
          );
        },
      ),
    );

    final messagesList = Selector<
        ChatProvider,
        ({
          List<Message> messages,
          bool isLoading,
          String? error,
          bool isLoadingMore,
          bool hasMore
        })>(
      selector: (_, provider) => (
        messages: provider.activeMessages,
        isLoading: provider.isLoadingMessages,
        error: provider.messagesError,
        isLoadingMore: provider.isLoadingMoreMessages,
        hasMore: provider.hasMoreMessages,
      ),
      shouldRebuild: (previous, next) =>
          previous.isLoading != next.isLoading ||
          previous.error != next.error ||
          previous.isLoadingMore != next.isLoadingMore ||
          previous.hasMore != next.hasMore ||
          !listEquals(previous.messages, next.messages),
      builder: (context, data, _) {
        if (data.messages.isNotEmpty) {
          _scrollToBottom();
        }
        
        return _buildMessagesList(
          data.messages,
          data.isLoading,
          data.error,
          data.isLoadingMore,
          data.hasMore,
        );
      },
    );

    final quickReplyArea = Selector<ChatProvider, List<String>>(
      selector: (_, provider) => provider.quickReplies,
      builder: (context, quickReplies, _) {
        return _buildQuickReplyArea(quickReplies);
      },
    );

    return Scaffold(
      appBar: appBar,
      body: Column(
        children: [
          Expanded(
            child: messagesList,
          ),
          quickReplyArea,
          _buildInputArea(),
        ],
      ),
    );
  }

  // (Méthodes de menu et actions admin inchangées)
  Widget _buildAdminActionsMenu(
      BuildContext context, ChatProvider provider, Conversation conversation) {
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
            title: const Text('Marquer Urgent'),
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
  void _handleAdminAction(BuildContext context, ChatProvider provider,
      String action, Conversation conversation) async {
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
            navigator.pop();
          }
          break;
        case 'reassign':
          await showAssignDeliverymanDialog(context, widget.orderId);
          break;
        case 'edit_order':
          final orderDetails =
              await orderProvider.fetchOrderById(widget.orderId);

          if (mounted) {
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
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.danger),
      );
    }
  }
  // (Fin des méthodes de menu)


  // Gestion de la pagination dans la liste (inchangée)
  Widget _buildMessagesList(
    List<Message> messages,
    bool isLoading,
    String? error,
    bool isLoadingMore,
    bool hasMore,
  ) {
    if (isLoading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
          child:
              Text(error, style: const TextStyle(color: AppTheme.danger)));
    }
    if (messages.isEmpty && !isLoadingMore) {
      return const Center(
          child:
              Text('Aucun message.', style: TextStyle(color: Colors.grey)));
    }

    final itemCount = messages.length + (isLoadingMore || !hasMore ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      reverse: false, 
      itemCount: itemCount,
      cacheExtent: 9999,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        
        if (index == 0 && (isLoadingMore || !hasMore)) {
          if (isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (!hasMore && messages.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Chip(
                  // C'est ce chip que vous voyez
                  label: const Text('Début de la conversation'), 
                  backgroundColor: Colors.grey.shade200,
                  labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            );
          }
          return const SizedBox.shrink(); // Cas vide
        }

        final messageIndex = index - (isLoadingMore || !hasMore ? 1 : 0);
        final message = messages[messageIndex];

        // Logique d'animation (inchangée)
        return TweenAnimationBuilder<double>(
          key: ValueKey(message.id),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            final double xOffset = message.isSentByMe
                ? (1.0 - value) * 30.0
                : (1.0 - value) * -30.0;

            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(xOffset, 0),
                child: child,
              ),
            );
          },
          child: ChatBubble(
            message: message,
          ),
        );
      },
    );
  }

  Widget _buildQuickReplyArea(List<String> quickReplies) {
    if (quickReplies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      color: Theme.of(context).dividerColor.withAlpha(50),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: quickReplies
              .map((reply) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ActionChip(
                      label: Text(reply,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.secondaryColor)),
                      backgroundColor: Colors.white,
                      shape: StadiumBorder(
                          side: BorderSide(
                              color: Theme.of(context).dividerColor)),
                      onPressed: () => _addQuickReply(reply),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // --- MODIFIÉ (Demande n°4) : Zone de saisie améliorée ---
  Widget _buildInputArea() {
    return Container(
      color: Theme.of(context).dividerColor.withAlpha(50),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25.0),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25.0),
                      borderSide: BorderSide.none,
                    ),
                    // Bouton d'envoi intégré
                    suffixIcon: IconButton(
                      icon: Icon(Icons.send, 
                          color: _isTyping 
                                 ? AppTheme.primaryColor 
                                 : Colors.grey.shade400),
                      onPressed: _isTyping ? _sendMessage : null,
                    ),
                  ),
                ),
              ),
              // --- Le FloatingActionButton a été supprimé ---
            ],
          ),
        ),
      ),
    );
  }
  // --- FIN MODIFICATION ---
}