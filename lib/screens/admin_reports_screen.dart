import 'package:flutter/material.dart';
// --- AJOUT ---
import 'package:wink_manager/widgets/network_status_icon.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports Journaliers'),
        // --- AJOUT DE L'ICÔNE ---
        actions: const [
          NetworkStatusIcon(),
        ],
      ),
      body: const Center(
        child: Text('Écran des Rapports (WIP)'),
      ),
    );
  }
}