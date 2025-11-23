// lib/screens/admin_reports_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/models/report_models.dart';
import 'package:wink_manager/providers/report_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/widgets/network_status_icon.dart';
import 'package:wink_manager/widgets/report_summary_card.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Charge les données initiales (pour aujourd'hui) au premier chargement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportProvider>(context, listen: false).loadReports();
    });

    _searchController.addListener(() {
      Provider.of<ReportProvider>(context, listen: false)
          .setSearch(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Affiche le sélecteur de date
  Future<void> _selectDate(BuildContext context) async {
    final provider = context.read<ReportProvider>();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && picked != provider.selectedDate) {
      // Efface la recherche en changeant de date
      _searchController.clear();
      provider.setDate(picked);
    }
  }

  /// Affiche un SnackBar
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
      ),
    );
  }

  /// Affiche une boîte de dialogue de chargement
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Gère l'action "Traiter le stockage"
  Future<void> _triggerProcessStorage() async {
    final provider = context.read<ReportProvider>();
    final dateStr = DateFormat('dd/MM/yyyy', 'fr_FR').format(provider.selectedDate);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer le Traitement'),
        content: Text(
            'Voulez-vous traiter les frais de stockage pour le $dateStr ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Traiter')),
        ],
      ),
    );

    if (confirmed == true) {
      _showLoadingDialog('Traitement du stockage...');
      try {
        final message = await provider.triggerProcessStorage();
        if (mounted) Navigator.pop(context); // Fermer le loading
        _showSnackbar(message);
      } catch (e) {
        if (mounted) Navigator.pop(context); // Fermer le loading
        _showSnackbar(e.toString(), isError: true);
      }
    }
  }

  /// Gère l'action "Recalculer"
  Future<void> _triggerRecalculate() async {
    final provider = context.read<ReportProvider>();
    final dateStr = DateFormat('dd/MM/yyyy', 'fr_FR').format(provider.selectedDate);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer le Recalcul'),
        content: Text(
            'Voulez-vous forcer le recalcul des bilans pour le $dateStr ? Cette action peut prendre du temps.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Recalculer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _showLoadingDialog('Recalcul en cours...');
      try {
        final message = await provider.triggerRecalculate();
        if (mounted) Navigator.pop(context); // Fermer le loading
        _showSnackbar(message);
      } catch (e) {
        if (mounted) Navigator.pop(context); // Fermer le loading
        _showSnackbar(e.toString(), isError: true);
      }
    }
  }

  /// Ouvre le BottomSheet avec les statistiques (STYLE AMÉLIORÉ)
  void _showStatsModal(BuildContext context, ReportStatCards? stats) {
    stats ??= ReportStatCards();

    showModalBottomSheet(
      context: context,
      // Permet au contenu de définir la hauteur
      isScrollControlled: true, 
      // Arrondit les coins supérieurs
      shape: const RoundedRectangleBorder( 
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Détermine la couleur du montant net total
        final Color totalRemitColor = (stats!.totalAmountToRemit < 0)
            ? AppTheme.danger
            : AppTheme.success;

        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poignée de glissement (Drag Handle)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Titre
              Text(
                'Statistiques Globales',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // *** NOUVELLE CARTE : Total Net à Verser ***
              _StatCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Total Net à Verser',
                value: ReportSummary.formatAmount(stats.totalAmountToRemit),
                color: totalRemitColor,
              ),
              const SizedBox(height: 10),

              _StatCard(
                icon: Icons.trending_down,
                title: 'Total Créances',
                value: ReportSummary.formatAmount(stats.totalDebt),
                color: AppTheme.danger,
              ),
              const SizedBox(height: 10),
              
              _StatCard(
                icon: Icons.storefront_outlined,
                title: 'Marchands Actifs',
                value: stats.activeMerchants.toString(),
                color: AppTheme.secondaryColor,
              ),
              const SizedBox(height: 10),

              _StatCard(
                icon: Icons.inventory_2_outlined,
                title: 'Total Stockage',
                value: ReportSummary.formatAmount(stats.totalStorage),
                color: AppTheme.accentColor,
              ),
              const SizedBox(height: 10),

              _StatCard(
                icon: Icons.kitchen_outlined,
                title: 'Total Emballage',
                value: ReportSummary.formatAmount(stats.totalPackaging),
                color: AppTheme.accentColor,
              ),
              // Padding pour le bas de l'écran (safe area)
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Écoute le ReportProvider
    return Consumer<ReportProvider>(
      builder: (context, provider, child) {
        final dateText =
            DateFormat('dd MMMM yyyy', 'fr_FR').format(provider.selectedDate);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rapports Journaliers'),
                Text(
                  dateText,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70),
                ),
              ],
            ),
            actions: [
              const NetworkStatusIcon(),
              IconButton(
                icon: const Icon(Icons.bar_chart),
                tooltip: 'Voir les statistiques globales',
                onPressed: () => _showStatsModal(context, provider.statCards),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                tooltip: 'Changer la date',
                onPressed: () => _selectDate(context),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60.0),
              child: Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un marchand...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          filled: true,
                          fillColor: AppTheme.background,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'recalculate') {
                          _triggerRecalculate();
                        } else if (value == 'storage') {
                          _triggerProcessStorage();
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'recalculate',
                          child: ListTile(
                            leading: Icon(Icons.sync, color: AppTheme.danger),
                            title: Text('Recalculer'),
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'storage',
                          child: ListTile(
                            leading: Icon(Icons.inventory_2_outlined,
                                color: AppTheme.secondaryColor),
                            title: Text('Traiter Stockage'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: provider.loadReports,
            child: _buildReportList(provider),
          ),
        );
      },
    );
  }

  /// Construit la liste des rapports.
  Widget _buildReportList(ReportProvider provider) {
    if (provider.isLoading && provider.filteredReports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            provider.error!,
            style: const TextStyle(color: AppTheme.danger),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (provider.filteredReports.isEmpty) {
      return const Center(
        child: Text(
          'Aucun rapport trouvé pour cette date.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // *** CORRECTION POUR LA CARTE COUPÉE ***
    // Ajout d'un Padding au ListView.builder
    return Padding(
      // Ajoute 90px en bas pour laisser de la place à la barre de nav et au FAB
      padding: const EdgeInsets.only(bottom: 90.0), 
      child: ListView.builder(
        // Le padding horizontal et vertical est maintenant sur le ListView
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        itemCount: provider.filteredReports.length,
        itemBuilder: (context, index) {
          final report = provider.filteredReports[index];
          return ReportSummaryCard(
            report: report,
            provider: provider, 
          );
        },
      ),
    );
  }
}

/// *** WIDGET INTERNE AMÉLIORÉ (Style ListTile avec Icône) ***
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon; // Ajout d'une icône

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      // Fond légèrement teinté
      color: color.withAlpha(20), 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // Bordure de la couleur respective
        side: BorderSide(color: color.withAlpha(100), width: 1), 
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icône et Titre
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    // Couleur du texte légèrement plus sombre
                    color: color.withAlpha(220), 
                  ),
                ),
              ],
            ),
            // Valeur (utilise Flexible et FittedBox pour éviter l'overflow)
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}