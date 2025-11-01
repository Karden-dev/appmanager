// lib/services/sync_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
// import 'package:sqflite/sqflite.dart'; // Supprimé

import 'package:wink_manager/models/pending_action.dart';
import 'package:wink_manager/services/admin_order_service.dart';
import 'package:wink_manager/services/database_service.dart';
// --- AJOUT ---
import 'package:wink_manager/repositories/order_repository.dart';

class SyncService {
  final AdminOrderService _apiService;
  final DatabaseService _dbService;
  // --- AJOUT ---
  final OrderRepository _orderRepository;
  
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  bool _isOnline = true; // Assumer online au démarrage

  // --- CORRECTION : Ajout du Repository ---
  SyncService(this._apiService, this._dbService, this._orderRepository);

  /// À appeler au démarrage de l'application (après login)
  void initialize() {
    // ... (Méthode inchangée) ...
    _connectivitySubscription?.cancel();
    
    Connectivity().checkConnectivity().then((results) {
      final result = results.firstWhere((r) => r != ConnectivityResult.none, orElse: () => ConnectivityResult.none);
      _handleConnectivityChange(result);
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final result = results.firstWhere((r) => r != ConnectivityResult.none, orElse: () => ConnectivityResult.none);
      _handleConnectivityChange(result);
    });
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    // ... (Méthode inchangée) ...
    final wasOnline = _isOnline;
    _isOnline = (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi);
    
    if (kDebugMode) {
      print('SyncService: Statut réseau changé. Online: $_isOnline');
    }

    if (_isOnline && !wasOnline && !_isSyncing) {
      _processQueue();
    }
  }

  /// Traite la file d'attente (FIFO)
  Future<void> _processQueue() async {
    if (_isSyncing) return; 
    if (!_isOnline) return; 

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
      final action = PendingAction.fromMap(map);
      bool success = false;
      
      try {
        if (kDebugMode) print('SyncService: Traitement Action ${action.type.name} (ID: ${action.id})');
        
        switch (action.type) {
          
          // --- CORRECTION LOGIQUE CREATE ---
          case SyncActionType.createOrder:
            final tempId = action.payload['tempId'] as int;
            final data = action.payload['data'] as Map<String, dynamic>;
            
            // 1. Appeler l'API avec POST (ID null)
            final newServerOrder = await _apiService.saveOrder(data, null);
            
            // 2. Demander au Repository de remplacer l'ID
            await _orderRepository.replaceTemporaryOrder(tempId, newServerOrder);
            break;
            
          // --- CORRECTION LOGIQUE UPDATE ---
          case SyncActionType.updateOrder:
            final orderId = action.payload['orderId'] as int;
            final data = action.payload['data'] as Map<String, dynamic>;
            
            // Appeler l'API avec PUT (ID non null)
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
            // S'assurer que l'ID n'est pas temporaire (sécurité)
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
        
        break; 
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
       _processQueue();
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}