// lib/screens/admin_remittance_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/cash_models.dart';
import 'package:wink_manager/providers/cash_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';

class AdminRemittanceDetailScreen extends StatefulWidget {
  final int deliverymanId;
  final String deliverymanName;

  const AdminRemittanceDetailScreen({
    super.key,
    required this.deliverymanId,
    required this.deliverymanName,
  });

  @override
  State<AdminRemittanceDetailScreen> createState() =>
      _AdminRemittanceDetailScreenState();
}

class _AdminRemittanceDetailScreenState
    extends State<AdminRemittanceDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Charge les détails au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<CashProvider>()
          .loadRemittanceDetails(widget.deliverymanId);
    });
  }

  // Helper pour le formatage monétaire
  String _formatAmount(double amount) {
    return NumberFormat.currency(
            locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0)
        .format(amount);
  }

  // Fonction de confirmation
  void _confirmRemittance() async {
    final provider = context.read<CashProvider>();
    final amount = provider.totalSelectedAmount;
    final count = provider.selectedOrderIds.length;

    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner au moins une commande.")),
      );
      return;
    }

    // Afficher un dialogue de confirmation
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmer le versement ?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Livreur : ${widget.deliverymanName}"),
            const SizedBox(height: 12),
            Text("Commandes sélectionnées : $count"),
            Text("Montant Total à encaisser :", style: TextStyle(color: Colors.grey.shade700)),
            Text(
              _formatAmount(amount),
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 16),
            const Text(
              "Cette action est irréversible. Assurez-vous d'avoir reçu physiquement le montant indiqué.",
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("CONFIRMER L'ENCAISSEMENT", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await provider.confirmRemittance(widget.deliverymanId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Versement confirmé avec succès !"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CashProvider>();
    final orders = provider.remittanceDetails;
    final isLoading = provider.isLoading;
    final selectedCount = provider.selectedOrderIds.length;
    final totalSelected = provider.totalSelectedAmount;

    // --- CALCULS DES TOTAUX ---
    final confirmedOrders = orders.where((o) => o.status == 'confirmed');
    final pendingOrders = orders.where((o) => o.status != 'confirmed');

    final totalCollected = confirmedOrders.fold(0.0, (sum, item) => sum + item.expectedAmount);
    final totalPending = pendingOrders.fold(0.0, (sum, item) => sum + item.expectedAmount);
    
    // Détermine si on peut tout sélectionner (seulement parmi les non confirmées)
    final allPendingSelected = pendingOrders.isNotEmpty && 
        provider.selectedOrderIds.length == pendingOrders.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Détail versement', style: TextStyle(fontSize: 16)),
            Text(widget.deliverymanName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          if (pendingOrders.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                provider.selectAllOrders(!allPendingSelected);
              },
              icon: Icon(
                allPendingSelected ? Icons.deselect : Icons.select_all,
                color: Colors.white,
              ),
              label: Text(
                allPendingSelected ? "Tout désélectionner" : "Tout sélectionner",
                style: const TextStyle(color: Colors.white),
              ),
            )
        ],
      ),
      body: Column(
        children: [
          // Résumé supérieur
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withAlpha((255 * 0.05).round()),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Déjà Encaissé",
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        _formatAmount(totalCollected),
                        style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.grey.shade600 
                        ), 
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 8)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Total Attendu (Reste)",
                          style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                      Text(
                        _formatAmount(totalPending),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Liste des commandes
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : orders.isEmpty
                    ? const Center(
                        child: Text("Aucune commande en attente de versement.",
                            style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: orders.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final isSelected =
                              provider.selectedOrderIds.contains(order.orderId);
                          return _buildOrderCard(order, isSelected, provider);
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.1).round()),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$selectedCount sélectionnée(s)",
                        style: TextStyle(
                            color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                    Text(
                      _formatAmount(totalSelected),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: ElevatedButton.icon(
                  onPressed: selectedCount > 0 && !isLoading ? _confirmRemittance : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: selectedCount > 0 ? 4 : 0,
                  ),
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text(
                    "ENCAISSER",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NOUVEAU DESIGN DE CARTE (Badge Standard "CONFIRMÉ")
  Widget _buildOrderCard(
      RemittanceOrder order, bool isSelected, CashProvider provider) {
    
    final bool isPaid = order.status == 'confirmed';

    return InkWell(
      onTap: isPaid ? null : () => provider.toggleOrderSelection(order.orderId),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isPaid 
              ? Colors.grey.shade100 
              : (isSelected ? Colors.green.shade50 : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPaid 
                ? Colors.transparent 
                : (isSelected ? Colors.green : Colors.grey.shade200),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (!isPaid) 
              BoxShadow(
                color: isSelected ? Colors.green.withAlpha((255 * 0.2).round()) : Colors.grey.withAlpha((255 * 0.1).round()),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 3),
              )
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête : Marchand et Montant
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.storefront, 
                                  size: 18, 
                                  color: isPaid ? Colors.grey : AppTheme.primaryColor
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    order.shopName ?? "Marchand Inconnu",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 16,
                                        color: isPaid ? Colors.grey : Colors.black87
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Cmd #${order.orderId}",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatAmount(order.expectedAmount),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: isPaid 
                                ? Colors.grey 
                                : (order.expectedAmount > 0 ? AppTheme.primaryColor : Colors.grey)
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: isPaid ? Colors.grey.shade300 : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.deliveryLocation,
                          style: TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.w500,
                            color: isPaid ? Colors.grey : Colors.black87
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 16, color: isPaid ? Colors.grey.shade300 : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.itemNames,
                          style: TextStyle(
                            color: isPaid ? Colors.grey.shade400 : Colors.grey.shade800, 
                            fontSize: 14
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- MODIFICATION : BADGE "CONFIRMÉ" STANDARD (PILULE) ---
            if (isPaid)
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50, // Fond léger
                    borderRadius: BorderRadius.circular(20), // Coins arrondis propres
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        "CONFIRMÉ",
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5, // Espacement léger, pas fantaisiste
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // --- FIN MODIFICATION ---

            if (isSelected && !isPaid)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.check_circle, color: Colors.green.withAlpha((255*0.5).round()), size: 24),
                ),
              ),
          ],
        ),
      ),
    );
  }
}