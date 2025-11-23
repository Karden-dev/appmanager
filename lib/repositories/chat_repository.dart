// lib/repositories/chat_repository.dart

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wink_manager/models/conversation.dart';
import 'package:wink_manager/models/message.dart';
import 'package:wink_manager/services/database_service.dart';

/// Gère l'accès à la base de données locale (Sqflite) pour le module de Chat Admin.
/// Ne gère que le cache local.
class ChatRepository {
  final DatabaseService _dbService;

  ChatRepository(this._dbService);

  // --- Gestion des Conversations (Liste Admin) ---

  /// Insère ou met à jour une liste de conversations dans le cache.
  Future<void> cacheConversations(List<Conversation> conversations) async {
    if (conversations.isEmpty) return;
    final db = await _dbService.database;
    try {
      await db.transaction((txn) async {
        Batch batch = txn.batch();
        for (var conv in conversations) {
          batch.insert(
            DatabaseService.tableConversations,
            conv.toMapForDb(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
      if (kDebugMode) {
        print(
            'ChatRepository: ${conversations.length} conversations mises en cache.');
      }
    } catch (e) {
      debugPrint('ChatRepository: Erreur cacheConversations: $e');
    }
  }

  /// Récupère les conversations depuis le cache local.
  // --- MODIFIÉ : Ajout de la pagination (page, limit) ---
  Future<List<Conversation>> getCachedConversations({
    required bool showArchived,
    required bool showUrgentOnly,
    int? page,
    int? limit,
  }) async {
  // --- FIN MODIFICATION ---
    final db = await _dbService.database;
    try {
      List<String> whereClauses = [];
      List<dynamic> whereArgs = [];

      // Logique de filtre
      whereClauses.add('is_archived = ?');
      whereArgs.add(showArchived ? 1 : 0);

      if (showUrgentOnly) {
        whereClauses.add('is_urgent = ?');
        whereArgs.add(1);
      }
      
      // --- MODIFIÉ : Ajout de la pagination SQL ---
      final int? offset = (page != null && limit != null) ? (page - 1) * limit : null;
      // --- FIN MODIFICATION ---

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseService.tableConversations,
        where: whereClauses.join(' AND '),
        whereArgs: whereArgs,
        orderBy: 'is_urgent DESC, last_message_time DESC',
        // --- MODIFIÉ : Ajout de limit et offset ---
        limit: limit,
        offset: offset,
        // --- FIN MODIFICATION ---
      );

      return List.generate(maps.length, (i) => Conversation.fromMap(maps[i]));
    } catch (e) {
      debugPrint('ChatRepository: Erreur getCachedConversations: $e');
      return [];
    }
  }

  /// Vide le cache des conversations.
  Future<void> clearConversationCache() async {
    final db = await _dbService.database;
    try {
      await db.delete(DatabaseService.tableConversations);
      if (kDebugMode) print('ChatRepository: Cache des conversations vidé.');
    } catch (e) {
      debugPrint('ChatRepository: Erreur clearConversationCache: $e');
    }
  }

  // --- Gestion des Messages (Chat Détaillé) ---

  /// Insère une liste de messages (typiquement l'historique).
  Future<void> cacheMessages(List<Message> messages) async {
    if (messages.isEmpty) return;
    final db = await _dbService.database;
    try {
      await db.transaction((txn) async {
        Batch batch = txn.batch();
        for (var message in messages) {
          batch.insert(
            DatabaseService.tableMessages,
            message.toMapForDb(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      debugPrint('ChatRepository: Erreur cacheMessages: $e');
    }
  }

  /// Insère un seul message (reçu via WebSocket).
  Future<void> cacheSingleMessage(Message message) async {
    final db = await _dbService.database;
    try {
      await db.insert(
        DatabaseService.tableMessages,
        message.toMapForDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('ChatRepository: Erreur cacheSingleMessage ${message.id}: $e');
    }
  }

  /// Remplace un message temporaire (ID > 999...) par le message réel du serveur.
  Future<void> replaceTempMessage(int tempId, Message realMessage) async {
    final db = await _dbService.database;
    try {
      await db.transaction((txn) async {
        await txn.delete(
          DatabaseService.tableMessages,
          where: 'id = ?',
          whereArgs: [tempId],
        );
        await txn.insert(
          DatabaseService.tableMessages,
          realMessage.toMapForDb(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      if (kDebugMode) {
        print(
            'ChatRepository: Message temporaire $tempId remplacé par ${realMessage.id}.');
      }
    } catch (e) {
      debugPrint(
          'ChatRepository: Erreur replaceTempMessage (Temp: $tempId, Real: ${realMessage.id}): $e');
      await cacheSingleMessage(realMessage);
    }
  }

  /// Récupère les messages locaux pour une orderId, triés par date.
  /// Supporte la pagination (limit).
  Future<List<Message>> getCachedMessages(
      int orderId, int currentUserId, {int? limit}) async {
    final db = await _dbService.database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseService.tableMessages,
        where: 'order_id = ?',
        whereArgs: [orderId],
        orderBy: 'created_at DESC', // Récupère les plus récents
        limit: limit, // Limite le nombre de résultats
      );

      final messages = List.generate(maps.length, (i) {
        return Message.fromMap(maps[i], currentUserId);
      });
      
      // Renvoie la liste en ordre chronologique (ASC) pour l'UI
      return messages.reversed.toList();

    } catch (e) {
      debugPrint(
          'ChatRepository: Erreur getCachedMessages pour order $orderId: $e');
      return [];
    }
  }

  /// Récupère le timestamp ('created_at') du dernier message local pour une orderId.
  Future<String?> getLatestMessageTimestamp(int orderId) async {
    final db = await _dbService.database;
    try {
      final List<Map<String, dynamic>> result = await db.query(
        DatabaseService.tableMessages,
        columns: ['created_at'],
        where: 'order_id = ?',
        whereArgs: [orderId],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      return result.isNotEmpty ? result.first['created_at'] as String? : null;
    } catch (e) {
      debugPrint(
          'ChatRepository: Erreur getLatestMessageTimestamp pour order $orderId: $e');
      return null;
    }
  }
}