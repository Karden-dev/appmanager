// Fichier : lib/screens/admin_order_details_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Import pour les actions d'appel
import 'package:wink_manager/models/admin_order.dart';
import 'package:wink_manager/models/order_history_item.dart';
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';
// FIX L9: Suppression de l'import non utilisé: // import 'package:wink_manager/models/order_item.dart'; 

class AdminOrderDetailsScreen extends StatefulWidget {
  final int orderId;

  const AdminOrderDetailsScreen({super.key, required this.orderId});

  @override
  State<AdminOrderDetailsScreen> createState() => _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState extends State<AdminOrderDetailsScreen> {
  @override
  void initState() {
    super.initState();
    // Charger les détails au démarrage de l'écran
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).clearError();
      Provider.of<OrderProvider>(context, listen: false)
          .fetchOrderById(widget.orderId);
    });
  }

  // --- Helpers Locaux ---

  String _formatAmount(double amount) {
    return NumberFormat.currency(
            locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0)
        .format(amount);
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(dateTime);
  }

  // CORRECTION (Sévérité 2): Rétablit la vérification 'if (mounted)' sur le State object.
  Future<void> _launchURL(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Impossible de lancer $url';
      }
    } catch (e) {
      // FIX L59: Utilisation de 'mounted' du State object.
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails Cde #${widget.orderId}'),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          // Gère l'état de chargement
          if (provider.isDetailLoading || provider.currentDetailOrder == null || provider.currentDetailOrder!.id != widget.orderId) {
            return const Center(child: CircularProgressIndicator());
          }
          // Gère l'état d'erreur
          if (provider.error != null && provider.currentDetailOrder == null) {
            return Center(child: Text("Erreur de chargement: ${provider.error}"));
          }

          final order = provider.currentDetailOrder!;

          // Affiche le contenu
          return ListView(
            padding: const EdgeInsets.all(12.0),
            children: [
              _buildInfoCard(context, order),
              const SizedBox(height: 16),
              _buildFinanceCard(context, order),
              const SizedBox(height: 16),
              _buildItemsCard(context, order), 
              const SizedBox(height: 16),
              _buildHistoryCard(context, order.history), 
            ],
          );
        },
      ),
    );
  }

  // --- Widgets de construction de section ---

  Widget _buildInfoCard(BuildContext context, AdminOrder order) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations Générales',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, color: theme.colorScheme.primary)),
            const Divider(height: 20),
            _buildDetailRow(context, Icons.storefront, 'Marchand', order.shop.name),
            // FIX L118: Suppression du dead_null_aware_expression (clientName est non-nullable dans le modèle)
            _buildDetailRow(context, Icons.person, 'Client', order.clientName), 
            
            // Ligne Téléphone Client avec Actions
            _buildDetailRow(
              context, 
              Icons.phone, 
              'Tél. Client', 
              order.clientPhone,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.call_outlined, color: AppTheme.success, size: 22),
                    tooltip: 'Appeler le client',
                    onPressed: () => _launchURL(context, 'tel:${order.clientPhone}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.message_outlined, color: Colors.blue, size: 22),
                    tooltip: 'WhatsApp le client',
                    onPressed: () {
                      final String cleanedPhone = order.clientPhone.replaceAll(RegExp(r'[^0-9]'), '');
                      final String whatsappNumber = cleanedPhone.startsWith('237') ? cleanedPhone : '237$cleanedPhone';
                      _launchURL(context, 'https://wa.me/$whatsappNumber');
                    },
                  ),
                ],
              )
            ),
            
            _buildDetailRow(context, Icons.location_on, 'Lieu Livraison', order.clientAddress, maxLines: 2),
            _buildDetailRow(context, Icons.two_wheeler, 'Livreur', order.deliverymanName ?? 'Non assigné'),
            _buildDetailRow(context, Icons.calendar_today, 'Date Création', _formatDateTime(order.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceCard(BuildContext context, AdminOrder order) {
    final theme = Theme.of(context);
    final double? fee = order.expeditionFee;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Montants et Statuts',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, color: theme.colorScheme.primary)),
            const Divider(height: 20),
            _buildDetailRow(context, Icons.receipt_long, 'Montant Articles', _formatAmount(order.totalAmount),
                valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
            _buildDetailRow(context, Icons.delivery_dining, 'Frais Livraison', _formatAmount(order.deliveryFee)),
            
            if (fee != null && fee > 0)
              _buildDetailRow(context, Icons.flight_takeoff, 'Frais Expédition', _formatAmount(fee), 
                  valueStyle: const TextStyle(color: AppTheme.text)),
            
            _buildDetailRow(context, Icons.account_balance_wallet, 'Montant à Verser', _formatAmount(order.payoutCalculatedAmount),
                valueStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: order.payoutCalculatedAmount >= 0 ? AppTheme.success : AppTheme.danger,
                  fontSize: 16
                )),

            const Divider(height: 20),
            _buildStatusBadge(context, order),
          ],
        ),
      ),
    );
  }

  // Widget pour la liste des articles
  Widget _buildItemsCard(BuildContext context, AdminOrder order) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Articles Commandés',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, color: theme.colorScheme.primary)),
            const Divider(height: 20),
            if (order.items.isEmpty)
              const Text('Aucun détail d\'article disponible.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: order.items.length,
                itemBuilder: (context, index) {
                   final item = order.items[index];
                   return ListTile(
                      leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryLight,
                          child: Text(item.quantity.toString(),
                              style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold))),
                      title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Text(_formatAmount(item.amount), style: const TextStyle(fontSize: 13, color: AppTheme.text)),
                      contentPadding: EdgeInsets.zero,
                    );
                },
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 56), 
              ),
          ],
        ),
      ),
    );
  }

  // Widget pour l'historique
  Widget _buildHistoryCard(BuildContext context, List<OrderHistoryItem> history) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historique', style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, color: theme.colorScheme.primary)),
            const Divider(height: 20),
            if (history.isEmpty)
              const Text('Aucun historique disponible.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: history.length,
                itemBuilder: (context, index) {
                   final hist = history.reversed.toList()[index]; 
                   return ListTile(
                      leading: const Icon(Icons.history, color: AppTheme.accentColor, size: 20),
                      title: Text(hist.action, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                          '${_formatDateTime(hist.createdAt)} par ${hist.userName ?? 'Système'}',
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)
                      ),
                      contentPadding: EdgeInsets.zero,
                    );
                },
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 56), 
              ),
          ],
        ),
      ),
    );
  }

  // --- Widgets Helpers ---

  // Helper de ligne modifié pour accepter un 'trailing' widget
  Widget _buildDetailRow(
      BuildContext context, IconData icon, String label, String value,
      {int maxLines = 1, TextStyle? valueStyle, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text('$label:', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing, // Ajoute le widget de fin (ex: boutons)
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, AdminOrder order) {
    final statusText = statusTranslations[order.status] ?? order.status;
    final paymentText = statusTranslations[order.paymentStatus] ?? order.paymentStatus;
    
    final statusColor = _getStatusColor(order.status);
    final statusIcon = _getStatusIcon(order.status);
    final paymentColor = _getPaymentColor(order.paymentStatus);
    final paymentIcon = _getPaymentIcon(order.paymentStatus);

    return Column(
      children: [
        Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 18),
            const SizedBox(width: 8),
            Text('Statut:', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(statusText,
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.bold, fontSize: 14))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(paymentIcon, color: paymentColor, size: 18),
            const SizedBox(width: 8),
            Text('Paiement:', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(paymentText,
                    style: TextStyle(
                        color: paymentColor, fontWeight: FontWeight.bold, fontSize: 14))),
          ],
        ),
      ],
    );
  }

  // Map de traduction de statut (maintenue ici pour la stabilité)
  static const Map<String, String> statusTranslations = {
    'pending': 'En attente',
    'in_progress': 'Assignée',
    'ready_for_pickup': 'Prête',
    'en_route': 'En route',
    'delivered': 'Livrée',
    'cancelled': 'Annulée',
    'failed_delivery': 'Livraison ratée',
    'reported': 'À relancer',
    'return_declared': 'Retour déclaré',
    'returned': 'Retournée'
  };

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
      case 'return_declared':
      case 'returned':
        return Icons.assignment_return_outlined;
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
}