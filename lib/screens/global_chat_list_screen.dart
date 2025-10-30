// lib/screens/global_chat_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../services/order_service.dart';
import '../services/websocket_service.dart';
import '../utils/app_theme.dart';
import 'chat_screen.dart';

class GlobalChatListScreen extends StatefulWidget {
  const GlobalChatListScreen({super.key});

  @override
  State<GlobalChatListScreen> createState() => _GlobalChatListScreenState();
}

class _GlobalChatListScreenState extends State<GlobalChatListScreen> {
  Future<List<Order>>? _conversationsFuture;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupWebSocketListener();
      _fetchConversations(forceCacheInvalidation: true); // Premier fetch force une mise à jour
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _setupWebSocketListener() {
    if (!mounted) return;
    final wsService = Provider.of<WebSocketService?>(context, listen: false);
    if (wsService == null) return;

    _eventSubscription?.cancel();
    _eventSubscription = wsService.eventStream.listen((event) {
      // Si un message arrive ou qu'une commande est mise à jour, on rafraîchit la liste
      if (event == 'UNREAD_COUNT_UPDATE' || event == 'ORDER_UPDATE') {
        // **MODIFIÉ: Force l'invalidation du cache de OrderService avant de fetch**
        _fetchConversations(forceCacheInvalidation: true); 
      }
    });
  }

  Future<void> _fetchConversations({bool forceCacheInvalidation = false}) async {
    if (!mounted) return;
    final orderService = Provider.of<OrderService?>(context, listen: false);
    if (orderService == null) {
      if (mounted) {
        setState(() {
          _conversationsFuture = Future.error("Service non disponible.");
        });
      }
      return;
    }

    // **NOUVEAU: Invalide le cache si l'appel vient d'un événement WS**
    if (forceCacheInvalidation) {
      orderService.invalidateOrderCache();
    }
    
    // Récupère toutes les commandes des 30 derniers jours
    final startDate = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 30)));
    final endDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (mounted) {
      setState(() {
        _conversationsFuture = orderService.fetchRiderOrders(
          statuses: ['all'],
          startDate: startDate,
          endDate: endDate,
        );
      });
    }
  }

  void _navigateToChat(Order order) {
    // Navigue vers l'écran de chat
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(order: order),
      ),
    ).then((_) {
      // Au retour du chat, on rafraîchit la liste pour mettre à jour
      // le statut "lu" (le compteur non lu devrait être à 0)
      _fetchConversations(forceCacheInvalidation: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Discussions'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchConversations(forceCacheInvalidation: true),
        child: FutureBuilder<List<Order>>(
          future: _conversationsFuture,
          builder: (context, snapshot) {
            if (_conversationsFuture == null || (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null)) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Erreur: ${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                    style: const TextStyle(color: AppTheme.danger),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'Aucune commande trouvée pour les 30 derniers jours.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            final orders = snapshot.data!;
            
            // On ne garde que les commandes qui ont des messages non lus
            // OU qui sont "non traitées" (pour permettre de démarrer une conversation)
            final relevantOrders = orders.where((o) {
              bool isUnprocessed = Order.unprocessedStatuses.contains(o.status);
              bool hasUnread = o.unreadCount > 0;
              // On garde si non lu, OU si encore en cours
              return hasUnread || isUnprocessed;
            }).toList();
            
            // Tri : Non lus en premier, puis les plus récents
            relevantOrders.sort((a, b) {
              if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
              if (a.unreadCount == 0 && b.unreadCount > 0) return 1;
              return b.createdAt.compareTo(a.createdAt);
            });

            if (relevantOrders.isEmpty) {
              return const Center(
                child: Text(
                  'Aucune discussion active ou non lue.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return ListView.separated(
              itemCount: relevantOrders.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 16),
              itemBuilder: (context, index) {
                final order = relevantOrders[index];
                final bool hasUnread = order.unreadCount > 0;

                return ListTile(
                  leading: Badge(
                    label: Text(order.unreadCount.toString()),
                    isLabelVisible: hasUnread,
                    backgroundColor: AppTheme.danger,
                    child: CircleAvatar(
                      backgroundColor: hasUnread ? AppTheme.primaryLight : AppTheme.background,
                      child: Icon(
                        Icons.chat_bubble_outline,
                        color: hasUnread ? AppTheme.primaryColor : AppTheme.secondaryColor.withAlpha(150),
                      ),
                    ),
                  ),
                  title: Text(
                    'Commande #${order.id}',
                    style: TextStyle(
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    'Marchand: ${order.shopName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _navigateToChat(order),
                );
              },
            );
          },
        ),
      ),
    );
  }
}