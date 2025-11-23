// lib/widgets/debt_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wink_manager/models/debt.dart';
import 'package:wink_manager/utils/app_theme.dart';

class DebtCard extends StatelessWidget {
  final Debt debt;
  final VoidCallback? onSettle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const DebtCard({
    super.key,
    required this.debt,
    this.onSettle,
    this.onEdit,
    this.onDelete,
  });

  String _formatAmount(double amount) {
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0)
        .format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'fr_FR').format(date);
  }

  // Configuration visuelle selon le type de dette
  ({String label, IconData icon, Color color}) _getTypeConfig(String type) {
    switch (type) {
      case 'daily_balance':
        return (label: 'Bilan Négatif', icon: Icons.trending_down, color: Colors.orange);
      case 'storage_fee':
        return (label: 'Stockage', icon: Icons.inventory_2_outlined, color: Colors.blue);
      case 'packaging':
        return (label: 'Emballage', icon: Icons.kitchen_outlined, color: Colors.purple);
      case 'expedition':
        return (label: 'Expédition', icon: Icons.local_shipping_outlined, color: Colors.indigo);
      default:
        return (label: 'Autre', icon: Icons.receipt_long_outlined, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPending = debt.status == 'pending';
    final typeConfig = _getTypeConfig(debt.type);
    final bool isManual = debt.type != 'daily_balance';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. EN-TÊTE : Identité Marchand + Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.shopName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.secondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(debt.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                // Indicateur discret si commentaire présent
                if (debt.comment != null && debt.comment!.isNotEmpty)
                  Tooltip(
                    message: debt.comment!,
                    triggerMode: TooltipTriggerMode.tap,
                    child: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // 2. CŒUR : Type + Montant
            Row(
              children: [
                // Icône Type
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: typeConfig.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(typeConfig.icon, color: typeConfig.color, size: 20),
                ),
                const SizedBox(width: 12),
                
                // Libellé Type
                Expanded(
                  child: Text(
                    typeConfig.label,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),

                // Montant
                Text(
                  _formatAmount(debt.amount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isPending ? AppTheme.danger : AppTheme.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            
            // Séparateur pointillé (simulé par Divider)
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 12),

            // 3. PIED : Statut & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Badge Statut
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPending ? Icons.hourglass_empty : Icons.check_circle,
                        size: 12,
                        color: isPending ? Colors.orange.shade800 : Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPending ? "À RÉGLER" : "PAYÉ${debt.settledAt != null ? ' le ${_formatDate(debt.settledAt!)}' : ''}",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPending ? Colors.orange.shade800 : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                if (isPending)
                  Row(
                    children: [
                      // Boutons Modifier/Supprimer (si manuel)
                      if (isManual) ...[
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                          onPressed: onEdit,
                          splashRadius: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                          onPressed: onDelete,
                          splashRadius: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                      ],
                      
                      // Bouton Payer (si action possible)
                      if (onSettle != null)
                        SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: onSettle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text("Régler", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
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