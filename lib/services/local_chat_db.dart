import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/chat_message.dart';

class LocalChatDb {
  static final LocalChatDb instance = LocalChatDb._internal();
  LocalChatDb._internal();

  static Database? _database;
  static Completer<Database>? _initCompleter;
  static const String _dbName = 'nodelink_local_chats.db';
  static const int _dbVersion = 1;

  final StreamController<void> _changeController = StreamController<void>.broadcast();
  Stream<void> get onDatabaseChanged => _changeController.stream;
  Timer? _debounceTimer;

  /// Strict Singleton Accessor: Ensures the database is opened exactly ONCE
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<Database>();

    try {
      _database = await _initDatabase();
      _initCompleter!.complete(_database);
      return _database!;
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // Safe PRAGMA initialization:
        // On Android, PRAGMA journal_mode returns a result row ('wal'), which causes native execSQL()
        // to throw: "Queries can be performed using SQLiteDatabase query or rawQuery methods only."
        // We use rawQuery first with fallback to execute, fully guarded in try-catch.
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL;');
        } catch (_) {
          try {
            await db.execute('PRAGMA journal_mode = WAL;');
          } catch (_) {}
        }

        try {
          await db.execute('PRAGMA busy_timeout = 8000;');
          await db.execute('PRAGMA synchronous = NORMAL;');
        } catch (_) {}
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            peerNodeId TEXT NOT NULL,
            senderId TEXT NOT NULL,
            decryptedText TEXT,
            messageType TEXT NOT NULL,
            mediaPath TEXT,
            mediaDuration TEXT,
            latitude REAL,
            longitude REAL,
            timestamp INTEGER NOT NULL,
            status TEXT NOT NULL,
            isOutgoing INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE chat_settings (
            peerNodeId TEXT PRIMARY KEY,
            isMuted INTEGER DEFAULT 0
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_messages_peer_timestamp ON messages (peerNodeId, timestamp)',
        );
      },
    );
  }

  /// Debounced change notification to prevent flooding SQLite queries during burst writes
  void _notifyChange() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 35), () {
      if (!_changeController.isClosed) {
        _changeController.add(null);
      }
    });
  }

  /// Inserts or updates a decrypted chat message in local SQLite
  Future<void> insertMessage(ChatMessage message) async {
    try {
      final db = await database;
      await db.insert(
        'messages',
        message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _notifyChange();
    } catch (e) {
      debugPrint('[LocalChatDb] Error inserting message: $e');
    }
  }

  /// Batch inserts multiple messages within a single transaction to prevent database locking
  Future<void> insertMessages(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    try {
      final db = await database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final message in messages) {
          batch.insert(
            'messages',
            message.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
      _notifyChange();
    } catch (e) {
      debugPrint('[LocalChatDb] Error batch inserting messages: $e');
    }
  }

  /// Updates message delivery/read status
  Future<void> updateMessageStatus(String messageId, String status) async {
    try {
      final db = await database;
      await db.update(
        'messages',
        {'status': status},
        where: 'id = ?',
        whereArgs: [messageId],
      );
      _notifyChange();
    } catch (e) {
      debugPrint('[LocalChatDb] Error updating status: $e');
    }
  }

  List<String> _resolvePeerCandidates(String peerNodeId) {
    final cleanDigits = peerNodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final candidates = <String>{peerNodeId};
    if (cleanDigits.isNotEmpty) {
      candidates.add(cleanDigits);
      candidates.add('node_$cleanDigits');
    }
    return candidates.toList();
  }

  /// Reactive stream of messages for a specific peer.
  /// Emits immediately upon subscription from local SQLite,
  /// then re-emits on every insert or update.
  Stream<List<ChatMessage>> watchMessages(String peerNodeId) async* {
    yield await getMessages(peerNodeId);
    await for (final _ in _changeController.stream) {
      yield await getMessages(peerNodeId);
    }
  }

  /// Retrieves full conversation history for a given peer sorted oldest to newest
  Future<List<ChatMessage>> getMessages(String peerNodeId) async {
    try {
      final db = await database;
      final candidates = _resolvePeerCandidates(peerNodeId);
      final placeholders = List.filled(candidates.length, '?').join(', ');
      final List<Map<String, dynamic>> maps = await db.query(
        'messages',
        where: 'peerNodeId IN ($placeholders)',
        whereArgs: candidates,
        orderBy: 'timestamp ASC',
      );
      return maps.map((m) => ChatMessage.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[LocalChatDb] Error getting messages: $e');
      return [];
    }
  }

  /// Retrieves the single latest message for a peer node
  Future<ChatMessage?> getLastMessage(String peerNodeId) async {
    try {
      final db = await database;
      final candidates = _resolvePeerCandidates(peerNodeId);
      final placeholders = List.filled(candidates.length, '?').join(', ');
      final List<Map<String, dynamic>> maps = await db.query(
        'messages',
        where: 'peerNodeId IN ($placeholders)',
        whereArgs: candidates,
        orderBy: 'timestamp DESC',
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return ChatMessage.fromMap(maps.first);
      }
    } catch (e) {
      debugPrint('[LocalChatDb] Error getting last message: $e');
    }
    return null;
  }

  /// Counts unread incoming messages from a peer node
  Future<int> getUnreadCount(String peerNodeId) async {
    try {
      final db = await database;
      final candidates = _resolvePeerCandidates(peerNodeId);
      final placeholders = List.filled(candidates.length, '?').join(', ');
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM messages WHERE peerNodeId IN ($placeholders) AND isOutgoing = 0 AND status != ?',
        [...candidates, 'read'],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('[LocalChatDb] Error getting unread count: $e');
      return 0;
    }
  }

  /// Marks all incoming messages from a peer node as read
  Future<void> markAllAsRead(String peerNodeId) async {
    try {
      final db = await database;
      final candidates = _resolvePeerCandidates(peerNodeId);
      final placeholders = List.filled(candidates.length, '?').join(', ');
      await db.update(
        'messages',
        {'status': 'read'},
        where: 'peerNodeId IN ($placeholders) AND isOutgoing = 0 AND status != ?',
        whereArgs: [...candidates, 'read'],
      );
      _notifyChange();
    } catch (e) {
      debugPrint('[LocalChatDb] Error marking read: $e');
    }
  }

  /// Marks all incoming messages across all peers as read
  Future<void> markAllConversationsAsRead() async {
    try {
      final db = await database;
      await db.update(
        'messages',
        {'status': 'read'},
        where: 'isOutgoing = 0 AND status != ?',
        whereArgs: ['read'],
      );
      _notifyChange();
    } catch (e) {
      debugPrint('[LocalChatDb] Error marking all conversations read: $e');
    }
  }

  /// Queries all media messages (photos, videos, audio) shared with a peer
  Future<List<ChatMessage>> getMediaMessages(String peerNodeId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'messages',
        where: 'peerNodeId = ? AND (messageType IN (?, ?, ?) OR mediaPath IS NOT NULL)',
        whereArgs: [peerNodeId, 'image', 'video', 'voice'],
        orderBy: 'timestamp DESC',
      );
      return maps.map((m) => ChatMessage.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[LocalChatDb] Error getting media messages: $e');
      return [];
    }
  }

  /// Clears decrypted chat history for a specific peer
  Future<void> clearChat(String peerNodeId) async {
    try {
      final db = await database;
      await db.delete(
        'messages',
        where: 'peerNodeId = ?',
        whereArgs: [peerNodeId],
      );
      _notifyChange();
    } catch (e) {
      debugPrint('[LocalChatDb] Error clearing chat: $e');
    }
  }

  /// Checks if a conversation is muted
  Future<bool> isMuted(String peerNodeId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'chat_settings',
        where: 'peerNodeId = ?',
        whereArgs: [peerNodeId],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return (maps.first['isMuted'] as int? ?? 0) == 1;
      }
    } catch (e) {
      debugPrint('[LocalChatDb] Error checking muted: $e');
    }
    return false;
  }

  /// Toggles mute notifications for a conversation
  Future<void> setMuted(String peerNodeId, bool isMuted) async {
    try {
      final db = await database;
      await db.insert(
        'chat_settings',
        {
          'peerNodeId': peerNodeId,
          'isMuted': isMuted ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _notifyChange();
    } catch (e) {
      debugPrint('[LocalChatDb] Error setting muted: $e');
    }
  }

  /// Retrieves list of all peer IDs that have local conversations
  Future<List<String>> getAllPeerIds() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.rawQuery(
        'SELECT DISTINCT peerNodeId FROM messages ORDER BY timestamp DESC',
      );
      return maps.map((m) => m['peerNodeId'] as String).toList();
    } catch (e) {
      debugPrint('[LocalChatDb] Error getting all peer IDs: $e');
      return [];
    }
  }
}
