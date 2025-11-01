import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/admin_order.dart';
import 'package:wink_manager/models/order_item.dart';
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/providers/order_provider.dart';

// --- Widget pour gérer la ligne d'un article (Style Amélioré) ---
// (Widget OrderItemEditor inchangé)
class OrderItemEditor extends StatelessWidget {
  final int index;
  final Function(int) onRemove;
  final TextEditingController nameController;
  final TextEditingController qtyController;
  final TextEditingController amountController;

  const OrderItemEditor({
    super.key,
    required this.index,
    required this.onRemove,
    required this.nameController,
    required this.qtyController,
    required this.amountController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300)
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Article',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                isDense: true, 
              ),
              validator: (value) => (value == null || value.isEmpty) ? 'Nom requis' : null,
            ),
          ),
          const SizedBox(width: 8),
          
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: qtyController,
              decoration: const InputDecoration(
                labelText: 'Qté',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              validator: (value) => (value == null || (int.tryParse(value) ?? 0) <= 0) ? 'Qté > 0' : null,
            ),
          ),
          const SizedBox(width: 8),
          
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Montant',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              validator: (value) => (value == null || value.isEmpty) ? 'Montant' : null,
            ),
          ),
          
          if (index > 0)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
                onPressed: () => onRemove(index),
                tooltip: 'Supprimer l\'article',
              ),
            ),
        ],
      ),
    );
  }
}


class AdminOrderEditScreen extends StatefulWidget {
  final AdminOrder? order; 

  const AdminOrderEditScreen({super.key, this.order});

  @override
  State<AdminOrderEditScreen> createState() => _AdminOrderEditScreenState();
}

class _AdminOrderEditScreenState extends State<AdminOrderEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // --- CORRECTION : Rétablissement du contrôleur de recherche simple ---
  final _shopSearchController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _deliveryLocationController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _expeditionFeeController = TextEditingController();
  
  Shop? _selectedShop; // L'objet Shop sélectionné est la source de vérité
  bool _isExpedition = false;
  DateTime _createdAt = DateTime.now();

  final List<Map<String, TextEditingController>> _itemControllers = [];

  bool get _isEditMode => widget.order != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final order = widget.order!;
      
      // Assumer l'ID du shop (vous devrez peut-être ajouter shop_id à AdminOrder)
      _selectedShop = Shop(id: order.id, name: order.shopName, phoneNumber: ''); // Utilise l'ID de la commande comme placeholder
      _shopSearchController.text = order.shopName; 
      
      _customerNameController.text = order.customerName ?? '';
      _customerPhoneController.text = order.customerPhone;
      _deliveryLocationController.text = order.deliveryLocation;
      _deliveryFeeController.text = order.deliveryFee.toStringAsFixed(0);
      _expeditionFeeController.text = order.expeditionFee.toStringAsFixed(0);
      _isExpedition = order.expeditionFee > 0;
      _createdAt = order.createdAt;
      
      if (order.items.isNotEmpty) {
        for (var item in order.items) {
          _addItemRow(item: item);
        }
      } else {
         _addItemRow();
      }
    } else {
      _addItemRow();
      _deliveryFeeController.text = "0";
      _expeditionFeeController.text = "0";
    }
    
    // --- SUPPRESSION : Le listener n'est plus nécessaire ---
    // _shopController.addListener(_onShopTextChanged);
  }
  
  // --- SUPPRESSION : La fonction _onShopTextChanged n'est plus nécessaire ---

  void _addItemRow({OrderItem? item}) {
    // ... (Inchangé) ...
    final nameController = TextEditingController(text: item?.itemName ?? '');
    final qtyController = TextEditingController(text: item?.quantity.toString() ?? '1');
    final amountController = TextEditingController(text: item?.amount.toStringAsFixed(0) ?? '0');

    setState(() {
      _itemControllers.add({
        'name': nameController,
        'qty': qtyController,
        'amount': amountController,
      });
    });
  }

  void _removeItemRow(int index) {
    // ... (Inchangé) ...
    if (_itemControllers.length <= 1) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez avoir au moins un article.'), backgroundColor: Colors.red),
      );
      return;
    }
    
    _itemControllers[index]['name']?.dispose();
    _itemControllers[index]['qty']?.dispose();
    _itemControllers[index]['amount']?.dispose();
    
    setState(() {
      _itemControllers.removeAt(index);
    });
  }


  @override
  void dispose() {
    // --- CORRECTION : Suppression du listener ---
    // _shopController.removeListener(_onShopTextChanged);
    _shopSearchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _deliveryLocationController.dispose();
    _deliveryFeeController.dispose();
    _expeditionFeeController.dispose();
    
    for (var controllers in _itemControllers) {
      controllers['name']?.dispose();
      controllers['qty']?.dispose();
      controllers['amount']?.dispose();
    }
    
    super.dispose();
  }

  Future<void> _saveForm() async {
    // --- CORRECTION : Validation basée sur l'objet _selectedShop ---
    if (!_formKey.currentState!.validate() || _selectedShop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires et SÉLECTIONNER un marchand.'), backgroundColor: Colors.red),
      );
      return; 
    }
    
    setState(() { _isLoading = true; });

    final List<Map<String, dynamic>> itemsList = [];
    double totalArticleAmount = 0;

    for (var controllers in _itemControllers) {
      // ... (Logique de parsing des items inchangée) ...
      final double amount = double.tryParse(controllers['amount']!.text) ?? 0;
      final int quantity = int.tryParse(controllers['qty']!.text) ?? 0;
      
      if (quantity <= 0) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La quantité de l\'article doit être supérieure à zéro.'), backgroundColor: Colors.red),
        );
        return;
      }

      itemsList.add({
        'item_name': controllers['name']!.text,
        'quantity': quantity,
        'amount': amount,
      });
      totalArticleAmount += amount;
    }
    
    // --- CORRECTION : Payload basé sur _selectedShop ---
    final Map<String, dynamic> orderData = {
      'shop_id': _selectedShop!.id, // ID du marchand (obligatoire)
      'shop_name': _selectedShop!.name, // Nom du marchand (obligatoire)
      'customer_name': _customerNameController.text.trim(),
      'customer_phone': _customerPhoneController.text.trim(),
      'delivery_location': _deliveryLocationController.text.trim(),
      'article_amount': totalArticleAmount,
      'delivery_fee': double.tryParse(_deliveryFeeController.text) ?? 0,
      'expedition_fee': _isExpedition ? (double.tryParse(_expeditionFeeController.text) ?? 0) : 0,
      'created_at': DateFormat("yyyy-MM-ddTHH:mm:ss").format(_createdAt),
      'items': itemsList,
    };

    try {
      await Provider.of<OrderProvider>(context, listen: false)
          .saveOrder(orderData, widget.order?.id);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commande sauvegardée (hors ligne si nécessaire) !'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(); 
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }
  
  Future<void> _selectCreatedAt() async {
    // ... (Inchangé) ...
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (pickedDate != null) {
       if (!mounted) return;
       final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_createdAt),
       );
       if (pickedTime != null) {
          setState(() {
            _createdAt = DateTime(
              pickedDate.year, pickedDate.month, pickedDate.day,
              pickedTime.hour, pickedTime.minute
            );
          });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // ... (Inchangé) ...
        title: Text(_isEditMode ? 'Modifier Cde #${widget.order!.id}' : 'Créer Commande'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveForm,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(12.0),
                children: [
                  // --- SECTION 1: INFORMATIONS DE BASE ---
                  _buildSectionCard(
                    theme: theme,
                    title: 'Informations de Base',
                    children: [
                      // RECHERCHE MARCHANDE (Autocomplete)
                      Autocomplete<Shop>(
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                           // Linkage : on assigne le controller interne à notre _shopSearchController
                           _shopSearchController.value = textEditingController.value;
                           
                           return TextFormField(
                            controller: textEditingController, // Utilise le contrôleur interne
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Marchand *',
                              icon: Icon(Icons.store),
                            ),
                            validator: (value) {
                              // --- CORRECTION : Validation stricte ---
                              if (_selectedShop == null) {
                                return 'Veuillez sélectionner un marchand';
                              }
                              if (value != _selectedShop!.name) {
                                return 'Marchand non valide. Sélectionnez.';
                              }
                              return null;
                            },
                           );
                        },
                        // Utilise la valeur de _selectedShop pour pré-remplir
                        initialValue: TextEditingValue(text: _selectedShop?.name ?? ''),
                        displayStringForOption: (Shop option) => option.name,
                        
                        optionsBuilder: (TextEditingValue textEditingValue) async {
                          if (textEditingValue.text.isEmpty) {
                            // Si l'utilisateur efface, on réinitialise l'objet
                            if (_selectedShop != null) {
                              setState(() { _selectedShop = null; });
                            }
                            return const Iterable<Shop>.empty();
                          }
                          if (mounted) {
                             // Appelle le repository (qui gère l'offline)
                             return await Provider.of<OrderProvider>(context, listen: false)
                              .searchShops(textEditingValue.text);
                          }
                          return const Iterable<Shop>.empty();
                        },
                        
                        onSelected: (Shop selection) {
                          setState(() {
                            _selectedShop = selection;
                            // On force la validation
                            _formKey.currentState?.validate();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Nom Client
                      TextFormField(
                        controller: _customerNameController,
                        decoration: const InputDecoration(labelText: 'Nom Client', icon: Icon(Icons.person)),
                      ),
                      const SizedBox(height: 16),
                      // Téléphone Client
                      TextFormField(
                        controller: _customerPhoneController,
                        decoration: const InputDecoration(labelText: 'Tél. Client *', icon: Icon(Icons.phone)),
                        keyboardType: TextInputType.phone,
                        validator: (value) => (value == null || value.isEmpty) ? 'Téléphone requis' : null,
                      ),
                      const SizedBox(height: 16),
                      // Lieu de Livraison
                      TextFormField(
                        controller: _deliveryLocationController,
                        decoration: const InputDecoration(labelText: 'Lieu de Livraison *', icon: Icon(Icons.location_on)),
                        validator: (value) => (value == null || value.isEmpty) ? 'Lieu requis' : null,
                      ),
                      const SizedBox(height: 16),
                      // Date de Création (avec icône d'édition)
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(_isEditMode ? 'Date de modification' : 'Date et heure de création'),
                        subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(_createdAt)),
                        trailing: Icon(Icons.edit, color: theme.colorScheme.primary),
                        onTap: _selectCreatedAt,
                        contentPadding: EdgeInsets.zero, 
                      ),
                    ],
                  ),
                  
                  // --- SECTION 2: ARTICLES COMMANDÉS ---
                  // (Inchangé)
                  _buildSectionCard(
                    theme: theme,
                    title: 'Articles Commandés',
                    children: [
                       ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _itemControllers.length,
                        itemBuilder: (context, index) {
                          return OrderItemEditor( 
                            index: index,
                            onRemove: _removeItemRow,
                            nameController: _itemControllers[index]['name']!,
                            qtyController: _itemControllers[index]['qty']!,
                            amountController: _itemControllers[index]['amount']!,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Ajouter un article'),
                        onPressed: () => _addItemRow(),
                      ),
                    ]
                  ),

                  // --- SECTION 3: FRAIS ET EXPÉDITION ---
                  // (Inchangé)
                  _buildSectionCard(
                    theme: theme,
                    title: 'Frais de Livraison et Expédition',
                    children: [
                       TextFormField(
                        controller: _deliveryFeeController,
                        decoration: const InputDecoration(labelText: 'Frais de Livraison *', icon: Icon(Icons.delivery_dining)),
                        keyboardType: TextInputType.number,
                        validator: (value) => (value == null || value.isEmpty) ? 'Frais requis' : null,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text("C'est une expédition"),
                        value: _isExpedition,
                        onChanged: (value) {
                          setState(() { _isExpedition = value; });
                        },
                        secondary: const Icon(Icons.local_shipping),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_isExpedition)
                        Padding(
                          padding: const EdgeInsets.only(left: 48.0, top: 8.0, bottom: 8.0),
                          child: TextFormField(
                            controller: _expeditionFeeController,
                            decoration: const InputDecoration(labelText: 'Frais d\'Expédition'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveForm, 
                          icon: const Icon(Icons.save), 
                          label: Text(_isEditMode ? 'Sauvegarder les modifications' : 'Créer la commande'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50), 
                          ),
                        )
                    ]
                  ),
                ],
              ),
            ),
    );
  }

  // Helper pour créer les cartes de section (Inchangé)
  Widget _buildSectionCard({required ThemeData theme, required String title, required List<Widget> children}) {
    // ... (Inchangé) ...
    return Card(
      elevation: 4, 
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(18.0), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title, 
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary, 
                fontSize: 18,
              )),
            const Divider(height: 24, thickness: 1.5),
            ...children,
          ],
        ),
      ),
    );
  }
}