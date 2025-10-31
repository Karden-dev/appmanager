// lib/screens/admin_orders_screen.dart

import 'package:flutter/material.dart';

// CORRECTION: Remplacement du contenu du service dupliqué par un 
//             véritable widget d'écran (StatefulWidget).
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  // Ajoutez ici la logique de chargement des commandes, les filtres, etc.
  // ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Commandes'),
        // Ajoutez ici les actions (filtres, recherche...)
      ),
      body: const Center(
        child: Text('Écran des Commandes (WIP)'),
      ),
      // Le FloatingActionButton est géré par MainNavigationScreen
    );
  }
}