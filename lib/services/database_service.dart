// lib/services/database_service.dart

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart'; // Pour kDebugMode

class DatabaseService {
  static const _databaseName = "wink_manager.db";
  // --- MODIFICATION : Version incrémentée pour la migration Shops ---
  static const _databaseVersion = 9; // <-- VERSION MISE À JOUR (v9)

  // Noms des tables (Existantes)
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
  static const tableRemittancesCache = 'remittances_cache';
  static const tableDebtsCache = 'debts_cache';
  static const tableCashTransactionsCache = 'cash_transactions_cache';
  static const tableShortfallsCache = 'shortfalls_cache'; 

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

  // Création des tables (utilisé pour la version initiale)
  Future _onCreate(Database db, int version) async {
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
      follow_up_at TEXT, 
      is_synced INTEGER NOT NULL DEFAULT 1 
    )
    ''');
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

    // --- MODIFICATION : Table Shops avec nouveaux champs ---
    await db.execute('''
    CREATE TABLE $tableShops (
      id INTEGER PRIMARY KEY, 
      name TEXT NOT NULL,
      phone_number TEXT NOT NULL,
      status TEXT DEFAULT 'actif',
      bill_packaging INTEGER DEFAULT 0,
      bill_storage INTEGER DEFAULT 0,
      packaging_price REAL DEFAULT 0.0,
      storage_price REAL DEFAULT 0.0,
      created_at TEXT
    )
    ''');
    // --- FIN MODIFICATION ---

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
    await _createRemittancesCacheTable(db);
    await _createDebtsCacheTable(db);
    await _createCashTransactionsCacheTable(db);
    await _createShortfallsCacheTable(db);
  }
  
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (kDebugMode) {
      print('DatabaseService: Migration de v$oldVersion à v$newVersion...');
    }
    if (oldVersion < 5) { /* ... */ }
    if (oldVersion < 6) { await _createRemittancesCacheTable(db); }
    if (oldVersion < 7) { await _createDebtsCacheTable(db); }
    if (oldVersion < 8) {
      await _createCashTransactionsCacheTable(db);
      await _createShortfallsCacheTable(db);
    }
    
    // --- MIGRATION V9 : Mise à jour de la table SHOPS ---
    if (oldVersion < 9) {
      if (kDebugMode) print('DatabaseService: Application de la v9 (Mise à jour Table Shops)...');
      // SQLite ne supporte pas l'ajout de plusieurs colonnes en une seule commande ALTER TABLE standard facilement,
      // on les ajoute une par une.
      try {
        await db.execute("ALTER TABLE $tableShops ADD COLUMN status TEXT DEFAULT 'actif'");
        await db.execute("ALTER TABLE $tableShops ADD COLUMN bill_packaging INTEGER DEFAULT 0");
        await db.execute("ALTER TABLE $tableShops ADD COLUMN bill_storage INTEGER DEFAULT 0");
        await db.execute("ALTER TABLE $tableShops ADD COLUMN packaging_price REAL DEFAULT 0.0");
        await db.execute("ALTER TABLE $tableShops ADD COLUMN storage_price REAL DEFAULT 0.0");
        await db.execute("ALTER TABLE $tableShops ADD COLUMN created_at TEXT");
      } catch (e) {
        // Si une colonne existe déjà (cas d'un dev partiel), on ignore l'erreur
        if (kDebugMode) print("Erreur migration v9 (peut-être déjà appliquée): $e");
      }
    }
  }
  
  // --- Méthodes Helper ---
  
  Future<void> _createChatTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMessages (
          id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL, user_id INTEGER NOT NULL, user_name TEXT NOT NULL,
          content TEXT NOT NULL, message_type TEXT NOT NULL, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableConversations (
          order_id INTEGER PRIMARY KEY, customer_phone TEXT, shop_name TEXT, deliveryman_name TEXT, deliveryman_phone TEXT,
          is_urgent INTEGER NOT NULL DEFAULT 0, is_archived INTEGER NOT NULL DEFAULT 0, 
          last_message TEXT, last_message_time TEXT, unread_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createReportsCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableReportsCache (
        id INTEGER PRIMARY KEY AUTOINCREMENT, report_date TEXT NOT NULL, shop_id INTEGER NOT NULL, shop_name TEXT NOT NULL,
        total_orders_sent INTEGER NOT NULL DEFAULT 0, total_orders_delivered INTEGER NOT NULL DEFAULT 0,
        total_revenue_articles REAL NOT NULL DEFAULT 0.0, total_delivery_fees REAL NOT NULL DEFAULT 0.0,
        total_expedition_fees REAL NOT NULL DEFAULT 0.0, total_packaging_fees REAL NOT NULL DEFAULT 0.0,
        total_storage_fees REAL NOT NULL DEFAULT 0.0, amount_to_remit REAL NOT NULL DEFAULT 0.0,
        UNIQUE(report_date, shop_id)
      )
    ''');
  }

  Future<void> _createRemittancesCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableRemittancesCache (
        id INTEGER PRIMARY KEY, shop_id INTEGER NOT NULL, shop_name TEXT NOT NULL, payment_name TEXT,
        phone_number_for_payment TEXT, payment_operator TEXT, gross_amount REAL NOT NULL,
        debts_consolidated REAL NOT NULL, net_amount REAL NOT NULL, status TEXT NOT NULL,
        remittance_date TEXT, payment_date TEXT
      )
    ''');
  }

  Future<void> _createDebtsCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDebtsCache (
        id INTEGER PRIMARY KEY, shop_id INTEGER NOT NULL, shop_name TEXT NOT NULL,
        amount REAL NOT NULL, type TEXT NOT NULL, status TEXT NOT NULL,
        comment TEXT, created_at TEXT NOT NULL, settled_at TEXT
      )
    ''');
  }

  Future<void> _createCashTransactionsCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCashTransactionsCache (
        id INTEGER PRIMARY KEY, 
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        type TEXT NOT NULL,
        category_id INTEGER,
        category_name TEXT,
        amount REAL NOT NULL,
        comment TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        validated_by INTEGER,
        validated_by_name TEXT,
        validated_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_user_date ON $tableCashTransactionsCache (user_id, created_at)');
  }
  
  Future<void> _createShortfallsCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableShortfallsCache (
        id INTEGER PRIMARY KEY, 
        deliveryman_id INTEGER NOT NULL,
        deliveryman_name TEXT NOT NULL,
        amount REAL NOT NULL,
        comment TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        settled_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sf_user_status ON $tableShortfallsCache (deliveryman_id, status)');
  }
}