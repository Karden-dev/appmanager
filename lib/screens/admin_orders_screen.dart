// Fichier : lib/screens/admin_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 

import '../providers/order_provider.dart';
import '../widgets/admin_order_card.dart';
// FIX: Suppression de l'import non utilisé: 'admin_order_details_screen.dart'
// import 'admin_order_details_screen.dart'; // Remplacé par l'importation directe lors de l'appel

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key}); 
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _selectedStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOrders();
    });
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    final provider = Provider.of<OrderProvider>(context, listen: false);

    provider.setStatusFilter(_selectedStatus);

    provider.setLoading(true);
    try {
      await provider.fetchOrders();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement: ${error.toString()}')),
      );
    } finally {
      if (mounted) {
          provider.setLoading(false);
      }
    }
  }

  final Map<String, String> statusFilters = const { 
    'ALL': 'Tous',
    'PENDING': 'Nouveau',
    'ASSIGNED': 'Assigné',
    'POSTPONED': 'Reporté',
    'DELIVERED': 'Livré',
    'CANCELLED': 'Annulé',
    'RETURNED': 'Retour',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commandes'),
      ),
      body: Column(
        children: [
          // Section des Filtres
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: statusFilters.keys.map((String key) {
                return ChoiceChip(
                  label: Text(statusFilters[key]!),
                  selected: _selectedStatus == key,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: _selectedStatus == key
                        ? Colors.white
                        : Colors.black87,
                  ),
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() {
                        _selectedStatus = key;
                      });
                      _fetchOrders(); 
                    }
                  },
                  checkmarkColor: Colors.white,
                );
              }).toList(),
            ),
          ),

          // Indicateur de chargement
          Consumer<OrderProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Liste des commandes
          Expanded(
            child: Consumer<OrderProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.orders.isEmpty) {
                  return const SizedBox.shrink();
                }

                if (provider.orders.isEmpty) {
                  return const Center(child: Text('Aucune commande trouvée.'));
                }

                return RefreshIndicator(
                  onRefresh: _fetchOrders,
                  child: ListView.builder(
                    itemCount: provider.orders.length,
                    itemBuilder: (context, index) {
                      final order = provider.orders[index];
                      // Vérifie si la commande est sélectionnée
                      final bool isSelected = provider.selectedOrderIds.contains(order.id);
                      
                      return AdminOrderCard(
                        order: order,
                        isSelected: isSelected, 
                        // Note: L'écran AdminOrderDetailsScreen doit être importé là où il est utilisé.
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}