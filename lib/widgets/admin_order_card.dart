// lib/widgets/admin_order_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/admin_order.dart';
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/screens/admin_order_details_screen.dart';
import 'package:wink_manager/screens/admin_order_edit_screen.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/order_action_dialogs.dart';

// Classe helper pour les couleurs et icônes (Inchangée)
class OrderCardHelpers {
  static const Map<String, String> paymentTranslations = {
    'pending': 'En attente',
    'cash': 'En espèces',
    'paid_to_supplier': 'Mobile Money',
    'cancelled': 'Annulé'
  };
  static Color getStatusColor(String status) {
    switch (status) {
      case 'delivered': return AppTheme.success;
      case 'cancelled': case 'failed_delivery': case 'return_declared': case 'returned': return AppTheme.danger;
      case 'pending': return Colors.orange.shade700;
      case 'in_progress': case 'ready_for_pickup': return Colors.blue.shade700;
      case 'en_route': return AppTheme.primaryColor;
      case 'reported': return Colors.purple.shade700;
      default: return Colors.grey.shade700;
    }
  }
  static IconData getStatusIcon(String status) {
    switch (status) {
      case 'delivered': return Icons.check_circle_outline;
      case 'cancelled': return Icons.cancel_outlined;
      case 'failed_delivery': return Icons.error_outline;
      case 'return_declared': case 'returned': return Icons.assignment_return_outlined;
      case 'pending': return Icons.pending_outlined;
      case 'in_progress': return Icons.assignment_ind_outlined;
      case 'ready_for_pickup': return Icons.inventory_2_outlined;
      case 'en_route': return Icons.local_shipping_outlined;
      case 'reported': return Icons.report_problem_outlined;
      default: return Icons.help_outline;
    }
  }
  static Color getPaymentColor(String paymentStatus) {
    switch (paymentStatus) {
      case 'pending': return Colors.orange.shade700;
      case 'cash': return AppTheme.success;
      case 'paid_to_supplier': return Colors.blue.shade700;
      case 'cancelled': return AppTheme.danger;
      default: return Colors.grey.shade700;
    }
  }
  static IconData getPaymentIcon(String paymentStatus) {
    switch (paymentStatus) {
      case 'pending': return Icons.hourglass_empty;
      case 'cash': return Icons.money;
      case 'paid_to_supplier': return Icons.phone_android;
      case 'cancelled': return Icons.money_off;
      default: return Icons.help_outline;
    }
  }
}
// Fin Helper

class AdminOrderCard extends StatelessWidget {
  final AdminOrder order;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const AdminOrderCard({
    super.key,
    required this.order,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  String _formatAmount(double amount) {
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(amount);
  }

  // --- Calcul du montant à verser ---
  double _calculatePayoutAmount() {
    if (order.status == 'delivered') {
      if (order.paymentStatus == 'cash') {
        return order.articleAmount - order.deliveryFee - order.expeditionFee;
      } else if (order.paymentStatus == 'paid_to_supplier') {
        return -order.deliveryFee - order.expeditionFee;
      }
    } else if (order.status == 'failed_delivery') {
      return (order.amountReceived ?? 0) - order.deliveryFee - order.expeditionFee;
    }
    return 0; // Pas de versement pour les autres statuts
  }

  // --- Formatage de la liste des articles ---
  String _formatItemsList() {
    if (order.items.isEmpty) {
      return 'Article non spécifié';
    }
    // Prend seulement le premier article pour l'aperçu
    final firstItem = order.items.first;
    String text = '${firstItem.quantity} x ${firstItem.itemName}';
    if (order.items.length > 1) {
      text += '... (+${order.items.length - 1})';
    }
    return text;
  }

  // Gère la logique d'action du menu (Ajout mounted checks)
  void _handleMenuAction(BuildContext context, String action) async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    switch (action) {
      case 'details':
        if (!context.mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrderDetailsScreen(orderId: order.id)));
        break;
      case 'edit':
        if (!context.mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrderEditScreen(order: order)));
        break;
      case 'assign':
        showAssignDeliverymanDialog(context, order.id);
        break;
      case 'status':
        if (order.deliverymanName != null) {
          _showSimpleStatusMenu(context, provider);
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assignez un livreur avant de changer le statut.'), backgroundColor: Colors.orange),
          );
        }
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmer la Suppression'),
            content: Text('Voulez-vous vraiment supprimer la commande #${order.id} ? Cette action est irréversible.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
            false;

        if (confirmed && context.mounted) {
          try {
            await provider.deleteOrder(order.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Commande #${order.id} supprimée.'), backgroundColor: Colors.green),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
            );
          }
        }
        break;
    }
  }

  // Menu de statut simplifié (pour admin) - (Inchangé)
  void _showSimpleStatusMenu(BuildContext context, OrderProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.check_circle_outline, color: OrderCardHelpers.getStatusColor('delivered')),
              title: const Text('Livrée'),
              onTap: () {
                Navigator.pop(ctx);
                showStatusActionDialog(context, order.id, 'delivered');
              },
            ),
            ListTile(
              leading: Icon(Icons.error_outline, color: OrderCardHelpers.getStatusColor('failed_delivery')),
              title: const Text('Livraison Ratée'),
              onTap: () {
                Navigator.pop(ctx);
                showStatusActionDialog(context, order.id, 'failed_delivery');
              },
            ),
            ListTile(
              leading: Icon(Icons.report_problem_outlined, color: OrderCardHelpers.getStatusColor('reported')),
              title: const Text('À Relancer'),
              onTap: () {
                Navigator.pop(ctx);
                showStatusActionDialog(context, order.id, 'reported');
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel_outlined, color: OrderCardHelpers.getStatusColor('cancelled')),
              title: const Text('Annulée'),
              onTap: () {
                Navigator.pop(ctx);
                showStatusActionDialog(context, order.id, 'cancelled');
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // --- LOGIQUE DE STYLE (Nettoyage des variables inutilisées) ---
    final statusColor = OrderCardHelpers.getStatusColor(order.status);
    final statusIcon = OrderCardHelpers.getStatusIcon(order.status);
    final statusText = statusTranslations[order.status] ?? order.status;
    final bool isAssigned = order.deliverymanName != null;
    final bool isPickedUp = order.pickedUpByRiderAt != null;
    final bool canChangeStatus = isAssigned;
    final bool canEdit = !isPickedUp;
    // --- FIN LOGIQUE DE STYLE ---

    // --- CALCUL MONTANT À VERSER ---
    final double payoutAmount = _calculatePayoutAmount();

    return Card(
      elevation: isSelected ? 8 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 3)
            : BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12.0),
        // --- NOUVEAU LAYOUT DE CARTE ---
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), // Padding vertical RÉDUIT
          child: Column(
            children: [
              // Ligne 1: ID, Marchand et Menu (Alignement corrigé)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center, // Alignement vertical au centre
                children: [
                  // ID et Marchand
                  Expanded(
                    child: Text(
                      '#${order.id} - ${order.shopName}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Bouton Menu d'Action
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(context, value),
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                    padding: EdgeInsets.zero, // Padding autour du bouton réduit
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'details',
                        child: ListTile(leading: Icon(Icons.visibility_outlined), title: Text('Détails')),
                      ),
                      PopupMenuItem<String>(
                        value: 'edit',
                        enabled: canEdit,
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined, color: canEdit ? null : Colors.grey),
                          title: Text('Modifier', style: TextStyle(color: canEdit ? null : Colors.grey)),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'assign',
                        child: ListTile(leading: Icon(Icons.delivery_dining_outlined), title: Text('Assigner')),
                      ),
                      PopupMenuItem<String>(
                        value: 'status',
                        enabled: canChangeStatus,
                        child: ListTile(
                          leading: Icon(Icons.rule_outlined, color: canChangeStatus ? null : Colors.grey),
                          title: Text('Statuer', style: TextStyle(color: canChangeStatus ? null : Colors.grey)),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(leading: Icon(Icons.delete_outline, color: AppTheme.danger), title: Text('Supprimer', style: TextStyle(color: AppTheme.danger))),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Ligne 2: Client, Lieu, Article (Espacement réduit)
              _buildDetailRow(context, Icons.person_outline, 'Client', order.customerName ?? order.customerPhone, subtitle: order.customerName != null ? '(${order.customerPhone})' : null),
              const SizedBox(height: 2), // Espacement entre lignes réduit
              _buildDetailRow(context, Icons.location_on_outlined, 'Lieu', order.deliveryLocation),
              const SizedBox(height: 2), // Espacement entre lignes réduit
              _buildDetailRow(context, Icons.shopping_bag_outlined, 'Articles', _formatItemsList()),
              const SizedBox(height: 8),

              // Ligne 3: Montants et "À Verser"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Montants (Article + Frais)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatAmount(order.articleAmount),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Frais: ${_formatAmount(order.deliveryFee)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  // Montant à verser
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatAmount(payoutAmount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: payoutAmount < 0 ? AppTheme.danger : (payoutAmount > 0 ? AppTheme.success : AppTheme.secondaryColor),
                        ),
                      ),
                      Text(
                        'À Verser',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 12), // Séparation réduite

              // Ligne 4: Statut & Livreur
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildStatusBadge(statusIcon, statusText, statusColor),
                  ),
                  Expanded(
                    flex: 3, 
                    // CORRECTION de l'erreur : Ajout du Label 'Livreur' (4ème argument positionnel)
                    child: _buildDetailRow(context, Icons.two_wheeler, 'Livreur', order.deliverymanName ?? 'Non Assigné', iconColor: isAssigned ? AppTheme.secondaryColor : Colors.grey, alignRight: true, isLivreur: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget de détail unifié pour l'alignement
  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value, {Color? iconColor, bool alignRight = false, String? subtitle, bool isLivreur = false}) {
    // Si c'est la ligne du livreur, on utilise un alignement différent
    if (isLivreur) {
        return Row(
          mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: iconColor ?? Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
              textAlign: alignRight ? TextAlign.right : TextAlign.left,
            ),
          ],
        );
    }
    
    // Pour toutes les autres lignes (Client, Lieu, Articles)
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor ?? Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(width: 4), // Espacement réduit entre Label et Valeur
        Expanded(
          child: Text(
            subtitle != null ? '$value $subtitle' : value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }


  // Badge de statut (modifié pour réduire l'espace entre l'icône et le texte)
  Widget _buildStatusBadge(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4), // Espacement réduit
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}