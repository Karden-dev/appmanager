// lib/screens/rider_cash_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // Bonne pratique

import '../services/order_service.dart';
import '../models/rider_cash_details.dart';
import '../utils/app_theme.dart';

class RiderCashScreen extends StatefulWidget {
  const RiderCashScreen({super.key});

  @override
  State<RiderCashScreen> createState() => _RiderCashScreenState();
}

class _RiderCashScreenState extends State<RiderCashScreen> {
  DateTime _selectedDate = DateTime.now();
  // Déclarer _cashDetailsFuture comme nullable au départ
  Future<RiderCashDetails>? _cashDetailsFuture;

  // Déclaration locale des traductions (inchangée)
  final Map<String, String> _statusTranslations = {
    'pending': 'En attente',
    'paid': 'Réglé',
    'confirmed': 'Confirmé',
    'partially_paid': 'Partiel',
  };

  @override
  void initState() {
    super.initState();
    // Charge les détails pour aujourd'hui initialement après le build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDetailsForSelectedDate();
    });
  }

  // Fonction pour lancer le fetch des détails de caisse
  Future<void> _fetchDetailsForSelectedDate() async {
    // Vérification initiale de mounted
    if (!mounted) return;

    final orderService = Provider.of<OrderService?>(context, listen: false);
    if (orderService == null) {
      if (mounted) {
        setState(() {
          _cashDetailsFuture = Future.error("Service de commandes non disponible.");
        });
      }
      return;
    }

    // Mise à jour de l'état pour indiquer le chargement et assigner la nouvelle Future
    if (mounted) {
      setState(() {
        // Lancement de la requête
        _cashDetailsFuture = orderService.fetchRiderCashDetails(_selectedDate);
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    // Garde une référence au contexte avant l'appel asynchrone
    final currentContext = context;
    // Vérification initiale de mounted
    if (!mounted) return;

    final DateTime? picked = await showDatePicker(
      context: currentContext, // Utilise le contexte local
      initialDate: _selectedDate,
      firstDate: DateTime(2020), // Ajustez si nécessaire
      lastDate: DateTime.now().add(const Duration(days: 1)), // Permet de sélectionner demain au max
      locale: const Locale('fr', 'FR'),
    );

    // Vérification de mounted APRES l'appel asynchrone
    if (!mounted) return;

    if (picked != null && picked != _selectedDate) {
      // Mise à jour de l'état local de la date AVANT de lancer le fetch
      setState(() {
        _selectedDate = picked;
        // Met _cashDetailsFuture à null pour montrer le spinner
        _cashDetailsFuture = null;
      });
      // Lance le fetch après la mise à jour de l'état
      _fetchDetailsForSelectedDate();
    }
  }

  // --- Widgets pour l'UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar( // <-- AppBar SUPPRIMÉE ICI
      //   title: const Text('Ma Caisse'),
      // ),
      body: Column(
        children: [
          // --- Sélecteur de Date ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Affichage pour le:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),
          ),

          // --- Résumé Financier ---
          FutureBuilder<RiderCashDetails>(
            future: _cashDetailsFuture, // Utilise la variable d'état
            builder: (context, snapshot) {
              // Gère l'état initial ou de rechargement
              if (_cashDetailsFuture == null || (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null)) {
                // Affiche un placeholder pendant le chargement initial forcé
                return _buildSummaryCard(null, false, true); // isLoading = true
              }
              // Affiche seulement le résumé une fois les données chargées
              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                final summary = snapshot.data!.summary;
                return _buildSummaryCard(summary);
              }
              // Affiche un placeholder en cas d'erreur
              return _buildSummaryCard(null, snapshot.hasError);
            },
          ),

          // --- Titre Liste Transactions ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              'Détail des Transactions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),

          // --- Liste des Transactions ---
          Expanded(
            child: FutureBuilder<RiderCashDetails>(
              future: _cashDetailsFuture, // Utilise la variable d'état
              builder: (context, snapshot) {
                 // Gère l'état initial ou de rechargement
                 if (_cashDetailsFuture == null || (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null)) {
                   return const Center(child: CircularProgressIndicator());
                 }
                // --- La suite reste identique ---
                if (snapshot.connectionState == ConnectionState.waiting) {
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
                } else if (!snapshot.hasData || snapshot.data!.transactions.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucune transaction pour cette date.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final transactions = snapshot.data!.transactions;

                // Ajout RefreshIndicator
                return RefreshIndicator(
                  onRefresh: _fetchDetailsForSelectedDate,
                  child: ListView.separated(
                    // physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      if (tx is OrderTransaction) {
                        return _buildOrderTransactionItem(tx);
                      } else if (tx is ExpenseTransaction) {
                        return _buildExpenseTransactionItem(tx);
                      } else if (tx is ShortfallTransaction) {
                        return _buildShortfallTransactionItem(tx);
                      } else if (tx is UnknownTransaction) {
                        // Optionnel: Gérer l'affichage des transactions inconnues
                        return ListTile(title: Text('Transaction inconnue ID: ${tx.id}'));
                      }
                      return const SizedBox.shrink();
                    },
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour la carte de résumé (ajout paramètre isLoading)
  Widget _buildSummaryCard(CashSummary? summary, [bool hasError = false, bool isLoading = false]) {
    // Valeurs avec formatage ou état de chargement/erreur
    String expected = isLoading ? 'Chargement...' : (hasError ? 'Erreur' : currencyFormatter.format(summary!.amountExpected));
    String confirmed = isLoading ? 'Chargement...' : (hasError ? 'Erreur' : currencyFormatter.format(summary!.amountConfirmed));
    String expenses = isLoading ? 'Chargement...' : (hasError ? 'Erreur' : currencyFormatter.format(summary!.totalExpenses.abs()));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSummaryRow(
              'Montant Attendu',
              expected,
              hasError ? AppTheme.danger : AppTheme.primaryColor,
              isLoading, // Passe l'état de chargement
            ),
            const Divider(height: 16),
            _buildSummaryRow(
              'Versements Confirmés',
              confirmed,
              hasError ? AppTheme.danger : Colors.green.shade700,
              isLoading, // Passe l'état de chargement
            ),
             const Divider(height: 16),
            _buildSummaryRow(
              'Total Dépenses',
              expenses,
              hasError ? AppTheme.danger : Colors.orange.shade800,
              isLoading, // Passe l'état de chargement
            ),
          ],
        ),
      ),
    );
  }

  // Widget helper pour une ligne du résumé (inchangé)
  Widget _buildSummaryRow(String label, String value, Color valueColor, bool isLoading) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        isLoading
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(
                value,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor),
              ),
      ],
    );
  }

  // --- Widgets pour les items de la liste de transactions (inchangés) ---

  // Item pour une commande (Type: order)
  Widget _buildOrderTransactionItem(OrderTransaction tx) {
    bool isExpedition = tx.amount < 0;
    String title = isExpedition ? 'Expédition #${tx.orderId}' : 'Commande #${tx.orderId}';
    IconData icon = isExpedition ? Icons.local_shipping_outlined : Icons.inventory_2_outlined;
    String statusText;
    Color statusColor;

    if (tx.remittanceStatus == 'confirmed') {
      statusText = 'Confirmé';
      statusColor = Colors.green;
    } else { // pending (par défaut)
      statusText = isExpedition ? 'Frais à confirmer' : 'Cash à verser';
      statusColor = Colors.orange;
    }

    return ListTile(
      leading: Icon(icon, color: AppTheme.secondaryColor, size: 30),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tx.shopName != null) Text('Marchand: ${tx.shopName}', style: const TextStyle(fontSize: 12)),
          if (tx.itemsList != null) Text('Articles: ${tx.itemsList}', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (tx.deliveryLocation != null) Text('Lieu: ${tx.deliveryLocation}', style: const TextStyle(fontSize: 12)),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            formatTransactionAmount(tx.amount, tx.type),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: getTransactionAmountColor(tx.amount, tx.type)),
          ),
          const SizedBox(height: 4),
           Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               Icon(Icons.circle, size: 8, color: statusColor),
               const SizedBox(width: 4),
               Text(statusText, style: TextStyle(fontSize: 11, color: statusColor)),
             ],
           ),
           if (tx.remittanceStatus == 'confirmed' && tx.confirmedAmount > 0 && tx.amount.abs() != tx.confirmedAmount)
              Text(
                '(${currencyFormatter.format(tx.confirmedAmount)})',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
        ],
      ),
      isThreeLine: true,
    );
  }

  // Item pour une dépense (Type: expense)
  Widget _buildExpenseTransactionItem(ExpenseTransaction tx) {
    return ListTile(
      leading: Icon(Icons.receipt_long_outlined, color: Colors.orange.shade800, size: 30),
      title: const Text('Dépense', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: tx.comment != null && tx.comment!.isNotEmpty ? Text(tx.comment!, style: const TextStyle(fontSize: 12)) : null,
      trailing: Column(
         crossAxisAlignment: CrossAxisAlignment.end,
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
             Text(
              formatTransactionAmount(tx.amount, tx.type),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: getTransactionAmountColor(tx.amount, tx.type)),
            ),
             _buildStatusBadge(tx.status),
         ],
      ),
       isThreeLine: tx.comment != null && tx.comment!.isNotEmpty,
    );
  }

  // Item pour un manquant (Type: shortfall)
  Widget _buildShortfallTransactionItem(ShortfallTransaction tx) {
    return ListTile(
      leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 30),
      title: const Text('Manquant', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: tx.comment != null && tx.comment!.isNotEmpty ? Text(tx.comment!, style: const TextStyle(fontSize: 12)) : null,
      trailing: Column(
         crossAxisAlignment: CrossAxisAlignment.end,
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
            Text(
              formatTransactionAmount(tx.amount, tx.type),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: getTransactionAmountColor(tx.amount, tx.type)),
            ),
             _buildStatusBadge(tx.status),
         ],
      ),
      isThreeLine: tx.comment != null && tx.comment!.isNotEmpty,
    );
  }

  // Helper pour afficher le badge de statut générique (inchangé)
   Widget _buildStatusBadge(String status) {
    String statusText = _statusTranslations[status] ?? status;
    Color statusColor;
    IconData statusIcon = Icons.circle;

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'confirmed': case 'paid':
        statusColor = Colors.green;
        break;
       case 'partially_paid':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(statusIcon, size: 8, color: statusColor),
        const SizedBox(width: 4),
        Text(statusText, style: TextStyle(fontSize: 11, color: statusColor)),
      ],
    );
  }

} // Fin _RiderCashScreenState