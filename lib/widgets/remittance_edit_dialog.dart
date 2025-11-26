// lib/widgets/remittance_edit_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wink_manager/models/remittance.dart';
import 'package:wink_manager/utils/app_theme.dart';

class RemittanceEditDialog extends StatefulWidget {
  final Remittance remittance;

  const RemittanceEditDialog({super.key, required this.remittance});

  @override
  State<RemittanceEditDialog> createState() => _RemittanceEditDialogState();
}

class _RemittanceEditDialogState extends State<RemittanceEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  String? _selectedOperator;

  final List<String> _operators = ['Orange Money', 'MTN Mobile Money'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.remittance.paymentName);
    _phoneController = TextEditingController(text: widget.remittance.phoneNumberForPayment);
    
    if (_operators.contains(widget.remittance.paymentOperator)) {
      _selectedOperator = widget.remittance.paymentOperator;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Utilisation de Dialog au lieu de AlertDialog pour un contrôle total du design
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20), // Marge autour de la modale
      child: SingleChildScrollView( // EMPÊCHE L'OVERFLOW
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre
                Row(
                  children: [
                    Icon(Icons.edit_note, color: AppTheme.primaryColor, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Modifier les infos', 
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.remittance.shopName, 
                            style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Divider(height: 30),

                // Champ Nom
                _buildLabel('Nom du compte'),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  decoration: _inputDecoration(hint: 'Ex: Essomba Jean', icon: Icons.person_outline),
                  validator: (value) => (value == null || value.isEmpty) ? 'Nom requis' : null,
                ),
                const SizedBox(height: 16),

                // Champ Téléphone
                _buildLabel('Téléphone'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                    _PhoneNumberFormatter(),
                  ],
                  decoration: _inputDecoration(hint: '6 XX XX XX XX', icon: Icons.phone_android),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Numéro requis';
                    if (value.length < 13) return '9 chiffres requis';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Champ Opérateur
                _buildLabel('Opérateur'),
                DropdownButtonFormField<String>(
                  value: _selectedOperator,
                  decoration: _inputDecoration(hint: 'Choisir...', icon: Icons.payment),
                  items: _operators.map((op) {
                    Color opColor = op == 'Orange Money' ? Colors.orange : const Color(0xFFffcc00);
                    return DropdownMenuItem(
                      value: op,
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: opColor),
                          const SizedBox(width: 8),
                          Text(op, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedOperator = val),
                  validator: (value) => value == null ? 'Opérateur requis' : null,
                ),
                
                const SizedBox(height: 24),

                // Boutons d'action
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.pop(context, {
                              'name': _nameController.text.trim(),
                              'phone': _phoneController.text.replaceAll(' ', ''), 
                              'operator': _selectedOperator,
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Enregistrer'),
                      ),
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

  // Helper pour le style des labels
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 4.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
      ),
    );
  }

  // Helper pour le style des inputs (Cohérent)
  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: Colors.grey[500]),
      filled: true,
      fillColor: const Color(0xFFF8F9FA), // Gris très léger
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
    );
  }
}

// Formatter Strict : X XX XX XX XX
class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    if (text.isEmpty) return newValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 0 || i == 2 || i == 4 || i == 6) {
        if (i < text.length - 1) buffer.write(' ');
      }
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}