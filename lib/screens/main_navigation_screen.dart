import 'package:flutter/material.dart';
import 'package:wink_manager/screens/admin_chat_list_screen.dart';
import 'package:wink_manager/screens/admin_hub_screen.dart';
import 'package:wink_manager/screens/admin_orders_screen.dart'; 
import 'package:wink_manager/screens/admin_reports_screen.dart';
import 'package:wink_manager/screens/admin_order_edit_screen.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/services/sync_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const AdminOrdersScreen(), 
    const AdminHubScreen(),     
    const AdminReportsScreen(), 
    const AdminChatListScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // On démarre UNIQUEMENT le SyncService ici
    Provider.of<SyncService>(context, listen: false).initialize();
  }
  
  // --- AJOUT : Dispose pour le SyncService ---
  @override
  void dispose() {
    Provider.of<SyncService>(context, listen: false).dispose();
    super.dispose();
  }
  // --- FIN AJOUT ---

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
    // ... (Reste du build inchangé) ...
    return Scaffold(
      extendBody: true, 
      
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddOrder,
        elevation: 3.0,
        shape: const CircleBorder(), 
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
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