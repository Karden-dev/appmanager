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

  Color _getPaymentColor(String paymentStatus) {
    switch (paymentStatus) {
      case 'pending': return Colors.orange.shade700;
      case 'cash': return Colors.green.shade700;
      case 'paid_to_supplier': return Colors.blue.shade700;
      case 'cancelled': return AppTheme.danger;
      default: return Colors.grey.shade700;
    }
  }

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
    
    if (didConfirm && context.mounted) {
      try {
        await provider.deleteOrder(order.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commande supprimée.'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final theme = Theme.of(context);

    final statusText = statusTranslations[order.status] ?? order.status;
    final paymentText = statusTranslations[order.paymentStatus] ?? order.paymentStatus;
    final statusColor = _getStatusColor(order.status);
    final paymentColor = _getPaymentColor(order.paymentStatus);

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
            // Navigation vers l'écran de détails
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
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Modifier')),
                      ),
                      const PopupMenuItem<String>(
                        value: 'assign',
                        child: ListTile(
                            leading: Icon(Icons.two_wheeler_outlined),
                            title: Text('Assigner')),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'status_delivered',
                        child: ListTile(
                            leading: Icon(Icons.check_circle_outline,
                                color: Colors.green),
                            title: Text('Statuer Livrée')),
                      ),
                      const PopupMenuItem<String>(
                        value: 'status_failed',
                        child: ListTile(
                            leading: Icon(Icons.error_outline,
                                color: Colors.orange),
                            title: Text('Statuer Ratée')),
                      ),
                       const PopupMenuItem<String>(
                        value: 'status_reported',
                        child: ListTile(
                            leading: Icon(Icons.replay_outlined,
                                color: Colors.purple),
                            title: Text('À relancer')),
                      ),
                      const PopupMenuItem<String>(
                        value: 'status_cancelled',
                        child: ListTile(
                            leading: Icon(Icons.cancel_outlined,
                                color: AppTheme.danger),
                            title: Text('Annuler')),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                            leading: Icon(Icons.delete_outline,
                                color: AppTheme.danger),
                            title: Text('Supprimer')),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 8),

              // --- Lignes d'information ---
              _buildInfoRow(Icons.store_outlined, order.shopName),
              _buildInfoRow(Icons.phone_outlined, order.customerPhone),
              _buildInfoRow(Icons.location_on_outlined, order.deliveryLocation),
              _buildInfoRow(Icons.two_wheeler_outlined, order.deliverymanName ?? 'Non assigné',
                  color: order.deliverymanName == null ? Colors.grey : AppTheme.text),
              
              const SizedBox(height: 10),

              // --- Ligne Statut & Paiement ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildStatusBadge(statusText, statusColor),
                  ),
                  Expanded(
                    child: _buildStatusBadge(paymentText, paymentColor,
                        alignment: CrossAxisAlignment.end),
                  ),
                ],
              ),
              
              const Divider(height: 16),
              
              // --- Ligne Montant à verser ---
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

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color ?? AppTheme.text, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color,
      {CrossAxisAlignment alignment = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
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
}