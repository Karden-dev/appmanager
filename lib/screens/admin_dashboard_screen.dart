// lib/screens/admin_dashboard_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/dashboard_models.dart';
import 'package:wink_manager/providers/dashboard_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/app_drawer.dart';
import 'package:wink_manager/screens/admin_shop_performance_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late DateTimeRange _selectedDateRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(start: now, end: now);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    Provider.of<DashboardProvider>(context, listen: false)
        .loadDashboardData(_selectedDateRange.start, _selectedDateRange.end);
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

  // Méthode pour formater les quantités (ex: 1 -> 01)
  String _formatCount(int value) {
    return value < 10 ? '0$value' : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Tableau de Bord', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
      drawer: AppDrawer(
        selectedIndex: 0,
        onItemTapped: (index) {},
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Erreur: ${provider.error}'),
                  ElevatedButton(onPressed: _loadData, child: const Text('Réessayer')),
                ],
              ),
            );
          }

          final data = provider.data;
          if (data == null) return const Center(child: Text("Aucune donnée disponible."));

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateFilterDisplay(),
                  const SizedBox(height: 24),

                  // 1. KPIs Financiers
                  _buildSectionTitle('Performances Financières'),
                  const SizedBox(height: 12),
                  _buildKpiGrid(data.metrics),
                  const SizedBox(height: 32),

                  // 2. Podium Livreurs
                  _buildSectionTitle('Podium des Champions'),
                  const SizedBox(height: 12),
                  _buildDeliverymanPodium(data.deliverymanRanking),
                  const SizedBox(height: 32),

                  // 3. Qualité & Volume
                  _buildSectionTitle('Qualité & Volume'),
                  const SizedBox(height: 12),
                  _buildQualityAndVolumeSection(data.metrics), 
                  const SizedBox(height: 32),

                  // 4. Top Marchands
                  _buildSectionTitle('Top Marchands & Fiabilité'),
                  const SizedBox(height: 12),
                  _buildShopRankingList(data.ranking),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- WIDGETS UI ---

  Widget _buildDateFilterDisplay() {
    final start = DateFormat('dd MMM', 'fr_FR').format(_selectedDateRange.start);
    final end = DateFormat('dd MMM', 'fr_FR').format(_selectedDateRange.end);
    final isToday = _selectedDateRange.start.day == DateTime.now().day && 
                    _selectedDateRange.start.month == DateTime.now().month &&
                    _selectedDateRange.start.year == DateTime.now().year;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              isToday ? "Aujourd'hui" : "$start - $end",
              style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.2),
      ),
    );
  }

  // --- 1. KPIs ---
  Widget _buildKpiGrid(DashboardMetrics metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard('Chiffre d\'Affaires', metrics.caNet, metrics.caVariation, Icons.monetization_on, Colors.blue, width: cardWidth),
            _buildKpiCard('Dépenses', metrics.totalExpenses, metrics.expensesVariation, Icons.arrow_circle_down, Colors.red, width: cardWidth, inverseTrend: true),
            _buildKpiCard('Solde Net', metrics.soldeNet, metrics.soldeVariation, Icons.account_balance_wallet, Colors.green, width: cardWidth),
            _buildKpiCard('Frais Liv.', metrics.totalDeliveryFees, metrics.deliveryFeesVariation, Icons.local_shipping, Colors.orange, width: cardWidth),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String title, double value, double? variation, IconData icon, MaterialColor color, {bool inverseTrend = false, required double width}) {
    Color trendColor = Colors.grey;
    IconData trendIcon = Icons.remove;
    String trendText = "-";

    if (variation != null) {
      trendText = "${variation > 0 ? '+' : ''}${variation.toStringAsFixed(1)}%";
      if (variation > 0) {
        trendColor = inverseTrend ? Colors.red : Colors.green;
        trendIcon = Icons.arrow_upward;
      } else if (variation < 0) {
        trendColor = inverseTrend ? Colors.green : Colors.red;
        trendIcon = Icons.arrow_downward;
      }
    }

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color.shade700, size: 20),
              ),
              if (variation != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: trendColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    children: [
                      Icon(trendIcon, size: 10, color: trendColor),
                      const SizedBox(width: 2),
                      Text(trendText, style: TextStyle(color: trendColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            _formatCurrency(value),
            style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- 2. PODIUM ---
  Widget _buildDeliverymanPodium(List<DeliverymanRankingItem> ranking) {
    if (ranking.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text("Aucune donnée livreur."))));
    
    final first = ranking.isNotEmpty ? ranking[0] : null;
    final second = ranking.length > 1 ? ranking[1] : null;
    final third = ranking.length > 2 ? ranking[2] : null;

    return SizedBox(
      height: 230, 
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end, 
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (second != null) _buildPodiumStep(second, 2, Colors.grey.shade400, 120),
          if (first != null) _buildPodiumStep(first, 1, const Color(0xFFFFD700), 160),
          if (third != null) _buildPodiumStep(third, 3, const Color(0xFFCD7F32), 100),
        ],
      ),
    );
  }

  Widget _buildPodiumStep(DeliverymanRankingItem item, int rank, Color color, double height) {
    String? varText;
    Color varColor = Colors.grey;
    if (item.rankVariation != null) {
      varText = "${item.rankVariation! > 0 ? '+' : ''}${item.rankVariation!.toStringAsFixed(0)}%";
      varColor = item.rankVariation! >= 0 ? Colors.green : Colors.red;
    }

    final double avatarRadiusOuter = rank == 1 ? 28 : 22;
    final double avatarRadiusInner = rank == 1 ? 24 : 19;
    final double fontSizeAvatar = rank == 1 ? 18 : 14;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 14.0),
                child: CircleAvatar(
                  radius: avatarRadiusOuter,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: avatarRadiusInner,
                    backgroundColor: color.withOpacity(0.2),
                    child: Text(
                      item.name.isNotEmpty ? item.name.substring(0, 1) : '?', 
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: fontSizeAvatar)
                    ),
                  ),
                ),
              ),
              if (rank == 1)
                const Positioned(top: 0, child: Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 24)),
            ],
          ),
          const SizedBox(height: 4),
          Text(item.name.split(' ').first, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1),
          Text("${item.deliveredCount} Liv.", style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
          
          if (varText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2.0),
              child: Text(varText, style: TextStyle(color: varColor, fontSize: 9, fontWeight: FontWeight.bold)),
            ),

          Container(
            height: height * 0.55,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(top: BorderSide(color: color, width: 4)),
            ),
            child: Center(
              child: Text("#$rank", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.withOpacity(0.6))),
            ),
          )
        ],
      ),
    );
  }

  // --- 3. SECTION QUALITÉ & VOLUME ---
  Widget _buildQualityAndVolumeSection(DashboardMetrics metrics) {
    return Column(
      children: [
        // PARTIE HAUTE : Les deux graphiques
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BLOC 1 : Jauge de Qualité
            Expanded(child: _buildQualityCard(metrics)),
            const SizedBox(width: 12),
            // BLOC 2 : Graphique Donut
            Expanded(child: _buildStatusDistributionCard(metrics)),
          ],
        ),
        const SizedBox(height: 12),
        
        // PARTIE BASSE : Liste Détaillée
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(16)
          ),
          child: Column(
            children: [
                // Utilisation de _formatCount pour les quantités
                _buildStatRow("Livrées", metrics.totalDelivered, Colors.green, metrics.deliveredVariation, inverseTrend: false),
                const SizedBox(height: 12),
                
                _buildStatRow("En Cours", metrics.totalInProgress, Colors.orange, null, inverseTrend: false),
                const SizedBox(height: 12),
                
                _buildStatRow("Annulées", metrics.totalFailedCancelled, Colors.red, metrics.failedVariation, inverseTrend: true),
                
                const Divider(height: 24),
                
                _buildStatRow("Total", metrics.totalSent, Colors.black87, metrics.ordersSentVariation, inverseTrend: false, isBold: true),
            ],
          ),
        ),
      ],
    );
  }

  // Bloc Gauche : Jauge
  Widget _buildQualityCard(DashboardMetrics metrics) {
    final total = metrics.totalSent;
    final rate = total == 0 ? 0.0 : metrics.totalDelivered / total;
    final percentage = (rate * 100).toInt();
    
    Color color;
    String label;
    if (percentage >= 80) { color = Colors.green; label = "Excellent"; } 
    else if (percentage >= 60) { color = Colors.orange; label = "Moyen"; } 
    else { color = Colors.red; label = "Mauvais"; }

    Widget? variationBadge;
    if (metrics.qualityRateVariation != null) {
        final val = metrics.qualityRateVariation!;
        final isPositive = val >= 0;
        variationBadge = Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1), 
              borderRadius: BorderRadius.circular(12)
            ),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: isPositive ? Colors.green : Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      "${isPositive ? '+' : ''}${val.toStringAsFixed(1)}%", 
                      style: TextStyle(fontSize: 11, color: isPositive ? Colors.green : Colors.red, fontWeight: FontWeight.bold)
                    ),
                ]
            )
        );
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribution équilibrée
        children: [
          const Text("Taux de Réussite", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          
          // CORRECTION : Espacement explicite pour éviter que le titre touche le cercle
          const SizedBox(height: 12),

          // CORRECTION : Taille réduite à 85 pour donner de l'espace
          SizedBox(
            width: 85,
            height: 85,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 85,
                  width: 85,
                  child: CircularProgressIndicator(
                    value: rate,
                    strokeWidth: 9,
                    backgroundColor: Colors.grey.shade100,
                    color: color,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("$percentage%", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                    Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.withOpacity(0.8))),
                  ],
                )
              ],
            ),
          ),
          
          // Espace du bas pour le badge
          if (variationBadge != null) variationBadge else const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Bloc Droite : Donut Chart
  Widget _buildStatusDistributionCard(DashboardMetrics metrics) {
    final delivered = metrics.totalDelivered.toDouble();
    final inProgress = metrics.totalInProgress.toDouble();
    final failed = metrics.totalFailedCancelled.toDouble();
    final total = metrics.totalSent;
    final bool isEmpty = total == 0;
    
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Volume Traité", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          
          // Espacement pour s'aligner avec la carte de gauche
          const SizedBox(height: 12),

          // CORRECTION : Taille harmonisée à 85
          SizedBox(
            height: 85,
            width: 85,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    startDegreeOffset: -90,
                    sections: isEmpty 
                      ? [PieChartSectionData(color: Colors.grey.shade200, value: 1, radius: 12, showTitle: false)]
                      : [
                        if (delivered > 0) PieChartSectionData(color: Colors.green, value: delivered, radius: 12, showTitle: false),
                        if (inProgress > 0) PieChartSectionData(color: Colors.orange, value: inProgress, radius: 12, showTitle: false),
                        if (failed > 0) PieChartSectionData(color: Colors.red, value: failed, radius: 12, showTitle: false),
                      ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("${metrics.totalSent}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const Text("Total", style: TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          
          // Légende
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendDot(Colors.green, metrics.totalDelivered),
                _buildLegendDot(Colors.orange, metrics.totalInProgress),
                _buildLegendDot(Colors.red, metrics.totalFailedCancelled),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, int value) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(_formatCount(value), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  // Widget pour les lignes de statistiques détaillées
  Widget _buildStatRow(String label, int value, Color color, double? variation, {required bool inverseTrend, bool isBold = false}) {
    Color varColor = Colors.grey;
    IconData varIcon = Icons.remove;
    String varText = "";
    bool showVar = variation != null && variation != 0;

    if (showVar) {
        varText = "${variation! > 0 ? '+' : ''}${variation.toStringAsFixed(0)}%";
        if (variation > 0) {
            // Hausse
            varColor = inverseTrend ? Colors.red : Colors.green;
            varIcon = Icons.arrow_upward;
        } else {
            // Baisse
            varColor = inverseTrend ? Colors.green : Colors.red;
            varIcon = Icons.arrow_downward;
        }
    }

    return Row(
      children: [
        // Point de couleur + Label
        if (label != "Total") Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        Expanded(
            child: Text(
                label, 
                style: TextStyle(
                    fontSize: 14, 
                    color: isBold ? Colors.black87 : Colors.grey.shade700, 
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w500
                )
            )
        ),
        
        // Valeur (Utilisation de _formatCount)
        Text(
          _formatCount(value), 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)
        ),
        
        // Variation (Badge)
        const SizedBox(width: 16),
        SizedBox(
            width: 65, 
            child: showVar ? Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                    Icon(varIcon, size: 12, color: varColor),
                    const SizedBox(width: 4),
                    Text(varText, style: TextStyle(fontSize: 12, color: varColor, fontWeight: FontWeight.bold)),
                ]
            ) : const SizedBox(),
        )
      ],
    );
  }

  // --- 4. TOP MARCHANDS ---
  Widget _buildShopRankingList(List<ShopRankingItem> ranking) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ...ranking.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final reliability = item.reliabilityRate;
            Color relColor = reliability > 0.9 ? Colors.green : (reliability > 0.7 ? Colors.orange : Colors.red);

            Widget? medal;
            if (index == 0) medal = const Text("🥇", style: TextStyle(fontSize: 16));
            else if (index == 1) medal = const Text("🥈", style: TextStyle(fontSize: 16));
            else if (index == 2) medal = const Text("🥉", style: TextStyle(fontSize: 16));

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

            return Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: medal ?? Text(item.shopName.isNotEmpty ? item.shopName.substring(0, 1) : 'S', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(item.shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                      
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_formatCurrency(item.totalDeliveryFeesGenerated), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                          if (item.feesVariation != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(varIcon, size: 10, color: varColor),
                                Text(varText, style: TextStyle(fontSize: 10, color: varColor, fontWeight: FontWeight.bold)),
                              ],
                            )
                        ],
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text("${item.ordersProcessedCount} Traitées", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          Text(" / ${item.ordersSentCount} Envoyées", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(value: reliability, minHeight: 4, backgroundColor: Colors.grey[100], color: relColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text("${(reliability * 100).toInt()}%", style: TextStyle(fontSize: 10, color: relColor, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 70),
              ],
            );
          }),
          TextButton(
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => const AdminShopPerformanceScreen())
            ),
            child: const Text("VOIR TOUS LES MARCHANDS", style: TextStyle(fontSize: 12)),
          )
        ],
      ),
    );
  }
}