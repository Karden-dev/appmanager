// lib/widgets/order_action_dialogs.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/user.dart'; 
import 'package:wink_manager/models/deliveryman.dart'; // Import pour Deliveryman
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';

// L'alias de type est conservé pour la rétrocompatibilité si d'autres fichiers l'utilisent
// typedef Deliveryman = User; 


// --- Constantes de traduction ---
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

// --- CORRECTION: Ajout du paramètre 'status' ---
Future<void> showStatusActionDialog(BuildContext context, int orderId, String status) async {
  // Définit si des champs supplémentaires sont requis
  final requiresPayment = status == 'delivered' || status == 'failed_delivery';
  String? selectedPaymentStatus;
  TextEditingController amountController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final bool confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('${statusTranslations[status] ?? status} Cde #$orderId'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Confirmez le changement de statut en "${statusTranslations[status] ?? status}".'),
                
                if (requiresPayment) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Statut Paiement',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    initialValue: selectedPaymentStatus,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('En espèces (Cash)')),
                      DropdownMenuItem(value: 'paid_to_supplier', child: Text('Mobile Money (Payé au Marchand)')),
                      DropdownMenuItem(value: 'pending', child: Text('En attente (Non payé)')),
                    ],
                    onChanged: (value) {
                      selectedPaymentStatus = value;
                    },
                    validator: (value) => value == null ? 'Sélection requise' : null,
                  ),
                  
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: status == 'delivered' ? 'Montant Payé par Client (FCFA)' : 'Montant Récupéré par Livreur (FCFA)',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || double.tryParse(value) == null) {
                        return 'Veuillez entrer un montant valide (0 si non applicable)';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Annuler'),
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ),
          ElevatedButton(
            child: const Text('Confirmer'),
            onPressed: () {
              if (requiresPayment) {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              } else {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ],
      );
    },
  ) ?? false;
  
  // --- Logique API après confirmation ---
  if (confirmed) {
    if (!context.mounted) return;
    final provider = Provider.of<OrderProvider>(context, listen: false);

    try {
      final double? amount = double.tryParse(amountController.text);
      
      await provider.updateOrderStatus(
        orderId,
        status,
        paymentStatus: requiresPayment ? selectedPaymentStatus : null,
        amountReceived: requiresPayment ? amount : null,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut de Cde #$orderId mis à jour en ${statusTranslations[status]}.'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur MAJ Statut: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }
}

// --- Boîte de dialogue d'assignation de livreur (inchangée) ---
Future<void> showAssignDeliverymanDialog(BuildContext context, int orderId) async {
  Deliveryman? selectedDeliveryman; 
  final textEditingController = TextEditingController();
  final focusNode = FocusNode();
  final formKey = GlobalKey<FormState>();

  final bool confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        key: formKey, 
        title: Text('Assigner Cde #$orderId'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Sélectionnez un livreur pour assigner cette commande :'),
            const SizedBox(height: 16),
            
            RawAutocomplete<Deliveryman>( 
              focusNode: focusNode,
              textEditingController: textEditingController,
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<Deliveryman>.empty();
                }
                final provider = Provider.of<OrderProvider>(context, listen: false);
                final results = await provider.searchDeliverymen(textEditingValue.text);
                return results; 
              },
              displayStringForOption: (Deliveryman option) => option.name ?? 'Livreur Inconnu',
              fieldViewBuilder: (
                BuildContext context,
                TextEditingController fieldTextEditingController,
                FocusNode fieldFocusNode,
                VoidCallback onFieldSubmitted,
              ) {
                return TextFormField(
                  controller: fieldTextEditingController,
                  focusNode: fieldFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Nom du Livreur',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.delivery_dining),
                  ),
                  validator: (value) {
                    if (selectedDeliveryman == null) {
                      return 'Veuillez sélectionner un livreur.';
                    }
                    return null;
                  },
                );
              },
              optionsViewBuilder: (
                BuildContext context,
                AutocompleteOnSelected<Deliveryman> onSelected,
                Iterable<Deliveryman> options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    child: SizedBox(
                      height: 200.0,
                      width: 300, 
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Deliveryman option = options.elementAt(index);
                          return ListTile(
                            title: Text(option.name ?? 'Livreur Inconnu'),
                            subtitle: Text('ID: ${option.id}'),
                            onTap: () {
                              onSelected(option);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              onSelected: (Deliveryman selection) {
                selectedDeliveryman = selection; 
                textEditingController.text = selection.name ?? 'Livreur Inconnu';
                focusNode.unfocus(); 
              },
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Annuler'),
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ),
          ElevatedButton(
            child: const Text('Assigner'),
            onPressed: () {
              if (selectedDeliveryman != null) {
                Navigator.of(context).pop(true);
              } else {
                textEditingController.clear();
                focusNode.requestFocus();
              }
            },
          ),
        ],
      );
    },
  ) ?? false;
  
  // --- Logique API après confirmation ---
  if (confirmed && selectedDeliveryman != null) {
    if (!context.mounted) return;
    final provider = Provider.of<OrderProvider>(context, listen: false);

    try {
      await provider.assignOrder(orderId, selectedDeliveryman!.id); 
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Commande #$orderId assignée à ${selectedDeliveryman!.name}.'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'assignation: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }
}