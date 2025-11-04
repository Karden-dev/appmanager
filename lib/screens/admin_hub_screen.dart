// lib/screens/admin_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/admin_order.dart';
// import 'package:wink_manager/models/user.dart'; // Remplacé par l'import Deliveryman
import 'package:wink_manager/models/deliveryman.dart'; // <-- CORRIGÉ : Import du type spécifique
import 'package:wink_manager/models/return_tracking.dart'; 
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/hub_order_card.dart';
import 'package:wink_manager/widgets/return_card.dart'; 
// --- AJOUT ---
import 'package:wink_manager/widgets/network_status_icon.dart';

class AdminHubScreen extends StatefulWidget {
  const AdminHubScreen({super.key});

  @override
  State<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends State<AdminHubScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = const ['Préparation', 'Retours'];

  // FILTRES POUR L'ONGLET RETOURS
  int? _selectedDeliverymanId; 
  DateTime? _startDate;
  DateTime? _endDate;
  // CORRIGÉ : Variable d'état déclarée comme List<Deliveryman>
  List<Deliveryman> _deliverymen = []; 
  bool _isLoadingDeliverymen = false;
  String? _selectedReturnStatus;
  
  // Search query state for local filtering
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE CHARGEMENT DES DONNÉES ---

  Future<void> _loadInitialData() async {
    // 1. Charger les livreurs
    await _fetchDeliverymen();
    // 2. Charger les commandes de préparation
    await _fetchPreparationOrders();
    // 3. Charger les retours avec les filtres initiaux
    _selectedReturnStatus = 'pending_return_to_hub';
    await _fetchPendingReturns();
  }

  // Récupère la liste des livreurs pour le Dropdown des filtres
  Future<void> _fetchDeliverymen() async {
    setState(() {
      _isLoadingDeliverymen = true;
    });
    try {
      final provider = Provider.of<OrderProvider>(context, listen: false);
      
      // CORRECTION : Le provider retourne List<Deliveryman>, l'assignation est maintenant valide.
      final deliverymenList = await provider.searchDeliverymen('');
      
      if (mounted) {
        _deliverymen = deliverymenList; 
      }
    } catch (error) {
      if (mounted) {
        _showSnackbar('Erreur de chargement des livreurs: ${error.toString().replaceFirst('Exception: ', '')}', success: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDeliverymen = false;
        });
      }
    }
  }

  // Récupère les commandes de l'onglet Préparation
  Future<void> _fetchPreparationOrders() async {
    await Provider.of<OrderProvider>(context, listen: false).loadOrdersToPrepare();
  }

  // Récupère les retours en attente, en appliquant les filtres
  Future<void> _fetchPendingReturns() async {
    final provider = Provider.of<OrderProvider>(context, listen: false);

    if (_startDate != null && _endDate != null && _startDate!.isAfter(_endDate!)) {
      _showSnackbar('La date de début ne peut pas être postérieure à la date de fin.', success: false);
      return;
    }

    await provider.loadPendingReturns(
      deliverymanId: _selectedDeliverymanId,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  // --- ACTIONS ---

  // Action pour marquer une commande comme prête
  Future<void> _markOrderAsReady(int orderId) async {
    if (!mounted) return;
    final provider = Provider.of<OrderProvider>(context, listen: false);

    try {
      await provider.markOrderAsReady(orderId); 
      if (!mounted) return;
      _showSnackbar('Commande #$orderId marquée comme prête!', success: true);
      _fetchPreparationOrders(); 
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Erreur: ${e.toString().replaceFirst('Exception: ', '')}', success: false);
    }
  }
  
  // Action pour traiter un retour (Confirmation de réception Hub)
  Future<void> _markReturnAsCompleted(int trackingId) async {
    if (!mounted) return;
    final provider = Provider.of<OrderProvider>(context, listen: false);

    try {
      await provider.confirmHubReception(trackingId); 
      if (!mounted) return;
      _showSnackbar('Retour #$trackingId confirmé au Hub!', success: true);
      _fetchPendingReturns(); 
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Erreur: Impossible de confirmer le retour. ${e.toString().replaceFirst('Exception: ', '')}', success: false);
    }
  }

  // --- FILTRES LOCAUX ET UTILITAIRES ---
  
  List<AdminOrder> _filterOrders(List<AdminOrder> orders) {
    if (_searchQuery.isEmpty) return orders;
    
    final normalizedQuery = _searchQuery.toLowerCase();
    
    return orders.where((order) {
      return order.id.toString().contains(normalizedQuery) ||
             order.shopName.toLowerCase().contains(normalizedQuery) ||
             (order.customerName?.toLowerCase().contains(normalizedQuery) ?? false) ||
             order.customerPhone.contains(normalizedQuery) ||
             (order.deliverymanName?.toLowerCase().contains(normalizedQuery) ?? false);
    }).toList();
  }
  
  List<ReturnTracking> _filterReturns(List<ReturnTracking> returns) {
      if (_searchQuery.isEmpty) return returns;
      
      final normalizedQuery = _searchQuery.toLowerCase();
      
      return returns.where((item) {
          return item.orderId.toString().contains(normalizedQuery) ||
                 item.shopName.toLowerCase().contains(normalizedQuery) ||
                 item.deliverymanName.toLowerCase().contains(normalizedQuery);
      }).toList();
  }

  void _showSnackbar(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : AppTheme.danger,
      ),
    );
  }

  // --- WIDGET PRINCIPAL ET VUES DES ONGLETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logistique Hub', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        // --- AJOUT DE L'ICÔNE ---
        actions: const [
           NetworkStatusIcon(),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((name) => Tab(text: name)).toList(),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Rechercher (ID, Marchand, Client...)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    if (mounted) {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    }
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              onChanged: (value) {
                if (mounted) {
                  setState(() {
                    _searchQuery = value;
                  });
                }
              },
            ),
          ),
          
          // Contenu des onglets
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _fetchPreparationOrders,
                  child: _buildPreparationList(context), 
                ),
                RefreshIndicator(
                  onRefresh: _fetchPendingReturns,
                  child: _buildReturnsList(context),    
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreparationList(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        final hubOrders = provider.hubPreparationOrders;

        if (provider.isLoading && hubOrders.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (hubOrders.isEmpty) {
          return const Center(child: Text('Aucune commande en attente de préparation.'));
        }

        final filteredOrders = _filterOrders(hubOrders);

        if (filteredOrders.isEmpty) {
           return const Center(child: Text('Aucun résultat ne correspond à la recherche.'));
        }
        
        // 1. Grouper par Livreur (ID)
        final Map<int?, List<AdminOrder>> groupedOrders = filteredOrders.fold({}, (map, order) {
          final key = order.deliverymanId ?? -1; 
          map.putIfAbsent(key, () => []).add(order);
          return map;
        });
        
        // 2. Trier les groupes (Non Assigné en premier, puis par nom du livreur)
        final sortedGroups = groupedOrders.entries.toList()..sort((a, b) {
          if (a.key == -1) return -1;
          if (b.key == -1) return 1;
          return (a.value.first.deliverymanName ?? '').compareTo(b.value.first.deliverymanName ?? '');
        });
        
        // 3. Tri des commandes dans chaque groupe (Non préparé avant Préparé)
        for (var group in groupedOrders.values) {
            group.sort((a, b) {
                final priorityA = a.status == 'in_progress' ? 0 : 1;
                final priorityB = b.status == 'in_progress' ? 0 : 1;

                if (priorityA != priorityB) return priorityA.compareTo(priorityB);
                
                return a.createdAt.compareTo(b.createdAt);
            });
        }

        // 4. Afficher les groupes et les cartes
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          itemCount: sortedGroups.length,
          itemBuilder: (context, index) {
            final group = sortedGroups[index];
            final groupName = group.key == -1 ? 'Non Assigné' : group.value.first.deliverymanName ?? 'Livreur Inconnu';
            final readyCount = group.value.where((o) => o.status == 'ready_for_pickup').length;
            final inProgressCount = group.value.where((o) => o.status == 'in_progress').length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10.0, bottom: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${groupName.toUpperCase()} (${group.value.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Row(
                        children: [
                          Text('$readyCount Prêt(s)', style: TextStyle(color: Colors.green.shade700, fontSize: 13)),
                          const SizedBox(width: 8),
                          Text('$inProgressCount En cours', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                ...group.value.map((order) => HubOrderCard(
                  order: order,
                  onMarkAsReady: () => _markOrderAsReady(order.id), // Utilisez l'ID de la commande
                  onRefresh: _fetchPreparationOrders,
                )),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReturnsList(BuildContext context) {
    final Map<String, String> statusOptions = {
      'pending_return_to_hub': 'En attente Hub',
      'received_at_hub': 'Confirmé Hub',
      'returned_to_shop': 'Retourné Marchand',
      'all': 'Tous les statuts',
    };
    
    return Column(
      children: [
        // --- ZONE DE FILTRES ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            children: [
              // 1. FILTRE PAR LIVREUR
              DropdownButtonFormField<int?>( 
                decoration: const InputDecoration(
                  labelText: 'Filtrer par Livreur',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                initialValue: _selectedDeliverymanId, 
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Tous les livreurs')), 
                  if (_isLoadingDeliverymen)
                    const DropdownMenuItem<int>(
                      value: -1, 
                      child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                    )
                  else
                    // CORRIGÉ: Mapping vers la liste de Deliveryman
                    ..._deliverymen.map((deliveryman) => DropdownMenuItem<int>(
                      value: deliveryman.id, 
                      child: Text(deliveryman.name ?? 'Livreur ID: ${deliveryman.id}'), 
                    )),
                ],
                onChanged: (int? newValue) { 
                  setState(() {
                    _selectedDeliverymanId = newValue; 
                    _fetchPendingReturns(); 
                  });
                },
                isExpanded: true,
              ),
              const SizedBox(height: 12),

              // 2. FILTRE PAR DATE (Début et Fin)
              Row(
                children: [
                  Expanded(
                    child: _buildDateFilter(
                      context,
                      label: 'Début',
                      selectedDate: _startDate,
                      onDateSelected: (date) {
                        setState(() {
                          _startDate = date;
                          _fetchPendingReturns();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDateFilter(
                      context,
                      label: 'Fin',
                      selectedDate: _endDate,
                      onDateSelected: (date) {
                        setState(() {
                          _endDate = date;
                          _fetchPendingReturns();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 3. FILTRE PAR STATUT
              DropdownButtonFormField<String>(
                  initialValue: _selectedReturnStatus ?? 'pending_return_to_hub', 
                  decoration: const InputDecoration(
                    labelText: 'Statut du Retour',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  items: statusOptions.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedReturnStatus = value == 'all' ? null : value; 
                      });
                      _fetchPendingReturns();
                    }
                  },
                ),

              // Optionnel: Bouton pour réinitialiser les filtres
              if (_selectedDeliverymanId != null || _startDate != null || _endDate != null || _selectedReturnStatus != 'pending_return_to_hub')
                TextButton.icon(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _selectedDeliverymanId = null;
                      _startDate = null;
                      _endDate = null;
                      _selectedReturnStatus = 'pending_return_to_hub'; 
                      _fetchPendingReturns();
                    });
                  },
                  label: const Text('Réinitialiser les filtres'),
                ),
              const Divider(),
            ],
          ),
        ),
        // --- LISTE DES RETOURS ---
        Expanded(
          child: Consumer<OrderProvider>(
            builder: (context, provider, child) {
              final returns = provider.pendingReturns; 

              if (provider.isLoading && returns.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (returns.isEmpty) {
                return const Center(child: Text('Aucun retour en attente.'));
              }
                
              final filteredReturns = _filterReturns(returns);

              if (filteredReturns.isEmpty) {
                 return const Center(child: Text('Aucun résultat ne correspond à la recherche.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                itemCount: filteredReturns.length,
                itemBuilder: (context, index) {
                  final item = filteredReturns[index];
                  return ReturnCard(
                    returnItem: item,
                    onConfirmReception: () => _markReturnAsCompleted(item.trackingId), 
                    onRefresh: _fetchPendingReturns,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Widget utilitaire pour le sélecteur de date
  Widget _buildDateFilter(
    BuildContext context, {
    required String label,
    required DateTime? selectedDate,
    required Function(DateTime?) onDateSelected, 
  }) {
    final formatter = DateFormat('dd/MM/yyyy');
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          final DateTime adjustedDate = label == 'Début'
              ? DateTime(picked.year, picked.month, picked.day)
              : DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
          onDateSelected(adjustedDate);
        } else if (selectedDate != null) {
           onDateSelected(null); 
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: selectedDate != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => onDateSelected(null), 
                )
              : const Icon(Icons.calendar_today, size: 20),
        ),
        child: Text(
          selectedDate != null ? formatter.format(selectedDate) : 'Sélectionner',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}