// lib/widgets/order_action_dialogs.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/deliveryman.dart'; // Import pour Deliveryman
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:intl/intl.dart'; // NOUVEAU : Import pour le formatage de date

// --- Constantes de traduction ---
const Map<String, String> statusTranslations = {
  'pending': 'En attente',
  'in_progress': 'Assignée',
  'ready_for_pickup': 'Prête',
  'en_route': 'En route',
  'delivered': 'Livrée',
  'cancelled': 'Annulée',
  'failed_delivery': 'Livraison ratée',
  'return_declared': 'Retour déclaré',
  'returned': 'Retournée',
  // *** NOUVELLES CLÉS EXACTES DU BACKEND ***
  'Ne decroche pas': 'Ne décroche pas',
  'Injoignable': 'Injoignable',
  'A relancer': 'À relancer',
  'Reportée': 'Reportée',
  // L'ancienne clé 'reported' est retirée des traductions visibles
};


// --- Dialogue de planification de suivi (Follow Up) ---
Future<DateTime?> _showScheduleFollowUpDialog(
    BuildContext context, dynamic orderIdOrList, String statusKey) async {
  DateTime? selectedDate = DateTime.now();
  TimeOfDay? selectedTime = TimeOfDay.now();
  final String statusText = statusTranslations[statusKey] ?? 'Suivi';
  final bool isBulk = orderIdOrList is List<int>;
  
  // Set initial time to next hour rounded up
  selectedTime = TimeOfDay(hour: (selectedTime.hour + 1) % 24, minute: 0);
  DateTime? finalDateTime;

  await showDialog<DateTime>(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isBulk 
              ? '$statusText ${orderIdOrList.length} Cdes'
              : '$statusText Cde #$orderIdOrList'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Sélectionnez la date et l\'heure de suivi pour le statut "$statusText" :'),
                const SizedBox(height: 24),
                // --- Date Picker ---
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text('Date : ${DateFormat('dd/MM/yyyy').format(selectedDate!)}'),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate!,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null && picked != selectedDate) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                ),
                // --- Time Picker ---
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text('Heure : ${selectedTime!.format(context)}'),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime!,
                    );
                    if (picked != null && picked != selectedTime) {
                      setState(() {
                        selectedTime = picked;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Annuler'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text('Planifier'),
                onPressed: () {
                  final finalDate = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    selectedTime!.hour,
                    selectedTime!.minute,
                  );
                  finalDateTime = finalDate;
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    },
  );
  return finalDateTime;
}


/// Affiche un dialogue contextuel pour changer le statut d'une ou plusieurs commandes.
///
/// [orderIdOrList] peut être un 'int' (ID unique) ou une 'List<int>' (IDs multiples).
/// [status] est le statut cible (ex: 'delivered', 'failed_delivery').
Future<void> showStatusActionDialog(BuildContext context, dynamic orderIdOrList, String status) async {
  final bool isBulk = orderIdOrList is List<int>;
  
  String? paymentStatusResult;
  double? amountResult;
  DateTime? followUpAtResult; 
  bool confirmed = false;

  if (status == 'delivered') {
    // --- DIALOGUE POUR 'LIVRÉE' (Style orders.html 'bulkStatusActionModal') ---
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

  // *** STATUTS DE PLANIFICATION ***
  } else if (status == 'A relancer' || status == 'Reportée') {
     
    final DateTime? scheduledDate = await _showScheduleFollowUpDialog(context, orderIdOrList, status);

    if (scheduledDate != null) {
      confirmed = true;
      followUpAtResult = scheduledDate;
      paymentStatusResult = 'pending'; // Statut implicite
      amountResult = null;
    }
  
  // *** STATUTS D'ÉCHEC DE CONTACT ***
  } else if (status == 'Injoignable' || status == 'Ne decroche pas') {
    final String statusText = statusTranslations[status] ?? 'Erreur';
    
    confirmed = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
            title: Text(isBulk ? '$statusText ${orderIdOrList.length} cdes ?' : '$statusText Cde #$orderIdOrList ?'),
            content: Text('Confirmez-vous le passage au statut "$statusText" ?'),
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
       paymentStatusResult = 'pending';
       amountResult = null;
       followUpAtResult = null; // La date de suivi doit être nulle pour ces statuts
    }

  } else if (status == 'reported') {
    // Statut ancien 'reported' (Conserver la logique au cas où, mais il est retiré de l'interface)
    confirmed = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
            title: Text(isBulk ? 'Relancer ${orderIdOrList.length} cdes ?' : 'Relancer Cde #$orderIdOrList ?'),
            content: const Text('Confirmez-vous le passage au statut "À Relancer (Ancien)" ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui')),
            ],
        )
    ) ?? false;
    if(confirmed) {
       paymentStatusResult = 'pending';
       amountResult = null;
       followUpAtResult = null;
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

    // --- MODIFICATION : Le bloc 'try...catch' gère maintenant les erreurs réseau ---
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
            status, // Utilise la chaîne de statut exacte
            paymentStatus: paymentStatusResult,
            amountReceived: amountResult,
            followUpAt: followUpAtResult, // Passage du followUpAt
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
          status, // Utilise la chaîne de statut exacte
          paymentStatus: paymentStatusResult,
          amountReceived: amountResult,
          followUpAt: followUpAtResult, // Passage du followUpAt
        );
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Statut de Cde #$orderIdOrList mis à jour.'), backgroundColor: AppTheme.success),
          );
        }
      }
    } catch (e) {
      // Si l'une des actions 'provider.updateOrderStatus' échoue (offline),
      // cette 'catch' l'interceptera.
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
                  // Cet appel utilise maintenant le cache-then-network
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

    // --- MODIFICATION : Le bloc 'try...catch' gère maintenant les erreurs réseau ---
    try {
      if (isBulk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assignation de ${orderIdOrList.length} commandes...'), duration: const Duration(seconds: 2)),
        );
        
        // Note : assignOrders gère maintenant les appels API
        await provider.assignOrders(orderIdOrList.toList(), selectedDeliveryman!.id);
        
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
      // Si l'action 'provider.assignOrder' échoue (offline),
      // cette 'catch' l'interceptera.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'assignation: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }
}