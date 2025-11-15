// lib/screens/admin_orders_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/admin_order.dart';
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/widgets/admin_order_card.dart'; 
import 'package:wink_manager/widgets/order_action_dialogs.dart'; 
import 'package:wink_manager/screens/admin_order_details_screen.dart';
import 'package:wink_manager/utils/app_theme.dart';
// --- AJOUT ---
import 'package:wink_manager/widgets/network_status_icon.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = true;

  bool _isSelectionMode = false;
  final Set<int> _selectedOrderIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Le filtre est initialisé à '' (Tous) dans le provider par défaut
      // Nous chargeons les commandes dès le départ.
      _loadOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      await Provider.of<OrderProvider>(context, listen: false).loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      Provider.of<OrderProvider>(context, listen: false).setSearchFilter(query);
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: provider.startDate, end: provider.endDate),
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              rangePickerHeaderBackgroundColor: Theme.of(context).colorScheme.primary,
              rangePickerHeaderForegroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      provider.setDateRange(picked.start, picked.end);
    }
  }

  void _toggleSelection(int orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
      } else {
        _selectedOrderIds.add(orderId);
      }
      _isSelectionMode = _selectedOrderIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedOrderIds.clear();
      _isSelectionMode = false;
    });
  }

  // --- IMPLÉMENTATION DES ACTIONS GROUPÉES (INCHANGÉES) ---

  // 1. Fonction pour le bouton d'assignation
  void _showBulkAssignDialog() {
    if (_selectedOrderIds.isEmpty || !mounted) return;
    // Appel au dialogue qui accepte 'dynamic' (List<int>)
    showAssignDeliverymanDialog(context, _selectedOrderIds.toList()).then((_) {
      _clearSelection(); 
    });
  }

  // 2. Fonction pour le bouton d'actions de statut (Icon.task_alt)
  void _showBulkStatusDialog() {
    if (_selectedOrderIds.isEmpty || !mounted) return;

    // Affiche le menu d'options (similaire à orders.html)
    showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              // *** MISE À JOUR DES ACTIONS GROUPÉES AVEC LES NOUVELLES CLÉS ***
              ListTile(leading: Icon(Icons.check_circle_outline, color: OrderCardHelpers.getStatusColor('delivered')), title: const Text('Livrée'), 
                onTap: () => Navigator.pop(sheetContext, 'delivered')),
              ListTile(leading: Icon(Icons.error_outline, color: OrderCardHelpers.getStatusColor('failed_delivery')), title: const Text('Livraison Ratée'), 
                onTap: () => Navigator.pop(sheetContext, 'failed_delivery')),
              // Nouveaux statuts de suivi
              ListTile(leading: Icon(OrderCardHelpers.getStatusIcon('A relancer'), color: OrderCardHelpers.getStatusColor('A relancer')), title: const Text('À Relancer'), 
                onTap: () => Navigator.pop(sheetContext, 'A relancer')),
              ListTile(leading: Icon(OrderCardHelpers.getStatusIcon('Reportée'), color: OrderCardHelpers.getStatusColor('Reportée')), title: const Text('Reporter'), 
                onTap: () => Navigator.pop(sheetContext, 'Reportée')),
              ListTile(leading: Icon(OrderCardHelpers.getStatusIcon('Injoignable'), color: OrderCardHelpers.getStatusColor('Injoignable')), title: const Text('Injoignable'), 
                onTap: () => Navigator.pop(sheetContext, 'Injoignable')),
              ListTile(leading: Icon(OrderCardHelpers.getStatusIcon('Ne decroche pas'), color: OrderCardHelpers.getStatusColor('Ne decroche pas')), title: const Text('Ne décroche pas'), 
                onTap: () => Navigator.pop(sheetContext, 'Ne decroche pas')),
              ListTile(leading: Icon(Icons.cancel_outlined, color: OrderCardHelpers.getStatusColor('cancelled')), title: const Text('Annulée'), 
                onTap: () => Navigator.pop(sheetContext, 'cancelled')),
              const Divider(),
              ListTile(leading: const Icon(Icons.delete_outline, color: AppTheme.danger), title: const Text('Supprimer (Groupé)'), 
                onTap: () => Navigator.pop(sheetContext, 'delete')),
            ],
          ),
        );
      },
    ).then((action) {
      if (action != null) {
        _handleBulkStatusAction(action);
      }
    });
  }

  // 3. Gère l'action choisie depuis le menu
  void _handleBulkStatusAction(String action) {
    if (_selectedOrderIds.isEmpty || !mounted) return;

    if (action == 'delete') {
      _handleBulkDelete();
    } else {
      // Pour tous les autres statuts (y compris les nouveaux)
      showStatusActionDialog(context, _selectedOrderIds.toList(), action).then((_) {
         _clearSelection();
      });
    }
  }

  // 4. Logique de suppression groupée
  void _handleBulkDelete() {
     showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmer la Suppression'),
          content: Text('Voulez-vous supprimer ces ${_selectedOrderIds.length} commandes ? Cette action est irréversible.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ).then((confirmed) async {
         if (confirmed == true && mounted) {
             final orderIdsList = _selectedOrderIds.toList();
             _clearSelection();
             
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text('Suppression de ${orderIdsList.length} commandes...'),
                 duration: const Duration(seconds: 2), 
               ),
             );
             
             for (final orderId in orderIdsList) {
                 try {
                     if (!mounted) return; 
                     await Provider.of<OrderProvider>(context, listen: false).deleteOrder(orderId);
                 } catch (e) {
                     if (!mounted) return;
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('Échec suppression Cde #$orderId: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppTheme.danger),
                     );
                 }
             }
         }
      });
  }

  // --- FIN DE L'IMPLÉMENTATION ---


  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final theme = Theme.of(context);
    final List<AdminOrder> orders = provider.orders;

    return Scaffold(
      appBar: _isSelectionMode
          ? _buildSelectionAppBar(theme)
          : _buildDefaultAppBar(context, provider, theme),
      body: Column(
        children: [
          _buildFilterBar(context, provider),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red)))
                    : orders.isEmpty
                        ? const Center(child: Text('Aucune commande trouvée.'))
                        : RefreshIndicator(
                            onRefresh: _loadOrders,
                            child: ListView.builder(
                              // *** CORRECTION 1 : Ajout de padding en bas pour éviter la coupe ***
                              padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 80.0),
                              itemCount: orders.length,
                              itemBuilder: (context, index) {
                                final order = orders[index];
                                final isSelected = _selectedOrderIds.contains(order.id);

                                return AdminOrderCard(
                                  order: order,
                                  isSelected: isSelected,
                                  onLongPress: () {
                                    _toggleSelection(order.id);
                                  },
                                  onTap: () {
                                    if (_isSelectionMode) {
                                      _toggleSelection(order.id);
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AdminOrderDetailsScreen(orderId: order.id),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  AppBar _buildDefaultAppBar(BuildContext context, OrderProvider provider, ThemeData theme) {
    return AppBar(
      title: const Text('Gestion Commandes'),
      actions: [
        // --- AJOUT DE L'ICÔNE ---
        const NetworkStatusIcon(),
        IconButton(
          icon: const Icon(Icons.calendar_today),
          tooltip: 'Changer la plage de dates',
          onPressed: () => _selectDateRange(context),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              '${DateFormat('dd/MM').format(provider.startDate)} - ${DateFormat('dd/MM/yy').format(provider.endDate)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimary),
            ),
          ),
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
      ),
      title: Text('${_selectedOrderIds.length} sélectionnée(s)'),
      actions: [
        IconButton(
          icon: const Icon(Icons.delivery_dining),
          tooltip: 'Assigner un livreur (Groupé)',
          onPressed: _showBulkAssignDialog, // <-- Appelle la fonction 1
        ),
        IconButton(
          icon: const Icon(Icons.task_alt),
          tooltip: 'Actions groupées (Statut, Suppr.)',
          onPressed: _showBulkStatusDialog, // <-- Appelle la fonction 2
        ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context, OrderProvider provider) {
    // *** CORRECTION 2 : Définition des options de filtre ***
    // 'all' est la clé vide ('') qui signifie "toutes les commandes" au backend.
    final Map<String, String> statusOptions = {
      '': 'Tous', // Filtre par défaut, couvre toutes les commandes
      // Ajoute tous les statuts individuels pour permettre le filtrage précis
      ...statusTranslations, 
    };
    // Note: Les options inutiles ou redondantes ('Tous (sauf retours)', 'Tous (complet)') sont retirées.
    
    final bool isSorted = provider.sortByLocation;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3, 
            child: DropdownButtonFormField<String>(
              // *** CORRECTION 3 : Le filtre par défaut est maintenant la clé vide (Tous) ***
              initialValue: provider.statusFilter.isEmpty ? '' : provider.statusFilter, 
              isDense: true,
              isExpanded: true, 
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              items: statusOptions.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  provider.setStatusFilter(value);
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(isSorted ? Icons.location_on : Icons.location_on_outlined),
            tooltip: isSorted ? 'Désactiver le tri par lieu' : 'Trier par lieu',
            color: isSorted ? theme.colorScheme.primary : Colors.grey.shade600,
            onPressed: () {
              provider.toggleSortByLocation();
            },
          ),
        ],
      ),
    );
  }
}