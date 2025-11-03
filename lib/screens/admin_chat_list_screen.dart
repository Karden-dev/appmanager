// lib/screens/admin_chat_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/conversation.dart';
import 'package:wink_manager/providers/chat_provider.dart';
import 'package:wink_manager/screens/admin_chat_screen.dart'; // Écran de destination
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/network_status_icon.dart';

class AdminChatListScreen extends StatefulWidget {
  const AdminChatListScreen({super.key});

  @override
  State<AdminChatListScreen> createState() => _AdminChatListScreenState();
}

class _AdminChatListScreenState extends State<AdminChatListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Le ChatProvider est déjà initialisé dans main.dart et charge les conversations
    // Nous pouvons attacher un listener de recherche ici
    _searchController.addListener(() {
      if (mounted) {
        Provider.of<ChatProvider>(context, listen: false)
            .setConversationSearch(_searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Action de naviguer vers un chat spécifique
  void _navigateToChat(BuildContext context, int orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminChatScreen(orderId: orderId),
      ),
    ).then((_) {
      // Au retour, désélectionne la conversation
      Provider.of<ChatProvider>(context, listen: false).deselectConversation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivis (Chat)'),
        actions: const [
          NetworkStatusIcon(),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // --- Barre de Filtres et Recherche (inspirée de suivis.html) ---
              _buildFilterBar(context, provider),

              // --- Liste des Conversations ---
              Expanded(
                child: _buildConversationList(context, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Construit la barre de recherche et les filtres.
  Widget _buildFilterBar(BuildContext context, ChatProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barre de recherche
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Rechercher (ID, Client, Marchand...)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        // (le listener notifiera le provider)
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
          const SizedBox(height: 12),
          // Filtres (Urgentes / Archivées)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FilterChip(
                label: const Text('Urgentes'),
                selected: provider.showUrgentOnly,
                onSelected: (_) => provider.toggleUrgentFilter(),
                avatar: Icon(
                  provider.showUrgentOnly
                      ? Icons.flag
                      : Icons.flag_outlined,
                  color: AppTheme.danger,
                ),
                selectedColor: AppTheme.danger.withOpacity(0.2),
                showCheckmark: false,
              ),
              FilterChip(
                label: const Text('Archivées'),
                selected: provider.showArchived,
                onSelected: (_) => provider.toggleArchivedFilter(),
                avatar: Icon(
                  provider.showArchived
                      ? Icons.archive
                      : Icons.archive_outlined,
                ),
                selectedColor: AppTheme.secondaryColor.withOpacity(0.2),
                showCheckmark: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construit la liste des conversations.
  Widget _buildConversationList(BuildContext context, ChatProvider provider) {
    if (provider.isLoadingConversations && provider.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.conversationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            provider.conversationError!,
            style: const TextStyle(color: AppTheme.danger),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Applique le filtre de recherche local (le reste est filtré par l'API/Cache)
    final filteredList = provider.conversations.where((conv) {
      final query = _searchController.text.toLowerCase().trim();
      if (query.isEmpty) return true;
      return (conv.orderId.toString().contains(query) ||
          (conv.customerPhone?.toLowerCase().contains(query) ?? false) ||
          (conv.shopName?.toLowerCase().contains(query) ?? false) ||
          (conv.deliverymanName?.toLowerCase().contains(query) ?? false));
    }).toList();

    if (filteredList.isEmpty) {
      return const Center(
        child: Text(
          'Aucune conversation trouvée pour ces filtres.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Utilise RefreshIndicator pour le "Pull-to-Refresh"
    return RefreshIndicator(
      onRefresh: () => provider.loadConversations(forceApi: true),
      child: ListView.separated(
        itemCount: filteredList.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 80),
        itemBuilder: (context, index) {
          final conv = filteredList[index];
          return _buildConversationItem(context, conv, provider.activeOrderId);
        },
      ),
    );
  }

  /// Construit un widget pour un item de la liste (ConversationListItem).
  Widget _buildConversationItem(
      BuildContext context, Conversation conv, int? activeOrderId) {
    final bool hasUnread = conv.unreadCount > 0;
    final bool isActive = conv.orderId == activeOrderId;
    final bool isUrgent = conv.isUrgent;

    String timeAgo = 'N/A';
    if (conv.lastMessageTime != null) {
      final now = DateTime.now();
      final diff = now.difference(conv.lastMessageTime!);
      if (diff.inDays > 0) {
        timeAgo = DateFormat('dd/MM', 'fr_FR').format(conv.lastMessageTime!);
      } else {
        timeAgo = DateFormat('HH:mm', 'fr_FR').format(conv.lastMessageTime!);
      }
    }

    IconData indicatorIcon = Icons.chat_bubble_outline;
    Color indicatorColor = Colors.grey;
    if (isUrgent) {
      indicatorIcon = Icons.flag;
      indicatorColor = AppTheme.danger;
    } else if (hasUnread) {
      indicatorIcon = Icons.chat;
      indicatorColor = AppTheme.primaryColor;
    }

    return ListTile(
      tileColor: isActive ? AppTheme.primaryLight.withOpacity(0.5) : null,
      leading: CircleAvatar(
        backgroundColor: indicatorColor.withOpacity(0.1),
        child: Icon(indicatorIcon, color: indicatorColor, size: 24),
      ),
      title: Text(
        '#${conv.orderId} - ${conv.shopName ?? 'N/A'}',
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        'L: ${conv.deliverymanName ?? 'N/A'} | Msg: ${conv.lastMessage ?? '...'}',
        style: TextStyle(
          color: hasUnread ? AppTheme.primaryColor : Colors.grey.shade600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeAgo,
            style: TextStyle(
              fontSize: 12,
              color: hasUnread ? AppTheme.primaryColor : Colors.grey.shade600,
            ),
          ),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                conv.unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ]
        ],
      ),
      onTap: () => _navigateToChat(context, conv.orderId),
    );
  }
}