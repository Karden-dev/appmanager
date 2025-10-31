// lib/widgets/return_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/return_tracking.dart';
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';

class ReturnCard extends StatelessWidget {
  final ReturnTracking returnItem;
  final VoidCallback onRefresh;
  final VoidCallback onConfirmReception; // <-- CORRIGÉ: Ajout du paramètre d'action

  const ReturnCard({
    super.key,
    required this.returnItem,
    required this.onRefresh,
    required this.onConfirmReception, // <-- CORRIGÉ
  });

  // Helper pour formater les dates
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(dateTime.toLocal());
  }
  
  // Définit la couleur et l'icône selon le statut de suivi
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_return_to_hub': return Colors.orange.shade700;
      case 'received_at_hub': return Colors.blue.shade700;
      case 'returned_to_shop': return AppTheme.success;
      default: return Colors.grey.shade700;
    }
  }
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending_return_to_hub': return Icons.history_toggle_off;
      case 'received_at_hub': return Icons.inventory_2_outlined;
      case 'returned_to_shop': return Icons.storefront;
      default: return Icons.help_outline;
    }
  }

  // Gère l'action de confirmation de réception au Hub
  void _handleConfirmReception(BuildContext context) async {
     if (!context.mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer Réception'),
        content: Text('Confirmez-vous la réception du colis #${returnItem.orderId} (suivi #${returnItem.trackingId}) au Hub ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            // Ici, on appelle la fonction passée par le parent (AdminHubScreen)
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Confirmer Réception'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      // Déclenche la fonction du parent qui contient la logique API + SnackBar
      onConfirmReception();
    }
  }

  void _showSnackbar(BuildContext context, String message, {bool success = true}) {
     if (!context.mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(message),
         backgroundColor: success ? Colors.green : AppTheme.danger,
       ),
     );
  }

  @override
  Widget build(BuildContext context) {
    final isPendingHub = returnItem.returnStatus == 'pending_return_to_hub';
    final isConfirmedHub = returnItem.returnStatus == 'received_at_hub';

    final statusColor = _getStatusColor(returnItem.returnStatus);
    final statusIcon = _getStatusIcon(returnItem.returnStatus);
    final statusText = returnStatusTranslations[returnItem.returnStatus] ?? returnItem.returnStatus;


    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: statusColor,
          width: 4,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1: Titre & Statut (Gros)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Retour Cde #${returnItem.orderId}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 18),
                    const SizedBox(width: 4),
                    Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            
            // Ligne 2: Infos
            _buildDetailRow(Icons.person_outline, 'Livreur', returnItem.deliverymanName),
            _buildDetailRow(Icons.storefront_outlined, 'Marchand', returnItem.shopName),
            _buildDetailRow(Icons.calendar_today_outlined, 'Déclaré le', _formatDateTime(returnItem.declarationDate)),
            if (returnItem.hubReceptionDate != null)
              _buildDetailRow(Icons.check_circle_outline, 'Reçu au Hub', _formatDateTime(returnItem.hubReceptionDate), valueColor: Colors.blue.shade700),
            
            if (returnItem.comment != null && returnItem.comment!.isNotEmpty)
              _buildCommentRow(returnItem.comment!),
            
            const Divider(height: 16),
            
            // Ligne 3: Bouton d'action
            SizedBox(
              width: double.infinity,
              child: isPendingHub
                  ? ElevatedButton.icon(
                      onPressed: () => _handleConfirmReception(context),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('CONFIRMER RÉCEPTION HUB'),
                    )
                  : (isConfirmedHub 
                      ? ElevatedButton.icon(
                          onPressed: () => _showSnackbar(context, 'Action de remise au Marchand à implémenter.', success: false),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                          icon: const Icon(Icons.storefront),
                          label: const Text('REMIS AU MARCHAND (WIP)'),
                        )
                      : Container(padding: const EdgeInsets.symmetric(vertical: 4), child: Center(child: Text('Suivi Terminé', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600))))
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    // ... (Code inchangé)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text('$label:', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, color: valueColor ?? AppTheme.secondaryColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCommentRow(String comment) {
     // ... (Code inchangé)
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 4.0),
       child: Row(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Icon(Icons.message_outlined, size: 18, color: Colors.grey.shade600),
           const SizedBox(width: 12),
           Expanded(
             child: Text(
               'Motif: "$comment"',
               style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
             ),
           ),
         ],
       ),
     );
  }
}