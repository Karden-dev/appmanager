// lib/widgets/remittance_stats_modal.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wink_manager/models/remittance.dart';
import 'package:wink_manager/utils/app_theme.dart';

class RemittanceStatsModal extends StatelessWidget {
  final RemittanceStats stats;
  final DateTime date;

  const RemittanceStatsModal({
    super.key,
    required this.stats,
    required this.date,
  });

  String _formatAmount(double amount) {
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    // Calcul du nombre total de transactions pour l'affichage
    final int totalTransactions = stats.orangeMoneyTransactions + stats.mtnMoneyTransactions;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée de glissement
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          
          // Titre et Date
          Column(
            children: [
              Text(
                "Synthèse des Versements",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryColor
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20)
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd MMMM yyyy', 'fr_FR').format(date),
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),

          // Carte Principale (TOTAL) - Design mis en avant
          _MainStatCard(
            title: 'TOTAL NET À VERSER',
            value: _formatAmount(stats.totalAmount),
            // Ajout du compteur de transactions ici
            subValue: '$totalTransactions transaction${totalTransactions > 1 ? 's' : ''}',
            color: AppTheme.primaryColor,
            icon: Icons.account_balance_wallet,
          ),
          
          const SizedBox(height: 16),

          // Grille des Opérateurs
          Row(
            children: [
              Expanded(
                child: _DetailStatCard(
                  title: 'Orange Money',
                  value: _formatAmount(stats.orangeMoneyTotal),
                  subValue: '${stats.orangeMoneyTransactions} trans.',
                  color: Colors.orange,
                  icon: Icons.phone_android,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DetailStatCard(
                  title: 'MTN Money',
                  value: _formatAmount(stats.mtnMoneyTotal),
                  subValue: '${stats.mtnMoneyTransactions} trans.',
                  color: const Color(0xFFffcc00),
                  icon: Icons.wifi_tethering,
                ),
              ),
            ],
          ),
          
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 10),
        ],
      ),
    );
  }
}

// Widget spécifique pour la carte principale (Plus grand, centré)
class _MainStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subValue;
  final Color color;
  final IconData icon;

  const _MainStatCard({
    required this.title,
    required this.value,
    required this.subValue,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Dégradé subtil pour un effet premium
        gradient: LinearGradient(
          colors: [color.withOpacity(0.08), color.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.secondaryColor,
              fontSize: 28, // Très grand pour la lisibilité
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              subValue,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget pour les cartes de détail (Plus compactes)
class _DetailStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subValue;
  final Color color;
  final IconData icon;

  const _DetailStatCard({
    required this.title,
    required this.value,
    required this.subValue,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.secondaryColor,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subValue,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ),
    );
  }
}