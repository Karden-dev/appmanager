// lib/widgets/add_transaction_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/cash_models.dart';
import 'package:wink_manager/models/user.dart'; // Import User pour tous les employés
import 'package:wink_manager/providers/cash_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';

class AddTransactionDialog extends StatefulWidget {
  final CashTransaction? transaction; // Optionnel : Présent si mode Édition

  const AddTransactionDialog({super.key, this.transaction});

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  
  late TextEditingController _amountController;
  late TextEditingController _commentController;
  
  // Pour la dépense (Lié à un User générique)
  int? _selectedUserId;
  String? _selectedUserName;
  int? _selectedCategoryId;
  
  // Ajout : Date sélectionnée
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    
    // Initialisation selon le mode
    _type = t?.type ?? 'expense';
    _amountController = TextEditingController(text: t != null ? t.amount.abs().toStringAsFixed(0) : '');
    _commentController = TextEditingController(text: t?.comment ?? '');
    
    _selectedUserId = t?.userId;
    _selectedUserName = t?.userName;
    _selectedCategoryId = t?.categoryId;
    // Si édition, on reprend la date existante, sinon aujourd'hui
    _selectedDate = t?.createdAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
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
    final provider = context.watch<CashProvider>();
    final isEditing = widget.transaction != null;
    
    return AlertDialog(
      title: Text(isEditing ? 'Modifier l\'opération' : 'Nouvelle Opération'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Type Switcher (Verrouillé en édition)
              if (!isEditing)
                Row(
                  children: [
                    Expanded(child: _buildTypeButton('Dépense', 'expense')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTypeButton('Décaissement', 'manual_withdrawal')),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_type == 'expense' ? Icons.shopping_bag : Icons.outbox, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        _type == 'expense' ? 'Dépense' : 'Décaissement',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ),
                
              const SizedBox(height: 20),
              
              // Sélecteur de Date (Nouveau)
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date de l\'opération',
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

              // Champs spécifiques Dépense
              if (_type == 'expense') ...[
                // Sélection de l'employé (User)
                Autocomplete<User>(
                   optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.isEmpty) return const Iterable<User>.empty();
                    // Recherche dans TOUS les utilisateurs (Admin, Staff, Livreur)
                    return await provider.searchUsers(textEditingValue.text);
                  },
                  displayStringForOption: (User option) => option.name,
                  onSelected: (User selection) {
                    setState(() {
                      _selectedUserId = selection.id;
                      _selectedUserName = selection.name;
                    });
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    if (controller.text.isEmpty && _selectedUserName != null) {
                        controller.text = _selectedUserName!;
                    }
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Bénéficiaire (Employé)',
                        prefixIcon: Icon(Icons.person_search),
                        border: OutlineInputBorder(),
                        hintText: 'Rechercher...'
                      ),
                      validator: (val) => _selectedUserId == null ? 'Sélectionnez un employé' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<int>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(),
                  ),
                  items: provider.categories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  )).toList(),
                  onChanged: isEditing ? null : (val) => setState(() => _selectedCategoryId = val),
                  validator: (val) => val == null ? 'Catégorie requise' : null,
                  disabledHint: Text(
                    _selectedCategoryId != null 
                      ? (provider.categories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => ExpenseCategory(id: 0, name: '...')).name)
                      : 'Catégorie'
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Montant
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Montant (FCFA)',
                  prefixIcon: Icon(Icons.attach_money),
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
                  labelText: 'Commentaire / Motif',
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
            backgroundColor: _type == 'expense' ? AppTheme.primaryColor : AppTheme.danger,
            foregroundColor: Colors.white,
          ),
          child: Text(isEditing ? 'Modifier' : 'Enregistrer'),
        ),
      ],
    );
  }

  Widget _buildTypeButton(String label, String type) {
    final isSelected = _type == type;
    return InkWell(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? (type == 'expense' ? AppTheme.primaryColor : AppTheme.danger) : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<CashProvider>();
      final amount = double.parse(_amountController.text);
      final comment = _commentController.text;

      try {
        if (widget.transaction != null) {
          // MODE ÉDITION
          await provider.updateTransaction(widget.transaction!.id, amount, comment);
          if (mounted) {
             Navigator.pop(context);
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Modification enregistrée"), backgroundColor: Colors.green));
          }
        } else {
          // MODE CRÉATION - Utilise la date sélectionnée
          if (_type == 'expense') {
            await provider.addExpense(_selectedUserId!, _selectedCategoryId!, amount, comment, _selectedDate);
          } else {
             await provider.addWithdrawal(amount, comment, 0, _selectedDate);
          }
          if (mounted) {
             Navigator.pop(context);
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opération enregistrée"), backgroundColor: Colors.green));
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