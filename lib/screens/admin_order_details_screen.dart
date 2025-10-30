// lib/screens/admin_order_details_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/admin_order.dart';
import 'package:wink_manager/models/order_history_item.dart';
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/order_action_dialogs.dart'; // Pour les traductions de statut

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
      Provider.of<OrderProvider>(context, listen: false)
          .fetchOrderById(widget.orderId);
    });
  }

  String _formatAmount(double amount) {
    return NumberFormat.currency(
            locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0)
        .format(amount);
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails Cde #${widget.orderId}'),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          if (provider.isDetailLoading || provider.currentDetailOrder == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.currentDetailOrder == null) {
            return Center(child: Text(provider.error!));
          }

          final order = provider.currentDetailOrder!;

          return ListView(
            padding: const EdgeInsets.all(12.0),
            children: [
              _buildInfoCard(order),
              const SizedBox(height: 16),
              _buildFinanceCard(order),
              const SizedBox(height: 16),
              _buildItemsCard(order),
              const SizedBox(height: 16),
              _buildHistoryCard(order.history),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(AdminOrder order) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations Générales',
                style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            _buildDetailRow(context, Icons.storefront, 'Marchand', order.shopName),
            _buildDetailRow(context, Icons.person, 'Client', order.customerName ?? 'N/A'),
            _buildDetailRow(context, Icons.phone, 'Tél. Client', order.customerPhone),
            _buildDetailRow(context, Icons.location_on, 'Lieu Livraison', order.deliveryLocation, maxLines: 2),
            _buildDetailRow(context, Icons.two_wheeler, 'Livreur', order.deliverymanName ?? 'Non assigné'),
            _buildDetailRow(context, Icons.calendar_today, 'Date Création', _formatDateTime(order.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceCard(AdminOrder order) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Montants et Statuts',
                style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            _buildDetailRow(context, Icons.receipt_long, 'Montant Articles', _formatAmount(order.articleAmount),
                valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
            _buildDetailRow(context, Icons.delivery_dining, 'Frais Livraison', _formatAmount(order.deliveryFee)),
            if (order.expeditionFee > 0)
              _buildDetailRow(context, Icons.flight_takeoff, 'Frais Expédition', _formatAmount(order.expeditionFee)),
            
            // Logique du montant à verser
            _buildDetailRow(context, Icons.account_balance_wallet, 'Montant à Verser', _formatAmount(order.payoutAmount),
                valueStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: order.payoutAmount >= 0 ? AppTheme.success : AppTheme.danger,
                  fontSize: 16
                )),

            const Divider(height: 20),
            _buildStatusBadge(context, order),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(AdminOrder order) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Articles Commandés',
                style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            if (order.items.isEmpty)
              const Text('Aucun détail d\'article disponible.')
            else
              ...order.items.map((item) => ListTile(
                    leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryLight,
                        child: Text(item.quantity.toString(),
                            style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold))),
                    title: Text(item.itemName),
                    trailing: Text(_formatAmount(item.amount * item.quantity)),
                    contentPadding: EdgeInsets.zero,
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(List<OrderHistoryItem> history) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historique', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            if (history.isEmpty)
              const Text('Aucun historique disponible.')
            else
              ...history.map((hist) => ListTile(
                    leading: const Icon(Icons.history, color: AppTheme.accentColor),
                    title: Text(hist.action),
                    subtitle: Text(
                        '${_formatDateTime(hist.createdAt)} par ${hist.userName ?? 'Système'}'),
                    contentPadding: EdgeInsets.zero,
                  )),
          ],
        ),
      ),
    );
  }

  // --- Widgets Helpers (copiés de riderapp/order_details_screen.dart) ---

  Widget _buildDetailRow(
      BuildContext context, IconData icon, String label, String value,
      {int maxLines = 1, TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
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
              style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w500),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
            Text('Statut:', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(statusText,
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.bold))),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(paymentIcon, color: paymentColor, size: 18),
            const SizedBox(width: 8),
            Text('Paiement:', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(paymentText,
                    style: TextStyle(
                        color: paymentColor, fontWeight: FontWeight.bold))),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green.shade700;
      case 'cancelled':
      case 'failed_delivery':
      case 'return_declared':
      case 'returned':
        return AppTheme.danger;
      case 'pending':
        return Colors.orange.shade700;
      case 'in_progress':
      case 'ready_for_pickup':
        return Colors.blue.shade700;
      case 'en_route':
        return AppTheme.primaryColor;
      case 'reported':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'delivered':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'failed_delivery':
        return Icons.error_outline;
      case 'return_declared':
      case 'returned':
        return Icons.assignment_return_outlined;
      case 'pending':
        return Icons.pending_outlined;
      case 'in_progress':
        return Icons.assignment_ind_outlined;
      case 'ready_for_pickup':
        return Icons.inventory_2_outlined;
      case 'en_route':
        return Icons.local_shipping_outlined;
      case 'reported':
        return Icons.report_problem_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Color _getPaymentColor(String paymentStatus) {
    switch (paymentStatus) {
      case 'pending':
        return Colors.orange.shade700;
      case 'cash':
        return Colors.green.shade700;
      case 'paid_to_supplier':
        return Colors.blue.shade700;
      case 'cancelled':
        return AppTheme.danger;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getPaymentIcon(String paymentStatus) {
    switch (paymentStatus) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'cash':
        return Icons.money;
      case 'paid_to_supplier':
        return Icons.phone_android;
      case 'cancelled':
        return Icons.money_off;
      default:
        return Icons.help_outline;
    }
  }
}