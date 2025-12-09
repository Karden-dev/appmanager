// lib/screens/admin_shop_performance_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/dashboard_models.dart';
import 'package:wink_manager/providers/dashboard_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';

class AdminShopPerformanceScreen extends StatefulWidget {
  const AdminShopPerformanceScreen({super.key});

  @override
  State<AdminShopPerformanceScreen> createState() => _AdminShopPerformanceScreenState();
}

class _AdminShopPerformanceScreenState extends State<AdminShopPerformanceScreen> {
  late DateTimeRange _selectedDateRange;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Par défaut : Du 1er du mois courant à aujourd'hui (pour une vision comptable mensuelle)
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    // On appelle la méthode spécifique pour charger la liste complète (limit=100 ou plus)
    Provider.of<DashboardProvider>(context, listen: false)
        .loadFullShopRanking(_selectedDateRange.start, _selectedDateRange.end);
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadData();
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Performances Marchands', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, color: AppTheme.primaryColor),
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Bloc Recherche & Info Date ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                // Badge Période
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.date_range, size: 14, color: Colors.blue.shade800),
                      const SizedBox(width: 6),
                      Text(
                        "${DateFormat('dd MMM').format(_selectedDateRange.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange.end)}",
                        style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Barre de Recherche
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un marchand...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                ),
              ],
            ),
          ),
          
          // --- Liste des Marchands ---
          Expanded(
            child: Consumer<DashboardProvider>(
              builder: (context, provider, child) {
                if (provider.isLoadingFullShop) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allShops = provider.fullShopRanking;
                if (allShops == null || allShops.isEmpty) {
                  return _buildEmptyState();
                }

                // Filtrage local (Recherche)
                final filteredShops = allShops.where((s) => s.shopName.toLowerCase().contains(_searchQuery)).toList();

                if (filteredShops.isEmpty) {
                  return const Center(child: Text("Aucun marchand trouvé."));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredShops.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    return _buildShopPerformanceCard(filteredShops[index], index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_mall_directory_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("Aucune donnée pour cette période.", style: TextStyle(color: Colors.grey.shade600)),
          TextButton(onPressed: _loadData, child: const Text("Actualiser"))
        ],
      ),
    );
  }

  Widget _buildShopPerformanceCard(ShopRankingItem item, int index) {
    final reliability = item.reliabilityRate;
    // Code couleur fiabilité
    Color relColor = reliability > 0.9 ? Colors.green : (reliability > 0.7 ? Colors.orange : Colors.red);
    
    // Calcul de la médaille ou du rang
    Widget? rankWidget;
    // On n'affiche le rang que si on ne filtre pas, sinon le classement n'a plus de sens visuel
    if (_searchQuery.isEmpty) {
      if (index == 0) rankWidget = const Text("🥇", style: TextStyle(fontSize: 28));
      else if (index == 1) rankWidget = const Text("🥈", style: TextStyle(fontSize: 28));
      else if (index == 2) rankWidget = const Text("🥉", style: TextStyle(fontSize: 28));
      else rankWidget = Text("#${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 16));
    } else {
      rankWidget = const Icon(Icons.store, color: Colors.grey);
    }

    // Variation
    Color varColor = Colors.grey;
    IconData varIcon = Icons.remove;
    String varText = "";
    
    if (item.feesVariation != null) {
      varText = "${item.feesVariation! > 0 ? '+' : ''}${item.feesVariation!.toStringAsFixed(0)}%";
      if (item.feesVariation! > 0) {
        varColor = Colors.green;
        varIcon = Icons.arrow_upward;
      } else if (item.feesVariation! < 0) {
        varColor = Colors.red;
        varIcon = Icons.arrow_downward;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          // Colonne Rang (Gauche)
          SizedBox(
            width: 40,
            child: Center(child: rankWidget),
          ),
          const SizedBox(width: 12),
          
          // Colonne Info Centrale
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                
                // Indicateurs Commandes
                Row(
                  children: [
                    _buildMiniBadge(Icons.send, "${item.ordersSentCount}", Colors.blue),
                    const SizedBox(width: 8),
                    _buildMiniBadge(Icons.check_circle, "${item.ordersProcessedCount}", Colors.green),
                  ],
                ),
                const SizedBox(height: 10),
                
                // Barre de fiabilité
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: reliability, minHeight: 6, backgroundColor: Colors.grey.shade100, color: relColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text("${(reliability * 100).toInt()}%", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: relColor)),
                  ],
                )
              ],
            ),
          ),

          // Colonne Finance (Droite)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatCurrency(item.totalDeliveryFeesGenerated),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
              ),
              const Text("Générés", style: TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 6),
              
              // Badge Variation
              if (item.feesVariation != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: varColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4)
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(varIcon, size: 10, color: varColor),
                      const SizedBox(width: 2),
                      Text(
                        varText,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: varColor),
                      ),
                    ],
                  ),
                )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}