// lib/services/sync_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'package:wink_manager/models/pending_action.dart';
import 'package:wink_manager/services/admin_order_service.dart';
import 'package:wink_manager/services/database_service.dart';
// --- MODIFICATION : L'import de OrderRepository n'est plus nécessaire ---
// import 'package:wink_manager/repositories/order_repository.dart';

class SyncService {
  final AdminOrderService _apiService;
  final DatabaseService _dbService;
  // --- MODIFICATION : Le champ _orderRepository est supprimé ---
  // final OrderRepository _orderRepository;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  bool _isOnline = true; // Assumer online au démarrage

  // --- MODIFICATION : Le constructeur est simplifié ---
  SyncService(this._apiService, this._dbService);

  /// À appeler au démarrage de l'application (après login)
  void initialize() {
    _connectivitySubscription?.cancel();

    Connectivity().checkConnectivity().then((results) {
      _handleConnectivityChange(results); 
    });

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (kDebugMode) {
      print('SyncService: Statut réseau changé. Online: $_isOnline');
    }

    _isOnline = !(results.length == 1 && results.first == ConnectivityResult.none);

    if (kDebugMode) {
      print('SyncService: Statut réseau changé. Online: $_isOnline');
    }

    if (_isOnline && !_isSyncing) {
      processQueue();
    }
  }

  /// Traite la file d'attente (FIFO)
  Future<void> processQueue() async {
    if (_isSyncing) {
      return;
    }
    if (!_isOnline) {
      if (kDebugMode) {
        print('SyncService: Traitement annulé (Offline).');
      }
      return;
    }

    _isSyncing = true;
    if (kDebugMode) {
      print('SyncService: --- Démarrage Traitement File d\'attente ---');
    }

    final db = await _dbService.database;
    List<Map<String, dynamic>> maps = await db.query(
      DatabaseService.tablePendingActions,
      orderBy: 'id ASC',
    );

    if (maps.isEmpty) {
      if (kDebugMode) {
        print('SyncService: File d\'attente vide.');
      }
      _isSyncing = false;
      return;
    }

    if (kDebugMode) {
      print('SyncService: ${maps.length} actions à synchroniser.');
    }

    for (final map in maps) {
      if (!_isOnline) {
        if (kDebugMode) {
          print('SyncService: Perte de connexion, pause du traitement.');
        }
        break;
      }

      final action = PendingAction.fromMap(map);
      bool success = false;

      try {
        if (kDebugMode) {
          print(
              'SyncService: Traitement Action ${action.type.name} (ID: ${action.id})');
        }

        switch (action.type) {
          
          // --- MODIFICATION : Ajout d'un case vide pour satisfaire l'analyseur ---
          // Cette action est dépréciée pour les commandes (Online-First),
          // donc nous ne faisons rien.
          case SyncActionType.createOrder:
            if (kDebugMode) {
              print("SyncService: Action 'createOrder' ignorée (dépréciée).");
            }
            // Ne fait rien, mais corrige l'erreur "non_exhaustive_switch"
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
              if (kDebugMode) {
                print(
                    'SyncService: Suppression annulée (ID temporaire $orderId).');
              }
            }
            break;
        }

        success = true;
      } catch (e) {
        if (kDebugMode) {
          print(
              'SyncService: ÉCHEC sync action ${action.id}. Erreur: $e');
        }

        await db.update(
            DatabaseService.tablePendingActions, {'attempts': action.attempts + 1},
            where: 'id = ?', whereArgs: [action.id]);
      }

      if (success) {
        await db.delete(DatabaseService.tablePendingActions,
            where: 'id = ?', whereArgs: [action.id]);
        if (kDebugMode) {
          print('SyncService: Action ${action.id} synchronisée et supprimée.');
        }
      }
    }

    if (kDebugMode) {
      print('SyncService: --- Fin Traitement File d\'attente ---');
    }
    _isSyncing = false;

    final remaining =
        await db.query(DatabaseService.tablePendingActions, limit: 1);
    if (remaining.isNotEmpty && _isOnline) {
      processQueue();
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}