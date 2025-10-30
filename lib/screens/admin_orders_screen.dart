// lib/screens/admin_orders_screen.dart

import 'dart:async'; // Importé pour Timer
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
// import 'package:wink_manager/models/admin_order.dart'; // <-- CORRECTION: Ligne supprimée (non utilisée)
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/admin_order_card.dart';
import 'package:wink_manager/widgets/order_action_dialogs.dart'; // Pour les dialogues d'action

class AdminOrdersScreen extends StatefulWidget {
  // Le widget est maintenant constant
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce; 

  // Map pour les filtres de statut
  static const Map<String, String> _statusOptions = {
    '': 'Tous (sauf retours)',
    'all': 'Absolument Tous',
    'pending': 'En attente',
    'in_progress': 'Assignée',
    'ready_for_pickup': 'Prête',
    'en_route': 'En route',
    'delivered': 'Livrée',
    'reported': 'À relancer',
    'failed_delivery': 'Ratée',
    'cancelled': 'Annulée',
    'return_declared': 'Retour déclaré',
    'returned': 'Retournée',
  };

  @override
  void initState() {
    super.initState();
    // Listener pour la recherche avec debounce
    _searchController.addListener(_onSearchChanged);
    
    // Chargement initial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Vérifie si le provider est déjà en chargement (ex: par un autre widget)
      final provider = Provider.of<OrderProvider>(context, listen: false);
      if (provider.orders.isEmpty && !provider.isLoading) {
         provider.loadOrders();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () { 
      if (mounted) {
        Provider.of<OrderProvider>(context, listen: false)
            .setSearchFilter(_searchController.text);
      }
    });
  }

  Future<void> _refreshOrders() async {
    await Provider.of<OrderProvider>(context, listen: false).loadOrders();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final initialRange = DateTimeRange(
      start: provider.startDate,
      end: provider.endDate,
    );
    final newRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initialRange,
      locale: const Locale('fr', 'FR'),
    );

    if (newRange != null) {
      provider.setDateRange(newRange.start, newRange.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Utilise Consumer pour écouter les changements du provider
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        final bool isSelectionMode = provider.isSelectionMode;
        
        return Scaffold(
          appBar: _buildAppBar(context, provider, isSelectionMode),
          body: Column(
            children: [
              _buildFilterBar(context, provider),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshOrders,
                  child: provider.isLoading && provider.orders.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : provider.error != null
                          ? Center(child: Text(provider.error!))
                          : provider.orders.isEmpty
                              ? const Center(
                                  child: Text('Aucune commande trouvée.',
                                      style: TextStyle(color: Colors.grey)))
                              : ListView.builder(
                                  itemCount: provider.orders.length,
                                  padding: const EdgeInsets.only(bottom: 80), // Espace pour le FAB
                                  itemBuilder: (context, index) {
                                    final order = provider.orders[index];
                                    return AdminOrderCard(
                                      order: order,
                                      isSelected: provider.selectedOrderIds
                                          .contains(order.id),
                                    );
                                  },
                                ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Widgets pour l'AppBar ---

  AppBar _buildAppBar(BuildContext context, OrderProvider provider, bool isSelectionMode) {
    return isSelectionMode
        ? _buildSelectionAppBar(context, provider)
        : _buildDefaultAppBar(context, provider);
  }

  AppBar _buildDefaultAppBar(BuildContext context, OrderProvider provider) {
    return AppBar(
      title: const Text('Commandes'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            // Logique pour afficher/cacher la barre de recherche si nécessaire
            // Pour l'instant, on suppose que la barre de recherche est dans _buildFilterBar
          },
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today_outlined),
          onPressed: () => _selectDateRange(context),
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar(BuildContext context, OrderProvider provider) {
    return AppBar(
      backgroundColor: AppTheme.secondaryColor,
      foregroundColor: Colors.white, // Assure que les icônes sont blanches
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => provider.clearSelection(),
      ),
      title: Text('${provider.selectedOrderIds.length} sélectionnée(s)'),
      actions: [
        IconButton(
          icon: const Icon(Icons.two_wheeler_outlined),
          tooltip: 'Assigner (Groupé)',
          onPressed: () {
            showAssignDeliverymanDialog(context, provider.selectedOrderIds.toList());
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Supprimer (Groupé)',
          onPressed: () async {
            final bool didConfirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Supprimer les commandes'),
                    content: Text(
                        'Êtes-vous sûr de vouloir supprimer ${provider.selectedOrderIds.length} commandes ?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Supprimer', style: TextStyle(color: AppTheme.danger)),
                      ),
                    ],
                  ),
                ) ?? false;

            if (didConfirm && context.mounted) {
              try {
                await provider.deleteSelectedOrders();
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Commandes supprimées.'), backgroundColor: Colors.green),
                   );
                 }
              } catch (e) {
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
                   );
                 }
              }
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: 'Tout sélectionner (Page)',
          onPressed: () {
            provider.toggleSelectAll(provider.orders.map((o) => o.id).toList());
          },
        ),
      ],
    );
  }

  // --- Widget pour la barre de filtres ---

  Widget _buildFilterBar(BuildContext context, OrderProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          // Ligne 1: Recherche
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Rechercher (ID, Client, Marchand, Lieu...)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        provider.setSearchFilter('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
          const SizedBox(height: 8),
          
          // Ligne 2: Filtre Statut et Plage de Date
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: provider.statusFilter,
                  decoration: InputDecoration(
                    labelText: 'Statut',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    isDense: true,
                  ),
                  items: _statusOptions.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      provider.setStatusFilter(newValue);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Bouton pour la plage de date
              IconButton(
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: () => _selectDateRange(context),
                tooltip: 'Changer la plage de dates',
              ),
              // Affichage de la plage de date
              Expanded(
                child: Text(
                  '${DateFormat('dd/MM', 'fr_FR').format(provider.startDate)} - ${DateFormat('dd/MM', 'fr_FR').format(provider.endDate)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}