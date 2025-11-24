// lib/widgets/close_cash_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/providers/cash_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';

class CloseCashDialog extends StatefulWidget {
  const CloseCashDialog({super.key});

  @override
  State<CloseCashDialog> createState() => _CloseCashDialogState();
}

class _CloseCashDialogState extends State<CloseCashDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clôturer la Caisse'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Cette action validera les entrées et sorties de la journée sélectionnée.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant physique compté (FCFA)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
              ),
              validator: (val) => (val == null || val.isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _commentController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Commentaire / Écart',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
          child: const Text('CLÔTURER', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      try {
        await context.read<CashProvider>().performClosing(
          double.parse(_amountController.text),
          _commentController.text,
          DateTime.now(),
        );
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caisse clôturée avec succès"), backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
      }
    }
  }
}