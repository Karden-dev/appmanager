// lib/screens/admin_cash_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/cash_models.dart';
import 'package:wink_manager/providers/cash_provider.dart';
import 'package:wink_manager/screens/admin_cash_closing_screen.dart';
import 'package:wink_manager/screens/admin_remittance_detail_screen.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/app_drawer.dart';
import 'package:wink_manager/widgets/network_status_icon.dart';
import 'package:wink_manager/widgets/add_transaction_dialog.dart';
import 'package:wink_manager/widgets/shortfall_edit_dialog.dart';

class AdminCashScreen extends StatefulWidget {
  const AdminCashScreen({super.key});

  @override
  State<AdminCashScreen> createState() => _AdminCashScreenState();
}

class _AdminCashScreenState extends State<AdminCashScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _operationFilter = 'all'; // 'all', 'expense', 'manual_withdrawal'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _searchController.clear();
          _searchQuery = '';
        });
        context.read<CashProvider>().setTabIndex(_tabController.index + 1);
      }
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CashProvider>().setTabIndex(1);
      context.read<CashProvider>().loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatAmount(double amount) {
    return NumberFormat.currency(
            locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0)
        .format(amount);
  }

  // --- ACTIONS ---

  void _showShortfallActionDialog(Shortfall item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Régler le manquant de ${item.deliverymanName} ?'),
        content: Text(
            'Confirmez-vous le remboursement de ${_formatAmount(item.amount)} ?\n\nCette somme sera ajoutée aux encaissements.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context
                    .read<CashProvider>()
                    .settleShortfall(item.id, item.amount);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Manquant réglé avec succès"),
                      backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Erreur: $e"), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('CONFIRMER',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      String title, String content, Future<void> Function() onDelete) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await onDelete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Suppression effectuée"),
              backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Erreur: $e"), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _goToRemittanceDetail(int deliverymanId, String deliverymanName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminRemittanceDetailScreen(
          deliverymanId: deliverymanId,
          deliverymanName: deliverymanName,
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final provider = context.read<CashProvider>();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          DateTimeRange(start: provider.startDate, end: provider.endDate),
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
                const ColorScheme.light(primary: AppTheme.primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      provider.setDateRange(picked.start, picked.end);
    }
  }

  void _showStatsBottomSheet(BuildContext context, CashMetrics metrics) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CashStatsModal(
        metrics: metrics,
        startDate: context.read<CashProvider>().startDate,
        endDate: context.read<CashProvider>().endDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CashProvider>();

    return Scaffold(
      drawer: AppDrawer(selectedIndex: -1, onItemTapped: (_) {}),
      appBar: AppBar(
        title: const Text('Caisse & Trésorerie'),
        actions: [
          const NetworkStatusIcon(),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: "Bilan",
            onPressed: () => _showStatsBottomSheet(context, provider.metrics),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: "Période",
            onPressed: _selectDate,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            })
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'VERSEMENTS'),
                  Tab(text: 'OPÉRATIONS'),
                  Tab(text: 'MANQUANTS'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRemittancesList(provider),
          _buildOperationsList(provider),
          _buildShortfallsList(provider),
        ],
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget? _buildFab(BuildContext context) {
    if (_tabController.index == 0) {
      // Versements -> Clôturer
      return FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminCashClosingScreen()),
          );
        },
        backgroundColor: AppTheme.secondaryColor,
        tooltip: 'Clôturer la caisse',
        child: const Icon(Icons.lock, color: Colors.white),
      );
    } else if (_tabController.index == 1) {
      // Opérations -> Ajouter
      return FloatingActionButton(
        onPressed: () => showDialog(
            context: context, builder: (_) => const AddTransactionDialog()),
        backgroundColor: AppTheme.primaryColor,
        tooltip: 'Ajouter opération',
        child: const Icon(Icons.add, color: Colors.white),
      );
    } else {
      // Manquants -> Ajouter
      return FloatingActionButton(
        onPressed: () {
           showDialog(
             context: context, 
             builder: (_) => const ShortfallEditDialog() 
           );
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      );
    }
  }

  // --- ONGLET 1 : VERSEMENTS ---
  Widget _buildRemittancesList(CashProvider provider) {
    var list = provider.remittanceSummary;
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((item) =>
              item.userName.toLowerCase().contains(_searchQuery))
          .toList();
    }

    list.sort((a, b) {
      if (a.pendingAmount > 0 && b.pendingAmount <= 0) return -1;
      if (a.pendingAmount <= 0 && b.pendingAmount > 0) return 1;
      return b.pendingAmount.compareTo(a.pendingAmount);
    });

    if (list.isEmpty) {
      return const Center(
          child: Text("Aucun versement trouvé pour cette période."));
    }

    return ListView.separated(
      itemCount: list.length,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = list[index];
        final hasPending = item.pendingAmount > 0;

        return Card(
          elevation: hasPending ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: hasPending
                ? const BorderSide(color: AppTheme.primaryColor, width: 1.5)
                : BorderSide.none,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor:
                  hasPending ? AppTheme.primaryColor : Colors.grey.shade200,
              child: Text(
                item.userName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: hasPending ? Colors.white : Colors.grey.shade600),
              ),
            ),
            title: Text(
              item.userName,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: hasPending ? Colors.black87 : Colors.grey.shade600),
            ),
            subtitle: Text(
              "${item.pendingCount} commande(s) en attente",
              style: TextStyle(
                  color: hasPending ? AppTheme.secondaryColor : Colors.grey),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatAmount(item.pendingAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: hasPending ? AppTheme.danger : Colors.grey,
                    fontSize: 16,
                  ),
                ),
                if (hasPending)
                  const Text("À ENCAISSER",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.danger))
                else
                  const Text("À JOUR",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
              ],
            ),
            onTap: () => _goToRemittanceDetail(item.userId, item.userName),
          ),
        );
      },
    );
  }

  // --- ONGLET 2 : OPÉRATIONS ---
  Widget _buildOperationsList(CashProvider provider) {
    var filteredOps = provider.transactions.where((op) {
      return op.type != 'remittance' && op.type != 'remittance_correction';
    }).toList();

    if (_operationFilter != 'all') {
      filteredOps =
          filteredOps.where((op) => op.type == _operationFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredOps = filteredOps.where((op) {
        final cat = op.categoryName?.toLowerCase() ?? '';
        final com = op.comment?.toLowerCase() ?? '';
        final user = op.userName.toLowerCase();
        return cat.contains(_searchQuery) ||
            com.contains(_searchQuery) ||
            user.contains(_searchQuery);
      }).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFilterChip('Tout', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Dépenses', 'expense'),
              const SizedBox(width: 8),
              _buildFilterChip('Décais.', 'manual_withdrawal'),
            ],
          ),
        ),
        Expanded(
          child: filteredOps.isEmpty
              ? const Center(child: Text("Aucune opération trouvée."))
              : ListView.separated(
                  itemCount: filteredOps.length,
                  padding: const EdgeInsets.only(bottom: 80),
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final op = filteredOps[index];
                    final isExpense = op.type == 'expense';
                    
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isExpense
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isExpense
                              ? Icons.shopping_bag_outlined
                              : Icons.account_balance,
                          color: isExpense ? Colors.orange : Colors.red,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        isExpense
                            ? (op.categoryName ?? 'Dépense')
                            : 'Décais.', // Abréviation
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      // MODIFICATION : Affichage sur 3 lignes distinctes
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ligne 1 : Commentaire
                          Text(
                            op.comment ?? 'Aucun commentaire',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Ligne 2 : Par : [Utilisateur]
                          Text(
                            "Par : ${op.userName}",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Ligne 3 : Date (dd/MM/yyyy)
                          Text(
                            DateFormat('dd/MM/yyyy').format(op.createdAt),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            // MODIFICATION : Retrait du signe - devant le montant
                            _formatAmount(op.amount.abs()),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                                fontSize: 15),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                showDialog(
                                  context: context,
                                  builder: (_) => AddTransactionDialog(transaction: op),
                                );
                              } else if (value == 'delete') {
                                _confirmDelete(
                                  "Supprimer l'opération ?", 
                                  "Voulez-vous vraiment supprimer cette opération de ${_formatAmount(op.amount.abs())} ?", 
                                  () => provider.deleteTransaction(op.id)
                                );
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Modifier')]),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: Colors.red))]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _operationFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _operationFilter = value);
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryColor : Colors.black),
    );
  }

  // --- ONGLET 3 : MANQUANTS ---
  Widget _buildShortfallsList(CashProvider provider) {
    var list = provider.shortfalls;

    if (_searchQuery.isNotEmpty) {
      list = list
          .where((sf) =>
              sf.deliverymanName.toLowerCase().contains(_searchQuery))
          .toList();
    }

    if (list.isEmpty) return const Center(child: Text("Aucun manquant."));

    return ListView.separated(
      itemCount: list.length,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final sf = list[index];
        final isPaid = sf.status == 'paid';

        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: isPaid ? Colors.green : AppTheme.danger, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sf.deliverymanName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (sf.comment != null)
                        Text(sf.comment!,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13)),
                      Text(
                        DateFormat('dd MMM yyyy').format(sf.createdAt),
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatAmount(sf.amount),
                        style: TextStyle(
                            color: isPaid ? Colors.green : AppTheme.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green.shade200)),
                            child: const Text("RÉGLÉ",
                                style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                          ),
                          
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                             if (value == 'pay') {
                               _showShortfallActionDialog(sf);
                             } else if (value == 'edit') {
                               showDialog(
                                  context: context,
                                  builder: (_) => ShortfallEditDialog(shortfall: sf),
                                );
                             } else if (value == 'delete') {
                                _confirmDelete(
                                  "Supprimer le manquant ?", 
                                  "Voulez-vous supprimer définitivement ce manquant ?", 
                                  () => provider.deleteShortfall(sf.id)
                                );
                             }
                          },
                          itemBuilder: (ctx) => [
                            if (!isPaid) const PopupMenuItem(value: 'pay', child: Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 18), SizedBox(width: 8), Text('Régler')])),
                            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Modifier')])),
                            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: Colors.red))])),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- MODAL STATS ---
class _CashStatsModal extends StatelessWidget {
  final CashMetrics metrics;
  final DateTime startDate;
  final DateTime endDate;

  const _CashStatsModal({
    required this.metrics,
    required this.startDate,
    required this.endDate,
  });

  String _formatAmount(double amount) {
    return NumberFormat.currency(
            locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0)
        .format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final String dateText = startDate.year == endDate.year &&
            startDate.month == endDate.month &&
            startDate.day == endDate.day
        ? DateFormat('dd MMM yyyy', 'fr_FR').format(startDate)
        : "Du ${DateFormat('dd/MM').format(startDate)} au ${DateFormat('dd/MM/yy').format(endDate)}";

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Text(
            "Bilan de Caisse",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 4),
          Text(dateText, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.secondaryColor,
                  AppTheme.secondaryColor.withOpacity(0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              children: [
                const Text("SOLDE THÉORIQUE EN CAISSE",
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0)),
                const SizedBox(height: 8),
                Text(
                  _formatAmount(metrics.montantEnCaisse),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: "TOTAL ENCAISSÉ",
                  value: metrics.totalCollected + metrics.creancesRemboursees + metrics.manquantsRembourses,
                  color: Colors.green,
                  icon: Icons.arrow_circle_down,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: "TOTAL DÉCAISSÉ",
                  value: metrics.totalExpenses + metrics.totalWithdrawals,
                  color: AppTheme.danger,
                  icon: Icons.arrow_circle_up,
                ),
              ),
            ],
          ),
          // Détails Encaissé
          const SizedBox(height: 12),
          const Align(alignment: Alignment.centerLeft, child: Text("Détails Encaissements", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
          _buildDetailRow("Encaissements Commandes", metrics.totalCollected, Colors.green),
          _buildDetailRow("Créances Remboursées", metrics.creancesRemboursees, Colors.green),
          _buildDetailRow("Manquants Remboursés", metrics.manquantsRembourses, Colors.green),
          
          // Détails Décaissé
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft, child: Text("Détails Décaissements", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
          _buildDetailRow("Dépenses", metrics.totalExpenses, Colors.orange),
          _buildDetailRow("Décaissements Manuels", metrics.totalWithdrawals, Colors.red),
          
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      {required String title,
      required double value,
      required Color color,
      required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade100,
              offset: const Offset(0, 4),
              blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatAmount(value),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          Text(_formatAmount(value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}