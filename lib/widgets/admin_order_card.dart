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

class AdminOrderCard extends StatelessWidget {
  final AdminOrder order;
  final bool isSelected;

  const AdminOrderCard({
    super.key,
    required this.order,
    required this.isSelected,
  });

  String _formatAmount(double amount) {
    return NumberFormat.currency(
            locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0)
        .format(amount);
  }

  // --- LOGIQUE DE STATUT (COPIÉE DE admin_order_details_screen) ---
  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered': return Colors.green.shade700;
      case 'cancelled':
      case 'failed_delivery':
      case 'return_declared':
      case 'returned':
        return AppTheme.danger;
      case 'pending': return Colors.orange.shade700;
      case 'in_progress':
      case 'ready_for_pickup':
        return Colors.blue.shade700;
      case 'en_route': return AppTheme.primaryColor;
      case 'reported': return Colors.purple.shade700;
      default: return Colors.grey.shade700;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'delivered': return Icons.check_circle_outline;
      case 'cancelled': return Icons.cancel_outlined;
      case 'failed_delivery': return Icons.error_outline;
      case 'return_declared': return Icons.assignment_return_outlined;
      case 'returned': return Icons.assignment_return_outlined;
      case 'pending': return Icons.pending_outlined;
      case 'in_progress': return Icons.assignment_ind_outlined;
      case 'ready_for_pickup': return Icons.inventory_2_outlined;
      case 'en_route': return Icons.local_shipping_outlined;
      case 'reported': return Icons.report_problem_outlined;
      default: return Icons.help_outline;
    }
  }

  Color _getPaymentColor(String paymentStatus) {
    switch (paymentStatus) {
      case 'pending': return Colors.orange.shade700;
      case 'cash': return Colors.green.shade700;
      case 'paid_to_supplier': return Colors.blue.shade700;
      case 'cancelled': return AppTheme.danger;
      default: return Colors.grey.shade700;
    }
  }
  
  IconData _getPaymentIcon(String paymentStatus) {
    switch (paymentStatus) {
      case 'pending': return Icons.hourglass_empty;
      case 'cash': return Icons.money;
      case 'paid_to_supplier': return Icons.phone_android;
      case 'cancelled': return Icons.money_off;
      default: return Icons.help_outline;
    }
  }
  // --- FIN LOGIQUE DE STATUT ---


  void _showConfirmDeletionDialog(BuildContext context, OrderProvider provider) async {
    final bool didConfirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Supprimer la commande'),
            content: Text(
                'Êtes-vous sûr de vouloir supprimer la commande #${order.id} ? Cette action est irréversible.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Supprimer', style: TextStyle(color: AppTheme.danger)),
              ),
            ],
          ),
        ) ?? false;
    
    // --- CORRECTION: Ajout du 'mounted' check ---
    if (didConfirm && context.mounted) {
      try {
        await provider.deleteOrder(order.id);
        // --- CORRECTION: Nouveau 'mounted' check après l'await ---
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Commande supprimée.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        // --- CORRECTION: Nouveau 'mounted' check après l'await ---
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final theme = Theme.of(context);

    // --- Traduction et couleurs (utilisées par le nouveau style) ---
    final statusText = statusTranslations[order.status] ?? order.status;
    final paymentText = statusTranslations[order.paymentStatus] ?? order.paymentStatus;
    final statusColor = _getStatusColor(order.status);
    final statusIcon = _getStatusIcon(order.status);
    final paymentColor = _getPaymentColor(order.paymentStatus);
    final paymentIcon = _getPaymentIcon(order.paymentStatus);
    
    // --- Logique pour l'article (Nouveau) ---
    String itemSummary = 'Aucun article';
    if (order.items.isNotEmpty) {
      itemSummary = '${order.items.first.quantity} x ${order.items.first.itemName}';
      if (order.items.length > 1) {
        itemSummary += '... (+${order.items.length - 1})';
      }
    }

    // Logique de contrôle des actions (inchangée)
    final bool isAssigned = order.deliverymanName != null;
    final bool canChangeStatus = isAssigned && (order.status == 'en_route' || order.status == 'reported');
    final bool canEdit = order.pickedUpByRiderAt == null;

    return Card(
      elevation: isSelected ? 4 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          if (provider.isSelectionMode) {
            provider.toggleSelection(order.id);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminOrderDetailsScreen(orderId: order.id),
              ),
            );
          }
        },
        onLongPress: () {
          provider.toggleSelection(order.id);
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Ligne 1: Checkbox, ID, Menu ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (bool? value) {
                      provider.toggleSelection(order.id);
                    },
                    activeColor: theme.colorScheme.primary,
                  ),
                  Expanded(
                    child: Text(
                      'Cde #${order.id}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminOrderEditScreen(order: order),
                          ),
                        );
                      } else if (value == 'assign') {
                        showAssignDeliverymanDialog(context, order.id);
                      } else if (value == 'status_delivered') {
                        showStatusActionDialog(context, order.id, 'delivered');
                      } else if (value == 'status_failed') {
                        showStatusActionDialog(context, order.id, 'failed_delivery');
                      } else if (value == 'status_reported') {
                        showStatusActionDialog(context, order.id, 'reported');
                      } else if (value == 'status_cancelled') {
                        showStatusActionDialog(context, order.id, 'cancelled');
                      } else if (value == 'delete') {
                        _showConfirmDeletionDialog(context, provider);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      // --- CORRECTION LINTER: Ajout de 'const' ---
                      PopupMenuItem<String>(
                        value: 'edit',
                        enabled: canEdit, 
                        child: ListTile(
                            leading: Icon(Icons.edit_outlined, color: canEdit ? null : Colors.grey), 
                            title: const Text('Modifier')), // const
                      ),
                      const PopupMenuItem<String>(
                        value: 'assign',
                        child: ListTile(
                            leading: Icon(Icons.two_wheeler_outlined),
                            title: Text('Assigner')),
                      ),
                      const PopupMenuDivider(),
                      // --- CORRECTION LINTER: Ajout de 'const' ---
                      PopupMenuItem<String>(
                        value: 'status_delivered',
                        enabled: canChangeStatus, 
                        child: ListTile(
                            leading: Icon(Icons.check_circle_outline,
                                color: canChangeStatus ? Colors.green : Colors.grey), 
                            title: const Text('Statuer Livrée')), // const
                      ),
                      // --- CORRECTION LINTER: Ajout de 'const' ---
                      PopupMenuItem<String>(
                        value: 'status_failed',
                        enabled: canChangeStatus, 
                        child: ListTile(
                            leading: Icon(Icons.error_outline,
                                color: canChangeStatus ? Colors.orange : Colors.grey), 
                            title: const Text('Statuer Ratée')), // const
                      ),
                       // --- CORRECTION LINTER: Ajout de 'const' ---
                       PopupMenuItem<String>(
                        value: 'status_reported',
                        enabled: canChangeStatus, 
                        child: ListTile(
                            leading: Icon(Icons.replay_outlined,
                                color: canChangeStatus ? Colors.purple : Colors.grey), 
                            title: const Text('À relancer')), // const
                      ),
                      // --- CORRECTION LINTER: Ajout de 'const' ---
                      PopupMenuItem<String>(
                        value: 'status_cancelled',
                        enabled: canChangeStatus, 
                        child: ListTile(
                            leading: Icon(Icons.cancel_outlined,
                                color: canChangeStatus ? AppTheme.danger : Colors.grey), 
                            title: const Text('Annuler')), // const
                      ),
                      const PopupMenuDivider(),
                      // --- CORRECTION LINTER: Ajout de 'const' ---
                      PopupMenuItem<String>(
                        value: 'delete',
                        enabled: canEdit,
                        child: ListTile(
                            leading: Icon(Icons.delete_outline,
                                color: canEdit ? AppTheme.danger : Colors.grey), 
                            title: const Text('Supprimer')), // const
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 8),

              // --- Lignes d'information (MODIFIÉES) ---
              // Appel aux méthodes qui étaient manquantes
              _buildInfoRow(Icons.store_outlined, order.shopName),
              _buildInfoRow(Icons.phone_outlined, order.customerPhone),
              _buildInfoRow(Icons.location_on_outlined, order.deliveryLocation),
              _buildInfoRow(Icons.two_wheeler_outlined, order.deliverymanName ?? 'Non assigné',
                  color: order.deliverymanName == null ? Colors.grey : AppTheme.text),
              
              // --- NOUVELLES LIGNES (ARTICLES ET MONTANTS) ---
              _buildInfoRow(Icons.shopping_bag_outlined, itemSummary, maxLines: 2),
              _buildInfoRow(Icons.receipt_long_outlined, 'Article: ${_formatAmount(order.articleAmount)} | Liv: ${_formatAmount(order.deliveryFee)}',
                  color: AppTheme.secondaryColor, fontWeight: FontWeight.w500),
              
              const SizedBox(height: 10),

              // --- Ligne Statut & Paiement (STYLE MODIFIÉ) ---
              // Appel aux méthodes qui étaient manquantes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusText(statusText, statusIcon, statusColor),
                  _buildStatusText(paymentText, paymentIcon, paymentColor,
                      alignment: CrossAxisAlignment.end),
                ],
              ),
              
              const Divider(height: 16),
              
              // --- Ligne Montant à verser (Inchangée) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Montant à Verser', style: theme.textTheme.bodyMedium),
                  Text(
                    _formatAmount(order.payoutAmount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: order.payoutAmount >= 0 ? AppTheme.success : AppTheme.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DÉFINITION DES MÉTHODES MANQUANTES ---

  /// Widget Helper pour les lignes d'info (Icone + Texte)
  Widget _buildInfoRow(IconData icon, String text, {Color? color, int maxLines = 1, FontWeight? fontWeight}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Alignement au début pour maxLines
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color ?? AppTheme.text, 
                fontSize: 13,
                fontWeight: fontWeight ?? FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: maxLines, // Appliquer maxLines
            ),
          ),
        ],
      ),
    );
  }

  /// Widget Helper pour l'affichage (Icone + Texte) des statuts
  Widget _buildStatusText(String text, IconData icon, Color color,
      {CrossAxisAlignment alignment = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        )
      ],
    );
  }
} // --- FIN DU FICHIER ---