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
  // --- NOUVEAU : Ajout du ScrollController pour la pagination ---
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        Provider.of<ChatProvider>(context, listen: false)
            .setConversationSearch(_searchController.text);
      }
    });

    // --- NOUVEAU : Ajout du listener ---
    _scrollController.addListener(_onScroll);

    // Charge la première page depuis le cache (ou l'API si le cache est vide)
    Provider.of<ChatProvider>(context, listen: false)
        .loadConversations(forceApi: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    // --- NOUVEAU : Nettoyage du listener ---
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // --- NOUVELLE MÉTHODE : Déclenche le chargement de la page suivante ---
  void _onScroll() {
    final provider = context.read<ChatProvider>();
    // Si on est en bas de la liste, qu'on ne charge pas déjà, et qu'il y a plus de conversations
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !provider.isLoadingMoreConversations &&
        provider.hasMoreConversations) {
      provider.loadMoreConversations();
    }
  }
  // --- FIN NOUVELLE MÉTHODE ---

  // Action de naviguer vers un chat spécifique (inchangée)
  void _navigateToChat(BuildContext context, int orderId) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminChatScreen(orderId: orderId),
      ),
    ).then((_) {
      chatProvider.deselectConversation();
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
            // --- MODIFIÉ : Le Selector observe plus d'états ---
            child: Selector<ChatProvider,
                ({
                  List<Conversation> convos,
                  bool isLoading,
                  String? error,
                  String searchQuery,
                  int? activeOrderId,
                  bool isLoadingMore, // <-- NOUVEAU
                  bool hasMore // <-- NOUVEAU
                })>(
              selector: (_, provider) => (
                convos: provider.conversations,
                isLoading: provider.isLoadingConversations,
                error: provider.conversationError,
                searchQuery: provider.searchQuery, 
                activeOrderId: provider.activeOrderId,
                isLoadingMore: provider.isLoadingMoreConversations, // <-- NOUVEAU
                hasMore: provider.hasMoreConversations // <-- NOUVEAU
              ),
              shouldRebuild: (prev, next) =>
                  prev.isLoading != next.isLoading ||
                  prev.error != next.error ||
                  prev.searchQuery != next.searchQuery || 
                  prev.activeOrderId != next.activeOrderId || 
                  prev.isLoadingMore != next.isLoadingMore || // <-- NOUVEAU
                  prev.hasMore != next.hasMore || // <-- NOUVEAU
                  !listEquals(prev.convos, next.convos),
              builder: (context, data, _) {
                final provider = context.read<ChatProvider>();
                // --- MODIFIÉ : Passe les nouveaux états ---
                return _buildConversationList(
                    context,
                    provider,
                    data.convos,
                    data.isLoading,
                    data.error,
                    data.searchQuery,
                    data.activeOrderId,
                    data.isLoadingMore, // <-- NOUVEAU
                    data.hasMore // <-- NOUVEAU
                  );
              },
            ),
            // --- FIN MODIFICATION ---
          ),
        ],
      ),
    );
  }

  /// Construit la barre de recherche et les filtres. (Inchangé)
  Widget _buildFilterBar(BuildContext context, ChatProvider provider,
      bool showUrgentOnly, bool showArchived) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).round()), 
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
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
                selectedColor: AppTheme.danger.withAlpha((255 * 0.2).round()), // 51
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
                selectedColor: AppTheme.secondaryColor.withAlpha((255 * 0.2).round()), // 51
                showCheckmark: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construit la liste des conversations.
  // --- MODIFIÉ : Accepte les nouveaux états ---
  Widget _buildConversationList(
    BuildContext context,
    ChatProvider provider, 
    List<Conversation> conversations,
    bool isLoading,
    String? error,
    String searchQuery,
    int? activeOrderId,
    bool isLoadingMore, // <-- NOUVEAU
    bool hasMore // <-- NOUVEAU
  ) {
  // --- FIN MODIFICATION ---

    // Affiche le spinner principal seulement au premier chargement
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

    // Logique de filtrage (inchangée)
    final filteredList = conversations.where((conv) {
      final query = searchQuery.toLowerCase().trim(); 
      if (query.isEmpty) return true;
      return (conv.orderId.toString().contains(query) ||
          (conv.customerPhone?.toLowerCase().contains(query) ?? false) ||
          (conv.shopName?.toLowerCase().contains(query) ?? false) ||
          (conv.deliverymanName?.toLowerCase().contains(query) ?? false));
    }).toList();

    if (filteredList.isEmpty && !isLoadingMore) {
      return const Center(
        child: Text(
          'Aucune conversation trouvée pour ces filtres.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    // --- MODIFIÉ : Ajout de itemCount et du controller ---
    // +1 pour le spinner ou le message de fin
    final itemCount = filteredList.length + (isLoadingMore || !hasMore ? 1 : 0);

    return RefreshIndicator(
      // Le refresh force la page 1 depuis l'API (géré par le provider)
      onRefresh: () => provider.loadConversations(forceApi: true),
      child: ListView.separated(
        // --- NOUVEAU : Ajout du controller ---
        controller: _scrollController,
        // --- FIN NOUVEAU ---
        itemCount: itemCount,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 80),
        
        cacheExtent: MediaQuery.of(context).size.height * 1.5,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,

        itemBuilder: (context, index) {
          // --- NOUVEAU : Logique d'affichage du dernier item (pagination) ---
          if (index == filteredList.length) {
            if (isLoadingMore) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (!hasMore && filteredList.isNotEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'Fin de la liste',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }
          // --- FIN NOUVEAU ---

          final conv = filteredList[index];
          return _buildConversationItem(context, conv, activeOrderId);
        },
      ),
    );
    // --- FIN MODIFICATION ---
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
      tileColor: isActive ? AppTheme.primaryLight.withAlpha((255 * 0.5).round()) : null, // 128
      leading: CircleAvatar(
        backgroundColor: indicatorColor.withAlpha((255 * 0.1).round()), // 26
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