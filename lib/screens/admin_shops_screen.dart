// lib/screens/admin_shops_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/providers/shop_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/app_drawer.dart';
import 'package:wink_manager/widgets/network_status_icon.dart';
import 'package:wink_manager/widgets/shop_edit_dialog.dart'; // Sera créé à l'étape suivante
import 'package:wink_manager/screens/main_navigation_screen.dart';

class AdminShopsScreen extends StatefulWidget {
  const AdminShopsScreen({super.key});

  @override
  State<AdminShopsScreen> createState() => _AdminShopsScreenState();
}

class _AdminShopsScreenState extends State<AdminShopsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Chargement initial des données
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShopProvider>().loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<ShopProvider>().setSearch(query);
    });
  }

  // --- ACTIONS ---

  void _showStatsModal(BuildContext context) {
    final stats = context.read<ShopProvider>().stats;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              "Statistiques Marchands",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _StatCard(
                  title: "TOTAL",
                  value: stats['total'].toString(),
                  color: AppTheme.secondaryColor,
                  icon: Icons.store,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  title: "ACTIFS",
                  value: stats['active'].toString(),
                  color: AppTheme.success,
                  icon: Icons.check_circle,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  title: "INACTIFS",
                  value: stats['inactive'].toString(),
                  color: Colors.grey,
                  icon: Icons.cancel,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog({Shop? shop}) async {
    await showDialog(
      context: context,
      builder: (ctx) => ShopEditDialog(shop: shop),
    );
  }

  void _toggleShopStatus(Shop shop) async {
    final action = shop.status == 'actif' ? 'Désactiver' : 'Activer';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action ${shop.name} ?'),
        content: Text('Voulez-vous vraiment $action ce marchand ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: shop.status == 'actif' ? AppTheme.danger : AppTheme.success,
            ),
            child: Text(
              action,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await context.read<ShopProvider>().toggleShopStatus(shop);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Statut mis à jour : ${shop.status == 'actif' ? 'Inactif' : 'Actif'}'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur: $e"), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }
  
  void _onDrawerItemTapped(int index) {
    Navigator.pop(context);
    // Comme "Marchands" n'est pas dans le MainNavigationScreen par défaut (c'est une page admin à part),
    // on redirige vers l'accueil si index != index courant, ou on gère la navigation.
    // Ici, on suppose un retour à l'accueil pour simplifier si on change d'onglet via le drawer.
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => const MainNavigationScreen())
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShopProvider>();
    final shops = provider.shops;

    return Scaffold(
      drawer: AppDrawer(selectedIndex: -1, onItemTapped: _onDrawerItemTapped),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Gestion Marchands'),
        actions: [
          const NetworkStatusIcon(),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Statistiques',
            onPressed: () => _showStatsModal(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // --- FILTRES ---
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un marchand...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: AppTheme.background,
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Tous',
                        isSelected: provider.statusFilter == null,
                        onTap: () => provider.setStatusFilter(null),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Actifs',
                        isSelected: provider.statusFilter == 'actif',
                        onTap: () => provider.setStatusFilter('actif'),
                        color: AppTheme.success,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Inactifs',
                        isSelected: provider.statusFilter == 'inactif',
                        onTap: () => provider.setStatusFilter('inactif'),
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (provider.error != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: AppTheme.danger.withOpacity(0.1),
              width: double.infinity,
              child: Text(
                provider.error!, 
                style: const TextStyle(color: AppTheme.danger), 
                textAlign: TextAlign.center
              )
            ),

          // --- LISTE ---
          Expanded(
            child: provider.isLoading && shops.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : shops.isEmpty
                    ? const Center(child: Text("Aucun marchand trouvé."))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80), // Espace pour FAB
                        itemCount: shops.length,
                        itemBuilder: (context, index) {
                          final shop = shops[index];
                          return _ShopCard(
                            shop: shop,
                            onEdit: () => _showEditDialog(shop: shop),
                            onToggleStatus: () => _toggleShopStatus(shop),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS INTERNES ---

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color = AppTheme.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final Shop shop;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const _ShopCard({
    required this.shop,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = shop.status == 'actif';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isActive ? AppTheme.success.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  child: Text(
                    shop.name.isNotEmpty ? shop.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isActive ? AppTheme.success : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shop.phoneNumber,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge Statut
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.success : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isActive ? 'ACTIF' : 'INACTIF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Indicateurs Facturation
                Row(
                  children: [
                    _FeatureIcon(
                      icon: Icons.inventory_2_outlined,
                      isActive: shop.billStorage,
                      label: 'Stockage',
                    ),
                    const SizedBox(width: 12),
                    _FeatureIcon(
                      icon: Icons.kitchen_outlined,
                      isActive: shop.billPackaging,
                      label: 'Emballage',
                    ),
                  ],
                ),
                // Actions
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: AppTheme.accentColor,
                      onPressed: onEdit,
                      tooltip: 'Modifier',
                    ),
                    IconButton(
                      icon: Icon(isActive ? Icons.block : Icons.check_circle_outline, size: 20),
                      color: isActive ? AppTheme.danger : AppTheme.success,
                      onPressed: onToggleStatus,
                      tooltip: isActive ? 'Désactiver' : 'Activer',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final String label;

  const _FeatureIcon({
    required this.icon,
    required this.isActive,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label ${isActive ? 'Activé' : 'Désactivé'}',
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? AppTheme.success : Colors.grey.shade300,
          ),
          if (isActive) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}