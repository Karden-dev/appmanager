// Fichier : lib/widgets/admin_order_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:wink_manager/models/admin_order.dart';
import 'package:wink_manager/models/order_item.dart'; // Import est nécessaire pour le type OrderItem
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/screens/admin_order_details_screen.dart';
import 'package:wink_manager/screens/admin_order_edit_screen.dart';
import 'package:wink_manager/utils/app_theme.dart';
// Utilise l'alias 'dialogs' pour accéder à la classe OrderActionDialogs
import 'package:wink_manager/widgets/order_action_dialogs.dart' as dialogs; 

class AdminOrderCard extends StatelessWidget {
  final AdminOrder order;
  final bool isSelected;

  const AdminOrderCard({
    super.key,
    required this.order,
    required this.isSelected,
  });

  // Formatteur de devise
  String _formatAmount(double amount) {
    return NumberFormat.currency(
            locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0)
        .format(amount);
  }
  
  // Widget pour afficher la liste des articles de manière compacte
  Widget _buildItemSummary(List<OrderItem> items) {
    // FIX: Définition de la fonction (était la source de l'avertissement unused_element)
    if (items.isEmpty) return const SizedBox.shrink();

    // Limiter l'affichage à 2 ou 3 articles max pour la carte
    final displayItems = items.take(2).toList();
    final remainingCount = items.length - displayItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Articles:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
        ...displayItems.map((item) => Text(
              '${item.quantity} x ${item.itemName}', 
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            )),
        if (remainingCount > 0)
          Text(
            '+ $remainingCount autre(s) article(s)',
            style: TextStyle(fontSize: 13, color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
      ],
    );
  }

  // Couleurs de statut
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

  // Couleurs de paiement
  Color _getPaymentColor(String paymentStatus) {
    switch (paymentStatus) {
      case 'pending': return Colors.orange.shade700;
      case 'cash': return Colors.green.shade700;
      case 'paid_to_supplier': return Colors.blue.shade700;
      case 'cancelled': return AppTheme.danger;
      default: return Colors.grey.shade700;
    }
  }

  // Affiche la boîte de dialogue de confirmation avant la suppression
  void _showConfirmDeletionDialog(BuildContext context, OrderProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    
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
        if (context.mounted) {
           messenger.showSnackBar(
             const SnackBar(content: Text('Commande supprimée.'), backgroundColor: Colors.green),
           );
        }
      } catch (e) {
        if (context.mounted) {
           messenger.showSnackBar(
             SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
           );
        }
      }
    }
  }

  // Lance un appel ou WhatsApp
  Future<void> _launchURL(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Impossible de lancer $url';
      }
    } catch (e) {
      if (context.mounted) {
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

    final statusText = dialogs.statusTranslations[order.status] ?? order.status;
    final paymentText = dialogs.statusTranslations[order.paymentStatus] ?? order.paymentStatus;
    final statusColor = _getStatusColor(order.status);
    final paymentColor = _getPaymentColor(order.paymentStatus);

    // Logique pour désactiver les actions de statut
    final bool isAssigned = order.deliverymanName != null;
    final bool canBeStatued = isAssigned && ['en_route', 'reported'].contains(order.status);
    final bool canBeCancelled = !['delivered', 'cancelled', 'returned'].contains(order.status);
    
    return Card(
      elevation: isSelected ? 4 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide(color: Colors.grey.shade200, width: 1), // Bordure légère par défaut
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
          padding: const EdgeInsets.fromLTRB(4.0, 8.0, 8.0, 12.0), // Padding ajusté pour le Checkbox
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
                      // --- Logique d'action du Menu ---
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminOrderEditScreen(order: order),
                          ),
                        );
                      } else if (value == 'assign') {
                        dialogs.OrderActionDialogs.showAssignDeliverymanDialog(context, [order.id]);
                      
                      } else if (value == 'status_change') { 
                        dialogs.OrderActionDialogs.showChangeStatusMenu(context, order);

                      } else if (value == 'contact_call') {
                        _launchURL(context, 'tel:${order.clientPhone}');
                      } else if (value == 'contact_whatsapp') {
                         final String cleanedPhone = order.clientPhone.replaceAll(RegExp(r'[^0-9]'), '');
                         final String whatsappNumber = cleanedPhone.startsWith('237') ? cleanedPhone : '237$cleanedPhone';
                        _launchURL(context, 'https://wa.me/$whatsappNumber');
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
                      
                      PopupMenuItem<String>(
                        value: 'status_change',
                        enabled: canBeStatued || canBeCancelled,
                        child: const ListTile(
                            enabled: true,
                            leading: Icon(Icons.published_with_changes_outlined,
                                color: AppTheme.accentColor),
                            title: Text('Changer Statut...')),
                      ),
                      const PopupMenuDivider(),

                      // --- Actions de Contact ---
                      const PopupMenuItem<String>(
                        value: 'contact_call',
                        child: ListTile(
                            leading: Icon(Icons.call_outlined, color: AppTheme.accentColor),
                            title: Text('Appeler Client')),
                      ),
                      const PopupMenuItem<String>(
                        value: 'contact_whatsapp',
                        child: ListTile(
                            leading: Icon(Icons.message_outlined, color: Colors.green),
                            title: Text('WhatsApp Client')),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                            leading: Icon(Icons.delete_outline,
                                color: AppTheme.danger),
                            title: Text('Supprimer')),
                      ),
                    ].cast<PopupMenuEntry<String>>(),
                  ),
                ],
              ),
              const Divider(height: 8, indent: 8, endIndent: 8),

              // --- Lignes d'information ---
              _buildInfoRow(Icons.store_outlined, order.shop.name),
              _buildInfoRow(Icons.phone_outlined, order.clientPhone),
              _buildInfoRow(Icons.location_on_outlined, order.clientAddress, maxLines: 2),
              
              _buildInfoRow(Icons.two_wheeler_outlined, order.deliverymanName ?? 'Non assigné',
                  color: order.deliverymanName == null ? Colors.grey[600] : AppTheme.text),
              
              // FIX: Appel de la fonction pour afficher le résumé des articles
              _buildItemSummary(order.items),

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
              
              // --- Lignes Montants ---
              _buildFinanceRow(theme, 'Montant Article', _formatAmount(order.totalAmount)),
              _buildFinanceRow(theme, 'Frais Livraison', _formatAmount(order.deliveryFee)),
              
              // --- Ligne Montant à verser ---
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Montant à Verser', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(
                      _formatAmount(order.payoutCalculatedAmount),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: order.payoutCalculatedAmount >= 0 ? AppTheme.success : AppTheme.danger,
                      ),
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

  // Retrait des paramètres 'key' inutilisés pour les helpers
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

  // Retrait des paramètres 'key' inutilisés pour les helpers
  Widget _buildStatusBadge(String text, Color color,
      {CrossAxisAlignment alignment = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha((255 * 0.1).round()), 
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

  // Retrait des paramètres 'key' inutilisés pour les helpers
  Widget _buildFinanceRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}