// lib/screens/admin_shop_stock_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/services/stock_service.dart';
import 'package:wink_manager/widgets/product_history_dialog.dart';
// import 'package:wink_manager/utils/app_theme.dart'; // Décommentez si besoin de couleurs spécifiques du thème

class AdminShopStockScreen extends StatefulWidget {
  final int shopId;
  final String shopName;

  const AdminShopStockScreen({super.key, required this.shopId, required this.shopName});

  @override
  State<AdminShopStockScreen> createState() => _AdminShopStockScreenState();
}

class _AdminShopStockScreenState extends State<AdminShopStockScreen> {
  bool _isLoading = false;
  
  // Données brutes (Liste plate venant de l'API)
  List<Map<String, dynamic>> _allProducts = [];
  
  // Données affichées (Groupées par Nom de produit)
  // Clé : Nom du produit, Valeur : Liste des variantes
  Map<String, List<Map<String, dynamic>>> _groupedDisplay = {};
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    try {
      final data = await Provider.of<StockService>(context, listen: false)
          .getShopInventory(widget.shopId);
      
      if (mounted) {
        setState(() {
          _allProducts = data;
          // Au chargement initial, on groupe tout sans filtre
          _groupedDisplay = _groupProducts(_allProducts);
        });
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  /// Transforme une liste plate en Map groupée par nom
  Map<String, List<Map<String, dynamic>>> _groupProducts(List<Map<String, dynamic>> flatList) {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    
    for (var product in flatList) {
      final name = product['name'] ?? 'Inconnu';
      if (!groups.containsKey(name)) {
        groups[name] = [];
      }
      groups[name]!.add(product);
    }
    
    // Optionnel : Trier les groupes par ordre alphabétique
    final sortedKeys = groups.keys.toList()..sort();
    final Map<String, List<Map<String, dynamic>>> sortedGroups = {};
    for (var key in sortedKeys) {
      sortedGroups[key] = groups[key]!;
    }
    
    return sortedGroups;
  }

  /// Filtre la liste plate puis la regroupe
  void _filter(String query) {
    if (query.isEmpty) {
      setState(() {
        _groupedDisplay = _groupProducts(_allProducts);
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    
    // On garde un produit si son NOM, sa RÉFÉRENCE ou sa VARIANTE contient la recherche
    final filteredList = _allProducts.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final ref = (p['reference'] ?? '').toString().toLowerCase();
      final variant = (p['variant'] ?? '').toString().toLowerCase();
      
      return name.contains(lowerQuery) || ref.contains(lowerQuery) || variant.contains(lowerQuery);
    }).toList();

    setState(() {
      _groupedDisplay = _groupProducts(filteredList);
    });
  }

  String _formatAmount(dynamic amount) {
    return "${double.parse(amount.toString()).toStringAsFixed(0)} F";
  }

  @override
  Widget build(BuildContext context) {
    // Calcul de la valeur totale (sur toute la liste, pas seulement filtrée, pour garder le KPI global)
    double totalValue = 0;
    for (var p in _allProducts) {
      totalValue += (int.parse(p['quantity'].toString()) * double.parse(p['selling_price'].toString()));
    }
    
    // Clés pour l'itération des groupes
    final groupKeys = _groupedDisplay.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Stock : ${widget.shopName}"),
      ),
      body: Column(
        children: [
          // --- KPI : Valeur Totale ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            width: double.infinity,
            child: Column(
              children: [
                const Text("Valeur Totale du Stock (Vente)", style: TextStyle(color: Colors.blue)),
                const SizedBox(height: 4),
                Text(_formatAmount(totalValue), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                Text("${_allProducts.length} références (variantes incluses)", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          
          // --- Barre de Recherche Dynamique ---
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Rechercher (Produit, Variante, Réf)...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: _filter,
            ),
          ),

          // --- Liste Groupée ---
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : groupKeys.isEmpty 
                ? const Center(child: Text("Aucun produit trouvé."))
                : ListView.builder(
                    itemCount: groupKeys.length,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemBuilder: (ctx, index) {
                      final productName = groupKeys[index];
                      final variants = _groupedDisplay[productName]!;
                      
                      // Calculs pour le header du groupe
                      int totalQty = 0;
                      bool hasLowStock = false;
                      
                      for (var v in variants) {
                        final q = int.parse(v['quantity'].toString());
                        final t = int.parse(v['alert_threshold'].toString());
                        totalQty += q;
                        if (q <= t) hasLowStock = true;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Theme(
                          // Supprime les bordures par défaut de l'ExpansionTile
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: hasLowStock ? Colors.red.shade50 : Colors.green.shade50,
                              child: Icon(Icons.inventory_2, color: hasLowStock ? Colors.red : Colors.green, size: 20),
                            ),
                            title: Text(
                              productName, 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                            ),
                            subtitle: Text(
                              "${variants.length} variante(s)", 
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "$totalQty", 
                                  style: TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.bold, 
                                    color: totalQty > 0 ? Colors.black87 : Colors.red
                                  )
                                ),
                                const Text("Total", style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            children: variants.map((variant) => _buildVariantRow(variant)).toList(),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Widget pour afficher une ligne de variante (Enfant de l'accordéon)
  Widget _buildVariantRow(Map<String, dynamic> product) {
    final qty = int.parse(product['quantity'].toString());
    final threshold = int.parse(product['alert_threshold'].toString());
    final bool isLow = qty <= threshold;
    final String variantName = product['variant'] ?? 'Standard';

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        color: Colors.grey.shade50, // Fond légèrement gris pour distinguer l'enfant
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 72, right: 16, top: 0, bottom: 0),
        dense: true,
        title: Text(
          variantName, 
          style: const TextStyle(fontWeight: FontWeight.w600)
        ),
        subtitle: Text("Réf: ${product['reference']} • Seuil: $threshold"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Prix de vente
            Text(
              _formatAmount(product['selling_price']),
              style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 16),
            // Quantité spécifique
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isLow ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "$qty", 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: isLow ? Colors.red : Colors.green
                )
              ),
            ),
            const SizedBox(width: 8),
            // Bouton historique spécifique à la variante
            IconButton(
              icon: const Icon(Icons.history, size: 18, color: Colors.grey),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => ProductHistoryDialog(
                    productId: product['id'],
                    productName: "${product['name']} ($variantName)",
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}