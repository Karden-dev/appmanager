// lib/screens/admin_shop_stock_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/services/stock_service.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/product_history_dialog.dart';

class AdminShopStockScreen extends StatefulWidget {
  final int shopId;
  final String shopName;

  const AdminShopStockScreen({super.key, required this.shopId, required this.shopName});

  @override
  State<AdminShopStockScreen> createState() => _AdminShopStockScreenState();
}

class _AdminShopStockScreenState extends State<AdminShopStockScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
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
      setState(() {
        _products = data;
        _filteredProducts = data;
      });
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products.where((p) => 
          (p['name'] ?? '').toLowerCase().contains(query.toLowerCase()) ||
          (p['reference'] ?? '').toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
    });
  }

  String _formatAmount(dynamic amount) {
    return "${double.parse(amount.toString()).toStringAsFixed(0)} F";
  }

  @override
  Widget build(BuildContext context) {
    double totalValue = 0;
    for (var p in _products) {
      totalValue += (int.parse(p['quantity'].toString()) * double.parse(p['selling_price'].toString()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Stock : ${widget.shopName}"),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            width: double.infinity,
            child: Column(
              children: [
                const Text("Valeur Totale du Stock (Vente)", style: TextStyle(color: Colors.blue)),
                const SizedBox(height: 4),
                Text(_formatAmount(totalValue), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                Text("${_products.length} références", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Rechercher (Nom, Réf)...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _filter,
            ),
          ),

          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredProducts.isEmpty 
                ? const Center(child: Text("Aucun produit."))
                : ListView.builder(
                    itemCount: _filteredProducts.length,
                    itemBuilder: (ctx, index) {
                      final product = _filteredProducts[index];
                      final qty = int.parse(product['quantity'].toString());
                      final threshold = int.parse(product['alert_threshold'].toString());
                      final bool isLow = qty <= threshold;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          title: Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Réf: ${product['reference']} • ${product['variant'] ?? ''}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "$qty", 
                                    style: TextStyle(
                                      fontSize: 18, 
                                      fontWeight: FontWeight.bold, 
                                      color: isLow ? Colors.red : Colors.green
                                    )
                                  ),
                                  Text(isLow ? "Bas" : "OK", style: TextStyle(fontSize: 10, color: isLow ? Colors.red : Colors.green)),
                                ],
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.history, color: Colors.grey),
                            ],
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => ProductHistoryDialog(
                                productId: product['id'],
                                productName: product['name'],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}