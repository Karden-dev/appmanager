// lib/screens/orders_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Ajouté pour Timer (même si non utilisé directement, bonne pratique)

import '../services/order_service.dart';
import '../models/order.dart';
import '../utils/app_theme.dart';
// Importe le widget OrderCard
import 'orders_today_screen.dart' show OrderCard;
// Import de l'écran de détails (utilisé par OrderCard)
// import 'order_details_screen.dart';


class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  // Déclarer _ordersFuture comme nullable au départ
  Future<List<Order>>? _ordersFuture;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  String? _searchQuery;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _setInitialDatesAndFetch();
  }

  void _setInitialDatesAndFetch() {
    final now = DateTime.now();
    // Défaut: Aujourd'hui
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _startDateController.text = DateFormat('dd/MM/yyyy', 'fr_FR').format(_startDate!);
    _endDateController.text = DateFormat('dd/MM/yyyy', 'fr_FR').format(_endDate!);
    // Premier fetch après le build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOrders();
    });
  }

  // Fonction pour lancer le fetch des commandes
  Future<void> _fetchOrders() async {
    // Vérification initiale de mounted
    if (!mounted) return;

    final orderService = Provider.of<OrderService?>(context, listen: false);
    if (orderService == null) {
      // Si le service n'est pas prêt, on met à jour l'état avec une erreur
      // La vérification mounted est importante avant setState
      if (mounted) {
        setState(() {
          _ordersFuture = Future.error("Service de commandes non disponible.");
        });
      }
      return;
    }

    // Mise à jour de l'état pour indiquer le chargement et assigner la nouvelle Future
    // C'est cette partie qui est cruciale pour que le FutureBuilder utilise la bonne Future
    if (mounted) {
      setState(() {
        _ordersFuture = orderService.fetchRiderOrders(
          statuses: ['all'], // Historique complet
          startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
          endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
          search: _searchQuery,
        );
      });
    }
  }


  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    // Garde une référence au contexte avant l'appel asynchrone
    final currentContext = context;
    // Vérification initiale de mounted
    if (!mounted) return;

    final DateTime? picked = await showDatePicker(
      context: currentContext, // Utilise le contexte local
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );

    // Vérification de mounted APRES l'appel asynchrone
    if (!mounted) return;

    if (picked != null) {
      // Mise à jour de l'état local des dates AVANT de lancer le fetch
      setState(() {
        if (isStartDate) {
          _startDate = DateTime(picked.year, picked.month, picked.day);
          _startDateController.text = DateFormat('dd/MM/yyyy', 'fr_FR').format(_startDate!);
        } else {
          _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
          _endDateController.text = DateFormat('dd/MM/yyyy', 'fr_FR').format(_endDate!);
        }
      });
      // Appelle la fonction qui déclenche le setState pour _ordersFuture
      _applyFilters();
    }
  }

  void _applyFilters() {
     // Mise à jour de la query de recherche (synchrone)
     final newSearchQuery = _searchController.text.trim().isEmpty ? null : _searchController.text.trim();

     if (mounted) { // Vérification avant setState
       setState(() {
         _searchQuery = newSearchQuery;
         // Si seulement la recherche a changé, on peut réutiliser la Future existante
         // mais pour simplifier et assurer la cohérence, on relance toujours le fetch.
         // On met _ordersFuture à null pour montrer le spinner pendant la recherche/filtrage
         _ordersFuture = null;
       });
     }
    // Lance le fetch après la mise à jour de l'état
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  // Helper local pour formater les montants (conservé car utile)
  String formatAmount(double? amount) {
    if (amount == null) return '0 FCFA';
    final formatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    return formatter.format(amount);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // --- Section des Filtres (Style amélioré) ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Rechercher (ID, Client, Lieu...)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                             if (!mounted) return;
                            _searchController.clear();
                            _applyFilters(); // Relance le fetch sans recherche
                          },
                        )
                      : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                   // Recherche dynamique OU sur validation
                   onSubmitted: (_) => _applyFilters(),
                   // Décommenter pour recherche dynamique (peut faire beaucoup d'appels API)
                   // onChanged: (_) {
                   //   // Optionnel: Ajouter un debounce ici si recherche dynamique activée
                   //   _applyFilters();
                   // },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startDateController,
                        decoration: InputDecoration(
                          labelText: 'Du',
                          prefixIcon: const Icon(Icons.calendar_today),
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                           contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, true), // Passe le BuildContext local
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _endDateController,
                        decoration: InputDecoration(
                          labelText: 'Au',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, false), // Passe le BuildContext local
                      ),
                    ),
                    // Bouton de filtre manuel (optionnel, _applyFilters est appelé après sélection date/recherche)
                    // const SizedBox(width: 10),
                    // ElevatedButton(
                    //   onPressed: _applyFilters,
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: AppTheme.secondaryColor,
                    //     foregroundColor: Colors.white,
                    //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    //     padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    //   ),
                    //   child: const Icon(Icons.filter_list),
                    // ),
                  ],
                ),
              ],
            ),
          ),

          // --- Section Liste des Commandes ---
          Expanded(
            child: FutureBuilder<List<Order>>(
              // Important: La Future est maintenant gérée par l'état
              future: _ordersFuture,
              builder: (context, snapshot) {
                 // Gère l'état initial où _ordersFuture est null OU quand on le remet à null pour forcer le spinner
                 if (_ordersFuture == null || (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null)) {
                   return const Center(child: CircularProgressIndicator());
                 }
                // --- La suite reste identique ---
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Optionnel: peut afficher un indicateur différent si des données précédentes existent
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                   return Center(
                     child: Padding(
                       padding: const EdgeInsets.all(16.0),
                       child: Text(
                         'Erreur: ${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                         style: const TextStyle(color: AppTheme.danger),
                         textAlign: TextAlign.center,
                       ),
                     ),
                   );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                   return const Center(
                     child: Text(
                       'Aucune commande trouvée pour ces filtres.',
                       style: TextStyle(color: Colors.grey),
                     ),
                   );
                }

                final orders = snapshot.data!;
                // Tri antichronologique pour l'historique
                orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                return RefreshIndicator( // Ajout du RefreshIndicator
                  onRefresh: _fetchOrders, // Appelle la fonction pour recharger
                  child: ListView.builder(
                    // physics: const AlwaysScrollableScrollPhysics(), // Assure que le scroll est toujours possible pour le refresh
                    padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      // Utilise OrderCard sans passer les callbacks d'action
                      return OrderCard(
                        order: orders[index],
                        // isActionInProgress: _isPerformingAction, // Plus nécessaire
                        // Pas de callbacks passés ici
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}