// lib/screens/tabs/hub_preparation_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // Nécessaire pour groupBy

import '../../models/admin_order.dart';
import '../../providers/order_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/hub_preparation_card.dart'; // Fichier que nous créerons ensuite

class HubPreparationTab extends StatefulWidget {
  const HubPreparationTab({super.key});

  @override
  State<HubPreparationTab> createState() => _HubPreparationTabState();
}

class _HubPreparationTabState extends State<HubPreparationTab>
    with AutomaticKeepAliveClientMixin {
  Future<void>? _loadPreparationOrders;

  @override
  void initState() {
    super.initState();
    // Utilise addPostFrameCallback pour appeler le provider après le premier build
    // sans causer d'erreur de build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // On stocke la future pour le FutureBuilder
      setState(() {
        _loadPreparationOrders = _fetchData(false);
      });
    });
  }

  // Garde l'état de l'onglet actif même s'il n'est pas visible
  @override
  bool get wantKeepAlive => true;

  /// Appelle le provider pour charger les données, avec une option de rafraîchissement forcé.
  Future<void> _fetchData(bool forceRefresh) async {
    // Utilise 'read' (listen: false) pour un appel unique
    final provider = Provider.of<OrderProvider>(context, listen: false);
    try {
      // 'fetchPreparationOrders' sera ajoutée à OrderProvider
      await provider.fetchPreparationOrders(forceRefresh: forceRefresh);
    } catch (error) {
      // Le provider gère déjà l'affichage des SnackBars d'erreur
      if (mounted && (provider.preparationOrders.isEmpty)) {
        // Affiche une erreur seulement si la liste est vide
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur chargement préparation: ${error.toString()}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  /// Regroupe les commandes par livreur, triées avec "Non Assigné" en premier.
  Map<String, List<AdminOrder>> _groupOrdersByDeliveryman(
      List<AdminOrder> orders) {
    // Logique de tri pour que les 'in_progress' apparaissent avant les 'ready_for_pickup'
    // comme dans preparation.js
    orders.sort((a, b) {
      if (a.status == 'in_progress' && b.status != 'in_progress') return -1;
      if (a.status != 'in_progress' && b.status == 'in_progress') return 1;
      return a.createdAt.compareTo(b.createdAt); // Tri secondaire par date
    });

    final grouped = groupBy(
      orders,
      (AdminOrder order) => order.deliverymanName ?? 'Non Assigné',
    );

    // Trier les groupes : "Non Assigné" en premier, puis alphabétique
    final sortedKeys = grouped.keys.sorted((a, b) {
      if (a == 'Non Assigné') return -1;
      if (b == 'Non Assigné') return 1;
      return a.compareTo(b);
    });

    return {for (var k in sortedKeys) k: grouped[k]!};
  }

  @override
  Widget build(BuildContext context) {
    // Appelle super.build pour AutomaticKeepAliveClientMixin
    super.build(context);

    // Utilise 'watch' pour écouter les changements (isLoading, liste d'ordres)
    final provider = context.watch<OrderProvider>();
    final orders = provider.preparationOrders;
    final isLoading = provider.isLoadingPreparation;

    return RefreshIndicator(
      onRefresh: () async {
        // Le RefreshIndicator déclenche un nouveau fetch forcé
        await _fetchData(true);
      },
      child: FutureBuilder(
        future: _loadPreparationOrders,
        builder: (ctx, snapshot) {
          // Affiche le spinner au premier chargement (géré par la future)
          if (snapshot.connectionState == ConnectionState.waiting && !isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Affiche l'erreur si le fetch initial échoue
          if (snapshot.hasError && orders.isEmpty && !isLoading) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Erreur: ${snapshot.error.toString()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.danger),
                ),
              ),
            );
          }

          // Affiche l'état vide
          if (orders.isEmpty && !isLoading) {
            return LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'Aucune commande à préparer.\nTirez pour rafraîchir.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              );
            });
          }
          
          // Si on charge en arrière-plan (ex: refresh) mais qu'on a déjà des données
          if (isLoading && orders.isEmpty) {
             return const Center(child: CircularProgressIndicator());
          }

          // Données prêtes : regrouper et afficher
          final groupedOrders = _groupOrdersByDeliveryman(orders);

          // Utilise CustomScrollView pour combiner les en-têtes et les listes
          return CustomScrollView(
            slivers: [
              // Ajoute un spinner en haut si on rafraîchit en arrière-plan
              if (isLoading && orders.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),

              // Itère sur chaque groupe (chaque livreur)
              ...groupedOrders.entries.map((entry) {
                final deliverymanName = entry.key;
                final deliverymanOrders = entry.value;

                // Calcul des compteurs (basé sur preparation.js)
                final readyCount = deliverymanOrders
                    .where((o) => o.status == 'ready_for_pickup')
                    .length;
                final inProgressCount = deliverymanOrders
                    .where((o) => o.status == 'in_progress')
                    .length;

                return [
                  // En-tête de groupe (Livreur)
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      margin: const EdgeInsets.only(
                          top: 16.0, left: 8.0, right: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppTheme.cardRadius),
                          topRight: Radius.circular(AppTheme.cardRadius),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              deliverymanName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppTheme.secondaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '$readyCount Prêt(s)',
                                style: const TextStyle(
                                    color: AppTheme.info,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$inProgressCount En cours',
                                style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Liste des commandes pour ce livreur
                  SliverPadding(
                    padding:
                        const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 16.0),
                    // Applique un fond et une ombre au conteneur de la liste
                    sliver: SliverDecoratedBoxAdapter(
                      decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(AppTheme.cardRadius),
                          bottomRight: Radius.circular(AppTheme.cardRadius),
                        ),
                         border: Border.all(color: Colors.grey[300]!),
                         boxShadow: [
                           BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                         ]
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final order = deliverymanOrders[index];
                            return HubPreparationCard(
                              key: ValueKey(order.id), // Clé pour la performance
                              order: order,
                            );
                          },
                          childCount: deliverymanOrders.length,
                        ),
                      ),
                    ),
                  ),
                ];
              }).expand((e) => e), // Aplatit la liste de listes
            ],
          );
        },
      ),
    );
  }
}

// Utilitaire pour SliverDecoratedBoxAdapter (peut être mis dans un fichier utils)
class SliverDecoratedBoxAdapter extends StatelessWidget {
  final Decoration decoration;
  final Widget sliver;

  const SliverDecoratedBoxAdapter({
    super.key,
    required this.decoration,
    required this.sliver,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedSliver(
      decoration: decoration,
      sliver: sliver,
    );
  }
}