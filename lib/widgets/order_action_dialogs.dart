// lib/widgets/order_action_dialogs.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/deliveryman.dart'; // Import pour Deliveryman
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';

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

/// Affiche un dialogue contextuel pour changer le statut d'une ou plusieurs commandes.
///
/// [orderIdOrList] peut être un 'int' (ID unique) ou une 'List<int>' (IDs multiples).
/// [status] est le statut cible (ex: 'delivered', 'failed_delivery').
Future<void> showStatusActionDialog(BuildContext context, dynamic orderIdOrList, String status) async {
  final bool isBulk = orderIdOrList is List<int>;
  
  String? paymentStatusResult;
  double? amountResult;
  bool confirmed = false;

  if (status == 'delivered') {
    // --- DIALOGUE POUR 'LIVRÉE' (Style orders.html 'bulkStatusActionModal') ---
    // Demande uniquement Cash ou Mobile Money.
    paymentStatusResult = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isBulk ? 'Statuer Livrée (${orderIdOrList.length} Cdes)' : 'Statuer Livrée (Cde #$orderIdOrList)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sélectionnez le mode de paiement pour ces commandes livrées :'),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Bouton Mobile Money
                  ElevatedButton.icon(
                    icon: const Icon(Icons.phone_android, color: Colors.white),
                    label: const Text('Mobile Money', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context, 'paid_to_supplier'),
                  ),
                  // Bouton Cash
                  ElevatedButton.icon(
                    icon: const Icon(Icons.money, color: Colors.white),
                    label: const Text('Cash', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context, 'cash'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
             TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop(null); // Renvoie null
              },
            ),
          ],
        );
      },
    );
    
    if (paymentStatusResult != null) {
      confirmed = true;
      amountResult = null; // Pas de montant pour 'delivered'
    }

  } else if (status == 'failed_delivery') {
    // --- DIALOGUE POUR 'LIVRAISON RATÉE' (Style orders.html 'bulkFailedDeliveryModal') ---
    // Demande uniquement le montant reçu.
    final TextEditingController amountController = TextEditingController(text: "0");
    final formKey = GlobalKey<FormState>();

    final bool? dialogConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isBulk ? 'Livraison Ratée (${orderIdOrList.length} Cdes)' : 'Livraison Ratée (Cde #$orderIdOrList)'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isBulk 
                  ? 'Montant perçu à appliquer à chaque commande (0 si aucun) :'
                  : 'Montant reçu du client (si paiement partiel) :'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant Récupéré (FCFA)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || double.tryParse(value) == null) {
                      return 'Montant invalide';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              child: const Text('Confirmer'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                   amountResult = double.tryParse(amountController.text) ?? 0.0;
                   Navigator.of(context).pop(true);
                }
              },
            ),
          ],
        );
      },
    );
    
    if (dialogConfirmed == true) {
       confirmed = true;
       paymentStatusResult = 'pending'; // Statut implicite pour 'failed_delivery'
    }

  } else if (status == 'reported') {
    // --- DIALOGUE POUR 'À RELANCER' (Confirmation simple) ---
    confirmed = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
            title: Text(isBulk ? 'Relancer ${orderIdOrList.length} cdes ?' : 'Relancer Cde #$orderIdOrList ?'),
            content: const Text('Confirmez-vous le passage au statut "À Relancer" ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui')),
            ],
        )
    ) ?? false;
    if(confirmed) {
       paymentStatusResult = 'pending';
       amountResult = null;
    }

  } else if (status == 'cancelled') {
    // --- DIALOGUE POUR 'ANNULÉE' (Confirmation simple) ---
     confirmed = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
            title: Text(isBulk ? 'Annuler ${orderIdOrList.length} cdes ?' : 'Annuler Cde #$orderIdOrList ?'),
            content: const Text('Voulez-vous confirmer l\'annulation ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true), 
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                  child: const Text('Oui', style: TextStyle(color: Colors.white))
              ),
            ],
        )
    ) ?? false;
     if(confirmed) {
       paymentStatusResult = 'cancelled';
       amountResult = null;
    }
  }

  // --- Logique API (Utilise les résultats des dialogues ci-dessus) ---
  if (confirmed) {
    if (!context.mounted) return;
    final provider = Provider.of<OrderProvider>(context, listen: false);

    try {
      if (isBulk) {
        // Mode groupé
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mise à jour de ${orderIdOrList.length} commandes...'), duration: const Duration(seconds: 2)),
        );
        
        for (final orderId in orderIdOrList) {
          if (!context.mounted) return;
          await provider.updateOrderStatus(
            orderId,
            status,
            paymentStatus: paymentStatusResult,
            amountReceived: amountResult,
          );
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Statut de ${orderIdOrList.length} commandes mis à jour.'), backgroundColor: AppTheme.success),
          );
        }
      } else {
        // Mode simple
        await provider.updateOrderStatus(
          orderIdOrList,
          status,
          paymentStatus: paymentStatusResult,
          amountReceived: amountResult,
        );
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Statut de Cde #$orderIdOrList mis à jour.'), backgroundColor: AppTheme.success),
          );
        }
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


/// Affiche un dialogue pour assigner un livreur à une ou plusieurs commandes.
///
/// [orderIdOrList] peut être un 'int' (ID unique) ou une 'List<int>' (IDs multiples).
Future<void> showAssignDeliverymanDialog(BuildContext context, dynamic orderIdOrList) async {
  Deliveryman? selectedDeliveryman; 
  final textEditingController = TextEditingController();
  final focusNode = FocusNode();
  
  final bool isBulk = orderIdOrList is List<int>;
  final formKey = GlobalKey<FormState>();

  final bool confirmed = (await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
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
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ],
        content: Form(
          key: formKey, 
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(isBulk 
                  ? 'Assigner ${orderIdOrList.length} commandes' 
                  : 'Assigner Cde #$orderIdOrList'),
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
                        width: MediaQuery.of(context).size.width * 0.7, 
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
        ),
      ); 
    },
  )) ?? false; 
  
  if (confirmed && selectedDeliveryman != null) {
    if (!context.mounted) return;
    final provider = Provider.of<OrderProvider>(context, listen: false);

    try {
      if (isBulk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assignation de ${orderIdOrList.length} commandes...'), duration: const Duration(seconds: 2)),
        );
        
        for (final orderId in orderIdOrList) {
          if (!context.mounted) return;
          await provider.assignOrder(orderId, selectedDeliveryman!.id);
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${orderIdOrList.length} commandes assignées à ${selectedDeliveryman!.name}.'), backgroundColor: AppTheme.success),
          );
        }

      } else {
        await provider.assignOrder(orderIdOrList, selectedDeliveryman!.id); 
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Commande #$orderIdOrList assignée à ${selectedDeliveryman!.name}.'), backgroundColor: AppTheme.success),
          );
        }
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