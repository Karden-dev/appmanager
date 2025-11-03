// lib/widgets/hub_order_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wink_manager/models/admin_order.dart';
import 'package:wink_manager/utils/app_theme.dart';
// Pour OrderCardHelpers
import 'package:wink_manager/screens/admin_order_edit_screen.dart'; // Pour la navigation vers l'édition
import 'package:wink_manager/widgets/order_action_dialogs.dart' show statusTranslations; 

class HubOrderCard extends StatelessWidget {
  final AdminOrder order;
  final VoidCallback onMarkAsReady;
  final VoidCallback onRefresh; // Pour forcer le rafraîchissement après une action
  
  const HubOrderCard({
    super.key,
    required this.order,
    required this.onMarkAsReady,
    required this.onRefresh,
  });

  String _formatAmount(double amount) {
    // ... (Code inchangé) ...
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(amount);
  }
  
  // Fonction qui construit la liste DÉTAILLÉE de tous les articles
  Widget _buildItemsList(BuildContext context) {
    // ... (Code inchangé) ...
    if (order.items.isEmpty) {
      return const Text('Aucun article détaillé.', style: TextStyle(fontStyle: FontStyle.italic));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Articles:', style: TextStyle(fontWeight: FontWeight.w600)), 
        const SizedBox(height: 4),
        ...order.items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
          child: Row(
            children: [
              Text('${item.quantity} x ${item.itemName}', style: const TextStyle(fontSize: 13)),
              const Spacer(),
              Text(_formatAmount(item.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        )),
      ],
    );
  }
  
  // Ouvre l'écran d'édition de commande (réutilisation de la logique AdminManager)
  void _openEditScreen(BuildContext context) {
    // ... (Code inchangé) ...
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminOrderEditScreen(order: order), 
      ),
    ).then((_) {
      onRefresh(); 
    });
  }


  @override
  Widget build(BuildContext context) {
    final statusText = statusTranslations[order.status] ?? order.status; 
    final isReady = order.status == 'ready_for_pickup';
    final isInProgress = order.status == 'in_progress';
    final canEdit = order.pickedUpByRiderAt == null; 
    
    // --- AJOUT : Vérification du statut de synchronisation ---
    final bool isSynced = order.isSynced;
    // --- FIN AJOUT ---

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 6.0),
      // --- AJOUT : Griser la carte si non synchronisée ---
      color: isSynced ? Colors.white : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        // Bordure latérale pour le statut
        side: BorderSide(
          color: isReady ? Colors.green.shade700 : (isInProgress ? AppTheme.primaryColor : (isSynced ? Colors.grey.shade300 : Colors.grey.shade700)),
          width: isSynced ? 4 : 5, // Bordure plus épaisse si non sync
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1: Titre, ID, Bouton d'édition
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // --- AJOUT : Icône si non synchronisé ---
                if (!isSynced)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Tooltip(
                      message: 'Modification en attente de synchronisation',
                      child: Icon(Icons.cloud_off_outlined, size: 18, color: Colors.grey.shade700),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${order.id} - ${order.shopName}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        order.deliverymanName ?? 'Non Assigné',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                // Bouton d'édition (visible seulement si non récupérée)
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: canEdit ? AppTheme.secondaryColor : Colors.grey),
                  tooltip: 'Modifier la commande complète',
                  onPressed: canEdit ? () => _openEditScreen(context) : null,
                ),
              ],
            ),
            const Divider(height: 12),
            
            // Ligne 2: Infos de base (Inchangé)
            Row(
              // ... (Code inchangé) ...
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(order.deliveryLocation, style: const TextStyle(fontSize: 13))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              // ... (Code inchangé) ...
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(order.customerPhone, style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),

            // Ligne 3: Liste des articles (détails) (Inchangé)
            _buildItemsList(context),
            
            const Divider(height: 16),
            
            // Ligne 4: Bouton d'action (Marquer comme prêt)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // Action: MarkAsReady (Seulement si in_progress et non récupéré)
                onPressed: isInProgress && canEdit ? onMarkAsReady : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isInProgress ? AppTheme.primaryColor : (isReady ? Colors.green : Colors.grey),
                  foregroundColor: Colors.white,
                ),
                icon: isReady ? const Icon(Icons.check_circle_outline) : const Icon(Icons.inventory_2_outlined),
                label: Text(
                  isReady 
                    ? 'PRÊT POUR RÉCUPÉRATION' 
                    : (isInProgress ? 'MARQUER COMME PRÊT' : statusText.toUpperCase()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}