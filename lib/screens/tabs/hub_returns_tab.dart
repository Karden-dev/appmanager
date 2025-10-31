// Fichier : lib/screens/tabs/hub_returns_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/order_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/hub_return_card.dart'; // Supposé exister

class HubReturnsTab extends StatefulWidget {
  const HubReturnsTab({super.key});

  @override
  State<HubReturnsTab> createState() => _HubReturnsTabState();
}

class _HubReturnsTabState extends State<HubReturnsTab> {
  // Filtres locaux (basés sur la logique de _refreshCurrentTab de admin_hub_screen.dart)
  String _selectedStatus = 'pending_return_to_hub';
  int? _selectedDeliverymanId;
  late DateTime _startDate;
  late DateTime _endDate;
  late DateFormat _apiFormatter;

  @override
  void initState() {
    super.initState();
    _apiFormatter = DateFormat('yyyy-MM-dd');
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30)); // Défaut : 30 jours
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchReturns());
  }

  Future<void> _fetchReturns({bool forceRefresh = false}) async {
    if (!mounted) return;
    final provider = Provider.of<OrderProvider>(context, listen: false);

    Map<String, dynamic> filters = {
      'status': _selectedStatus,
      'deliverymanId': _selectedDeliverymanId,
      'startDate': _apiFormatter.format(_startDate),
      'endDate': _apiFormatter.format(_endDate),
    };
    
    provider.setLoading(true);
    try {
      await provider.fetchPendingReturns(
        filters: filters,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement: ${e.toString()}')),
      );
    } finally {
      if (!mounted) return;
      provider.setLoading(false);
    }
  }

  Future<void> _selectDateRange() async {
    final DateTime? pickedStart = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
    );
    if (pickedStart != null) {
      final DateTime? pickedEnd = await showDatePicker(
        context: context,
        initialDate: _endDate,
        firstDate: pickedStart,
        lastDate: DateTime.now(),
      );
      if (pickedEnd != null) {
        setState(() {
          _startDate = pickedStart;
          _endDate = pickedEnd;
        });
        _fetchReturns();
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // FIX: Définition des couleurs à partir du contexte
    final dangerColor = AppTheme.danger; // FIX L103, L163
    final backgroundColor = AppTheme.background; // FIX L223

    return Column(
      children: [
        // Zone des filtres
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Filtre Livreur (Dropdown)
              Consumer<OrderProvider>(
                builder: (context, provider, child) {
                  // Options pour les livreurs (incluant ALL)
                  final deliverymanOptions = [
                    DropdownMenuItem<int?>(
                        // FIX: Couleur danger sur le texte (ancienne L163)
                        value: null, child: Text('Tous les livreurs', style: TextStyle(color: dangerColor))), 
                    ...provider.deliverymen
                        .map((d) => DropdownMenuItem<int>(
                              value: d.id,
                              child: Text(d.name),
                            ))
                        .toList(),
                  ];

                  return DropdownButtonFormField<int?>(
                    decoration: const InputDecoration(labelText: 'Livreur', isDense: true),
                    // FIX: Remplacement de 'value' (deprecated) par 'initialValue'
                    initialValue: _selectedDeliverymanId, 
                    items: deliverymanOptions,
                    onChanged: (value) {
                      setState(() {
                        _selectedDeliverymanId = value;
                        _fetchReturns();
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 8),

              // Filtre de statut (Dropdown)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Statut de Retour', isDense: true),
                // FIX: Remplacement de 'value' (deprecated) par 'initialValue'
                initialValue: _selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'pending_return_to_hub', child: Text('En attente de retour')),
                  DropdownMenuItem(value: 'returned_to_hub', child: Text('Retourné au Hub')),
                  DropdownMenuItem(value: 'processed_return', child: Text('Traité')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value!;
                    _fetchReturns();
                  });
                },
              ),
              const SizedBox(height: 8),

              // Sélecteur de date
              Row(
                children: [
                  Expanded(
                    child: InputChip(
                      avatar: const Icon(Icons.calendar_today),
                      label: Text('Du: ${DateFormat('dd/MM/yyyy').format(_startDate)}'),
                      onPressed: _selectDateRange,
                      backgroundColor: backgroundColor, // Utilisation de la couleur de fond
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InputChip(
                      avatar: const Icon(Icons.calendar_today),
                      label: Text('Au: ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
                      onPressed: _selectDateRange,
                      backgroundColor: backgroundColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Liste des retours
        Expanded(
          child: Consumer<OrderProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (provider.pendingReturns.isEmpty) {
                return const Center(child: Text('Aucun retour trouvé.'));
              }

              return RefreshIndicator(
                onRefresh: _fetchReturns,
                child: ListView.builder(
                  itemCount: provider.pendingReturns.length,
                  itemBuilder: (context, index) {
                    final returnItem = provider.pendingReturns[index];
                    return HubReturnCard(returnTracking: returnItem);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}