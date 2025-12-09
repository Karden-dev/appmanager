// lib/widgets/chat_bubble.dart

import 'package:flutter/material.dart'; // <-- CORRECTION: 'package://' -> 'package:'
import 'package:intl/intl.dart';
import 'package:wink_manager/models/message.dart';
import 'package:wink_manager/utils/app_theme.dart';

/// Widget dédié à l'affichage d'une bulle de chat (Message Admin ou Livreur).
class ChatBubble extends StatelessWidget { // <-- 'StatelessWidget' maintenant reconnu
  final Message message;
  const ChatBubble({super.key, required this.message}); // <-- 'super.key' maintenant reconnu

  @override // <-- 'override' maintenant valide
  Widget build(BuildContext context) { // <-- 'Widget' et 'BuildContext' reconnus
    final isSent = message.isSentByMe;
    final isSystem = message.messageType == 'system';

    // Style pour les messages Système
    if (isSystem) {
      return Container( // <-- 'Container' reconnu
        alignment: Alignment.center, // <-- 'Alignment' reconnu
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16), // <-- 'EdgeInsets' reconnu
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration( // <-- 'BoxDecoration' reconnu
          // CORRECTION (Lint): Remplace 'withAlpha(30)'
          color: AppTheme.accentColor.withOpacity(30 / 255), 
          borderRadius: BorderRadius.circular(8), // <-- 'BorderRadius' reconnu
          border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)), // <-- 'Border' reconnu
        ),
        child: Text( // <-- 'Text' reconnu
          message.content,
          textAlign: TextAlign.center, // <-- 'TextAlign' reconnu
          style: TextStyle( // <-- 'TextStyle' reconnu
            fontSize: 11,
            fontStyle: FontStyle.italic, // <-- 'FontStyle' reconnu
            // CORRECTION (Lint): Remplace 'withAlpha(200)'
            color: AppTheme.accentColor.withOpacity(200 / 255), 
          ),
        ),
      );
    }

    // Style pour les messages Utilisateur (Envoyé vs Reçu)
    return Align( // <-- 'Align' reconnu
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        constraints: BoxConstraints( // <-- 'BoxConstraints' reconnu
            maxWidth: MediaQuery.of(context).size.width * 0.75), // <-- 'MediaQuery' reconnu
        decoration: BoxDecoration(
          // Admin (Envoyé) = Corail clair
          // Livreur (Reçu) = Blanc
          color: isSent ? AppTheme.primaryLight : Colors.white, // <-- 'Colors' reconnu
          borderRadius: BorderRadius.only( // <-- 'BorderRadius' reconnu
            topLeft: const Radius.circular(15), // <-- 'Radius' reconnu
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(isSent ? 15 : 5),
            bottomRight: Radius.circular(isSent ? 5 : 15),
          ),
          boxShadow: [ // <-- 'BoxShadow' reconnu
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1), // <-- 'Offset' reconnu
            ),
          ],
        ),
        child: Column( // <-- 'Column' reconnu
          crossAxisAlignment:
              isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start, // <-- 'CrossAxisAlignment' reconnu
          children: [
            // Affiche le nom de l'expéditeur (si ce n'est pas l'admin)
            if (!isSent)
              Padding( // <-- 'Padding' reconnu
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  message.userName, // Nom du Livreur
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold, // <-- 'FontWeight' reconnu
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            // Contenu du message
            Text(
              message.content,
              style: TextStyle(
                color: isSent ? AppTheme.secondaryColor : AppTheme.text,
                fontSize: 15,
              ),
            ),
            // Heure
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                DateFormat('HH:mm').format(message.createdAt.toLocal()),
                style: TextStyle(
                  fontSize: 10,
                  color:
                      isSent ? Colors.grey.shade700 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}