// lib/widgets/network_status_icon.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wink_manager/providers/network_provider.dart';

class NetworkStatusIcon extends StatelessWidget {
  const NetworkStatusIcon({super.key});

  @override
  Widget build(BuildContext context) {
    // 'watch' reconstruit ce widget quand 'isOnline' change
    final isOnline = context.watch<NetworkProvider>().isOnline; 

    return Tooltip(
      message: isOnline ? 'Connecté au serveur' : 'Hors ligne',
      child: Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Icon(
          isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
          color: isOnline ? Colors.white : Colors.grey[400],
        ),
      ),
    );
  }
}