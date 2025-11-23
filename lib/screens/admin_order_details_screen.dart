// lib/screens/admin_order_details_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Pour le formatage
import 'package:provider/provider.dart'; // Pour accéder aux traductions
import 'package:url_launcher/url_launcher.dart'; // Import pour les actions d'appel
import 'package:wink_manager/models/admin_order.dart';
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/order_action_dialogs.dart'; 
// Import de la classe publique (corrigé)
import 'package:wink_manager/widgets/admin_order_card.dart'; // Contient OrderCardHelpers

class AdminOrderDetailsScreen extends StatefulWidget {
  final int orderId;

  const AdminOrderDetailsScreen({super.key, required this.orderId});

  @override
  State<AdminOrderDetailsScreen> createState() => _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState extends State<AdminOrderDetailsScreen> {
  Future<AdminOrder>? _orderFuture;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  void _loadOrderDetails() {
    // Charge les détails complets (y compris l'historique) via le provider
    final provider = Provider.of<OrderProvider>(context, listen: false);
    setState(() {
      _orderFuture = provider.fetchOrderById(widget.orderId);
    });
  }

  // Helper pour formater les montants
  String _formatAmount(double amount) {
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(amount);
  }

  // Helper pour formater les dates
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    // S'assure que la date est en heure locale avant de formater
    return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(dateTime.toLocal());
  }

  // --- Fonctions pour les actions d'appel (UrlLauncher) ---
  Future<void> _launchURL(Uri uri) async {
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir $uri'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // Action pour le bouton "Appeler"
  void _callClient(String phoneNumber) {
    final cleanedPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    _launchURL(Uri(scheme: 'tel', path: cleanedPhone));
  }

  // Action pour le bouton "WhatsApp"
  void _whatsAppClient(String phoneNumber) {
    String cleanedPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Logique de formatage pour le Cameroun (identique à riderapp)
    if (cleanedPhone.startsWith('00237') && cleanedPhone.length == 14) {
      cleanedPhone = cleanedPhone.substring(5); // 69...
    } else if (cleanedPhone.startsWith('237') && cleanedPhone.length == 12) {
      cleanedPhone = cleanedPhone.substring(3); // 69...
    } else if (cleanedPhone.length == 10 && cleanedPhone.startsWith('06')) {
       cleanedPhone = cleanedPhone.substring(1); // 69...
    }
    // Si 9 chiffres commençant par 6 ou 2, c'est bon.
    
    final String whatsappNumber = '237$cleanedPhone';
    _launchURL(Uri.parse('https://wa.me/$whatsappNumber'));
  }
  // --- Fin des actions d'appel ---


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminOrder?>(
      future: _orderFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text('Commande #${widget.orderId}')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: Text('Erreur Commande #${widget.orderId}')),
            body: Center(child: Text('Erreur: ${snapshot.error ?? 'Commande non trouvée'}')),
          );
        }

        final order = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text('Détails #${order.id}'),
          ),
          body: RefreshIndicator( 
            onRefresh: () async { _loadOrderDetails(); },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // --- Section Infos Générales ---
                _buildSectionCard(
                  context,
                  title: 'Informations Générales',
                  children: [
                    _buildDetailRow(context, Icons.storefront, 'Marchand', order.shopName),
                    _buildDetailRow(context, Icons.person, 'Client', order.customerName ?? 'N/A'),
                    
                    // --- Ligne Téléphone avec actions (SEULS boutons d'action sur cette page) ---
                    _buildPhoneRow(context, order.customerPhone),
                    // --- FIN Ligne Téléphone ---
                    
                    _buildDetailRow(context, Icons.location_on, 'Lieu Livraison', order.deliveryLocation, maxLines: 2),
                    _buildDetailRow(context, Icons.person_pin_circle_outlined, 'Livreur', order.deliverymanName ?? 'Non assigné'),
                    _buildDetailRow(context, Icons.calendar_today, 'Date Création', _formatDateTime(order.createdAt)),
                  ],
                ),
                const SizedBox(height: 16),
  
                // --- Section Montants et Statuts ---
                _buildSectionCard(
                  context,
                  title: 'Montants et Statuts',
                  children: [
                    _buildDetailRow(context, Icons.receipt_long, 'Montant Articles', _formatAmount(order.articleAmount), valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
                    _buildDetailRow(context, Icons.local_shipping, 'Frais Livraison', _formatAmount(order.deliveryFee)),
                    if (order.expeditionFee > 0)
                      _buildDetailRow(context, Icons.flight_takeoff, 'Frais Expédition', _formatAmount(order.expeditionFee)),
                    const SizedBox(height: 10),
                    _buildStatusBadge(context, order),
                  ],
                ),
                const SizedBox(height: 16),
  
                // --- Section Articles ---
                _buildSectionCard(
                  context,
                  title: 'Articles Commandés',
                  children: [
                    if (order.items.isNotEmpty)
                      ...order.items.map((item) => ListTile(
                            leading: CircleAvatar(child: Text(item.quantity.toString())),
                            title: Text(item.itemName),
                            trailing: Text(_formatAmount(item.amount)),
                            dense: true,
                          ))
                    else
                      const Text('Aucun détail d\'article disponible (Montant global appliqué).'),
                  ],
                ),
                const SizedBox(height: 16),
                
                // --- Section Historique (Implémentée) ---
                _buildSectionCard(
                  context,
                  title: 'Historique de la commande',
                  children: [
                    if (order.history.isEmpty)
                      const Text('Aucun historique disponible pour cette commande.', style: TextStyle(color: Colors.grey))
                    else
                      Column(
                        children: order.history.map((hist) => ListTile(
                              leading: const Icon(Icons.history_toggle_off, size: 20),
                              title: Text(hist.action, style: const TextStyle(fontSize: 14)),
                              subtitle: Text(
                                '${_formatDateTime(hist.createdAt)} par ${hist.userName ?? 'Système'}',
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                              ),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            )).toList(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // *** WIDGETS DE BOUTONS D'ACTION DE STATUT SUPPRIMÉS ***

  Widget _buildSectionCard(BuildContext context, {required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
            const Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  // MODIFICATION 1 : Padding vertical réduit à 4.0
  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value, {int maxLines = 1, TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0), // <-- Espacement réduit
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

  // MODIFICATION 2 : Espacement et boutons d'action corrigés
  Widget _buildPhoneRow(BuildContext context, String phoneNumber) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0), // <-- Espacement réduit pour alignement
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.phone, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text('Tel:', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              phoneNumber,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), // Numéro en gras
            ),
          ),
          // Bouton Appeler (fonctionnel)
          IconButton(
            icon: const Icon(Icons.call, color: AppTheme.success, size: 24), 
            tooltip: 'Appeler',
            onPressed: () => _callClient(phoneNumber),
            padding: const EdgeInsets.symmetric(horizontal: 4), 
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4), 
          // Bouton WhatsApp (fonctionnel)
          IconButton(
            icon: const Icon(Icons.message, color: Colors.green, size: 24), 
            tooltip: 'WhatsApp',
            onPressed: () => _whatsAppClient(phoneNumber),
            padding: const EdgeInsets.symmetric(horizontal: 4), 
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
  // --- FIN WIDGET ---

  Widget _buildStatusBadge(BuildContext context, AdminOrder order) {
    // --- CORRECTION : Utilisation de la classe publique OrderCardHelpers ---
    final statusText = statusTranslations[order.status] ?? order.status;
    final paymentText = OrderCardHelpers.paymentTranslations[order.paymentStatus] ?? order.paymentStatus;
    
    final statusColor = OrderCardHelpers.getStatusColor(order.status);
    final statusIcon = OrderCardHelpers.getStatusIcon(order.status);
    final paymentColor = OrderCardHelpers.getPaymentColor(order.paymentStatus);
    final paymentIcon = OrderCardHelpers.getPaymentIcon(order.paymentStatus);
    // --- FIN CORRECTION ---

    return Column(
      children: [
        Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 18),
            const SizedBox(width: 8),
            Text('Statut:', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(width: 8),
            Expanded(child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(paymentIcon, color: paymentColor, size: 18),
            const SizedBox(width: 8),
            Text('Paiement:', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(width: 8),
            Expanded(child: Text(paymentText, style: TextStyle(color: paymentColor, fontWeight: FontWeight.bold))),
          ],
        ),
        // --- NOUVEAU : Affichage de la date de suivi si présente (followUpAt) ---
        if (order.followUpAt != null)
           Padding(
             padding: const EdgeInsets.only(top: 6.0),
             child: Row(
               children: [
                 Icon(order.status == 'reportee' ? Icons.calendar_today : Icons.redo, size: 18, color: Colors.blue),
                 const SizedBox(width: 8),
                 Text(order.status == 'reportee' ? 'Prochain RDV:' : 'À Relancer Le:', style: TextStyle(color: Colors.grey.shade700)),
                 const SizedBox(width: 8),
                 Expanded(child: Text(_formatDateTime(order.followUpAt), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
               ],
             ),
           ),
        // --- CORRECTION : Affichage du montant reçu (si échec) ---
        // Utilise amountReceived qui est maintenant dans le modèle
        if (order.status == 'failed_delivery' && (order.amountReceived ?? 0.0) > 0) 
           Padding(
             padding: const EdgeInsets.only(top: 6.0),
             child: Row(
               children: [
                 const Icon(Icons.attach_money, size: 18, color: Colors.orange),
                 const SizedBox(width: 8),
                 Text('Montant Reçu (Échec):', style: TextStyle(color: Colors.grey.shade700)),
                 const SizedBox(width: 8),
                 Expanded(child: Text(_formatAmount(order.amountReceived!), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
               ],
             ),
           ),
        // Affichage de la date de récupération
        if (order.pickedUpByRiderAt != null)
           Padding(
             padding: const EdgeInsets.only(top: 6.0),
             child: Row(
               children: [
                 const Icon(Icons.check_box_outlined, size: 18, color: Colors.green),
                 const SizedBox(width: 8),
                 Text('Récupéré:', style: TextStyle(color: Colors.grey.shade700)),
                 const SizedBox(width: 8),
                 Expanded(child: Text(_formatDateTime(order.pickedUpByRiderAt), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
               ],
             ),
           ),
      ],
    );
  }
}