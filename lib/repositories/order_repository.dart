// lib/repositories/order_repository.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wink_manager/models/admin_order.dart';
import 'package:wink_manager/models/deliveryman.dart';
import 'package:wink_manager/models/order_history_item.dart';
import 'package:wink_manager/models/order_item.dart';
import 'package:wink_manager/models/pending_action.dart';
import 'package:wink_manager/models/return_tracking.dart';
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/services/admin_order_service.dart';
import 'package:wink_manager/services/database_service.dart';

class OrderRepository {
  final AdminOrderService _apiService;
  final DatabaseService _dbService;

  OrderRepository(this._apiService, this._dbService);

  // --- LOGIQUE DE LECTURE (FETCH) ---
  // (Méthodes de lecture inchangées : fetchAdminOrders, fetchOrdersToPrepare, etc.)
  Future<List<AdminOrder>> fetchAdminOrders({
    required DateTime startDate,
    required DateTime endDate,
    required String statusFilter,
    required String searchFilter,
  }) async {
    try {
      final apiOrders = await _apiService.fetchAdminOrders(
        startDate: startDate,
        endDate: endDate,
        statusFilter: statusFilter,
        searchFilter: searchFilter,
      );
      await _syncOrdersToDb(apiOrders);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('OrderRepository: fetchAdminOrders OFFLINE. ${e.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OrderRepository: fetchAdminOrders ERREUR INCONNUE. $e');
      }
    }
    return _getOrdersFromDb();
  }
  Future<List<AdminOrder>> fetchOrdersToPrepare() async {
    try {
      final apiOrders = await _apiService.fetchOrdersToPrepare();
      await _syncOrdersToDb(apiOrders, clearExisting: false);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('OrderRepository: fetchOrdersToPrepare OFFLINE. ${e.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OrderRepository: fetchOrdersToPrepare ERREUR INCONNUE. $e');
      }
    }
    return _getOrdersFromDb(
        statuses: ['in_progress', 'ready_for_pickup']);
  }
  Future<List<ReturnTracking>> fetchPendingReturns({
    String? status,
    int? deliverymanId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final apiReturns = await _apiService.fetchPendingReturns(
        status: status,
        deliverymanId: deliverymanId,
        startDate: startDate,
        endDate: endDate,
      );
      
      final db = await _dbService.database;
      await db.transaction((txn) async {
        await txn.delete(DatabaseService.tableReturnTracking);
        for (final item in apiReturns) {
          await txn.insert(DatabaseService.tableReturnTracking, _returnToMap(item));
        }
      });

    } on DioException catch (e) {
      if (kDebugMode) {
        print('OrderRepository: fetchPendingReturns OFFLINE. ${e.message}');
      }
    } catch (e) {
       if (kDebugMode) {
        print('OrderRepository: fetchPendingReturns ERREUR INCONNUE. $e');
      }
    }
    
    final db = await _dbService.database;
    final maps = await db.query(DatabaseService.tableReturnTracking);
    return maps.map((map) => _returnFromMap(map)).toList();
  }
  Future<AdminOrder> fetchOrderById(int orderId) async {
     try {
       final apiOrder = await _apiService.fetchOrderById(orderId);
       await _syncOrdersToDb([apiOrder], clearExisting: false);
     } on DioException catch (e) {
       if (kDebugMode) {
         print('OrderRepository: fetchOrderById OFFLINE. ${e.message}');
       }
     } catch (e) {
       if (kDebugMode) {
         print('OrderRepository: fetchOrderById ERREUR INCONNUE. $e');
       }
     }
     
     final orders = await _getOrdersFromDb(orderId: orderId);
     if (orders.isEmpty) {
       throw Exception('Commande #$orderId non trouvée en local.');
     }
     return orders.first;
  }
  Future<List<Deliveryman>> searchDeliverymen(String query) async {
     try {
       final apiDeliverymen = await _apiService.fetchActiveDeliverymen(query);
       
       final db = await _dbService.database;
       await db.transaction((txn) async {
         for (final d in apiDeliverymen) {
           final deliveryman = Deliveryman.fromJson(d);
           await txn.insert(
             DatabaseService.tableDeliverymen, 
             _deliverymanToMap(deliveryman), 
             conflictAlgorithm: ConflictAlgorithm.replace
           );
         }
       });
       
     } on DioException catch (e) {
       if (kDebugMode) {
         print('OrderRepository: searchDeliverymen OFFLINE. ${e.message}');
       }
     } catch (e) {
        if (kDebugMode) {
         print('OrderRepository: searchDeliverymen ERREUR INCONNUE. $e');
       }
     }
     
     final db = await _dbService.database;
     final maps = await db.query(DatabaseService.tableDeliverymen,
       where: 'name LIKE ?',
       whereArgs: ['%$query%']
     );
     return maps.map((map) => _deliverymanFromMap(map)).toList();
  }
  Future<List<Shop>> searchShops(String query) async {
    try {
       final apiShops = await _apiService.searchShops(query);
       
       final db = await _dbService.database;
       await db.transaction((txn) async {
         for (final shop in apiShops) {
           await txn.insert(
             DatabaseService.tableShops, 
             _shopToMap(shop), 
             conflictAlgorithm: ConflictAlgorithm.replace
           );
         }
       });
       
     } on DioException catch (e) {
       if (kDebugMode) {
         print('OrderRepository: searchShops OFFLINE. ${e.message}');
       }
     } catch (e) {
        if (kDebugMode) {
         print('OrderRepository: searchShops ERREUR INCONNUE. $e');
       }
     }
     
     final db = await _dbService.database;
     final maps = await db.query(DatabaseService.tableShops,
       where: 'name LIKE ?',
       whereArgs: ['%$query%']
     );
     return maps.map((map) => _shopFromMap(map)).toList();
  }

  // --- LOGIQUE D'ÉCRITURE (OFFLINE) ---
  
  /// 7. Sauvegarder (Créer / Modifier) Commande
  Future<void> saveOrder(Map<String, dynamic> orderData, int? orderId) async {
    final db = await _dbService.database;
    
    // 1. Préparer les données pour la DB LOCALE (contient shop_name)
    final orderForDb = {
      'shop_name': orderData['shop_name'], // Requis pour l'affichage offline
      'deliveryman_id': null,
      'deliveryman_name': null,
      'customer_name': orderData['customer_name'],
      'customer_phone': orderData['customer_phone'],
      'delivery_location': orderData['delivery_location'],
      'article_amount': orderData['article_amount'],
      'delivery_fee': orderData['delivery_fee'],
      'expedition_fee': orderData['expedition_fee'],
      'status': 'pending', 
      'payment_status': 'pending', 
      'created_at': orderData['created_at'],
      'picked_up_by_rider_at': null,
      'amount_received': 0.0,
      'is_synced': 0, 
    };

    // 2. --- CORRECTION : Préparer le payload pour l'API ---
    // Copier la map et retirer le champ 'shop_name' qui fait échouer l'API
    final payloadData = Map<String, dynamic>.from(orderData);
    payloadData.remove('shop_name'); 
    // L'API ne recevra que 'shop_id', 'customer_name', etc.

    await db.transaction((txn) async {
      int newOrderId;
      SyncActionType actionType;
      Map<String, dynamic> payload;
      
      if (orderId == null) {
        // --- CRÉATION OFFLINE ---
        newOrderId = -(DateTime.now().millisecondsSinceEpoch);
        orderForDb['id'] = newOrderId; // ID temporaire pour la DB locale
        actionType = SyncActionType.createOrder;
        
        await txn.insert(
          DatabaseService.tableOrders, 
          orderForDb,
          conflictAlgorithm: ConflictAlgorithm.replace 
        );
        
        // CORRECTION : Le payload contient le tempId et la donnée NETTOYÉE
        payload = { 'tempId': newOrderId, 'data': payloadData };
        
      } else {
        // --- MODIFICATION ---
        newOrderId = orderId;
        actionType = SyncActionType.updateOrder;
        
        // Données pour la mise à jour locale
        final updateDataForDb = Map<String, dynamic>.from(orderForDb);
        // (ID est géré par whereArgs, pas besoin de l'inclure ici)

        await txn.update(
          DatabaseService.tableOrders, 
          updateDataForDb, 
          where: 'id = ?', whereArgs: [orderId]
        );
        await txn.delete(DatabaseService.tableOrderItems, where: 'order_id = ?', whereArgs: [orderId]);

        // CORRECTION : Le payload contient le vrai ID et la donnée NETTOYÉE
        payload = { 'orderId': newOrderId, 'data': payloadData };
      }
      
      // Insérer les items (logique inchangée)
      final List<Map<String, dynamic>> itemsList = List.from(orderData['items']);
      for (final itemData in itemsList) {
        await txn.insert(DatabaseService.tableOrderItems, {
          'order_id': newOrderId,
          'item_name': itemData['item_name'],
          'quantity': itemData['quantity'],
          'amount': itemData['amount'],
        });
      }
      
      // Ajouter l'action à la file d'attente avec le payload NETTOYÉ
      final action = PendingAction(
        type: actionType,
        payload: payload, // Utilise le payload corrigé
        createdAt: DateTime.now(),
      );
      await txn.insert(DatabaseService.tablePendingActions, action.toMap());

      if (kDebugMode) {
        print('Action ${actionType.name} (ID: $newOrderId) ajoutee a la file d attente.');
      }
    });
  }
  
  /// --- NOUVELLE MÉTHODE : Remplacement d'ID ---
  /// Remplace une commande temporaire (ID négatif) par la vraie commande du serveur.
  Future<void> replaceTemporaryOrder(int tempId, AdminOrder newServerOrder) async {
    // ... (Méthode inchangée, elle est correcte) ...
    final db = await _dbService.database;

    await db.transaction((txn) async {
      await txn.delete(
        DatabaseService.tableOrders,
        where: 'id = ?',
        whereArgs: [tempId],
      );

      await txn.insert(
        DatabaseService.tableOrders,
        _orderToMap(newServerOrder), 
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final item in newServerOrder.items) {
        await txn.insert(DatabaseService.tableOrderItems, _itemToMap(item, newServerOrder.id));
      }

      for (final hist in newServerOrder.history) {
        await txn.insert(DatabaseService.tableOrderHistory, _historyToMap(hist, newServerOrder.id));
      }
    });

    if (kDebugMode) {
      print('Repository: Commande temporaire $tempId remplacée par ID Serveur ${newServerOrder.id}.');
    }
  }

  // ... (Méthodes inchangées : deleteOrder, assignOrder, updateOrderStatus, etc.)
  Future<void> deleteOrder(int orderId) async {
      final db = await _dbService.database;
      await db.delete(DatabaseService.tableOrders, where: 'id = ?', whereArgs: [orderId]);
      
      final action = PendingAction(
        type: SyncActionType.deleteOrder,
        payload: { 'orderId': orderId },
        createdAt: DateTime.now(),
      );
      await db.insert(DatabaseService.tablePendingActions, action.toMap());
  }
  Future<void> assignOrder(int orderId, int deliverymanId) async {
    final db = await _dbService.database;
    
    final maps = await db.query(DatabaseService.tableDeliverymen, where: 'id = ?', whereArgs: [deliverymanId]);
    final deliverymanName = maps.isNotEmpty ? _deliverymanFromMap(maps.first).name : 'Livreur ID $deliverymanId';
    
    await db.update(DatabaseService.tableOrders, 
      { 
        'deliveryman_id': deliverymanId, 
        'deliveryman_name': deliverymanName,
        'status': 'in_progress', 
        'is_synced': 0 
      },
      where: 'id = ?', whereArgs: [orderId]
    );

    final action = PendingAction(
      type: SyncActionType.assignOrder,
      payload: { 'orderId': orderId, 'deliverymanId': deliverymanId },
      createdAt: DateTime.now(),
    );
    await db.insert(DatabaseService.tablePendingActions, action.toMap());
  }
  Future<void> updateOrderStatus(
      int orderId, String status, {String? paymentStatus, double? amountReceived}) async {
        
      final db = await _dbService.database;
      
      final data = {
        'status': status,
        'is_synced': 0, 
      };
      if (paymentStatus != null) data['payment_status'] = paymentStatus;
      if (amountReceived != null) data['amount_received'] = amountReceived;
      
      await db.update(DatabaseService.tableOrders, data, where: 'id = ?', whereArgs: [orderId]);

      final action = PendingAction(
        type: SyncActionType.updateStatus,
        payload: {
          'orderId': orderId, 
          'status': status, 
          'paymentStatus': paymentStatus, 
          'amountReceived': amountReceived
        },
        createdAt: DateTime.now(),
      );
      await db.insert(DatabaseService.tablePendingActions, action.toMap());
  }
  Future<void> markOrderAsReady(int orderId) async {
    await updateOrderStatus(orderId, 'ready_for_pickup');
    
    final db = await _dbService.database;
    final action = PendingAction(
      type: SyncActionType.markAsReady,
      payload: { 'orderId': orderId },
      createdAt: DateTime.now(),
    );
    await db.insert(DatabaseService.tablePendingActions, action.toMap());
  }
  Future<void> confirmHubReception(int trackingId) async {
      final db = await _dbService.database;
      
      await db.update(DatabaseService.tableReturnTracking, 
        { 
          'return_status': 'received_at_hub', 
          'hub_reception_date': DateTime.now().toIso8601String() 
        },
        where: 'tracking_id = ?', whereArgs: [trackingId]
      );
      
      final action = PendingAction(
        type: SyncActionType.confirmHubReception,
        payload: { 'trackingId': trackingId },
        createdAt: DateTime.now(),
      );
      await db.insert(DatabaseService.tablePendingActions, action.toMap());
  }

  // --- HELPERS DB ---
  // ... (Méthodes _syncOrdersToDb et _getOrdersFromDb inchangées) ...
  Future<void> _syncOrdersToDb(List<AdminOrder> apiOrders, {bool clearExisting = true}) async {
    final db = await _dbService.database;

    await db.transaction((txn) async {
      if (clearExisting) {
        await txn.delete(DatabaseService.tableOrders, where: 'is_synced = 1');
      }
      
      for (final order in apiOrders) {
        await txn.insert(
          DatabaseService.tableOrders, 
          _orderToMap(order), 
          conflictAlgorithm: ConflictAlgorithm.replace
        );
        
        await txn.delete(DatabaseService.tableOrderItems, where: 'order_id = ?', whereArgs: [order.id]);
        await txn.delete(DatabaseService.tableOrderHistory, where: 'order_id = ?', whereArgs: [order.id]);
        
        for (final item in order.items) {
          await txn.insert(DatabaseService.tableOrderItems, _itemToMap(item, order.id));
        }
        for (final hist in order.history) {
          await txn.insert(DatabaseService.tableOrderHistory, _historyToMap(hist, order.id));
        }
      }
    });
  }
  Future<List<AdminOrder>> _getOrdersFromDb({int? orderId, List<String>? statuses}) async {
    final db = await _dbService.database;

    String whereClause = '1=1'; 
    List<dynamic> whereArgs = [];
    
    if (orderId != null) {
      whereClause += ' AND id = ?'; 
      whereArgs.add(orderId);
    }
    
    if (statuses != null && statuses.isNotEmpty) {
       whereClause += ' AND status IN (${statuses.map((_) => '?').join(',')})'; 
       whereArgs.addAll(statuses);
    }
    
    final orderMaps = await db.query(
      DatabaseService.tableOrders, 
      where: whereClause,
      whereArgs: whereArgs
    );

    if (orderMaps.isEmpty) return [];

    final itemsMaps = await db.query(DatabaseService.tableOrderItems);
    final historyMaps = await db.query(DatabaseService.tableOrderHistory);
    
    final itemsByOrderId = <int, List<Map<String, dynamic>>>{};
    for (var map in itemsMaps) {
      final id = map['order_id'] as int;
      itemsByOrderId.putIfAbsent(id, () => []).add(map);
    }
    
    final historyByOrderId = <int, List<Map<String, dynamic>>>{};
    for (var map in historyMaps) {
      final id = map['order_id'] as int;
      historyByOrderId.putIfAbsent(id, () => []).add(map);
    }

    return orderMaps.map((orderMap) {
      final id = orderMap['id'] as int;
      final itemsList = (itemsByOrderId[id] ?? [])
          .map((map) => _itemFromMap(map))
          .toList();
      final historyList = (historyByOrderId[id] ?? [])
          .map((map) => _historyFromMap(map))
          .toList();
          
      return _orderFromMap(orderMap, itemsList, historyList);
    }).toList();
  }


  // --- MAPPERS ---
  // ... (Mappers inchangés) ...
  Map<String, dynamic> _orderToMap(AdminOrder order) {
    return {
      'id': order.id,
      'shop_name': order.shopName,
      'deliveryman_id': order.deliverymanId,
      'deliveryman_name': order.deliverymanName,
      'customer_name': order.customerName,
      'customer_phone': order.customerPhone,
      'delivery_location': order.deliveryLocation,
      'article_amount': order.articleAmount,
      'delivery_fee': order.deliveryFee,
      'expedition_fee': order.expeditionFee,
      'status': order.status,
      'payment_status': order.paymentStatus,
      'created_at': order.createdAt.toIso8601String(),
      'picked_up_by_rider_at': order.pickedUpByRiderAt?.toIso8601String(),
      'amount_received': order.amountReceived,
      'is_synced': order.isSynced ? 1 : 0, 
    };
  }
  AdminOrder _orderFromMap(Map<String, dynamic> map, List<OrderItem> items, List<OrderHistoryItem> history) {
    return AdminOrder(
      id: map['id'] as int,
      shopName: map['shop_name'] as String,
      deliverymanId: map['deliveryman_id'] as int?,
      deliverymanName: map['deliveryman_name'] as String?,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String,
      deliveryLocation: map['delivery_location'] as String,
      articleAmount: map['article_amount'] as double,
      deliveryFee: map['delivery_fee'] as double,
      expeditionFee: map['expedition_fee'] as double,
      status: map['status'] as String,
      paymentStatus: map['payment_status'] as String,
      createdAt: DateTime.parse(map['created_at']),
      pickedUpByRiderAt: map['picked_up_by_rider_at'] != null ? DateTime.parse(map['picked_up_by_rider_at']) : null,
      amountReceived: map['amount_received'] as double?,
      items: items,
      history: history,
      isSynced: (map['is_synced'] as int? ?? 1) == 1,
    );
  }
  Map<String, dynamic> _itemToMap(OrderItem item, int orderId) {
    return {
      'id': item.id,
      'order_id': orderId,
      'item_name': item.itemName,
      'quantity': item.quantity,
      'amount': item.amount,
    };
  }
  OrderItem _itemFromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      itemName: map['item_name'] as String,
      quantity: map['quantity'] as int,
      amount: map['amount'] as double,
    );
  }
  Map<String, dynamic> _historyToMap(OrderHistoryItem history, int orderId) {
    return {
      'id': history.id,
      'order_id': orderId,
      'action': history.action,
      'user_name': history.userName,
      'created_at': history.createdAt.toIso8601String(),
    };
  }
  OrderHistoryItem _historyFromMap(Map<String, dynamic> map) {
    return OrderHistoryItem(
      id: map['id'] as int,
      action: map['action'] as String,
      userName: map['user_name'] as String?,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
  Map<String, dynamic> _returnToMap(ReturnTracking item) {
    return {
      'tracking_id': item.trackingId,
      'order_id': item.orderId,
      'shop_name': item.shopName,
      'deliveryman_name': item.deliverymanName,
      'return_status': item.returnStatus,
      'declaration_date': item.declarationDate.toIso8601String(),
      'hub_reception_date': item.hubReceptionDate?.toIso8601String(),
      'comment': item.comment,
    };
  }
  ReturnTracking _returnFromMap(Map<String, dynamic> map) {
    return ReturnTracking(
      trackingId: map['tracking_id'] as int,
      orderId: map['order_id'] as int,
      shopName: map['shop_name'] as String,
      deliverymanName: map['deliveryman_name'] as String,
      returnStatus: map['return_status'] as String,
      declarationDate: DateTime.parse(map['declaration_date']),
      hubReceptionDate: map['hub_reception_date'] != null ? DateTime.parse(map['hub_reception_date']) : null,
      comment: map['comment'] as String?,
    );
  }
  Map<String, dynamic> _deliverymanToMap(Deliveryman d) {
    return { 'id': d.id, 'name': d.name, 'phone': d.phone };
  }
  Deliveryman _deliverymanFromMap(Map<String, dynamic> map) {
    return Deliveryman(
      id: map['id'] as int,
      name: map['name'] as String?,
      phone: map['phone'] as String?,
    );
  }
  Map<String, dynamic> _shopToMap(Shop shop) {
    return {
      'id': shop.id,
      'name': shop.name,
      'phone_number': shop.phoneNumber,
    };
  }
  Shop _shopFromMap(Map<String, dynamic> map) {
    return Shop(
      id: map['id'] as int,
      name: map['name'] as String,
      phoneNumber: map['phone_number'] as String,
    );
  }
}