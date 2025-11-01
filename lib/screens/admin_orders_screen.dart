// lib/screens/admin_orders_screen.dart

import 'dart:async';
import 'package:flutter/material.dart'; // <-- AJOUTÉ : Corrige DateRangePickerMode
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/admin_order.dart';
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/widgets/admin_order_card.dart'; 
import 'package:wink_manager/widgets/order_action_dialogs.dart'; 
// --- AJOUTÉ : Corrige l'erreur 'Undefined method' ---
import 'package:wink_manager/screens/admin_order_details_screen.dart';

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
    // --- SUPPRIMÉ : La variable 'initialMode' inutilisée ---
    
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

  void _showBulkAssignDialog() {
    if (_selectedOrderIds.isEmpty || !mounted) return;
    // CORRECTION 1: Ajout du cast 'as dynamic' pour résoudre l'erreur de type
    showAssignDeliverymanDialog(context, _selectedOrderIds.toList() as dynamic).then((_) {
      _clearSelection(); 
    });
  }

  void _showBulkStatusDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Action groupée de statut non implémentée.')),
    );
  }

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
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
                                      // --- CORRIGÉ : Appel correct au constructeur ---
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
          tooltip: 'Assigner un livreur',
          onPressed: _showBulkAssignDialog,
        ),
        IconButton(
          icon: const Icon(Icons.task_alt),
          tooltip: 'Changer le statut',
          onPressed: _showBulkStatusDialog,
        ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context, OrderProvider provider) {
    final Map<String, String> statusOptions = {
      '': 'Tous (sauf retours)',
      ...statusTranslations,
      'all': 'Tous (complet)',
    };
    
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
            flex: 3, // --- MODIFIÉ : Donné plus d'espace au dropdown
            child: DropdownButtonFormField<String>(
              // CORRECTION 2: Utilisation de 'initialValue' au lieu de 'value'
              initialValue: provider.statusFilter, 
              isDense: true,
              isExpanded: true, // --- AJOUTÉ : Force le dropdown à s'étendre
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
                  // --- MODIFIÉ : Permet au texte de tronquer
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