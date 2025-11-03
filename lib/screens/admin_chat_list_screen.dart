import 'package:flutter/material.dart';
// --- AJOUT ---
import 'package:wink_manager/widgets/network_status_icon.dart';

class AdminChatListScreen extends StatelessWidget {
  const AdminChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivis (Chat)'),
        // --- AJOUT DE L'ICÔNE ---
        actions: const [
          NetworkStatusIcon(),
        ],
      ),
      body: const Center(
        child: Text('Écran des Suivis (WIP)'),
      ),
    );
  }
}