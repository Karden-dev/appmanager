// lib/widgets/debt_stats_modal.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wink_manager/providers/debt_provider.dart'; // Pour DebtStats
import 'package:wink_manager/utils/app_theme.dart';

class DebtStatsModal extends StatelessWidget {
  final DebtStats stats;
  final DateTime startDate;
  final DateTime endDate;

  const DebtStatsModal({
    super.key,
    required this.stats,
    required this.startDate,
    required this.endDate,
  });

  String _formatAmount(double amount) {
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final String dateText = startDate.year == endDate.year && startDate.month == endDate.month && startDate.day == endDate.day
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
          // Poignée
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Titre et Période
          Column(
            children: [
              Text(
                "Situation des Créances",
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
                    Icon(Icons.date_range, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      dateText,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 1. KPI Principal : TOTAL EN ATTENTE (Rouge)
          _MainStatCard(
            title: 'TOTAL CRÉANCES EN ATTENTE',
            value: _formatAmount(stats.totalPending),
            subValue: '${stats.debtorsCount} marchand(s) concerné(s)',
            color: AppTheme.danger,
            icon: Icons.warning_amber_rounded,
          ),

          const SizedBox(height: 16),

          // 2. KPI Secondaires (Grille)
          Row(
            children: [
              // Total Réglé (Vert)
              Expanded(
                child: _DetailStatCard(
                  title: 'Total Réglé',
                  value: _formatAmount(stats.totalPaid),
                  subValue: 'Sur la période',
                  color: AppTheme.success,
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 12),
              // Taux de recouvrement (Bleu)
              Expanded(
                child: _DetailStatCard(
                  title: 'Taux Règlement',
                  value: '${stats.settlementRate.toStringAsFixed(1)} %',
                  subValue: 'Performance',
                  color: AppTheme.accentColor,
                  icon: Icons.pie_chart_outline,
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

// --- Widgets de Carte (Style Pro) ---

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
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.secondaryColor,
              fontSize: 28,
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
          BoxShadow(color: Colors.grey.shade100, offset: const Offset(0, 4), blurRadius: 10)
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
                  title.toUpperCase(),
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 18, fontWeight: FontWeight.w800),
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