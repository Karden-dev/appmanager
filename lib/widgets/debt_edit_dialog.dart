// lib/widgets/debt_edit_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/debt.dart';
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/providers/order_provider.dart'; // Pour la recherche de shops
import 'package:wink_manager/utils/app_theme.dart';

class DebtEditDialog extends StatefulWidget {
  final Debt? debt; // Null si création

  const DebtEditDialog({super.key, this.debt});

  @override
  State<DebtEditDialog> createState() => _DebtEditDialogState();
}

class _DebtEditDialogState extends State<DebtEditDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _amountController;
  late TextEditingController _commentController;
  
  Shop? _selectedShop;
  late DateTime _selectedDate;
  String _selectedType = 'other';

  // Types de créances manuelles (correspondance avec debts.js)
  final Map<String, String> _manualTypes = {
    'other': 'Autre',
    'expedition': 'Frais d\'expédition (manuel)',
    'packaging': 'Frais d\'emballage (manuel)',
    'storage_fee': 'Frais de stockage (manuel)',
  };

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    _amountController = TextEditingController(text: d != null ? d.amount.toStringAsFixed(0) : '');
    _commentController = TextEditingController(text: d?.comment ?? '');
    _selectedDate = d?.createdAt ?? DateTime.now();
    _selectedType = (d != null && _manualTypes.containsKey(d.type)) ? d.type : 'other';
    
    if (d != null) {
      // En mode édition, on pré-remplit le marchand
      _selectedShop = Shop(id: d.shopId, name: d.shopName, phoneNumber: '');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.debt != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(
                  children: [
                    Icon(isEditing ? Icons.edit_note : Icons.add_circle_outline, 
                         color: AppTheme.primaryColor, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      isEditing ? 'Modifier la créance' : 'Nouvelle créance',
                      style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),

                // 1. Sélection Marchand (Autocomplete)
                _buildLabel('Marchand'),
                Autocomplete<Shop>(
                  initialValue: TextEditingValue(text: _selectedShop?.name ?? ''),
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.isEmpty) return const Iterable<Shop>.empty();
                    // On utilise le OrderProvider existant pour la recherche de marchands (évite de dupliquer le code)
                    return await Provider.of<OrderProvider>(context, listen: false)
                        .searchShops(textEditingValue.text);
                  },
                  displayStringForOption: (Shop option) => option.name,
                  onSelected: (Shop selection) {
                    setState(() => _selectedShop = selection);
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      // En mode édition, on empêche de changer le marchand pour garder la cohérence
                      enabled: !isEditing, 
                      style: TextStyle(color: isEditing ? Colors.grey : AppTheme.text),
                      decoration: _inputDecoration(
                        hint: 'Rechercher un marchand...', 
                        icon: Icons.storefront
                      ),
                      validator: (value) {
                        if (_selectedShop == null) return 'Veuillez sélectionner un marchand';
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 2. Montant
                _buildLabel('Montant (FCFA)'),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.danger),
                  decoration: _inputDecoration(hint: 'Ex: 1500', icon: Icons.money_off),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Montant requis';
                    if (double.tryParse(value) == null) return 'Montant invalide';
                    if (double.parse(value) <= 0) return 'Le montant doit être positif';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 3. Type
                _buildLabel('Type de créance'),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: _inputDecoration(hint: 'Choisir...', icon: Icons.category),
                  items: _manualTypes.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: const TextStyle(fontSize: 14)),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedType = val!),
                ),
                const SizedBox(height: 16),

                // 4. Date
                _buildLabel('Date d\'application'),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: _inputDecoration(hint: '', icon: Icons.calendar_today),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Commentaire
                _buildLabel('Commentaire (Optionnel)'),
                TextFormField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: _inputDecoration(hint: 'Détails...', icon: Icons.comment),
                ),

                const SizedBox(height: 24),

                // Boutons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          // Retourne les données au parent pour traitement
                          Navigator.pop(context, {
                            'shop_id': _selectedShop!.id,
                            'amount': double.parse(_amountController.text),
                            'type': _selectedType,
                            'created_at': _selectedDate.toIso8601String(),
                            'comment': _commentController.text.trim(),
                          });
                        }
                      },
                      child: Text(isEditing ? 'Modifier' : 'Créer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 4.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: Colors.grey[500]),
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.danger, width: 1)),
    );
  }
}