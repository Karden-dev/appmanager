// lib/widgets/shortfall_edit_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/cash_models.dart';
import 'package:wink_manager/models/deliveryman.dart';
import 'package:wink_manager/providers/cash_provider.dart';
import 'package:wink_manager/providers/order_provider.dart'; // Pour searchDeliverymen
import 'package:wink_manager/utils/app_theme.dart';

class ShortfallEditDialog extends StatefulWidget {
  final Shortfall? shortfall; // Null si création

  const ShortfallEditDialog({super.key, this.shortfall});

  @override
  State<ShortfallEditDialog> createState() => _ShortfallEditDialogState();
}

class _ShortfallEditDialogState extends State<ShortfallEditDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _amountController;
  late TextEditingController _commentController;
  late TextEditingController _userSearchController; // Pour l'affichage
  
  int? _selectedDeliverymanId;
  String? _selectedDeliverymanName;
  
  // Ajout : Date sélectionnée
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final s = widget.shortfall;
    
    _amountController = TextEditingController(text: s != null ? s.amount.toStringAsFixed(0) : '');
    _commentController = TextEditingController(text: s?.comment ?? '');
    _userSearchController = TextEditingController();
    
    // Si édition, on utilise la date du manquant
    _selectedDate = s?.createdAt ?? DateTime.now();
    
    if (s != null) {
      _selectedDeliverymanId = s.deliverymanId;
      _selectedDeliverymanName = s.deliverymanName;
      _userSearchController.text = s.deliverymanName;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }
  
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.shortfall != null;

    return AlertDialog(
      title: Text(isEditing ? 'Modifier le manquant' : 'Nouveau manquant'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sélection Livreur (Employé)
              if (!isEditing)
                Autocomplete<Deliveryman>(
                   optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.isEmpty) return const Iterable<Deliveryman>.empty();
                    return await context.read<OrderProvider>().searchDeliverymen(textEditingValue.text);
                  },
                  displayStringForOption: (Deliveryman option) => option.name ?? 'Inconnu',
                  onSelected: (Deliveryman selection) {
                    setState(() {
                      _selectedDeliverymanId = selection.id;
                      _selectedDeliverymanName = selection.name;
                      _userSearchController.text = selection.name ?? '';
                    });
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Livreur concerné',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                        hintText: 'Rechercher un livreur...'
                      ),
                      validator: (val) => _selectedDeliverymanId == null ? 'Sélectionnez un livreur dans la liste' : null,
                    );
                  },
                )
              else
                // Affichage statique en édition
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Livreur", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text(
                              _selectedDeliverymanName ?? 'Inconnu',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
              const SizedBox(height: 16),
              
              // Sélecteur de Date
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date du manquant',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Montant
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.danger),
                decoration: const InputDecoration(
                  labelText: 'Montant (FCFA)',
                  prefixIcon: Icon(Icons.money_off),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Requis';
                  if (double.tryParse(val) == null) return 'Invalide';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Commentaire
              TextFormField(
                controller: _commentController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Motif / Commentaire',
                  prefixIcon: Icon(Icons.comment),
                  border: OutlineInputBorder(),
                ),
                validator: (val) => (val == null || val.isEmpty) ? 'Motif requis' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.danger,
            foregroundColor: Colors.white,
          ),
          child: Text(isEditing ? 'Modifier' : 'Créer'),
        ),
      ],
    );
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<CashProvider>();
      final amount = double.parse(_amountController.text);
      final comment = _commentController.text;

      try {
        if (widget.shortfall != null) {
          // MODE ÉDITION
          await provider.updateShortfall(widget.shortfall!.id, amount, comment);
          if (mounted) {
             Navigator.pop(context);
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Manquant mis à jour"), backgroundColor: Colors.green));
          }
        } else {
          // MODE CRÉATION
          // On s'assure que l'ID du livreur est bien présent et on passe la date choisie
          if (_selectedDeliverymanId != null) {
            await provider.createShortfall(_selectedDeliverymanId!, amount, comment, _selectedDate);
            if (mounted) {
               Navigator.pop(context);
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Manquant créé"), backgroundColor: Colors.green));
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
        }
      }
    }
  }
}