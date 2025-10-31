// lib/widgets/hub_preparation_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/admin_order.dart';
// import '../models/order_item.dart'; // CORRECTION: Import supprimé (Sévérité 4)
import '../providers/order_provider.dart';
import '../screens/admin_order_edit_screen.dart'; 
import '../utils/app_theme.dart';
// CORRECTION: Import de dialogs supprimé (Sévérité 8)

// CORRECTION (Sévérité 8): Ajout de la map localement pour supprimer la dépendance
const Map<String, String> statusTranslations = {
  'pending': 'En attente',
  'in_progress': 'En Préparation', // Statut personnalisé pour le Hub
  'ready_for_pickup': 'Prête',
  'en_route': 'En route',
  'delivered': 'Livrée',
  'cancelled': 'Annulée',
  'failed_delivery': 'Livraison ratée',
  'reported': 'À relancer',
  'return_declared': 'Retour déclaré',
  'returned': 'Retournée'
};


class HubPreparationCard extends StatefulWidget {
  final AdminOrder order;

  const HubPreparationCard({super.key, required this.order});

  @override
  State<HubPreparationCard> createState() => _HubPreparationCardState();
}

class _HubPreparationCardState extends State<HubPreparationCard> {
  bool _isLoading = false; // État de chargement local pour le bouton
  
  // Formatage des montants
  final _currencyFormatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );

  // --- Actions ---

  // Action : Marquer comme "Prête pour ramassage"
  Future<void> _markAsReady() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final provider = Provider.of<OrderProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      await provider.markOrderAsReady(widget.order.id);
      
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Commande #${widget.order.id} marquée comme PRÊTE.'),
          backgroundColor: AppTheme.success,
        ),
      );
      // Le provider va rafraîchir la liste, l'état _isLoading sera réinitialisé par la reconstruction
      
    } catch (error) {
      if (!mounted) return;
      
      messenger.showSnackBar(
        SnackBar(
          content: Text('Échec préparation: ${error.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppTheme.danger,
        ),
      );
      // Annule le chargement localement en cas d'erreur
      if (mounted) {
         setState(() => _isLoading = false);
      }
    }
  }

  // Action : Naviguer vers l'écran d'édition
  void _navigateToEditScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AdminOrderEditScreen(order: widget.order),
      ),
    ).then((_) {
      // CORRECTION (Sévérité 2): Vérification 'mounted' après l'await
      if (!mounted) return;
      
      // Au retour, force le rafraîchissement
      Provider.of<OrderProvider>(context, listen: false)
          .fetchPreparationOrders(forceRefresh: true);
    });
  }

  // --- Widgets Helpers (Style AdminOrderCard) ---

  // Affiche une ligne d'information simple
  Widget _buildInfoRow(IconData icon, String text, {Color? color, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, left: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color ?? AppTheme.text, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: maxLines,
            ),
          ),
        ],
      ),
    );
  }
  
  // Affiche les badges de statut (style riderapp)
  Widget _buildStatusBadge(String text, Color color,
      {CrossAxisAlignment alignment = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(26), // Utilise withAlpha
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Couleurs de statut (simplifié pour le hub)
  Color _getStatusColor(String status) {
    switch (status) {
      case 'ready_for_pickup': return AppTheme.info;
      case 'in_progress': return Colors.orange.shade700;
      default: return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = widget.order;
    
    // Statuts et Logique
    final bool isReady = order.status == 'ready_for_pickup';
    // Utilisation de la map locale
    final statusText = statusTranslations[order.status] ?? order.status;
    final statusColor = _getStatusColor(order.status);

    // Montant à collecter (Total Articles)
    final double amountToCollect = order.totalAmount;
    
    // Premier article pour affichage
    final String firstItem = order.items.isNotEmpty 
      ? "${order.items.first.itemName} (x${order.items.first.quantity})"
      : "Aucun article détaillé";

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4.0, 8.0, 8.0, 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Ligne 1: ID, Montant et Bouton Modifier ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Pas de Checkbox ici, on commence par l'ID
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text(
                    'Cde #${order.id}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                // Montant à collecter (style riderapp)
                Text(
                  _currencyFormatter.format(amountToCollect),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                // Bouton Modifier
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.accentColor, size: 22),
                  tooltip: 'Modifier la commande',
                  onPressed: () => _navigateToEditScreen(context),
                ),
              ],
            ),
            const Divider(height: 8, indent: 8, endIndent: 8),

            // --- Lignes d'information (Style AdminOrderCard) ---
            _buildInfoRow(Icons.store_outlined, order.shop.name),
            _buildInfoRow(Icons.phone_outlined, order.clientPhone),
            _buildInfoRow(Icons.location_on_outlined, order.clientAddress, maxLines: 2),
            _buildInfoRow(Icons.shopping_basket_outlined, firstItem, maxLines: 2),
            
            const SizedBox(height: 10),

            // --- Ligne Statut & Livreur (Style AdminOrderCard) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildStatusBadge(statusText, statusColor),
                ),
                Expanded(
                  child: _buildStatusBadge(
                    order.deliverymanName ?? 'Non assigné', 
                    order.deliverymanName == null ? Colors.grey : AppTheme.secondaryColor,
                    alignment: CrossAxisAlignment.end
                  ),
                ),
              ],
            ),
            
            // --- Ligne 4: Action (Bouton "Marquer Prête") ---
            // Le bouton ne s'affiche que si la commande n'est PAS prête
            if (!isReady)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Center(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      // Le bouton est grisé si _isLoading ou si l'état est déjà 'ready'
                      onPressed: _isLoading ? null : _markAsReady,
                      icon: _isLoading 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(_isLoading ? 'En cours...' : 'Marquer Prête'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}