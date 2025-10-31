// Fichier : lib/widgets/order_action_dialogs.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/admin_order.dart';
import '../providers/order_provider.dart'; 
import '../utils/app_theme.dart';

// Constantes de traduction nécessaires pour d'autres fichiers (ex: AdminOrderCard)
const Map<String, String> statusTranslations = {
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

class OrderActionDialogs {
  // Cette classe n'a pas besoin de constructeur ni de méthodes non-statiques.

  // --- Dialogue 1: Assigner un ou plusieurs commandes ---

  static void showAssignDeliverymanDialog(
      BuildContext context, List<int> orderIds) {
    
    final provider = Provider.of<OrderProvider>(context, listen: false);
    
    // Le type Deliveryman doit être défini dans OrderProvider
    Deliveryman? selectedDeliveryman; 
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            orderIds.length > 1
                ? 'Assigner ${orderIds.length} commandes'
                : 'Assigner la commande',
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Recherchez un livreur:',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  // Utilisation de Autocomplete pour une recherche dynamique
                  Autocomplete<Deliveryman>(
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration( 
                          labelText: 'Nom du Livreur',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (selectedDeliveryman == null || value!.isEmpty) {
                            return 'Livreur requis';
                          }
                          return null;
                        },
                      );
                    },
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Deliveryman>.empty(); 
                      }
                      final List<Deliveryman> result = await provider.searchDeliverymen(textEditingValue.text);
                      return result.cast<Deliveryman>(); 
                    },
                    displayStringForOption: (Deliveryman option) => option.name,
                    onSelected: (Deliveryman selection) {
                      setState(() {
                        selectedDeliveryman = selection;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: selectedDeliveryman == null
                  ? null
                  : () async {
                      if (selectedDeliveryman != null) {
                        final messenger = ScaffoldMessenger.of(ctx);

                        try {
                          await provider.assignOrders(
                              orderIds, selectedDeliveryman!.id);

                          if (!ctx.mounted) return;
                          // FIX: Retrait du 'const' du SnackBar pour utiliser AppTheme.success
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('Commandes assignées avec succès!'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                          Navigator.pop(ctx); 
                        } catch (e) {
                          if (!ctx.mounted) return;
                          // FIX: Retrait du 'const' du SnackBar pour utiliser AppTheme.danger
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Échec assignation: ${e.toString().replaceFirst('Exception: ', '')}'),
                              backgroundColor: AppTheme.danger,
                            ),
                          );
                        }
                      }
                    },
              // FIX: Accès direct à AppTheme.primaryColor
              child: const Text('Assigner', style: TextStyle(color: AppTheme.primaryColor)), 
            ),
          ],
        );
      },
    );
  }

  // --- Dialogue 2: Changer le Statut (pour les détails) ---
  
  static void showChangeStatusMenu(
      BuildContext context, AdminOrder order) { 
    
    final List<String> availableStatuses = _getAvailableStatuses(order.status);

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final provider = Provider.of<OrderProvider>(ctx, listen: false);
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Changer le statut',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              // Ajout du scroll si la liste est longue
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: availableStatuses.map((status) {
                      return ListTile(
                        title: Text(statusTranslations[status]?.toUpperCase() ?? status.toUpperCase()),
                        leading: Icon(_getStatusIcon(status)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showConfirmationDialog(
                              context, order, status, provider);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Affiche un dialogue de confirmation pour le changement de statut
  static void _showConfirmationDialog(BuildContext context, AdminOrder order,
      String newStatus, OrderProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmer le statut: ${statusTranslations[newStatus]?.toUpperCase() ?? newStatus.toUpperCase()}'),
        content: Text(
            'Voulez-vous vraiment changer le statut de la commande #${order.id} à ${statusTranslations[newStatus]?.toUpperCase() ?? newStatus.toUpperCase()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              final messenger = ScaffoldMessenger.of(context);
              
              try {
                await provider.updateOrderStatus(order.id, newStatus);
                
                if (!context.mounted) return;
                // FIX: Retrait du 'const' du SnackBar pour utiliser AppTheme.success
                messenger.showSnackBar(
                  SnackBar(
                      content: Text('Statut de #${order.id} mis à jour.'),
                      backgroundColor: AppTheme.success),
                );
              } catch (e) {
                if (!context.mounted) return;
                // FIX: Retrait du 'const' du SnackBar pour utiliser AppTheme.danger
                messenger.showSnackBar(
                  SnackBar(
                      content: Text('Erreur: ${e.toString().replaceFirst('Exception: ', '')}'),
                      backgroundColor: AppTheme.danger),
                );
              }
            },
            // FIX: Accès direct à AppTheme.primaryColor
            child: const Text('Confirmer',
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }


  // --- Logique utilitaire pour les statuts (Inchangée) ---

  static List<String> _getAvailableStatuses(String currentStatus) {
    const allStatuses = [
      'pending',
      'in_progress',
      'ready_for_pickup',
      'en_route',
      'delivered',
      'reported',
      'failed_delivery',
      'cancelled',
      'return_declared',
      'returned'
    ];
    return allStatuses.where((status) => status != currentStatus).toList();
  }

  static IconData _getStatusIcon(String status) {
    switch (status) {
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
      case 'failed_delivery':
        return Icons.cancel;
      case 'en_route':
        return Icons.delivery_dining;
      case 'ready_for_pickup':
        return Icons.inventory;
      case 'reported':
        return Icons.schedule;
      default:
        return Icons.pending;
    }
  }
}