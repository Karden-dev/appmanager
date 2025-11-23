// lib/screens/admin_debts_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/debt.dart';
import 'package:wink_manager/providers/debt_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/app_drawer.dart';
import 'package:wink_manager/widgets/debt_card.dart';
import 'package:wink_manager/widgets/debt_edit_dialog.dart';
import 'package:wink_manager/widgets/debt_stats_modal.dart';
import 'package:wink_manager/widgets/network_status_icon.dart';
import 'package:wink_manager/screens/main_navigation_screen.dart';

class AdminDebtsScreen extends StatefulWidget {
  const AdminDebtsScreen({super.key});

  @override
  State<AdminDebtsScreen> createState() => _AdminDebtsScreenState();
}

class _AdminDebtsScreenState extends State<AdminDebtsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Synchroniser l'onglet UI avec le Provider
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        context.read<DebtProvider>().setTabIndex(_tabController.index);
      }
    });

    _scrollController.addListener(_onScroll);

    // Chargement initial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Réinitialiser à l'onglet 0 au démarrage
      context.read<DebtProvider>().setTabIndex(0);
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final provider = context.read<DebtProvider>();
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !provider.isLoadingMore &&
        provider.hasMore) {
      provider.loadMore();
    }
  }

  Future<void> _loadData() async {
    await context.read<DebtProvider>().loadData();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<DebtProvider>().setSearch(query);
    });
  }

  Future<void> _selectDateRange() async {
    final provider = context.read<DebtProvider>();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: provider.startDate, end: provider.endDate),
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      provider.setDateRange(picked.start, picked.end);
    }
  }

  // --- ACTIONS UI ---

  void _showStatsSheet() {
    final provider = context.read<DebtProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DebtStatsModal(
        stats: provider.stats,
        startDate: provider.startDate,
        endDate: provider.endDate,
      ),
    );
  }

  Future<void> _showAddDebtDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const DebtEditDialog(), // Mode création
    );

    if (result != null && mounted) {
      _showLoadingFeedback("Création en cours...");
      try {
        await context.read<DebtProvider>().createDebt(result);
        _showSuccessFeedback("Créance ajoutée avec succès !");
      } catch (e) {
        _showErrorFeedback("Erreur: $e");
      }
    }
  }

  Future<void> _showEditDialog(Debt debt) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => DebtEditDialog(debt: debt), // Mode édition
    );

    if (result != null && mounted) {
      _showLoadingFeedback("Modification en cours...");
      try {
        // On récupère amount et comment du résultat
        await context.read<DebtProvider>().updateDebt(
          debt.id,
          result['amount'],
          result['comment'] ?? '',
        );
        _showSuccessFeedback("Créance modifiée !");
      } catch (e) {
        _showErrorFeedback("Erreur: $e");
      }
    }
  }

  Future<void> _settleDebt(Debt debt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmer le règlement"),
        content: Text("Marquer la créance de ${debt.shopName} comme RÉGLÉE ?\n\nMontant : ${_formatAmount(debt.amount)}"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text("Confirmer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _showLoadingFeedback("Traitement...");
      try {
        await context.read<DebtProvider>().settleDebt(debt.id);
        _showSuccessFeedback("Créance réglée !");
      } catch (e) {
        _showErrorFeedback("Erreur: $e");
      }
    }
  }

  Future<void> _deleteDebt(Debt debt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer la créance"),
        content: const Text("Cette action est irréversible. Continuer ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _showLoadingFeedback("Suppression...");
      try {
        await context.read<DebtProvider>().deleteDebt(debt.id);
        _showSuccessFeedback("Créance supprimée.");
      } catch (e) {
        _showErrorFeedback("Erreur: $e");
      }
    }
  }

  // --- FEEDBACK ---
  void _showLoadingFeedback(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), const SizedBox(width: 16), Text(msg)]),
      duration: const Duration(seconds: 1),
    ));
  }
  void _showSuccessFeedback(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.success));
  void _showErrorFeedback(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.replaceFirst('Exception: ', '')), backgroundColor: AppTheme.danger));
  
  String _formatAmount(double amount) => NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(amount);

  void _onDrawerItemTapped(int index) {
    Navigator.pop(context);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtProvider>();
    final dateRangeText = provider.startDate.year == provider.endDate.year && 
                          provider.startDate.month == provider.endDate.month && 
                          provider.startDate.day == provider.endDate.day
        ? DateFormat('dd MMM yyyy', 'fr_FR').format(provider.startDate)
        : "${DateFormat('dd/MM').format(provider.startDate)} - ${DateFormat('dd/MM').format(provider.endDate)}";

    return Scaffold(
      drawer: AppDrawer(selectedIndex: -1, onItemTapped: _onDrawerItemTapped),
      appBar: AppBar(
        leading: Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Créances'),
            Text(dateRangeText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70)),
          ],
        ),
        actions: [
          const NetworkStatusIcon(),
          IconButton(icon: const Icon(Icons.bar_chart), tooltip: 'Stats', onPressed: _showStatsSheet),
          IconButton(icon: const Icon(Icons.date_range), tooltip: 'Période', onPressed: _selectDateRange),
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDebtDialog,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),

      body: Column(
        children: [
          // Barre de Filtres + Tabs
          Container(
            color: Colors.white,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.primaryColor,
                  tabs: const [
                    Tab(text: 'EN ATTENTE'),
                    Tab(text: 'HISTORIQUE'),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher (Marchand, Commentaire)...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: AppTheme.background,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ],
            ),
          ),

          if (provider.error != null)
             Container(
               padding: const EdgeInsets.all(8), 
               color: AppTheme.danger.withOpacity(0.1), 
               width: double.infinity, 
               child: Text(provider.error!, style: const TextStyle(color: AppTheme.danger), textAlign: TextAlign.center)
             ),

          // Liste des Dettes
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.loadData(forceApi: true),
              child: provider.isLoading && provider.debts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.debts.isEmpty
                      ? Center(child: Text(_tabController.index == 0 ? "Aucune créance en attente." : "Aucun historique pour cette période."))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80), // Espace pour le FAB
                          itemCount: provider.debts.length + (provider.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == provider.debts.length) return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
                            
                            final debt = provider.debts[index];
                            return DebtCard(
                              debt: debt,
                              onSettle: () => _settleDebt(debt),
                              // On autorise l'édition/suppression uniquement pour les dettes manuelles (pas 'daily_balance')
                              onEdit: debt.type != 'daily_balance' ? () => _showEditDialog(debt) : null,
                              onDelete: debt.type != 'daily_balance' ? () => _deleteDebt(debt) : null,
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}