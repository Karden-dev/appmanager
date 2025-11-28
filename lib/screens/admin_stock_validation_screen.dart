// lib/screens/admin_stock_validation_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/services/stock_service.dart';
import 'package:wink_manager/providers/shop_provider.dart';
// import 'package:wink_manager/utils/app_theme.dart'; // RETIRÉ CAR INUTILISÉ
import 'package:wink_manager/widgets/app_drawer.dart';
import 'package:wink_manager/screens/admin_shop_stock_screen.dart';

class AdminStockValidationScreen extends StatefulWidget {
  const AdminStockValidationScreen({super.key});

  @override
  State<AdminStockValidationScreen> createState() => _AdminStockValidationScreenState();
}

class _AdminStockValidationScreenState extends State<AdminStockValidationScreen> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des Stocks"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [ // AJOUT DE CONST ICI
            Tab(icon: Icon(Icons.check_circle_outline), text: "Validations"),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: "Inventaires"),
          ],
        ),
      ),
      drawer: AppDrawer(selectedIndex: 3, onItemTapped: (i){}), 
      body: TabBarView(
        controller: _tabController,
        children: [
          // ONGLET 1 : VALIDATIONS
          const _ValidationTab(),
          
          // ONGLET 2 : LISTE DES MARCHANDS
          const _InventoryListTab(),
        ],
      ),
    );
  }
}

// --- SOUS-WIDGET : ONGLET VALIDATION ---
class _ValidationTab extends StatefulWidget {
  const _ValidationTab();

  @override
  State<_ValidationTab> createState() => _ValidationTabState();
}

class _ValidationTabState extends State<_ValidationTab> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final service = Provider.of<StockService>(context, listen: false);
      final data = await service.getPendingRequests();
      setState(() { _requests = data; });
    } catch (e) {
      // Gestion erreur silencieuse
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _validate(int requestId, int quantity) async {
    try {
      await Provider.of<StockService>(context, listen: false).validateRequest(requestId, quantity);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stock validé !"), backgroundColor: Colors.green));
      _loadRequests();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _reject(int requestId, String reason) async {
    try {
      await Provider.of<StockService>(context, listen: false).rejectRequest(requestId, reason);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rejeté."), backgroundColor: Colors.orange));
      _loadRequests();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    }
  }

  void _showImageDialog(String? imageUrl) {
    if (imageUrl == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            imageUrl.startsWith('http') || imageUrl.startsWith('data')
              ? Image.network(imageUrl, errorBuilder: (c,e,s) => const Padding(padding: EdgeInsets.all(20), child: Text("Image non affichable"))) 
              : const Padding(padding: EdgeInsets.all(20), child: Text("Format non supporté")),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer"))
          ],
        ),
      ),
    );
  }

  void _openCorrectionDialog(Map<String, dynamic> req) {
    final qtyController = TextEditingController(text: req['quantity_declared'].toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Corriger la quantité"),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Quantité Réelle", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _validate(req['id'], int.parse(qtyController.text));
            },
            child: const Text("Valider Correction"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade100),
            const SizedBox(height: 16),
            const Text("Aucune demande en attente.", style: TextStyle(color: Colors.grey)),
            TextButton(onPressed: _loadRequests, child: const Text("Actualiser"))
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _requests.length,
      itemBuilder: (ctx, index) {
        final req = _requests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(req['shop_name'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(DateFormat('dd/MM HH:mm').format(DateTime.parse(req['created_at'])), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showImageDialog(req['proof_image_url']),
                      child: Container(
                        width: 60, height: 60,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req['product_name'] ?? 'Produit', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text("Déclaré : ${req['quantity_declared']}", style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _reject(req['id'], "Refusé par admin"),
                      child: const Text("Rejeter", style: TextStyle(color: Colors.red)),
                    ),
                    TextButton(
                      onPressed: () => _openCorrectionDialog(req),
                      child: const Text("Corriger", style: TextStyle(color: Colors.orange)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: () => _validate(req['id'], req['quantity_declared']),
                      child: const Text("Valider"),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- SOUS-WIDGET : ONGLET LISTE INVENTAIRES ---
class _InventoryListTab extends StatefulWidget {
  const _InventoryListTab();

  @override
  State<_InventoryListTab> createState() => _InventoryListTabState();
}

class _InventoryListTabState extends State<_InventoryListTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // CORRECTION ICI : Utilisation de loadData() au lieu de fetchShops()
      Provider.of<ShopProvider>(context, listen: false).loadData(); 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopProvider>(
      builder: (context, shopProvider, child) {
        if (shopProvider.isLoading) return const Center(child: CircularProgressIndicator());
        
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: shopProvider.shops.length,
          itemBuilder: (ctx, index) {
            final shop = shopProvider.shops[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.shade50,
                  child: const Icon(Icons.store, color: Colors.teal),
                ),
                title: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Cliquez pour voir le stock"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminShopStockScreen(shopId: shop.id, shopName: shop.name),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}