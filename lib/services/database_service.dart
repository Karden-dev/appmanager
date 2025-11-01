// lib/services/database_service.dart

// --- CORRECTION DE L'IMPORT ---
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static const _databaseName = "wink_manager.db";
  static const _databaseVersion = 1;

  // Noms des tables
  static const tableOrders = 'orders';
  static const tableOrderItems = 'order_items';
  static const tableOrderHistory = 'order_history';
  static const tableReturnTracking = 'return_tracking';
  static const tableShops = 'shops';
  static const tableDeliverymen = 'deliverymen';
  static const tablePendingActions = 'pending_actions';

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
    final path = join(documentsDirectory.path, _databaseName); // 'join' est maintenant reconnu

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
    );
  }

  // Activer les clés étrangères
  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Création des tables
  Future _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE $tableOrders (
      id INTEGER PRIMARY KEY, 
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
  }

  // --- Des méthodes CRUD (Create, Read, Update, Delete) viendront ici ---
  // (Nous les ajouterons dans le Repository)
}