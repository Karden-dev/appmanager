// Fichier : lib/screens/admin_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:provider/provider.dart';

import '../providers/order_provider.dart';
import '../utils/app_theme.dart'; // Nécessaire pour AppTheme.danger
import 'tabs/hub_preparation_tab.dart'; 
import 'tabs/hub_returns_tab.dart';   

class AdminHubScreen extends StatefulWidget {
  const AdminHubScreen({super.key});

  @override
  State<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends State<AdminHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  /// Actualise les données de l'onglet actif
  Future<void> _refreshCurrentTab() async {
    // FIX: Vérification de mounted avant l'accès à context
    if (!mounted) return;
    final provider = Provider.of<OrderProvider>(context, listen: false);
    
    if (_tabController.index == 0) {
      await provider.fetchPreparationOrders(forceRefresh: true);
    } else {
      
      final DateFormat apiFormatter = DateFormat('yyyy-MM-dd');
      final DateTime endDate = DateTime.now();
      final DateTime startDate = endDate.subtract(const Duration(days: 30));
      
      final Map<String, dynamic> defaultFilters = {
        'status': 'pending_return_to_hub',
        'deliverymanId': null,
        'startDate': apiFormatter.format(startDate),
        'endDate': apiFormatter.format(endDate),
      };

      await provider.fetchPendingReturns(
        filters: defaultFilters, 
        forceRefresh: true
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    // Utilisation de Theme.of(context) pour l'accès aux couleurs
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final Color dangerColor = AppTheme.danger; // Accès direct au champ statique

    // Nous utilisons 'watch' pour que les badges se mettent à jour
    final provider = context.watch<OrderProvider>();
    final int prepCount = provider.preparationOrders.length;
    final int returnCount = provider.pendingReturns
        .where((r) => r.returnStatus == 'pending_return_to_hub')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logistique Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _refreshCurrentTab,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          // FIX: Utilisation de primaryColor (locale)
          indicatorColor: primaryColor, 
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey[600],
          tabs: [
            Tab(
              icon: Badge(
                label: Text(prepCount.toString()),
                isLabelVisible: prepCount > 0,
                child: const Icon(Icons.inventory_2_outlined),
              ),
              text: 'Préparation',
            ),
            Tab(
              icon: Badge(
                label: Text(returnCount.toString()),
                isLabelVisible: returnCount > 0,
                // FIX: Utilisation de dangerColor (statique)
                backgroundColor: dangerColor, 
                child: const Icon(Icons.assignment_return_outlined),
              ),
              text: 'Retours',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Onglet 1: Écran de Préparation
          HubPreparationTab(),

          // Onglet 2: Écran des Retours
          HubReturnsTab(),
        ],
      ),
    );
  }
}