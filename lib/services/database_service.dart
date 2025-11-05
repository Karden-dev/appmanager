// lib/services/database_service.dart

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart'; // Pour kDebugMode

class DatabaseService {
  static const _databaseName = "wink_manager.db";
  // --- MODIFICATION : Version incrémentée pour la migration ---
  static const _databaseVersion = 4; // <-- VERSION MISE À JOUR

  // Noms des tables
  static const tableOrders = 'orders';
  static const tableOrderItems = 'order_items';
  static const tableOrderHistory = 'order_history';
  static const tableReturnTracking = 'return_tracking';
  static const tableShops = 'shops';
  static const tableDeliverymen = 'deliverymen';
  static const tablePendingActions = 'pending_actions';
  static const tableMessages = 'messages_cache';
  static const tableConversations = 'conversations_cache';
  static const tableReportsCache = 'reports_cache';

  // Singleton
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
  }

  // Activer les clés étrangères
  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Création des tables
  Future _onCreate(Database db, int version) async {
    // --- MODIFICATION : Ajout de shop_id ---
    await db.execute('''
    CREATE TABLE $tableOrders (
      id INTEGER PRIMARY KEY, 
      shop_id INTEGER, 
      shop_name TEXT NOT NULL,
      deliveryman_id INTEGER,
      deliveryman_name TEXT,
      customer_name TEXT,
      customer_phone TEXT NOT NULL,
      delivery_location TEXT NOT NULL,
      article_amount REAL NOT NULL,
      delivery_fee REAL NOT NULL,
      expedition_fee REAL NOT NULL,
      status TEXT NOT NULL,
      payment_status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      picked_up_by_rider_at TEXT,
      amount_received REAL,
      is_synced INTEGER NOT NULL DEFAULT 1 
    )
    ''');
    // Ajout d'un index pour la nouvelle colonne
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_shop_id ON $tableOrders (shop_id)');

    await db.execute('''
    CREATE TABLE $tableOrderItems (
      id INTEGER PRIMARY KEY, 
      order_id INTEGER NOT NULL,
      item_name TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      amount REAL NOT NULL,
      FOREIGN KEY (order_id) REFERENCES $tableOrders (id) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE $tableOrderHistory (
      id INTEGER PRIMARY KEY, 
      order_id INTEGER NOT NULL,
      action TEXT NOT NULL,
      user_name TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (order_id) REFERENCES $tableOrders (id) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE $tableReturnTracking (
      tracking_id INTEGER PRIMARY KEY, 
      order_id INTEGER NOT NULL,
      shop_name TEXT NOT NULL,
      deliveryman_name TEXT NOT NULL,
      return_status TEXT NOT NULL,
      declaration_date TEXT NOT NULL,
      hub_reception_date TEXT,
      comment TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE $tableShops (
      id INTEGER PRIMARY KEY, 
      name TEXT NOT NULL,
      phone_number TEXT NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE $tableDeliverymen (
      id INTEGER PRIMARY KEY, 
      name TEXT,
      phone TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE $tablePendingActions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      payload TEXT NOT NULL,
      created_at TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0
    )
    ''');
    
    await _createChatTables(db);
    await _createReportsCacheTable(db);
  }
  
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (kDebugMode) {
      print('DatabaseService: Migration de v$oldVersion à v$newVersion...');
    }
    if (oldVersion < 2) {
      if (kDebugMode) print('DatabaseService: Application de la v2 (Tables Chat)...');
      await _createChatTables(db);
    }
    if (oldVersion < 3) {
      if (kDebugMode) print('DatabaseService: Application de la v3 (Table Cache Rapports)...');
      await _createReportsCacheTable(db);
    }
    // --- NOUVELLE MIGRATION V4 ---
    if (oldVersion < 4) {
      if (kDebugMode) print('DatabaseService: Application de la v4 (Ajout shop_id à orders)...');
      try {
        await db.execute('ALTER TABLE $tableOrders ADD COLUMN shop_id INTEGER');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_order_shop_id ON $tableOrders (shop_id)');
      } catch (e) {
         if (kDebugMode) print('Erreur migration v4 (colonne existe peut-être déjà): $e');
      }
    }
    // --- FIN MIGRATION V4 ---
  }
  
  Future<void> _createChatTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMessages (
          id INTEGER PRIMARY KEY,
          order_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          user_name TEXT NOT NULL,
          content TEXT NOT NULL,
          message_type TEXT NOT NULL,
          created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_msg_order_id ON $tableMessages (order_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_msg_created_at ON $tableMessages (created_at)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableConversations (
          order_id INTEGER PRIMARY KEY,
          customer_phone TEXT,
          shop_name TEXT,
          deliveryman_name TEXT,
          is_urgent INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          last_message TEXT,
          last_message_time TEXT,
          unread_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_conv_last_time ON $tableConversations (last_message_time)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_conv_flags ON $tableConversations (is_archived, is_urgent)');
  }

  Future<void> _createReportsCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableReportsCache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_date TEXT NOT NULL, 
        shop_id INTEGER NOT NULL,
        shop_name TEXT NOT NULL,
        total_orders_sent INTEGER NOT NULL DEFAULT 0,
        total_orders_delivered INTEGER NOT NULL DEFAULT 0,
        total_revenue_articles REAL NOT NULL DEFAULT 0.0,
        total_delivery_fees REAL NOT NULL DEFAULT 0.0,
        total_expedition_fees REAL NOT NULL DEFAULT 0.0,
        total_packaging_fees REAL NOT NULL DEFAULT 0.0,
        total_storage_fees REAL NOT NULL DEFAULT 0.0,
        amount_to_remit REAL NOT NULL DEFAULT 0.0,
        UNIQUE(report_date, shop_id)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_report_date ON $tableReportsCache (report_date)');
  }

}