// lib/screens/admin_stock_validation_screen.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/services/stock_service.dart';
import 'package:wink_manager/providers/shop_provider.dart';
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
      backgroundColor: const Color(0xFFF5F7FA), // Fond gris très clair pour le contraste
      appBar: AppBar(
        title: const Text("Gestion des Stocks", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.check_circle_outlined), text: "Validations"),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: "Inventaires"),
          ],
        ),
      ),
      drawer: AppDrawer(selectedIndex: 3, onItemTapped: (i){}),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ValidationTab(),
          _InventoryListTab(),
        ],
      ),
    );
  }
}

// ==============================================================================
// 1. ONGLET VALIDATIONS (Design "Carte Commande" Épuré)
// ==============================================================================
class _ValidationTab extends StatefulWidget {
  const _ValidationTab();

  @override
  State<_ValidationTab> createState() => _ValidationTabState();
}

class _ValidationTabState extends State<_ValidationTab> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final service = Provider.of<StockService>(context, listen: false);
      final data = await service.getPendingRequests();
      if (mounted) {
        setState(() { 
          _allRequests = data; 
          _filterRequests(_searchController.text);
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement demandes: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterRequests(String query) {
    if (query.isEmpty) {
      setState(() => _filteredRequests = _allRequests);
      return;
    }
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredRequests = _allRequests.where((req) {
        final shopName = (req['shop_name'] ?? '').toString().toLowerCase();
        final productName = (req['product_name'] ?? '').toString().toLowerCase();
        final ref = (req['reference'] ?? '').toString().toLowerCase();
        return shopName.contains(lowerQuery) || productName.contains(lowerQuery) || ref.contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> _validate(int requestId, int quantity) async {
    try {
      await Provider.of<StockService>(context, listen: false).validateRequest(requestId, quantity);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Validé avec succès !"), backgroundColor: Colors.green));
      _loadRequests();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _reject(int requestId, String reason) async {
    try {
      await Provider.of<StockService>(context, listen: false).rejectRequest(requestId, reason);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Demande rejetée."), backgroundColor: Colors.orange));
      _loadRequests();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    }
  }

  // --- GESTION IMAGE (Base64 / URL / Placeholder) ---
  Widget _buildImageWidget(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24)
        )
      );
    }

    try {
      // 1. Cas URL Web
      if (imageUrl.startsWith('http')) {
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
        );
      } 
      // 2. Cas Base64 (avec ou sans préfixe data:image)
      else {
        String cleanBase64 = imageUrl;
        if (imageUrl.contains(',')) {
          cleanBase64 = imageUrl.split(',').last;
        }
        // Nettoyage des retours à la ligne potentiels
        cleanBase64 = cleanBase64.replaceAll('\n', '').replaceAll('\r', '');
        
        return Image.memory(
          base64Decode(cleanBase64),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error_outline, color: Colors.red)),
        );
      }
    } catch (e) {
      return const Center(child: Icon(Icons.error, color: Colors.red));
    }
  }

  void _showImageDialog(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.white,
                constraints: const BoxConstraints(maxHeight: 500, maxWidth: 500),
                child: _buildImageWidget(imageUrl),
              ),
            ),
            Positioned(
              top: 5, right: 5,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 18,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
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
              if(qtyController.text.isNotEmpty) _validate(req['id'], int.parse(qtyController.text));
            },
            child: const Text("Valider"),
          )
        ],
      ),
    );
  }

  // --- DESIGN DES BOUTONS CARRÉS ---
  Widget _buildSquareButton({
    required IconData icon, 
    required Color color, 
    required VoidCallback onTap, 
    bool isFilled = false,
    Color? iconColor
  }) {
    return Material(
      color: isFilled ? color : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48, 
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            // Bordure fine si non rempli, pas de bordure si rempli
            border: isFilled ? null : Border.all(color: color.withOpacity(0.5), width: 1.5),
            // Ombre légère si rempli
            boxShadow: isFilled ? [
              BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))
            ] : null,
          ),
          child: Icon(
            icon, 
            color: isFilled ? (iconColor ?? Colors.white) : color, 
            size: 24
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- BARRE DE RECHERCHE ---
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0,2))]
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Rechercher...",
              prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              suffixIcon: _searchController.text.isNotEmpty 
                ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); _filterRequests(''); }) 
                : null
            ),
            onChanged: _filterRequests,
          ),
        ),

        // --- LISTE DES DEMANDES ---
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _filteredRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _allRequests.isEmpty ? "Aucune demande." : "Aucun résultat.",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16)
                      ),
                      if (_allRequests.isNotEmpty)
                         TextButton(onPressed: () { _searchController.clear(); _filterRequests(''); }, child: const Text("Tout afficher"))
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredRequests.length,
                  itemBuilder: (ctx, index) {
                    final req = _filteredRequests[index];
                    final productName = req['product_name'] ?? 'Produit';
                    final variantRef = req['reference']; 

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20), // Coins plus arrondis
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // --- 1. EN-TÊTE (Boutique & Heure) ---
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.store_mall_directory, size: 18, color: Colors.blue.shade700),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    req['shop_name']?.toString().toUpperCase() ?? 'INCONNU', 
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey.shade800),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  DateFormat('dd/MM HH:mm').format(DateTime.parse(req['created_at'])), 
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12)
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // --- 2. CORPS DE LA CARTE ---
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // A. Image (Carré arrondi)
                                GestureDetector(
                                  onTap: () => _showImageDialog(req['proof_image_url']),
                                  child: Container(
                                    width: 64, height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: _buildImageWidget(req['proof_image_url']),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // B. Détails Produit
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        productName, 
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF2D3436)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      // Badge Référence/Variante
                                      if (variantRef != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF3E0), // Orange très pâle
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            variantRef, 
                                            style: const TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.bold) // Orange foncé
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // C. Quantité (Badge Vert)
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9), // Vert très pâle
                                    borderRadius: BorderRadius.circular(12)
                                  ),
                                  child: Column(
                                    children: [
                                      Text("Déclaré", style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                                      Text(
                                        "+${req['quantity_declared']}", 
                                        style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w900, fontSize: 20)
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                            const SizedBox(height: 16),

                            // --- 3. ACTIONS (Boutons Carrés) ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Bouton Rejeter (Croix Rouge)
                                _buildSquareButton(
                                  icon: Icons.close, 
                                  color: Colors.red, 
                                  onTap: () => _reject(req['id'], "Refusé par admin")
                                ),
                                const SizedBox(width: 12),
                                
                                // Bouton Corriger (Crayon Gris/Bleu)
                                _buildSquareButton(
                                  icon: Icons.edit, 
                                  color: Colors.blueGrey, 
                                  onTap: () => _openCorrectionDialog(req)
                                ),
                                const SizedBox(width: 12),
                                
                                // Bouton Valider (Coche Blanche sur fond Vert)
                                _buildSquareButton(
                                  icon: Icons.check, 
                                  color: const Color(0xFF43A047), // Vert Google
                                  isFilled: true,
                                  onTap: () => _validate(req['id'], req['quantity_declared'])
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ==============================================================================
// 2. ONGLET INVENTAIRES (Liste Marchands)
// ==============================================================================
class _InventoryListTab extends StatefulWidget {
  const _InventoryListTab();

  @override
  State<_InventoryListTab> createState() => _InventoryListTabState();
}

class _InventoryListTabState extends State<_InventoryListTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ShopProvider>(context, listen: false).loadData(); 
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopProvider>(
      builder: (context, shopProvider, child) {
        if (shopProvider.isLoading) return const Center(child: CircularProgressIndicator());
        
        final filteredShops = shopProvider.shops.where((shop) {
          return shop.name.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        return Column(
          children: [
            // Recherche
            Container(
               padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
               decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0,2))]),
               child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Rechercher une boutique...",
                  prefixIcon: const Icon(Icons.store_mall_directory, color: Colors.teal),
                  filled: true,
                  fillColor: Colors.teal.shade50.withOpacity(0.3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),

            // Liste
            Expanded(
              child: filteredShops.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), const Text("Aucun résultat.", style: TextStyle(color: Colors.grey))]))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredShops.length,
                    itemBuilder: (ctx, index) {
                      final shop = filteredShops[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(radius: 24, backgroundColor: Colors.teal.shade50, child: Text(shop.name.isNotEmpty ? shop.name[0].toUpperCase() : 'S', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700, fontSize: 18))),
                          title: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: const Row(children: [Icon(Icons.touch_app, size: 14, color: Colors.grey), SizedBox(width: 4), Text("Voir le stock", style: TextStyle(fontSize: 12, color: Colors.grey))]),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminShopStockScreen(shopId: shop.id, shopName: shop.name))),
                        ),
                      );
                    },
                  ),
            ),
          ],
        );
      },
    );
  }
}