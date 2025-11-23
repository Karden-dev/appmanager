// lib/repositories/order_repository.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wink_manager/models/admin_order.dart';
import 'package:wink_manager/models/deliveryman.dart';
import 'package:wink_manager/models/order_history_item.dart';
import 'package:wink_manager/models/order_item.dart';
// import 'package:wink_manager/models/pending_action.dart'; // SUPPRIMÉ
import 'package:wink_manager/models/return_tracking.dart';
import 'package:wink_manager/models/shop.dart';
import 'package:wink_manager/services/admin_order_service.dart';
import 'package:wink_manager/services/database_service.dart';

class OrderRepository {
  final AdminOrderService _apiService;
  final DatabaseService _dbService;

  OrderRepository(this._apiService, this._dbService);

  // --- LOGIQUE DE LECTURE (Cache-then-Network - MODIFIÉE) ---
  // --- MODIFIÉ : Ajout de la pagination (page, limit) ---
  Future<List<AdminOrder>> fetchAdminOrders({
    required DateTime startDate,
    required DateTime endDate,
    required String statusFilter,
    required String searchFilter,
    required int page,
    required int limit,
  }) async {
  // --- FIN MODIFICATION ---
    try {
      final apiOrders = await _apiService.fetchAdminOrders(
        startDate: startDate,
        endDate: endDate,
        statusFilter: statusFilter,
        searchFilter: searchFilter,
        page: page, // <-- NOUVEAU
        limit: limit, // <-- NOUVEAU
      );
      // Ne vide le cache que si on charge la première page
      await _syncOrdersToDb(apiOrders, clearExisting: page == 1);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('OrderRepository: fetchAdminOrders OFFLINE. ${e.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OrderRepository: fetchAdminOrders ERREUR INCONNUE. $e');
      }
    }
    // Charge depuis la BDD locale, en appliquant les filtres ET la pagination
    return _getOrdersFromDb(
      startDate: startDate,
      endDate: endDate,
      status: statusFilter.isEmpty ? null : statusFilter,
      search: searchFilter.isEmpty ? null : searchFilter,
      page: page, // <-- NOUVEAU
      limit: limit, // <-- NOUVEAU
    );
  }
  
  // (Inchangée)
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
  
  // (Inchangée)
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
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];
    if (status != null && status != 'all') {
      whereClauses.add('return_status = ?');
      whereArgs.add(status);
    }
    
    final maps = await db.query(
      DatabaseService.tableReturnTracking,
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );
    return maps.map((map) => _returnFromMap(map)).toList();
  }
  
  // (Inchangée)
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
  
  // (Inchangée)
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
  
  // (Inchangée)
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

  // --- LOGIQUE D'ÉCRITURE (ONLINE-FIRST - Inchangée) ---
  
  Future<void> saveOrder(Map<String, dynamic> orderData, int? orderId) async {
    try {
      final payloadData = {
        'shop_id': orderData['shop_id'],
        'customer_name': orderData['customer_name'],
        'customer_phone': orderData['customer_phone'],
        'delivery_location': orderData['delivery_location'],
        'article_amount': orderData['article_amount'],
        'delivery_fee': orderData['delivery_fee'],
        'expedition_fee': orderData['expedition_fee'],
        'created_at': orderData['created_at'],
        'items': orderData['items'],
      };

      final newServerOrder = await _apiService.saveOrder(payloadData, orderId);
      
      await _syncOrdersToDb([newServerOrder], clearExisting: false);

      if (kDebugMode) {
        print('Action saveOrder (ID: ${newServerOrder.id}) synchronisée avec succès.');
      }

    } on DioException {
      if (kDebugMode) {
        print('OrderRepository: saveOrder ÉCHEC (Offline).');
      }
      rethrow; 
    } catch (e) {
      if (kDebugMode) {
        print('OrderRepository: saveOrder ERREUR INCONNUE. $e');
      }
      rethrow; 
    }
  }
  
  Future<void> deleteOrder(int orderId) async {
    try {
      await _apiService.deleteOrder(orderId);
      
      final db = await _dbService.database;
      await db.delete(DatabaseService.tableOrders, where: 'id = ?', whereArgs: [orderId]);
      
      if (kDebugMode) {
        print('Action deleteOrder (ID: $orderId) synchronisée avec succès.');
      }
      
    } on DioException {
      if (kDebugMode) {
        print('OrderRepository: deleteOrder ÉCHEC (Offline).');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('OrderRepository: deleteOrder ERREUR INCONNUE. $e');
      }
      rethrow;
    }
  }

  Future<void> assignOrder(int orderId, int deliverymanId) async {
    try {
      await _apiService.assignOrders([orderId], deliverymanId);
      
      final db = await _dbService.database;
      
      final maps = await db.query(DatabaseService.tableDeliverymen, where: 'id = ?', whereArgs: [deliverymanId]);
      final deliverymanName = maps.isNotEmpty ? _deliverymanFromMap(maps.first).name : 'Livreur ID $deliverymanId';
      
      await db.update(DatabaseService.tableOrders, 
        { 
          'deliveryman_id': deliverymanId, 
          'deliveryman_name': deliverymanName,
          'status': 'in_progress', 
          'is_synced': 1 
        },
        where: 'id = ?', whereArgs: [orderId]
      );

      if (kDebugMode) {
        print('Action assignOrder (ID: $orderId) synchronisée avec succès.');
      }

    } on DioException {
      if (kDebugMode) {
        print('OrderRepository: assignOrder ÉCHEC (Offline).');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('OrderRepository: assignOrder ERREUR INCONNUE. $e');
      }
      rethrow;
    }
  }
  
  Future<void> updateOrderStatus(
      int orderId, 
      String status, 
      {String? paymentStatus, 
      double? amountReceived,
      DateTime? followUpAt,
      }) async {
        
    try {
      await _apiService.updateOrderStatus(
        orderId, 
        status, 
        paymentStatus: paymentStatus, 
        amountReceived: amountReceived, 
        followUpAt: followUpAt
      );
      
      final db = await _dbService.database;
      
      final Map<String, Object?> data = {
        'status': status,
        'is_synced': 1, 
      };
      if (paymentStatus != null) data['payment_status'] = paymentStatus;
      if (amountReceived != null) data['amount_received'] = amountReceived;
      data['follow_up_at'] = followUpAt?.toIso8601String();
      
      await db.update(DatabaseService.tableOrders, data, where: 'id = ?', whereArgs: [orderId]);
      
      if (kDebugMode) {
        print('Action updateOrderStatus (ID: $orderId) synchronisée avec succès.');
      }

    } on DioException {
      if (kDebugMode) {
        print('OrderRepository: updateOrderStatus ÉCHEC (Offline).');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('OrderRepository: updateOrderStatus ERREUR INCONNUE. $e');
      }
      rethrow;
    }
  }
  
  Future<void> markOrderAsReady(int orderId) async {
    try {
      await _apiService.markOrderAsReady(orderId);
      
      final db = await _dbService.database;
      await db.update(DatabaseService.tableOrders,
        { 'status': 'ready_for_pickup', 'is_synced': 1 },
        where: 'id = ?', whereArgs: [orderId]
      );
      
      if (kDebugMode) {
        print('Action markOrderAsReady (ID: $orderId) synchronisée avec succès.');
      }
      
    } on DioException {
      if (kDebugMode) {
        print('OrderRepository: markOrderAsReady ÉCHEC (Offline).');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('OrderRepository: markOrderAsReady ERREUR INCONNUE. $e');
      }
      rethrow;
    }
  }

  Future<void> confirmHubReception(int trackingId) async {
    try {
      await _apiService.confirmHubReception(trackingId);
      
      final db = await _dbService.database;
      await db.update(DatabaseService.tableReturnTracking, 
        { 
          'return_status': 'received_at_hub', 
          'hub_reception_date': DateTime.now().toIso8601String() 
        },
        where: 'tracking_id = ?', whereArgs: [trackingId]
      );
      
      if (kDebugMode) {
        print('Action confirmHubReception (ID: $trackingId) synchronisée avec succès.');
      }
      
    } on DioException {
      if (kDebugMode) {
        print('OrderRepository: confirmHubReception ÉCHEC (Offline).');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('OrderRepository: confirmHubReception ERREUR INCONNUE. $e');
      }
      rethrow;
    }
  }

  // --- HELPERS DB (Inchangés) ---
  
  Future<void> _syncOrdersToDb(List<AdminOrder> apiOrders, {bool clearExisting = true}) async {
    final db = await _dbService.database;

    await db.transaction((txn) async {
      if (clearExisting) {
        // Supprime uniquement les commandes synchronisées. 
        // Si page == 1, on vide la liste. Si page > 1, on ne vide rien.
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

  // --- MODIFIÉ : Ajout de la pagination (page, limit) ---
  Future<List<AdminOrder>> _getOrdersFromDb({
    int? orderId,
    List<String>? statuses,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? search,
    int? page, // <-- NOUVEAU
    int? limit, // <-- NOUVEAU
  }) async {
  // --- FIN MODIFICATION ---
    final db = await _dbService.database;

    List<String> whereClauses = ['1=1'];
    List<dynamic> whereArgs = [];

    if (orderId != null) {
      whereClauses.add('id = ?');
      whereArgs.add(orderId);
    }
    if (statuses != null && statuses.isNotEmpty) {
      whereClauses.add('status IN (${statuses.map((_) => '?').join(',')})');
      whereArgs.addAll(statuses);
    }
    if (status != null && status != 'all') {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }
    
    if (startDate != null && endDate != null) {
      final dateStart = DateFormat('yyyy-MM-ddT00:00:00').format(startDate);
      final dateEnd = DateFormat('yyyy-MM-ddT23:59:59').format(endDate);

      whereClauses.add(
          '( (created_at >= ? AND created_at <= ?) OR (follow_up_at >= ? AND follow_up_at <= ?) )');
      whereArgs.addAll([dateStart, dateEnd, dateStart, dateEnd]);
    } else if (startDate != null) {
        whereClauses.add('(created_at >= ? OR follow_up_at >= ?)');
        whereArgs.addAll([DateFormat('yyyy-MM-ddT00:00:00').format(startDate), DateFormat('yyyy-MM-ddT00:00:00').format(startDate)]);
    } else if (endDate != null) {
        whereClauses.add('(created_at <= ? OR follow_up_at <= ?)');
        whereArgs.addAll([DateFormat('yyyy-MM-ddT23:59:59').format(endDate), DateFormat('yyyy-MM-ddT23:59:59').format(endDate)]);
    }
    
    if (search != null && search.isNotEmpty) {
      final query = '%$search%';
      whereClauses.add(
          '(id LIKE ? OR shop_name LIKE ? OR customer_phone LIKE ? OR delivery_location LIKE ? OR deliveryman_name LIKE ?)');
      whereArgs.addAll([query, query, query, query, query]);
    }
    
    // --- MODIFIÉ : Ajout de la pagination SQL ---
    final int? offset = (page != null && limit != null) ? (page - 1) * limit : null;
    // --- FIN MODIFICATION ---

    final orderMaps = await db.query(
      DatabaseService.tableOrders, 
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit, // <-- NOUVEAU
      offset: offset, // <-- NOUVEAU
    );

    if (orderMaps.isEmpty) return [];

    final orderIds = orderMaps.map((map) => map['id'] as int).toList();
    final idChunks = orderIds.map((_) => '?').join(',');

    final itemsMaps = await db.query(
      DatabaseService.tableOrderItems,
      where: 'order_id IN ($idChunks)',
      whereArgs: orderIds,
    );
    final historyMaps = await db.query(
      DatabaseService.tableOrderHistory,
      where: 'order_id IN ($idChunks)',
      whereArgs: orderIds,
    );
    
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

  // (Inchangée)
  Future<List<AdminOrder>> getOrdersFromDbByShopAndDate(int shopId, DateTime date) async {
    final db = await _dbService.database;

    final String dateStart = DateFormat('yyyy-MM-ddT00:00:00').format(date);
    final String dateEnd = DateFormat('yyyy-MM-ddT23:59:59').format(date);

    final orderMaps = await db.query(
      DatabaseService.tableOrders,
      where: 'shop_id = ? AND created_at BETWEEN ? AND ? AND status IN (?, ?)',
      whereArgs: [shopId, dateStart, dateEnd, 'delivered', 'failed_delivery'],
      orderBy: 'created_at ASC',
    );

    if (orderMaps.isEmpty) return [];

    final orderIds = orderMaps.map((map) => map['id'] as int).toList();
    final idChunks = orderIds.map((_) => '?').join(',');
    
    final itemsMaps = await db.query(
      DatabaseService.tableOrderItems,
      where: 'order_id IN ($idChunks)',
      whereArgs: orderIds,
    );
    
    final itemsByOrderId = <int, List<Map<String, dynamic>>>{};
    for (var map in itemsMaps) {
      final id = map['order_id'] as int;
      itemsByOrderId.putIfAbsent(id, () => []).add(map);
    }

    return orderMaps.map((orderMap) {
      final id = orderMap['id'] as int;
      final itemsList = (itemsByOrderId[id] ?? [])
          .map((map) => _itemFromMap(map))
          .toList();
      return _orderFromMap(orderMap, itemsList, []); 
    }).toList();
  }

  // --- MAPPERS (Inchangés) ---
  
  Map<String, dynamic> _orderToMap(AdminOrder order) {
    final Map<String, dynamic> map = {
      'id': order.id,
      'shop_id': order.shopId, 
      'shop_name': order.shopName,
      'customer_phone': order.customerPhone,
      'delivery_location': order.deliveryLocation,
      'article_amount': order.articleAmount,
      'delivery_fee': order.deliveryFee,
      'expedition_fee': order.expeditionFee,
      'status': order.status,
      'payment_status': order.paymentStatus,
      'created_at': order.createdAt.toIso8601String(),
      'is_synced': order.isSynced ? 1 : 0, 
    };
    
    map['deliveryman_id'] = order.deliverymanId;
    map['deliveryman_name'] = order.deliverymanName;
    map['customer_name'] = order.customerName;
    map['picked_up_by_rider_at'] = order.pickedUpByRiderAt?.toIso8601String();
    map['follow_up_at'] = order.followUpAt?.toIso8601String();
    map['amount_received'] = order.amountReceived;

    return map;
  }
  
  AdminOrder _orderFromMap(Map<String, dynamic> map, List<OrderItem> items, List<OrderHistoryItem> history) {
    return AdminOrder(
      id: map['id'] as int,
      shopId: map['shop_id'] as int? ?? 0, 
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
      followUpAt: map['follow_up_at'] != null ? DateTime.parse(map['follow_up_at']) : null,
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
    final Map<String, dynamic> map = {
      'tracking_id': item.trackingId,
      'order_id': item.orderId,
      'shop_name': item.shopName,
      'deliveryman_name': item.deliverymanName,
      'return_status': item.returnStatus,
      'declaration_date': item.declarationDate.toIso8601String(),
    };
    
    map['hub_reception_date'] = item.hubReceptionDate?.toIso8601String();
    map['comment'] = item.comment;
    
    return map.cast<String, dynamic>(); 
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