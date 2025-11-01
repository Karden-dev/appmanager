import 'package:flutter/material.dart';
import 'package:wink_manager/screens/admin_chat_list_screen.dart';
import 'package:wink_manager/screens/admin_hub_screen.dart';
// CORRECTION 1: Importation décommentée pour résoudre l'erreur
import 'package:wink_manager/screens/admin_orders_screen.dart'; 
import 'package:wink_manager/screens/admin_reports_screen.dart';
import 'package:wink_manager/screens/admin_order_edit_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // Correction: La liste doit être 'final' et non 'const' si les éléments ne 
  // sont pas des const déclarations (même si les classes sont Stateless/Stateful).
  static final List<Widget> _widgetOptions = <Widget>[
    const AdminOrdersScreen(), // Le symbole est maintenant résolu
    const AdminHubScreen(),     
    const AdminReportsScreen(), 
    const AdminChatListScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

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
      extendBody: true, 
      
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      
      // Floating Action Button pour l'ajout de commande (fonctionnalité conservée)
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddOrder,
        elevation: 3.0,
        shape: const CircleBorder(), 
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      
      // Ancrage du FAB entre les éléments de la barre de navigation
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      // Remplacement de BottomAppBar par le widget moderne NavigationBar (Material 3)
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        height: 65, 
        elevation: 4, 
        
        // CORRECTION 2: Remplacement de .withOpacity(0.1) par .withAlpha(26)
        indicatorColor: Theme.of(context).colorScheme.primary.withAlpha((255 * 0.1).round()), // Équivaut à .withAlpha(26)

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
          // Les destinations 2 et 3 décalent l'encoche du FAB, comme prévu par centerDocked.
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