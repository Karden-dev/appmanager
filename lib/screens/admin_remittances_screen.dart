// lib/screens/admin_remittances_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/remittance.dart';
import 'package:wink_manager/providers/remittance_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/app_drawer.dart';
import 'package:wink_manager/widgets/network_status_icon.dart';
import 'package:wink_manager/widgets/remittance_edit_dialog.dart';
import 'package:wink_manager/widgets/remittance_stats_modal.dart';
import 'package:wink_manager/screens/main_navigation_screen.dart';

class AdminRemittancesScreen extends StatefulWidget {
  const AdminRemittancesScreen({super.key});

  @override
  State<AdminRemittancesScreen> createState() => _AdminRemittancesScreenState();
}

class _AdminRemittancesScreenState extends State<AdminRemittancesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final provider = context.read<RemittanceProvider>();
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !provider.isLoadingMore &&
        provider.hasMore) {
      provider.loadMore();
    }
  }

  Future<void> _loadData() async {
    await context.read<RemittanceProvider>().loadData();
  }

  Future<void> _handleSync() async {
    final provider = context.read<RemittanceProvider>();
    try {
      await provider.syncData();
      if (mounted) _showSuccessFeedback("Données synchronisées !");
    } catch (e) {
      if (mounted) _showErrorFeedback("Erreur sync: $e");
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<RemittanceProvider>().setSearch(query);
    });
  }

  Future<void> _selectDate() async {
    final provider = context.read<RemittanceProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) provider.setDate(picked);
  }

  // --- FORMATAGE ---
  String _formatAmount(double amount) {
    return NumberFormat.currency(
            locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0)
        .format(amount);
  }

  String _formatPhoneDisplay(String? phone) {
    if (phone == null || phone.isEmpty) return 'Non défini';
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 9) return phone;
    // Format X XX XX XX XX
    return '${clean[0]} ${clean.substring(1, 3)} ${clean.substring(3, 5)} ${clean.substring(5, 7)} ${clean.substring(7)}';
  }

  // --- MODALES & ACTIONS ---
  void _showStatsSheet() {
    final provider = context.read<RemittanceProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RemittanceStatsModal(
        stats: provider.stats,
        date: provider.selectedDate,
      ),
    );
  }

  Future<void> _showEditDialog(Remittance rem) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => RemittanceEditDialog(remittance: rem),
    );

    if (result != null && mounted) {
      _showLoadingFeedback("Mise à jour...");
      try {
        await context.read<RemittanceProvider>().updatePaymentDetails(
              rem.shopId,
              result['name'],
              result['phone'],
              result['operator'],
            );
        _showSuccessFeedback("Infos mises à jour !");
      } catch (e) {
        _showErrorFeedback("Erreur: $e");
      }
    }
  }

  Future<void> _payRemittance(Remittance rem) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmer le paiement"),
        content: Text(
            "Payer ${rem.shopName} ?\nMontant Net : ${_formatAmount(rem.netAmount)}"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text("Confirmer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _showLoadingFeedback("Paiement...");
      try {
        await context.read<RemittanceProvider>().markAsPaid(rem.id);
        _showSuccessFeedback("Paiement enregistré !");
      } catch (e) {
        _showErrorFeedback("Erreur: $e");
      }
    }
  }

  void _showLoadingFeedback(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
          Text(msg)
        ]),
        duration: const Duration(seconds: 1)));
  }

  void _showSuccessFeedback(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.success));
  }

  void _showErrorFeedback(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg.replaceFirst('Exception: ', '')),
        backgroundColor: AppTheme.danger));
  }
  
  void _onDrawerItemTapped(int index) {
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RemittanceProvider>();
    final dateText =
        DateFormat('dd MMM yyyy', 'fr_FR').format(provider.selectedDate);

    return Scaffold(
      drawer: AppDrawer(selectedIndex: -1, onItemTapped: _onDrawerItemTapped),
      appBar: AppBar(
        leading: Builder(
            builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer())),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Versements'),
            Text(dateText,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70)),
          ],
        ),
        actions: [
          const NetworkStatusIcon(),
          IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Stats',
              onPressed: _showStatsSheet),
          IconButton(
              icon: const Icon(Icons.calendar_today),
              tooltip: 'Date',
              onPressed: _selectDate),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      filled: true,
                      fillColor: AppTheme.background,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12)),
                    child: DropdownButton<String>(
                      value: provider.statusFilter,
                      icon: const Icon(Icons.filter_list,
                          color: AppTheme.secondaryColor, size: 20),
                      style: const TextStyle(fontSize: 13, color: AppTheme.text),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Tous')),
                        DropdownMenuItem(value: 'pending', child: Text('En attente')),
                        DropdownMenuItem(value: 'paid', child: Text('Payés')),
                      ],
                      onChanged: (val) {
                        if (val != null) provider.setStatusFilter(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: provider.isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync, color: AppTheme.accentColor),
                  onPressed: provider.isSyncing ? null : _handleSync,
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleSync,
        child: Column(
          children: [
            if (provider.error != null)
              Container(
                  padding: const EdgeInsets.all(8),
                  color: AppTheme.danger.withOpacity(0.1),
                  width: double.infinity,
                  child: Text(provider.error!,
                      style: const TextStyle(color: AppTheme.danger),
                      textAlign: TextAlign.center)),
            Expanded(
              child: provider.isLoading && provider.remittances.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.remittances.isEmpty
                      ? const Center(
                          child: Text("Aucun versement trouvé."))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 80),
                          itemCount: provider.remittances.length +
                              (provider.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == provider.remittances.length) {
                              return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator()));
                            }
                            final item = provider.remittances[index];
                            return _buildTicketCard(item);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET "TICKET" COMPACT & PRO ---
  Widget _buildTicketCard(Remittance item) {
    final bool isPending = item.status == 'pending';
    final bool isPayable = isPending && item.netAmount > 0;
    final bool isOrange = item.paymentOperator == 'Orange Money';
    final Color opColor = isOrange ? Colors.orange : const Color(0xFFffcc00);
    
    final Color statusColor = isPending ? Colors.orange.shade800 : Colors.green.shade700;
    final Color statusBg = isPending ? Colors.orange.shade50 : Colors.green.shade50;
    final String statusText = isPending ? 'En attente' : 'Payé';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12), // Densité augmentée (padding réduit)
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. LIGNE HAUTE (Identité)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.shopName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 15, 
                      color: AppTheme.secondaryColor
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    statusText.toUpperCase(),
                    style: TextStyle(
                      color: statusColor, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 10
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 2. LIGNE MILIEU (Contact Compact)
            Row(
              children: [
                // Petit carré opérateur
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: opColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isOrange ? Icons.phone_android : Icons.wifi_tethering,
                    color: opColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                // Infos Tél + Nom
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatPhoneDisplay(item.phoneNumberForPayment),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800, // Gras
                          fontSize: 14,
                          color: AppTheme.text,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        item.paymentName ?? 'Nom non défini',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Bouton Modifier (Crayon)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.grey, size: 18),
                  onPressed: () => _showEditDialog(item),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 3. LIGNE BASSE (Finances "Ticket" + Action)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F8), // Gris très léger ticket
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Bloc Montant
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Détails (Brut/Dette) en petit
                      Row(
                        children: [
                          Text("Brut: ${_formatAmount(item.grossAmount)}", 
                              style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                          if (item.debtsConsolidated > 0)
                            Text("   Dette: ${_formatAmount(item.debtsConsolidated)}", 
                                style: const TextStyle(fontSize: 10, color: AppTheme.danger)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Net à Payer
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text("NET À PAYER: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.secondaryColor)),
                          const SizedBox(width: 4),
                          Text(
                            _formatAmount(item.netAmount),
                            style: const TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.w900, 
                              color: AppTheme.primaryColor
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Bouton Action (Compact)
                  if (isPayable)
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () => _payRemittance(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: const StadiumBorder(), // Pill button
                          elevation: 0,
                        ),
                        child: const Text("Payer", style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    )
                  else if (!isPending)
                    const Icon(Icons.check_circle, color: Colors.green, size: 24)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}