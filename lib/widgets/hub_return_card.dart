// lib/widgets/hub_return_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/return_tracking.dart';
import '../providers/order_provider.dart';
import '../utils/app_theme.dart';

class HubReturnCard extends StatefulWidget {
  final ReturnTracking returnTracking;

  const HubReturnCard({super.key, required this.returnTracking});

  @override
  State<HubReturnCard> createState() => _HubReturnCardState();
}

class _HubReturnCardState extends State<HubReturnCard> {
  // État de chargement local pour le bouton d'action
  bool _isLoading = false; 
  
  // Formatage de la date courte
  final _dateFormatter = DateFormat('dd MMM HH:mm', 'fr_FR');

  // --- Actions ---

  // Action : Marquer comme "Reçu au Hub"
  Future<void> _receiveReturnAtHub() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final provider = Provider.of<OrderProvider>(context, listen: false);
    // Capture des contextes (ScaffoldMessenger) avant l'await
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      await provider.confirmHubReception(widget.returnTracking.trackingId);

      // Vérification 'mounted' après l'await
      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Retour reçu au Hub. Liste mise à jour.'),
          backgroundColor: AppTheme.success,
        ),
      );
      // L'état _isLoading est géré par la reconstruction du provider après confirmation
      
    } catch (error) {
      // Vérification 'mounted' après l'await
      if (!mounted) return;
      
      messenger.showSnackBar(
        SnackBar(
          content: Text('Échec de réception: ${error.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppTheme.danger,
        ),
      );
      // Annule le chargement en cas d'erreur
      setState(() => _isLoading = false);
    }
    // Rétablissement de l'état de chargement si le widget est toujours monté
    if (mounted) {
       setState(() => _isLoading = false);
    }
  }

  // --- Widgets Helpers ---

  // Affiche une ligne d'information simple
  Widget _buildInfoRow(IconData icon, String label, String? text, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$label: ',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                children: [
                  TextSpan(
                    text: text ?? 'N/A',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor ?? AppTheme.text),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  // Mappe le statut à un texte lisible et une couleur
  Map<String, dynamic> _getStatusDisplay(String status) {
    switch (status) {
      case 'return_declared':
        return {'text': 'Déclaré par Livreur', 'color': AppTheme.warning, 'icon': Icons.assignment_return_outlined};
      case 'pending_return_to_hub':
        return {'text': 'En attente Hub (Livreur)', 'color': Colors.orange.shade700, 'icon': Icons.pending_actions_outlined};
      case 'received_at_hub':
        return {'text': 'Reçu au Hub', 'color': AppTheme.info, 'icon': Icons.warehouse_outlined};
      case 'returned_to_shop':
        return {'text': 'Retourné au Marchand', 'color': AppTheme.success, 'icon': Icons.check_circle_outline};
      default:
        return {'text': 'Inconnu', 'color': Colors.grey, 'icon': Icons.help_outline};
    }
  }

  @override
  Widget build(BuildContext context) {
    final rt = widget.returnTracking;
    final statusDisplay = _getStatusDisplay(rt.returnStatus);
    
    // Condition pour afficher le bouton d'action
    final bool canReceive = rt.returnStatus == 'pending_return_to_hub';
    
    final Color borderColor = statusDisplay['color'] as Color;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius / 2),
        border: Border(
          left: BorderSide(
            color: borderColor,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            // CORRECTION: Remplacement de .withOpacity(0.1) par .withAlpha(26)
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Ligne 1: ID de commande et Statut ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cde #${rt.orderId} (Suivi #${rt.trackingId})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.secondaryColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: borderColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(statusDisplay['icon'] as IconData, size: 14, color: borderColor),
                      const SizedBox(width: 4),
                      Text(
                        statusDisplay['text'],
                        style: TextStyle(
                          color: borderColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 10),
            
            // --- Ligne 2: Livreur et Marchand ---
            _buildInfoRow(
              Icons.two_wheeler_outlined,
              'Livreur',
              rt.deliverymanName,
              valueColor: AppTheme.primaryColor,
            ),
            const SizedBox(height: 6),
            _buildInfoRow(
              Icons.storefront,
              'Marchand',
              rt.shopName,
            ),
            
            // --- Ligne 3: Date de déclaration ---
            const SizedBox(height: 6),
            _buildInfoRow(
              Icons.calendar_today_outlined,
              'Déclaré le',
              _dateFormatter.format(rt.declarationDate),
            ),
            
            // --- Ligne 4: Commentaire ---
            if (rt.comment != null && rt.comment!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commentaire:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rt.comment!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.text,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

            // --- Ligne 5: Action (bouton "Recevoir au Hub") ---
            if (canReceive) 
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Center(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _receiveReturnAtHub,
                      icon: _isLoading 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.download_done, size: 18),
                      label: Text(_isLoading ? 'Réception en cours...' : 'Recevoir au Hub'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
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