import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/providers/order_provider.dart';
// Pour les maps de statut

// --- NOUVEAU MODÈLE: Représente un livreur pour l'Autocomplete ---
class Deliveryman {
  final int id;
  final String name;

  Deliveryman({required this.id, required this.name});

  @override
  String toString() => name; // Utilisé par Autocomplete
}

// --- CORRECTION: Ajout de la map statusTranslations ---
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
// --- FIN CORRECTION ---


// --- DIALOGUE DE STATUT ---
Future<void> showStatusActionDialog(BuildContext context, int orderId, String status) async {
  final provider = Provider.of<OrderProvider>(context, listen: false);

  // Statuts qui demandent une confirmation de paiement
  if (status == 'delivered') {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mode de Paiement (Livrée)'),
        content: const Text('Sélectionnez comment le client a payé :'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleStatusUpdate(context, provider, orderId, status, paymentStatus: 'paid_to_supplier', amountReceived: 0);
            },
            child: const Text('Mobile Money'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleStatusUpdate(context, provider, orderId, status, paymentStatus: 'cash', amountReceived: 0);
            },
            child: const Text('Cash'),
          ),
        ],
      ),
    );
  }
  
  // Statut de base pour Annulée, À relancer, etc.
  if (status == 'cancelled' || status == 'reported') {
    final String paymentStatus = status == 'cancelled' ? 'cancelled' : 'pending';
    
    // --- CORRECTION: Capture du contexte avant l'await ---
    final bool didConfirm = await _confirmAction(context, 'Annuler la commande', 'Êtes-vous sûr de vouloir annuler cette commande ?');
    if (status == 'cancelled' && !didConfirm) return;
    
    // Le contexte est toujours valide ici car on n'a pas utilisé de contexte après l'await
    return _handleStatusUpdate(context, provider, orderId, status, paymentStatus: paymentStatus, amountReceived: 0);
  }

  // Statut Livraison ratée (requiert un montant reçu potentiel)
  if (status == 'failed_delivery') {
    TextEditingController amountController = TextEditingController(text: '0');
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Livraison Ratée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Montant reçu du client (si paiement partiel) :'),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Montant reçu (FCFA)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              Navigator.pop(ctx);
              _handleStatusUpdate(context, provider, orderId, status, amountReceived: amount);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}

// Fonction d'appel API réelle pour le statut
Future<void> _handleStatusUpdate(
    BuildContext context,
    OrderProvider provider,
    int orderId,
    String status,
    {String? paymentStatus, double? amountReceived}) async {
  
  // --- CORRECTION: Capture de ScaffoldMessenger avant l'await ---
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  
  try {
    await provider.updateOrderStatus(
      orderId,
      status,
      paymentStatus: paymentStatus,
      amountReceived: amountReceived,
    );
    
    // --- CORRECTION: Vérification context.mounted après l'await ---
    if (!context.mounted) return;
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Statut mis à jour en ${statusTranslations[status]}!')),
    );
  } catch (e) {
    // --- CORRECTION: Vérification context.mounted après l'await ---
    if (!context.mounted) return;
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Erreur statut: ${e.toString()}'), backgroundColor: Colors.red),
    );
  }
}

// --- DIALOGUE D'ASSIGNATION (Multi-Sélection et Autocomplete) ---
// Accepte un seul ID (int) ou une liste d'IDs (List<int>)
Future<void> showAssignDeliverymanDialog(BuildContext context, dynamic orderIdOrIds) async {
  final provider = Provider.of<OrderProvider>(context, listen: false);
  
  // Conversion en List<int> pour gérer l'assignation multiple
  final List<int> orderIds = (orderIdOrIds is int) 
      ? [orderIdOrIds] 
      : (orderIdOrIds as List<int>);
      
  if (orderIds.isEmpty) return;
  
  Deliveryman? selectedDeliveryman;
  final isMulti = orderIds.length > 1;
  
  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(isMulti 
              ? 'Assigner ${orderIds.length} Commandes' 
              : 'Assigner Commande #${orderIds.first}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sélectionnez le livreur actif pour l\'assignation :',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              // Champ Autocomplete pour les Livreur
              Autocomplete<Deliveryman>(
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                   return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Nom du Livreur',
                      prefixIcon: Icon(Icons.two_wheeler),
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
                  
                  // REMPLACER CECI par l'appel réel au provider: 
                  return await provider.searchDeliverymen(textEditingValue.text);
                },
                displayStringForOption: (Deliveryman option) => option.name,
                onSelected: (Deliveryman selection) {
                  setState(() { selectedDeliveryman = selection; });
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: selectedDeliveryman == null ? null : () async {
                // --- CORRECTION: Capture de Navigator et ScaffoldMessenger avant l'await ---
                final navigator = Navigator.of(ctx);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                try {
                  // Appel API pour assigner (supporte la liste d'IDs)
                  await provider.assignOrders(orderIds, selectedDeliveryman!.id); 

                  // --- CORRECTION: Vérification context.mounted après l'await ---
                  if (!context.mounted) return;
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                        content: Text(isMulti
                            ? 'Assignation de ${orderIds.length} commandes réussie!'
                            : 'Commande #${orderIds.first} assignée avec succès!')),
                  );
                  
                } catch (e) {
                  // --- CORRECTION: Vérification context.mounted après l'await ---
                  if (!context.mounted) return;
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Erreur assignation: ${e.toString()}'), backgroundColor: Colors.red),
                  );
                } finally {
                  // --- CORRECTION: Vérification context.mounted après l'await ---
                  if (context.mounted) {
                     navigator.pop();
                  }
                }
              },
              child: const Text('Assigner'),
            ),
          ],
        );
      },
    ),
  );
}

// Fonction de confirmation générique
Future<bool> _confirmAction(BuildContext context, String title, String content) async {
  // --- CORRECTION: Suppression de la variable 'navigator' inutilisée ---
  // final navigator = Navigator.of(context);

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui')),
      ],
    ),
  );
  
  return result ?? false;
}