// lib/services/sync_service.dart

import 'dart:async'; // <-- CORRECTION: 'dart:async' au lieu de 'dart.async'
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'package:wink_manager/models/pending_action.dart';
import 'package:wink_manager/services/admin_order_service.dart';
import 'package:wink_manager/services/database_service.dart';
import 'package:wink_manager/repositories/order_repository.dart';

class SyncService {
  final AdminOrderService _apiService;
  final DatabaseService _dbService;
  final OrderRepository _orderRepository;
  
  StreamSubscription? _connectivitySubscription; // <-- Cette ligne est maintenant valide
  bool _isSyncing = false;
  bool _isOnline = true; // Assumer online au démarrage

  SyncService(this._apiService, this._dbService, this._orderRepository);

  /// À appeler au démarrage de l'application (après login)
  void initialize() {
    _connectivitySubscription?.cancel();
    
    // Vérifie l'état initial
    Connectivity().checkConnectivity().then((results) {
      final result = results.firstWhere((r) => r != ConnectivityResult.none, orElse: () => ConnectivityResult.none);
      _handleConnectivityChange(result);
    });

    // Écoute les changements futurs
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final result = results.firstWhere((r) => r != ConnectivityResult.none, orElse: () => ConnectivityResult.none);
      _handleConnectivityChange(result);
    });
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    _isOnline = (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi);
    
    if (kDebugMode) {
      print('SyncService: Statut réseau changé. Online: $_isOnline');
    }

    // (Logique Corrigée 1) : Se déclenche si Online ET pas déjà en train de synchroniser.
    if (_isOnline && !_isSyncing) {
      processQueue(); 
    }
  }

  /// Traite la file d'attente (FIFO)
  Future<void> processQueue() async { 
    if (_isSyncing) return; 
    if (!_isOnline) {
       if (kDebugMode) print('SyncService: Traitement annulé (Offline).');
       return; 
    }

    _isSyncing = true;
    if (kDebugMode) print('SyncService: --- Démarrage Traitement File d\'attente ---');

    final db = await _dbService.database;
    List<Map<String, dynamic>> maps = await db.query(
      DatabaseService.tablePendingActions,
      orderBy: 'id ASC', 
    );

    if (maps.isEmpty) {
      if (kDebugMode) print('SyncService: File d\'attente vide.');
      _isSyncing = false;
      return;
    }
    
    if (kDebugMode) print('SyncService: ${maps.length} actions à synchroniser.');

    for (final map in maps) {
      if (!_isOnline) {
         if (kDebugMode) print('SyncService: Perte de connexion, pause du traitement.');
         break;
      }
      
      final action = PendingAction.fromMap(map);
      bool success = false;
      
      try {
        if (kDebugMode) print('SyncService: Traitement Action ${action.type.name} (ID: ${action.id})');
        
        switch (action.type) {
          
          case SyncActionType.createOrder:
            final tempId = action.payload['tempId'] as int;
            final data = action.payload['data'] as Map<String, dynamic>;
            
            final newServerOrder = await _apiService.saveOrder(data, null);
            await _orderRepository.replaceTemporaryOrder(tempId, newServerOrder);
            break;
            
          case SyncActionType.updateOrder:
            final orderId = action.payload['orderId'] as int;
            final data = action.payload['data'] as Map<String, dynamic>;
            await _apiService.saveOrder(data, orderId);
            break;
            
          case SyncActionType.assignOrder:
            final orderId = action.payload['orderId'] as int;
            final deliverymanId = action.payload['deliverymanId'] as int;
            await _apiService.assignOrders([orderId], deliverymanId); 
            break;
            
          case SyncActionType.updateStatus:
            final orderId = action.payload['orderId'] as int;
            await _apiService.updateOrderStatus(
              orderId,
              action.payload['status'] as String,
              paymentStatus: action.payload['paymentStatus'] as String?,
              amountReceived: action.payload['amountReceived'] as double?,
            );
            break;

          case SyncActionType.markAsReady:
            final orderId = action.payload['orderId'] as int;
            await _apiService.markOrderAsReady(orderId);
            break;
            
          case SyncActionType.confirmHubReception:
            final trackingId = action.payload['trackingId'] as int;
            await _apiService.confirmHubReception(trackingId);
            break;
            
          case SyncActionType.deleteOrder:
            final orderId = action.payload['orderId'] as int;
            if (orderId > 0) {
              await _apiService.deleteOrder(orderId);
            } else {
              if (kDebugMode) print('SyncService: Suppression annulée (ID temporaire $orderId).');
            }
            break;
        }
        
        success = true;
        
      } catch (e) {
        if (kDebugMode) print('SyncService: ÉCHEC sync action ${action.id}. Erreur: $e');
        
        await db.update(
          DatabaseService.tablePendingActions,
          { 'attempts': action.attempts + 1 },
          where: 'id = ?', whereArgs: [action.id]
        );
        
        // (Logique Corrigée 2) : 'break;' est supprimé pour ne pas bloquer la file.
      }

      if (success) {
        await db.delete(
          DatabaseService.tablePendingActions, 
          where: 'id = ?', whereArgs: [action.id]
        );
        if (kDebugMode) print('SyncService: Action ${action.id} synchronisée et supprimée.');
      }
    }
    
    if (kDebugMode) print('SyncService: --- Fin Traitement File d\'attente ---');
    _isSyncing = false;
    
    final remaining = await db.query(DatabaseService.tablePendingActions, limit: 1);
    if(remaining.isNotEmpty && _isOnline) {
       processQueue();
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}