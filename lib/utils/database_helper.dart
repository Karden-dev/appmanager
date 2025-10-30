// lib/utils/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p; // Alias pour éviter conflit
import 'package:flutter/foundation.dart'; // Pour kDebugMode

import '../models/message.dart'; // Assure-toi que ce chemin est correct

class DatabaseHelper {
  static const String _dbName = 'wink_sync_db.db'; // Même base que SyncService
  static const String _messagesTableName = 'messages';
  static const int _dbVersion = 2; // Incrémenté pour ajouter la table messages

  Database? _database;

  // Singleton instance
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Getter pour la base de données
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // Initialisation de la base de données
  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        // Crée la table sync_requests si elle n'existe pas déjà
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sync_requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT,
            method TEXT,
            payload TEXT,
            token TEXT
          )
        ''');
        // Crée la table messages
        await _createMessagesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Logique de migration
        if (oldVersion < 2) {
          debugPrint("DB Upgrade: Création table $_messagesTableName (v$newVersion)");
          await _createMessagesTable(db);
        }
        // Ajouter d'autres migrations ici si nécessaire
      },
    );
  }

  // Fonction pour créer la table messages
  Future<void> _createMessagesTable(Database db) async {
     await db.execute('''
      CREATE TABLE IF NOT EXISTS $_messagesTableName (
          id INTEGER PRIMARY KEY,
          order_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          user_name TEXT NOT NULL,
          content TEXT NOT NULL,
          message_type TEXT NOT NULL,
          created_at TEXT NOT NULL
      )
    ''');
    // Index
    await db.execute('CREATE INDEX IF NOT EXISTS idx_message_order_id ON $_messagesTableName (order_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_message_created_at ON $_messagesTableName (created_at)');
    debugPrint("DB Helper: Table '$_messagesTableName' créée/vérifiée.");
  }

  // --- Opérations CRUD pour les Messages ---

  /// Insère un message ou le remplace s'il existe déjà (basé sur l'ID).
  Future<void> insertMessage(Message message) async {
    final db = await database;
    try {
      await db.insert(
        _messagesTableName,
        message.toMapForDb(), // Assure-toi d'avoir cette méthode dans Message
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // Optionnel: Log en mode debug
      // if (kDebugMode) { print('DB Helper: Message ${message.id} inséré/remplacé.'); }
    } catch (e) {
      debugPrint('DB Helper: Erreur insertMessage ${message.id}: $e');
      // Gérer l'erreur si nécessaire (ex: afficher un message à l'utilisateur ?)
    }
  }

  /// Insère une liste de messages efficacement.
  Future<void> insertMessages(List<Message> messages) async {
    if (messages.isEmpty) return;
    final db = await database;
    try {
      await db.transaction((txn) async {
        Batch batch = txn.batch();
        for (var message in messages) {
          batch.insert(
            _messagesTableName,
            message.toMapForDb(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true); // noResult: true pour la performance
      });
      // Optionnel: Log en mode debug
      // if (kDebugMode) { print('DB Helper: ${messages.length} messages insérés/remplacés.'); }
    } catch (e) {
       debugPrint('DB Helper: Erreur insertMessages: $e');
    }
  }

  /// Récupère les messages locaux pour une orderId, triés par date.
  Future<List<Message>> getMessages(int orderId, int currentUserId) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _messagesTableName,
        where: 'order_id = ?',
        whereArgs: [orderId],
        orderBy: 'created_at ASC',
      );

      // Convertit les Maps en objets Message
      // Assure-toi d'avoir Message.fromMap dans ton modèle
      return List.generate(maps.length, (i) {
        final message = Message.fromMap(maps[i]);
        // Détermine isSentByMe ici car on a currentUserId
        return Message(
          id: message.id,
          orderId: message.orderId,
          userId: message.userId,
          userName: message.userName,
          content: message.content,
          messageType: message.messageType,
          createdAt: message.createdAt,
          isSentByMe: message.userId == currentUserId, // <- Détermination de isSentByMe
        );
      });
    } catch (e) {
       debugPrint('DB Helper: Erreur getMessages pour order $orderId: $e');
       return [];
    }
  }

  /// Récupère le timestamp ('created_at') du dernier message local pour une orderId.
  Future<String?> getLatestMessageTimestamp(int orderId) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> result = await db.query(
        _messagesTableName,
        columns: ['created_at'],
        where: 'order_id = ?',
        whereArgs: [orderId],
        orderBy: 'created_at DESC',
        limit: 1,
      );

      return result.isNotEmpty ? result.first['created_at'] as String? : null;
    } catch (e) {
      debugPrint('DB Helper: Erreur getLatestMessageTimestamp pour order $orderId: $e');
      return null;
    }
  }

  /// Supprime tous les messages d'une conversation (optionnel).
  Future<void> clearMessages(int orderId) async {
    final db = await database;
    try {
      int count = await db.delete(
        _messagesTableName,
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      debugPrint('DB Helper: $count messages supprimés pour order $orderId.');
    } catch (e) {
      debugPrint('DB Helper: Erreur clearMessages pour order $orderId: $e');
    }
  }
}

// RAPPEL : Assure-toi d'avoir ajouté ces méthodes à lib/models/message.dart
/*
  Map<String, dynamic> toMapForDb() {
    return {
      'id': id,
      'order_id': orderId,
      'user_id': userId,
      'user_name': userName,
      'content': content,
      'message_type': messageType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String());
    } catch(e) {
      if (kDebugMode) { print("Erreur parsing DB date: $e, Data: ${map['created_at']}"); }
      parsedDate = DateTime.now();
    }
    return Message(
      id: map['id'] as int? ?? 0,
      orderId: map['order_id'] as int? ?? 0,
      userId: map['user_id'] as int? ?? 0,
      userName: map['user_name'] as String? ?? 'Inconnu',
      content: map['content'] as String? ?? '',
      messageType: map['message_type'] as String? ?? 'user',
      createdAt: parsedDate,
      // isSentByMe doit être déterminé lors de l'appel à getMessages
      isSentByMe: false,
    );
  }
*/