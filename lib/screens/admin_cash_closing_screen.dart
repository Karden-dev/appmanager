// lib/screens/admin_cash_closing_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/cash_models.dart';
import 'package:wink_manager/providers/cash_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';

class AdminCashClosingScreen extends StatefulWidget {
  const AdminCashClosingScreen({super.key});

  @override
  State<AdminCashClosingScreen> createState() => _AdminCashClosingScreenState();
}

class _AdminCashClosingScreenState extends State<AdminCashClosingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  
  // Ajout : Date de clôture
  DateTime _closingDate = DateTime.now();

  double _difference = 0;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateDifference);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CashProvider>().loadData();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _updateDifference() {
    final provider = context.read<CashProvider>();
    final actual = double.tryParse(_amountController.text) ?? 0;
    setState(() {
      _difference = actual - provider.metrics.montantEnCaisse;
    });
  }
  
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _closingDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(), // Impossible de clôturer dans le futur
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {
        _closingDate = picked;
      });
    }
  }

  Future<void> _submitClosing() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmer la clôture"),
        content: Text(
          "Date : ${DateFormat('dd/MM/yyyy').format(_closingDate)}\n"
          "Montant : ${_amountController.text} FCFA\n"
          "Ecart : ${_difference.toStringAsFixed(0)} FCFA"
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text("Valider Clôture", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
       try {
         // On passe la date choisie
         await context.read<CashProvider>().performClosing(
           double.parse(_amountController.text),
           _commentController.text,
           _closingDate,
         );
         if (mounted) {
             _amountController.clear();
             _commentController.clear();
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caisse clôturée !"), backgroundColor: Colors.green));
         }
       } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
       }
    }
  }

  String _formatAmount(double amount) {
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CashProvider>();
    final theoreticalAmount = provider.metrics.montantEnCaisse;
    final history = provider.closingHistory;

    return Scaffold(
      appBar: AppBar(title: const Text("Clôture de Caisse")),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- SECTION FORMULAIRE ---
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text("NOUVELLE CLÔTURE", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                            const Divider(height: 24),
                            
                            // Sélecteur de Date
                            InkWell(
                              onTap: _pickDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date de clôture',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                child: Text(
                                  DateFormat('dd/MM/yyyy').format(_closingDate),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  const Text("MONTANT THÉORIQUE", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatAmount(theoreticalAmount),
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.secondaryColor),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Montant physique compté',
                                prefixIcon: Icon(Icons.money),
                                border: OutlineInputBorder(),
                                suffixText: 'FCFA',
                              ),
                              validator: (val) => (val == null || val.isEmpty) ? 'Requis' : null,
                            ),
                            const SizedBox(height: 16),
                            if (_amountController.text.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _difference == 0 ? Colors.green.shade50 : (_difference < 0 ? Colors.red.shade50 : Colors.blue.shade50),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _difference == 0 ? Colors.green : (_difference < 0 ? Colors.red : Colors.blue)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Écart :", style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text(
                                      _formatAmount(_difference),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        color: _difference == 0 ? Colors.green : (_difference < 0 ? Colors.red : Colors.blue)
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            TextFormField(
                              controller: _commentController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Commentaire',
                                prefixIcon: Icon(Icons.comment),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _submitClosing,
                              icon: const Icon(Icons.lock_outline),
                              label: const Text("VALIDER LA CLÔTURE"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- SECTION HISTORIQUE ---
                  Text("HISTORIQUE DE LA PÉRIODE", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  
                  if (history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: Text("Aucune clôture sur cette période.")),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        final isBalanced = item.difference == 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 1,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isBalanced ? Colors.green.shade50 : Colors.red.shade50,
                              child: Icon(
                                isBalanced ? Icons.check : Icons.priority_high,
                                color: isBalanced ? Colors.green : Colors.red,
                                size: 20,
                              ),
                            ),
                            title: Text(DateFormat('dd/MM/yyyy à HH:mm').format(item.closingDate)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Par: ${item.closedByUserName ?? 'Inconnu'}"),
                                if (item.comment != null && item.comment!.isNotEmpty)
                                  Text("Note: ${item.comment}", style: const TextStyle(fontStyle: FontStyle.italic)),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("Reel: ${_formatAmount(item.actualCashCounted)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  "Ecart: ${_formatAmount(item.difference)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isBalanced ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w600
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}