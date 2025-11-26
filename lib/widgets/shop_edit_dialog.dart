// lib/widgets/shop_edit_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/providers/shop_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';

class ShopEditDialog extends StatefulWidget {
  final Shop? shop; // Si null, on est en mode Création

  const ShopEditDialog({super.key, this.shop});

  @override
  State<ShopEditDialog> createState() => _ShopEditDialogState();
}

class _ShopEditDialogState extends State<ShopEditDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _packagingPriceController;
  late TextEditingController _storagePriceController;

  bool _billPackaging = false;
  bool _billStorage = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final s = widget.shop;
    
    _nameController = TextEditingController(text: s?.name ?? '');
    _phoneController = TextEditingController(text: s?.phoneNumber ?? '');
    
    // Valeurs par défaut comme sur le web (50 et 100)
    _packagingPriceController = TextEditingController(
        text: s != null ? s.packagingPrice.toStringAsFixed(0) : '50');
    _storagePriceController = TextEditingController(
        text: s != null ? s.storagePrice.toStringAsFixed(0) : '100');

    _billPackaging = s?.billPackaging ?? false;
    _billStorage = s?.billStorage ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _packagingPriceController.dispose();
    _storagePriceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final provider = context.read<ShopProvider>();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final packagingPrice = double.tryParse(_packagingPriceController.text) ?? 0;
    final storagePrice = double.tryParse(_storagePriceController.text) ?? 0;

    // Construction de l'objet de données pour l'API
    final shopData = {
      'name': name,
      'phone_number': phone,
      'bill_packaging': _billPackaging,
      'bill_storage': _billStorage,
      'packaging_price': packagingPrice,
      'storage_price': storagePrice,
      // 'created_by' est géré par le backend ou via le token Auth
    };

    try {
      if (widget.shop != null) {
        // Mode Modification
        await provider.updateShop(widget.shop!.id, shopData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Marchand modifié avec succès"), backgroundColor: Colors.green),
          );
        }
      } else {
        // Mode Création
        await provider.createShop(shopData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Marchand créé avec succès"), backgroundColor: Colors.green),
          );
        }
      }
      
      if (mounted) Navigator.of(context).pop(); // Fermer la modale

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.shop != null;

    return AlertDialog(
      title: Text(
        isEditing ? 'Modifier le marchand' : 'Ajouter un marchand',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- IDENTITÉ ---
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du marchand',
                  prefixIcon: Icon(Icons.store),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (val) => (val == null || val.isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                validator: (val) => (val == null || val.isEmpty) ? 'Téléphone requis' : null,
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Divider(),
              ),
              
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Options de Facturation", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              const SizedBox(height: 12),

              // --- EMBALLAGE ---
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Facturer Emballages"),
                      subtitle: const Text("Ajoute des frais auto."),
                      value: _billPackaging,
                      activeColor: AppTheme.primaryColor,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _billPackaging = val),
                    ),
                    if (_billPackaging)
                      TextFormField(
                        controller: _packagingPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Prix Emballage (FCFA)',
                          prefixIcon: Icon(Icons.kitchen),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (val) {
                          if (_billPackaging && (val == null || val.isEmpty)) return 'Prix requis';
                          return null;
                        },
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),

              // --- STOCKAGE ---
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Facturer Stockage"),
                      subtitle: const Text("Frais journaliers"),
                      value: _billStorage,
                      activeColor: AppTheme.primaryColor,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _billStorage = val),
                    ),
                    if (_billStorage)
                      TextFormField(
                        controller: _storagePriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Prix Stockage (FCFA/jour)',
                          prefixIcon: Icon(Icons.inventory_2),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                         validator: (val) {
                          if (_billStorage && (val == null || val.isEmpty)) return 'Prix requis';
                          return null;
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isEditing ? 'Sauvegarder' : 'Ajouter'),
        ),
      ],
    );
  }
}