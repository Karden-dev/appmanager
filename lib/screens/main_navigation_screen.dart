// lib/screens/main_navigation_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/screens/admin_chat_list_screen.dart';
import 'package:wink_manager/screens/admin_hub_screen.dart';
import 'package:wink_manager/screens/admin_orders_screen.dart'; 
import 'package:wink_manager/screens/admin_reports_screen.dart';
import 'package:wink_manager/screens/admin_order_edit_screen.dart';
import 'package:wink_manager/services/sync_service.dart';
import 'package:wink_manager/widgets/app_drawer.dart'; // Import du Drawer personnalisé

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // Liste des écrans principaux
  static final List<Widget> _widgetOptions = <Widget>[
    const AdminOrdersScreen(), 
    const AdminHubScreen(),     
    const AdminReportsScreen(), 
    const AdminChatListScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Initialisation du service de synchronisation
    Provider.of<SyncService>(context, listen: false).initialize();
  }
  
  @override
  void dispose() {
    Provider.of<SyncService>(context, listen: false).dispose();
    super.dispose();
  }

  // Gestion du clic sur la BottomBar
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Gestion du clic dans le Drawer (ferme le drawer et change l'index)
  void _onDrawerItemTapped(int index) {
    Navigator.pop(context); // Ferme le drawer
    setState(() {
      _selectedIndex = index;
    });
  }

  // Navigation vers la création de commande
  void _navigateToAddOrder() {
     Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminOrderEditScreen(order: null), 
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Intégration du Drawer personnalisé
      drawer: AppDrawer(
        selectedIndex: _selectedIndex,
        onItemTapped: _onDrawerItemTapped,
      ),
      
      // Permet au corps de passer sous la barre de navigation et le FAB
      extendBody: true, 
      
      // Affichage de l'écran sélectionné
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      
      // Bouton d'action flottant (Ajouter Commande)
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddOrder,
        elevation: 3.0,
        shape: const CircleBorder(), 
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      // Barre de navigation inférieure
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        height: 65, 
        elevation: 4, 
        
        indicatorColor: Theme.of(context).colorScheme.primary.withAlpha((255 * 0.1).round()),

        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt_rounded),
            label: 'Commandes',
          ),
          NavigationDestination(
            icon: Icon(Icons.warehouse_outlined),
            selectedIcon: Icon(Icons.warehouse_rounded),
            label: 'Logistique',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Rapports',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Suivis',
          ),
        ],
      ),
    );
  }
}