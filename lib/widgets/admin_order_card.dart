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

// Classe helper pour les couleurs et icônes (Mise à jour pour les nouveaux statuts)
class OrderCardHelpers {
  static const Map<String, String> paymentTranslations = {
    'pending': 'En attente',
    'cash': 'En espèces',
    'paid_to_supplier': 'Mobile Money',
    'cancelled': 'Annulé'
  };
  
  // *** COULEURS UNIQUES POUR LES NOUVEAUX STATUTS ***
  static Color getStatusColor(String status) {
    switch (status) {
      case 'delivered': return AppTheme.success;
      case 'cancelled': case 'failed_delivery': case 'return_declared': case 'returned': return AppTheme.danger;
      case 'pending': return Colors.orange.shade700;
      case 'in_progress': case 'ready_for_pickup': return Colors.blue.shade700;
      case 'en_route': return AppTheme.primaryColor;
      
      case 'A relancer': return Colors.purple.shade700; // Planification (Relance)
      case 'Reportée': return Colors.indigo.shade700; // Planification (Report)
      
      case 'Injoignable': return AppTheme.warning; // Jaune (Alerte douce)
      case 'Ne decroche pas': return Colors.orange.shade800; // Orange foncé (Alerte spécifique/distincte)
      case 'reported': return Colors.grey.shade500; // Couleur pour l'ancien statut s'il est encore dans la DB
      
      default: return Colors.grey.shade700; 
    }
  }
  
  // *** ICÔNES UNIQUES POUR LES NOUVEAUX STATUTS ***
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

      case 'A relancer': return Icons.redo_outlined; 
      case 'Reportée': return Icons.schedule_outlined;
      case 'Injoignable': return Icons.phone_missed_outlined; // Icône distincte
      case 'Ne decroche pas': return Icons.phone_disabled_outlined; // Icône distincte
      case 'reported': return Icons.report_problem_outlined; // Icône pour l'ancien statut
      
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

  // Menu de statut simplifié (pour admin) - MISE À JOUR DES ACTIONS ET LABELS
  void _showSimpleStatusMenu(BuildContext context, OrderProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(OrderCardHelpers.getStatusIcon('delivered'), color: OrderCardHelpers.getStatusColor('delivered')),
              title: const Text('Livrée'),
              onTap: () {
                Navigator.pop(ctx);
                showStatusActionDialog(context, order.id, 'delivered');
              },
            ),
            ListTile(
              leading: Icon(OrderCardHelpers.getStatusIcon('failed_delivery'), color: OrderCardHelpers.getStatusColor('failed_delivery')),
              title: const Text('Livraison Ratée'),
              onTap: () {
                Navigator.pop(ctx);
                showStatusActionDialog(context, order.id, 'failed_delivery');
              },
            ),
            
            // --- NOUVELLES ACTIONS (Sans '(Planifier)', sans 'reported') ---
            ListTile(
              leading: Icon(OrderCardHelpers.getStatusIcon('A relancer'), color: OrderCardHelpers.getStatusColor('A relancer')),
              title: const Text('À Relancer'), // Suppression de (Planifier)
              onTap: () {
                Navigator.pop(ctx);
                showStatusActionDialog(context, order.id, 'A relancer'); 
              },
            ),
            ListTile(
              leading: Icon(OrderCardHelpers.getStatusIcon('Reportée'), color: OrderCardHelpers.getStatusColor('Reportée')),
              title: const Text('Reporter'), // Suppression de (Planifier)
              onTap: () {
                Navigator.pop(ctx);
                showStatusActionDialog(context, order.id, 'Reportée'); 
              },
            ),
            ListTile(
              leading: Icon(OrderCardHelpers.getStatusIcon('Injoignable'), color: OrderCardHelpers.getStatusColor('Injoignable')),
              title: const Text('Injoignable'), 
              onTap: () {
                Navigator.pop(ctx);
                showStatusActionDialog(context, order.id, 'Injoignable'); 
              },
            ),
             ListTile(
              leading: Icon(OrderCardHelpers.getStatusIcon('Ne decroche pas'), color: OrderCardHelpers.getStatusColor('Ne decroche pas')),
              title: const Text('Ne décroche pas'), 
              onTap: () {
                Navigator.pop(ctx);
                showStatusActionDialog(context, order.id, 'Ne decroche pas'); 
              },
            ),
            // --- FIN NOUVELLES ACTIONS ---
            
            // L'ancienne action 'reported' est retirée de l'affichage
            
            ListTile(
              leading: Icon(OrderCardHelpers.getStatusIcon('cancelled'), color: OrderCardHelpers.getStatusColor('cancelled')),
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

    // Récupération du texte de statut depuis order_action_dialogs.dart (maintenant corrigé pour les nouvelles clés)
    final statusColor = OrderCardHelpers.getStatusColor(order.status);
    final statusIcon = OrderCardHelpers.getStatusIcon(order.status);
    final statusText = statusTranslations[order.status] ?? order.status; 
    final bool isAssigned = order.deliverymanName != null;
    final bool isPickedUp = order.pickedUpByRiderAt != null;
    final bool canChangeStatus = isAssigned;
    final bool canEdit = !isPickedUp;
    
    final bool isSynced = order.isSynced;
    final double payoutAmount = _calculatePayoutAmount();

    return Card(
      elevation: isSelected ? 8 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 3)
            : !isSynced
                ? BorderSide(color: Colors.grey.shade600, width: 2.0)
                : BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      color: isSynced ? Colors.white : Colors.grey.shade100,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Column(
            children: [
              // Ligne 1: ID, Marchand et Menu (Alignement corrigé)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center, 
                children: [
                  if (!isSynced)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Tooltip(
                        message: 'Modification en attente de synchronisation',
                        child: Icon(Icons.cloud_off_outlined, size: 18, color: Colors.grey.shade700),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      '#${order.id} - ${order.shopName}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(context, value),
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                    padding: EdgeInsets.zero, 
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
              
              // Ligne 2: Client, Lieu, Article (Inchangé)
              _buildDetailRow(context, Icons.person_outline, 'Client', order.customerName ?? order.customerPhone, subtitle: order.customerName != null ? '(${order.customerPhone})' : null),
              const SizedBox(height: 2),
              _buildDetailRow(context, Icons.location_on_outlined, 'Lieu', order.deliveryLocation),
              const SizedBox(height: 2), 
              _buildDetailRow(context, Icons.shopping_bag_outlined, 'Articles', _formatItemsList()),
              const SizedBox(height: 8),

              // Ligne 3: Montants et "À Verser" (Inchangé)
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

              const Divider(height: 12), 

              // Ligne 4: Statut & Livreur (Inchangé)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildStatusBadge(statusIcon, statusText, statusColor),
                  ),
                  Expanded(
                    flex: 3, 
                    child: _buildDetailRow(context, Icons.two_wheeler, 'Livreur', order.deliverymanName ?? 'Non Assigné', iconColor: isAssigned ? AppTheme.secondaryColor : Colors.grey, alignRight: true, isLivreur: true),
                  ),
                ],
              ),
              
              // *** NOUVEAU : Affichage de la date de suivi (FollowUpAt) ***
              if (order.followUpAt != null) 
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: order.status == 'Reportée' ? Colors.indigo.shade700 : Colors.purple.shade700),
                      const SizedBox(width: 8),
                      Text('Suivi le:', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700)),
                      const SizedBox(width: 4), 
                      Text(
                        DateFormat('dd/MM HH:mm').format(order.followUpAt!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget de détail unifié (Inchangé)
  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value, {Color? iconColor, bool alignRight = false, String? subtitle, bool isLivreur = false}) {
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
        const SizedBox(width: 4), 
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


  // Badge de statut (Inchangé)
  Widget _buildStatusBadge(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4), 
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