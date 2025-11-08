// lib/widgets/report_summary_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:wink_manager/models/report_models.dart';
import 'package:wink_manager/providers/report_provider.dart';
import 'package:wink_manager/utils/app_theme.dart';

class ReportSummaryCard extends StatelessWidget {
  final ReportSummary report;
  final ReportProvider provider; 

  const ReportSummaryCard({
    super.key,
    required this.report,
    required this.provider,
  });

  /// Gère l'action de copie
  Future<void> _copyReport(BuildContext context) async {
    // Affiche un SnackBar "Copie en cours..."
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Génération du rapport et copie...'),
        backgroundColor: AppTheme.accentColor,
        duration: Duration(seconds: 1),
      ),
    );

    try {
      // 1. Appelle le provider pour générer la chaîne et la copier
      final message = await provider.generateReportStringForCopy(report.shopId);
      
      // 2. Affiche le résultat (Succès)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      // 2. Affiche le résultat (Erreur)
      final message = e.toString().replaceFirst('Exception: ', '');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountToRemitColor = report.amountToRemit < 0
        ? AppTheme.danger
        : (report.amountToRemit > 0 ? AppTheme.success : AppTheme.text);

    // Vérifie si cet ID est dans la liste des rapports copiés du provider
    final bool isCopied =
        context.watch<ReportProvider>().copiedShopIds.contains(report.shopId);

    return Card(
      elevation: 1,
      // Marge verticale réduite
      margin: const EdgeInsets.symmetric(vertical: 4.0), 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        // Padding vertical et horizontal réduits
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1: Nom du Marchand et Bouton Copier (Espacement réduit)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start, // Alignement en haut
              children: [
                Expanded(
                  child: Padding(
                    // Padding top réduit
                    padding: const EdgeInsets.only(top: 4.0, left: 4.0), 
                    child: Text(
                      report.shopName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    isCopied ? Icons.check_circle : Icons.copy_all_outlined,
                    color: isCopied ? AppTheme.success : AppTheme.accentColor,
                  ),
                  tooltip: isCopied
                      ? 'Rapport copié !'
                      : 'Copier le rapport détaillé',
                  onPressed: () => _copyReport(context),
                ),
              ],
            ),
            
            // Divider (Espacement réduit)
            const Divider(height: 12), // <-- Hauteur réduite

            // Ligne 2: Grille de Stats (Ligne 1 de la grille)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatItem(
                    label: 'Envoyées',
                    value: report.totalOrdersSent.toString()),
                _StatItem(
                    label: 'Livrées',
                    value: report.totalOrdersDelivered.toString(),
                    color: AppTheme.success),
                _StatItem(
                    label: 'Encaissement',
                    value:
                        ReportSummary.formatAmount(report.totalRevenueArticles),
                    isAmount: true),
                _StatItem(
                    label: 'Frais Liv.',
                    value:
                        ReportSummary.formatAmount(report.totalDeliveryFees),
                    isAmount: true),
              ],
            ),
            
            // Espace réduit
            const SizedBox(height: 10), // <-- Hauteur réduite

            // Ligne 3: Grille de Stats (Ligne 2 de la grille)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 _StatItem(
                    label: 'Frais Exp.',
                    value:
                        ReportSummary.formatAmount(report.totalExpeditionFees),
                    isAmount: true),
                _StatItem(
                    label: 'Frais Emb.',
                    value:
                        ReportSummary.formatAmount(report.totalPackagingFees),
                    isAmount: true),
                _StatItem(
                    label: 'Frais Stock.',
                    value:
                        ReportSummary.formatAmount(report.totalStorageFees),
                    isAmount: true),
                // Placeholder pour garder l'alignement (4e colonne vide)
                const Expanded(child: SizedBox()), 
              ],
            ),
            
            // Ligne 4: Montant à verser (Position conservée)
            const Divider(height: 12), // <-- Hauteur réduite
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Montant Net à Verser',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    ReportSummary.formatAmount(report.amountToRemit),
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: amountToRemitColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget interne pour afficher un item de statistique (Titre en haut, Valeur en bas).
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool isAmount;

  const _StatItem({
    required this.label,
    required this.value,
    this.color,
    this.isAmount = false,
  });

  @override
  Widget build(BuildContext context) {
    // Utilise Expanded pour que 4 items tiennent sur une ligne
    return Expanded(
      child: Column(
        // Aligne le contenu à GAUCHE
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color ?? AppTheme.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // Aligne le texte à GAUCHE
            textAlign: TextAlign.left, 
          ),
        ],
      ),
    );
  }
}