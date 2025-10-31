// Fichier : lib/screens/main_navigation_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
// FIX: Ajout de l'import manquant pour résoudre l'erreur "creation_with_non_type"
import 'admin_orders_screen.dart'; 
import 'admin_hub_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_chat_list_screen.dart'; 

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    // L23 est ici. La classe est maintenant reconnue grâce à l'import ci-dessus.
    AdminOrdersScreen(), 
    AdminHubScreen(),
    AdminReportsScreen(),
    AdminChatListScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Utilisation de watch pour réagir aux changements d'authentification
    final authService = context.watch<AuthService>(); 

    // Si l'utilisateur n'est plus authentifié (token expiré, etc.), naviguer vers l'écran de connexion
    if (!authService.isAuthenticated) {
      // Utilisation du PushReplacement pour empêcher le retour à cet écran
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/');
      });
      return const SizedBox.shrink(); 
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wink Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.logout(),
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: 'Commandes',
          ),
          NavigationDestination(
            icon: Icon(Icons.storage),
            label: 'Hub',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics),
            label: 'Rapports',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}