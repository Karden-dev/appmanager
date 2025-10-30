// lib/services/notification_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert'; // <--- AJOUT NÉCESSAIRE POUR jsonDecode

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialisation du plugin
  Future<void> initialize() async {
    // Configuration Android: Utilise l'icône par défaut de l'app
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuration iOS
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
            );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      // **IMPLÉMENTATION DU TODO**
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('Notification payload (clic): ${response.payload}');
        
        if (response.payload != null && response.payload!.isNotEmpty) {
           try {
              final payloadData = jsonDecode(response.payload!);
              final orderId = payloadData['order_id']; // Récupère l'ID de la commande

              if (orderId != null) {
                  // **TODO : Ici, tu dois utiliser un GlobalKey ou une fonction de rappel**
                  // **pour naviguer vers ChatScreen(orderId).**
                  debugPrint('Action requise: Naviguer vers la commande ID: $orderId');
                  // L'implémentation finale de la navigation doit être dans main.dart ou un NavigatorObserver
              }
           } catch (e) {
              debugPrint('Erreur de parsing du payload: $e');
           }
        }
      },
    );

    // Demander la permission pour Android 13+
    try {
      final bool? granted = await _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      debugPrint("NotificationService: Permission Android 13+ accordée: $granted");
    } catch (e) {
      debugPrint("Erreur demande permission Android 13+: $e");
    }
    
    // Demande de permission pour iOS
    try {
        await _notificationsPlugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    } catch (e) {
      debugPrint("Erreur demande permission iOS: $e");
    }

     debugPrint("NotificationService: Initialisation terminée et permissions demandées.");
  }

  // Afficher une notification
  Future<void> showNotification(int id, String title, String body, {String? payload}) async {
    
    // --- Configuration Android (Haute Priorité) ---
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'wink_rider_channel_id', // Id unique du canal
      'Notifications Livreur WINK', // Nom du canal
      channelDescription: 'Notifications pour les commandes, messages et statuts.', // Description du canal
      
      // Paramètres cruciaux pour la visibilité
      importance: Importance.max, // **ESSENTIEL**
      priority: Priority.high, // **ESSENTIEL**
      visibility: NotificationVisibility.public, // Visible sur l'écran de verrouillage
      
      playSound: true, 
      enableVibration: true, 
      ticker: 'Wink Express', 
    );

    // Paramètres iOS
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    try {
      // Appel pour afficher la notification
      await _notificationsPlugin.show(
        id,    // ID unique pour la notification
        title, 
        body,  
        platformChannelDetails, 
        payload: payload, // Le payload contient l'order_id
      );
      debugPrint("NotificationService: Appel à _notificationsPlugin.show() effectué pour ID $id - Titre: $title");
    } catch (e) {
      debugPrint("NotificationService: Erreur lors de l'affichage de la notification ID $id: $e");
    }
  }
}