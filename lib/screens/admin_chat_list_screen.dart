// lib/screens/admin_chat_list_screen.dart

import 'package:flutter/foundation.dart'; // Pour listEquals
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
    _searchController.addListener(() {
      if (mounted) {
        Provider.of<ChatProvider>(context, listen: false)
            .setConversationSearch(_searchController.text);
      }
    });

    // --- CORRECTION HORS-LIGNE (Comportement WhatsApp) ---
    // On s'assure de charger le cache local (base de données)
    // dès que l'écran est initialisé.
    // C'est rapide et fonctionne hors ligne. Le WebSocket
    // (géré par le provider) s'occupera de l'instantanéité.
    Provider.of<ChatProvider>(context, listen: false)
        .loadConversations(forceApi: false);
    // --- FIN CORRECTION ---
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Action de naviguer vers un chat spécifique
  void _navigateToChat(BuildContext context, int orderId) {
    // --- CORRECTION (use_build_context_synchronously) ---
    // On capture le provider AVANT l'appel asynchrone (Navigator.push)
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminChatScreen(orderId: orderId),
      ),
    ).then((_) {
      // On utilise le provider capturé, sans faire référence à 'context'
      chatProvider.deselectConversation();
    });
    // --- FIN CORRECTION ---
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
      body: Column( 
        children: [
          Selector<ChatProvider, ({bool urgent, bool archived})>(
            selector: (_, provider) => (
              urgent: provider.showUrgentOnly,
              archived: provider.showArchived
            ),
            builder: (context, filters, _) {
              final provider = context.read<ChatProvider>();
              return _buildFilterBar(
                  context, provider, filters.urgent, filters.archived);
            },
          ),
          Expanded(
            child: Selector<ChatProvider,
                ({
                  List<Conversation> convos,
                  bool isLoading,
                  String? error,
                  String searchQuery,
                  int? activeOrderId
                })>(
              selector: (_, provider) => (
                convos: provider.conversations,
                isLoading: provider.isLoadingConversations,
                error: provider.conversationError,
                searchQuery: provider.searchQuery, 
                activeOrderId: provider.activeOrderId
              ),
              shouldRebuild: (prev, next) =>
                  prev.isLoading != next.isLoading ||
                  prev.error != next.error ||
                  prev.searchQuery != next.searchQuery || 
                  prev.activeOrderId != next.activeOrderId || 
                  !listEquals(prev.convos, next.convos),
              builder: (context, data, _) {
                final provider = context.read<ChatProvider>();
                return _buildConversationList(
                    context,
                    provider,
                    data.convos,
                    data.isLoading,
                    data.error,
                    data.searchQuery,
                    data.activeOrderId);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Construit la barre de recherche et les filtres.
  Widget _buildFilterBar(BuildContext context, ChatProvider provider,
      bool showUrgentOnly, bool showArchived) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            // --- CORRECTION (deprecated_member_use) ---
            color: Colors.black.withAlpha((255 * 0.05).round()), // 13
            // --- FIN CORRECTION ---
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
                selected: showUrgentOnly, 
                onSelected: (_) => provider.toggleUrgentFilter(), 
                avatar: Icon(
                  showUrgentOnly
                      ? Icons.flag
                      : Icons.flag_outlined,
                  color: AppTheme.danger,
                ),
                // --- CORRECTION (deprecated_member_use) ---
                selectedColor: AppTheme.danger.withAlpha((255 * 0.2).round()), // 51
                // --- FIN CORRECTION ---
                showCheckmark: false,
              ),
              FilterChip(
                label: const Text('Archivées'),
                selected: showArchived, 
                onSelected: (_) => provider.toggleArchivedFilter(), 
                avatar: Icon(
                  showArchived
                      ? Icons.archive
                      : Icons.archive_outlined,
                ),
                // --- CORRECTION (deprecated_member_use) ---
                selectedColor: AppTheme.secondaryColor.withAlpha((255 * 0.2).round()), // 51
                // --- FIN CORRECTION ---
                showCheckmark: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construit la liste des conversations.
  Widget _buildConversationList(
    BuildContext context,
    ChatProvider provider, 
    List<Conversation> conversations,
    bool isLoading,
    String? error,
    String searchQuery,
    int? activeOrderId,
  ) {
    if (isLoading && conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            error,
            style: const TextStyle(color: AppTheme.danger),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final filteredList = conversations.where((conv) {
      final query = searchQuery.toLowerCase().trim(); 
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

    return RefreshIndicator(
      onRefresh: () => provider.loadConversations(forceApi: true),
      child: ListView.separated(
        itemCount: filteredList.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 80),
        
        cacheExtent: MediaQuery.of(context).size.height * 1.5,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,

        itemBuilder: (context, index) {
          final conv = filteredList[index];
          return _buildConversationItem(context, conv, activeOrderId);
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
      key: ValueKey(conv.orderId), 
      // --- CORRECTION (deprecated_member_use) ---
      tileColor: isActive ? AppTheme.primaryLight.withAlpha((255 * 0.5).round()) : null, // 128
      leading: CircleAvatar(
        // --- CORRECTION (deprecated_member_use) ---
        backgroundColor: indicatorColor.withAlpha((255 * 0.1).round()), // 26
        // --- FIN CORRECTION ---
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