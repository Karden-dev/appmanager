// lib/widgets/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/screens/admin_cash_screen.dart'; // <-- AJOUTÉ
import 'package:wink_manager/screens/admin_debts_screen.dart';
import 'package:wink_manager/screens/admin_remittances_screen.dart';
import 'package:wink_manager/screens/main_navigation_screen.dart';
import 'package:wink_manager/services/auth_service.dart';
import 'package:wink_manager/utils/app_theme.dart';

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.user;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // En-tête Profil
          UserAccountsDrawerHeader(
            accountName: Text(
              user?.name ?? 'Admin',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(user?.phoneNumber ?? ''),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: AppTheme.secondaryColor),
            ),
            decoration: const BoxDecoration(
              color: AppTheme.secondaryColor,
            ),
          ),

          // --- NAVIGATION PRINCIPALE ---
          ListTile(
            leading: const Icon(Icons.home_filled, color: AppTheme.secondaryColor),
            title: const Text('Accueil / Opérations'),
            onTap: () {
              Navigator.pop(context); // Ferme le drawer
              // Navigue vers l'écran principal et vide la pile de navigation pour éviter les boucles
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                (route) => false,
              );
            },
          ),
          
          const Divider(),

          // --- SECTION FINANCE ---
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Text(
              "FINANCE & COMPTABILITÉ",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.payments_outlined, color: AppTheme.primaryColor),
            title: const Text('Versements Marchands'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AdminRemittancesScreen()),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.money_off_csred_outlined, color: AppTheme.danger),
            title: const Text('Gestion des Créances'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AdminDebtsScreen()),
              );
            },
          ),
          
          // --- MODIFICATION : Entrée Caisse activée ---
          ListTile(
            leading: const Icon(Icons.savings_outlined, color: Colors.green),
            title: const Text('Gestion Caisse'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AdminCashScreen()),
              );
            },
          ),
          // --- FIN MODIFICATION ---

          const Divider(),

          // --- DÉCONNEXION ---
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.danger),
            title: const Text('Déconnexion', style: TextStyle(color: AppTheme.danger)),
            onTap: () {
              Navigator.pop(context);
              authService.logout();
            },
          ),
        ],
      ),
    );
  }
}