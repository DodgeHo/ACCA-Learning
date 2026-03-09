import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _db;
  static const String _dbAssetVersion = '2026-03-01-zh-fix-v1';

  static Future<Database> getInstance() async {
    if (_db != null) return _db!;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'data.db');

    // copy from asset if not yet present
    if (!await File(path).exists()) {
      await _copyAssetDb(path);
    }

    _db = await openDatabase(path);
    await _ensureRuntimeTables(_db!);

    final needsRepair = await _needsNativeRepair(_db!);
    if (needsRepair) {
      final statusRows = await _db!.query('user_status');
      final chatRows = await _db!.query('chat_history');
      await _db!.close();
      _db = null;

      if (await File(path).exists()) {
        await File(path).delete();
      }
      await _copyAssetDb(path);

      _db = await openDatabase(path);
      await _ensureRuntimeTables(_db!);

      for (final row in statusRows) {
        await _db!.insert('user_status', row);
      }
      for (final row in chatRows) {
        try {
          await _db!.insert(
            'chat_history',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (e) {
          debugPrint('chat history restore skipped: $e');
        }
      }
    }

    await _markDbVersion(_db!);
    return _db!;
  }

  static Future<void> _copyAssetDb(String path) async {
    final data = await rootBundle.load('assets/data.db');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(path).writeAsBytes(bytes, flush: true);
  }

  static Future<void> _ensureRuntimeTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_status (
        question_id INTEGER,
        status TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_history (
        question_id INTEGER PRIMARY KEY,
        content TEXT,
        updated_at TEXT
      )
    ''');
  }

  static Future<void> _markDbVersion(Database db) async {
    await db.insert(
      'app_meta',
      {'key': 'db_asset_version', 'value': _dbAssetVersion},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<bool> _needsNativeRepair(Database db) async {
    final versionRow = await db.query(
      'app_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['db_asset_version'],
      limit: 1,
    );
    final currentVersion = versionRow.isNotEmpty ? versionRow.first['value'] as String? : null;
    if (currentVersion != null && currentVersion == _dbAssetVersion) {
      return false;
    }

    final row = await db.rawQuery(
      "SELECT stem_zh FROM questions WHERE stem_zh IS NOT NULL LIMIT 1",
    );
    if (row.isEmpty) return false;
    final sample = (row.first['stem_zh'] as String?) ?? '';

    return sample.contains('�') || sample.contains('һ�') || sample.contains('��');
  }

  // questions
  static Future<List<Map<String, dynamic>>> fetchQuestions({String? filterStatus}) async {
    final db = await getInstance();
    if (filterStatus != null) {
      return await db.rawQuery('''
        SELECT q.* FROM questions q
        JOIN user_status s ON s.question_id=q.id
        WHERE s.status=?
      ''', [filterStatus]);
    }
    return await db.query('questions');
  }

  // user status operations
  static Future<String?> getStatus(int questionId) async {
    final db = await getInstance();
    final res = await db.query('user_status',
        columns: ['status'],
        where: 'question_id = ?',
        whereArgs: [questionId],
        orderBy: 'rowid DESC',
        limit: 1);
    if (res.isNotEmpty) return res.first['status'] as String;
    return null;
  }

  static Future<void> setStatus(int questionId, String status) async {
    final db = await getInstance();
    await db.delete('user_status', where: 'question_id=?', whereArgs: [questionId]);
    await db.insert('user_status', {
      'question_id': questionId,
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> clearStatuses() async {
    final db = await getInstance();
    await db.delete('user_status');
  }

  static Future<Map<int, String>> getLatestStatuses() async {
    final db = await getInstance();
    final rows = await db.rawQuery('''
      SELECT us.question_id, us.status
      FROM user_status us
      INNER JOIN (
        SELECT question_id, MAX(rowid) AS max_rowid
        FROM user_status
        GROUP BY question_id
      ) latest ON latest.max_rowid = us.rowid
    ''');

    final map = <int, String>{};
    for (final row in rows) {
      final qid = row['question_id'];
      final status = row['status'];
      if (qid is int && status is String) {
        map[qid] = status;
      }
    }
    return map;
  }

  /// return a map of status->count for all existing entries
  static Future<Map<String,int>> countByStatus() async {
    final db = await getInstance();
    final rows = await db.rawQuery('SELECT status,COUNT(*) as c FROM user_status GROUP BY status');
    final Map<String,int> m = {};
    for (var r in rows) {
      m[r['status'] as String] = r['c'] as int;
    }
    return m;
  }

  static Future<String?> getChatHistory(int questionId) async {
    final db = await getInstance();
    final res = await db.query(
      'chat_history',
      columns: ['content'],
      where: 'question_id = ?',
      whereArgs: [questionId],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return res.first['content'] as String?;
  }

  static Future<Map<int, String>> getAllChatHistories() async {
    final db = await getInstance();
    final rows = await db.query('chat_history');
    final map = <int, String>{};
    for (final row in rows) {
      final qid = row['question_id'];
      final content = row['content'];
      if (qid is int && content is String && content.trim().isNotEmpty) {
        map[qid] = content;
      }
    }
    return map;
  }

  static Future<void> setChatHistory(int questionId, String content) async {
    final db = await getInstance();
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      await clearChatHistory(questionId);
      return;
    }
    await db.insert(
      'chat_history',
      {
        'question_id': questionId,
        'content': content,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> clearChatHistory(int questionId) async {
    final db = await getInstance();
    await db.delete('chat_history', where: 'question_id = ?', whereArgs: [questionId]);
  }

  static Future<void> clearAllChatHistories() async {
    final db = await getInstance();
    await db.delete('chat_history');
  }

  static Future<void> importChatHistories(
    Map<int, String> histories, {
    bool clearExisting = false,
  }) async {
    final db = await getInstance();
    await db.transaction((txn) async {
      if (clearExisting) {
        await txn.delete('chat_history');
      }
      for (final entry in histories.entries) {
        final content = entry.value.trim();
        if (content.isEmpty) continue;
        await txn.insert(
          'chat_history',
          {
            'question_id': entry.key,
            'content': entry.value,
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
