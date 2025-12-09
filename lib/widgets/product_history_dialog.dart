// lib/widgets/product_history_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/services/stock_service.dart';
import 'package:wink_manager/utils/app_theme.dart';

class ProductHistoryDialog extends StatefulWidget {
  final int productId;
  final String productName;

  const ProductHistoryDialog({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<ProductHistoryDialog> createState() => _ProductHistoryDialogState();
}

class _ProductHistoryDialogState extends State<ProductHistoryDialog> {
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = Provider.of<StockService>(context, listen: false)
        .getProductHistory(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Historique : ${widget.productName}", style: const TextStyle(fontSize: 18)),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Erreur: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
            }
            final history = snapshot.data ?? [];

            if (history.isEmpty) {
              return const Center(child: Text("Aucun mouvement enregistré."));
            }

            return ListView.separated(
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, index) {
                final move = history[index];
                final date = DateTime.parse(move['created_at']);
                final type = move['type'];
                final quantity = move['quantity'] as int;
                
                String author = "Inconnu";
                if (move['admin_name'] != null) {
                  author = "Admin: ${move['admin_name']}";
                } else if (move['staff_name'] != null) {
                  author = "Staff: ${move['staff_name']}";
                } else if (move['performed_by_staff_id'] != null) {
                   author = "Marchand";
                }

                IconData icon;
                Color color;
                String label;

                switch (type) {
                  case 'entry':
                    icon = Icons.download;
                    color = Colors.green;
                    label = "Entrée";
                    break;
                  case 'sale':
                    icon = Icons.upload;
                    color = Colors.blue;
                    label = "Vente";
                    break;
                  case 'adjustment':
                    icon = Icons.tune;
                    color = Colors.orange;
                    label = "Ajustement";
                    break;
                  case 'return':
                    icon = Icons.replay;
                    color = Colors.purple;
                    label = "Retour";
                    break;
                  default:
                    icon = Icons.circle;
                    color = Colors.grey;
                    label = type;
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        quantity > 0 ? "+$quantity" : "$quantity",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: quantity > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Stock: ${move['stock_before']} ➔ ${move['stock_after']}"),
                      Text(
                        "${DateFormat('dd/MM HH:mm').format(date)} • $author",
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Fermer"),
        )
      ],
    );
  }
}