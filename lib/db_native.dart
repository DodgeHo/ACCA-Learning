import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast/sembast_io.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

class AppDatabase {
  static sqflite.Database? _sqfliteDb;
  static sembast.Database? _sembastDb;
  static const String _dbAssetVersion = '2026-03-25-quiz-fix-v2';

  static final _questionStore = sembast.stringMapStoreFactory.store('questions');
  static final _statusStore = sembast.intMapStoreFactory.store('user_status');
  static final _chatStore = sembast.intMapStoreFactory.store('chat_history');
  static final _metaStore = sembast.stringMapStoreFactory.store('meta');

  static bool get _useDesktopSembast => !kIsWeb && (Platform.isWindows || Platform.isLinux);

  static Future<void> _ensureInitialized() async {
    if (_useDesktopSembast) {
      await _ensureDesktopDb();
      return;
    }
    await _ensureSqfliteDb();
  }

  static Future<void> _ensureDesktopDb() async {
    if (_sembastDb != null) return;

    final supportDir = await getApplicationSupportDirectory();
    await supportDir.create(recursive: true);
    final dbPath = p.join(supportDir.path, 'data.db');

    try {
      _sembastDb = await databaseFactoryIo.openDatabase(dbPath);
    } catch (_) {
      // Older Windows builds may leave a SQLite file at this path.
      // If sembast cannot read it, recreate with the new desktop format.
      final old = File(dbPath);
      if (await old.exists()) {
        await old.delete();
      }
      _sembastDb = await databaseFactoryIo.openDatabase(dbPath);
    }

    final version = await _metaStore.record('questions_version').get(_sembastDb!) as Map<String, dynamic>?;
    final currentVersion = version?['value'] as String?;
    final count = await _questionStore.count(_sembastDb!);
    final needsRepair = await _needsDesktopRepair(_sembastDb!);

    if (count == 0 || currentVersion != _dbAssetVersion || needsRepair) {
      await _questionStore.drop(_sembastDb!);
      await _importQuestionsFromJson(_sembastDb!);
      await _metaStore.record('questions_version').put(_sembastDb!, {'value': _dbAssetVersion});
    }
  }

  static Future<bool> _needsDesktopRepair(sembast.Database db) async {
    final sample = await _questionStore.findFirst(db, finder: sembast.Finder(limit: 1));
    if (sample == null) return false;
    final stem = (sample['stem_zh'] as String?) ?? '';
    return stem.contains('�') || stem.contains('һ�') || stem.contains('��');
  }

  static Future<void> _importQuestionsFromJson(sembast.Database db) async {
    final data = await rootBundle.loadString('assets/questions.json');
    final List<dynamic> list = json.decode(data);
    final records = list.map((e) => Map<String, dynamic>.from(e)).toList();
    await _questionStore.records(records.map((r) => r['id'].toString()).toList()).put(db, records);
  }

  static Future<void> _ensureSqfliteDb() async {
    if (_sqfliteDb != null) return;

    final databasesPath = await sqflite.getDatabasesPath();
    final path = p.join(databasesPath, 'data.db');

    if (!await File(path).exists()) {
      await _copyAssetDb(path);
    }

    _sqfliteDb = await sqflite.openDatabase(path);
    await _ensureRuntimeTables(_sqfliteDb!);

    final needsRepair = await _needsNativeRepair(_sqfliteDb!);
    if (needsRepair) {
      final statusRows = await _sqfliteDb!.query('user_status');
      final chatRows = await _sqfliteDb!.query('chat_history');
      await _sqfliteDb!.close();
      _sqfliteDb = null;

      if (await File(path).exists()) {
        await File(path).delete();
      }
      await _copyAssetDb(path);

      _sqfliteDb = await sqflite.openDatabase(path);
      await _ensureRuntimeTables(_sqfliteDb!);

      for (final row in statusRows) {
        await _sqfliteDb!.insert('user_status', row);
      }
      for (final row in chatRows) {
        try {
          await _sqfliteDb!.insert(
            'chat_history',
            row,
            conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
          );
        } catch (e) {
          debugPrint('chat history restore skipped: $e');
        }
      }
    }

    await _markDbVersion(_sqfliteDb!);
  }

  static Future<void> _copyAssetDb(String path) async {
    final data = await rootBundle.load('assets/data.db');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(path).writeAsBytes(bytes, flush: true);
  }

  static Future<void> _ensureRuntimeTables(sqflite.Database db) async {
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

  static Future<void> _markDbVersion(sqflite.Database db) async {
    await db.insert(
      'app_meta',
      {'key': 'db_asset_version', 'value': _dbAssetVersion},
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  static Future<bool> _needsNativeRepair(sqflite.Database db) async {
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
      'SELECT stem_zh FROM questions WHERE stem_zh IS NOT NULL LIMIT 1',
    );
    if (row.isEmpty) return false;
    final sample = (row.first['stem_zh'] as String?) ?? '';

    return sample.contains('�') || sample.contains('һ�') || sample.contains('��');
  }

  static Future<List<Map<String, dynamic>>> fetchQuestions({String? filterStatus}) async {
    await _ensureInitialized();

    if (_useDesktopSembast) {
      final db = _sembastDb!;
      final finder = sembast.Finder();
      if (filterStatus != null) {
        final statusMap = await _statusStore.find(
          db,
          finder: sembast.Finder(filter: sembast.Filter.equals('status', filterStatus)),
        );
        final ids = statusMap.map((e) => e['question_id'].toString()).toList();
        if (ids.isEmpty) return [];
        finder.filter = sembast.Filter.inList('id', ids);
      }
      final records = await _questionStore.find(db, finder: finder);
      return records.map((r) => Map<String, dynamic>.from(r.value)).toList();
    }

    final db = _sqfliteDb!;
    if (filterStatus != null) {
      return db.rawQuery(
        '''
        SELECT q.* FROM questions q
        JOIN user_status s ON s.question_id=q.id
        WHERE s.status=?
        ''',
        [filterStatus],
      );
    }
    return db.query('questions');
  }

  static Future<String?> getStatus(int questionId) async {
    await _ensureInitialized();

    if (_useDesktopSembast) {
      final db = _sembastDb!;
      final recs = await _statusStore.find(
        db,
        finder: sembast.Finder(
          filter: sembast.Filter.equals('question_id', questionId),
          sortOrders: [sembast.SortOrder('timestamp', false)],
          limit: 1,
        ),
      );
      if (recs.isNotEmpty) return recs.first.value['status'] as String?;
      return null;
    }

    final db = _sqfliteDb!;
    final res = await db.query(
      'user_status',
      columns: ['status'],
      where: 'question_id = ?',
      whereArgs: [questionId],
      orderBy: 'rowid DESC',
      limit: 1,
    );
    if (res.isNotEmpty) return res.first['status'] as String?;
    return null;
  }

  static Future<void> setStatus(int questionId, String status) async {
    await _ensureInitialized();

    if (_useDesktopSembast) {
      await _statusStore.add(_sembastDb!, {
        'question_id': questionId,
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return;
    }

    await _sqfliteDb!.insert('user_status', {
      'question_id': questionId,
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> clearStatuses() async {
    await _ensureInitialized();
    if (_useDesktopSembast) {
      await _statusStore.drop(_sembastDb!);
      return;
    }
    await _sqfliteDb!.delete('user_status');
  }

  static Future<Map<int, String>> getLatestStatuses() async {
    await _ensureInitialized();

    if (_useDesktopSembast) {
      final recs = await _statusStore.find(
        _sembastDb!,
        finder: sembast.Finder(sortOrders: [sembast.SortOrder('timestamp')]),
      );
      final map = <int, String>{};
      for (final record in recs) {
        final qid = record['question_id'];
        final status = record['status'];
        if (qid is int && status is String) {
          map[qid] = status;
        }
      }
      return map;
    }

    final rows = await _sqfliteDb!.rawQuery(
      '''
      SELECT us.question_id, us.status
      FROM user_status us
      INNER JOIN (
        SELECT question_id, MAX(rowid) AS max_rowid
        FROM user_status
        GROUP BY question_id
      ) latest ON latest.max_rowid = us.rowid
      ''',
    );

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

  static Future<Map<String, int>> countByStatus() async {
    if (_useDesktopSembast) {
      final latest = await getLatestStatuses();
      final map = <String, int>{};
      for (final st in latest.values) {
        map[st] = (map[st] ?? 0) + 1;
      }
      return map;
    }

    await _ensureInitialized();
    final rows = await _sqfliteDb!.rawQuery(
      '''
      SELECT us.status, COUNT(*) AS c
      FROM user_status us
      INNER JOIN (
        SELECT question_id, MAX(rowid) AS max_rowid
        FROM user_status
        GROUP BY question_id
      ) latest ON latest.max_rowid = us.rowid
      GROUP BY us.status
      ''',
    );
    final map = <String, int>{};
    for (final row in rows) {
      map[row['status'] as String] = row['c'] as int;
    }
    return map;
  }

  static Future<Map<String, int>> recentDontKnowTrend({int days = 7}) async {
    await _ensureInitialized();

    if (_useDesktopSembast) {
      final recs = await _statusStore.find(
        _sembastDb!,
        finder: sembast.Finder(
          filter: sembast.Filter.equals('status', 'DontKnow'),
          sortOrders: [sembast.SortOrder('timestamp', false)],
        ),
      );

      final earliest = DateTime.now().subtract(Duration(days: days - 1));
      final out = <String, int>{};
      for (final rec in recs) {
        final ts = rec['timestamp'];
        if (ts is! String) continue;
        final dt = DateTime.tryParse(ts);
        if (dt == null) continue;
        if (dt.isBefore(earliest)) continue;
        final day = dt.toIso8601String().substring(0, 10);
        out[day] = (out[day] ?? 0) + 1;
      }
      return out;
    }

    final since = DateTime.now().subtract(Duration(days: days - 1)).toIso8601String();
    final rows = await _sqfliteDb!.rawQuery(
      '''
      SELECT substr(updated_at, 1, 10) AS day, COUNT(*) AS c
      FROM user_status
      WHERE status = ? AND updated_at >= ?
      GROUP BY day
      ORDER BY day DESC
      ''',
      ['DontKnow', since],
    );

    final out = <String, int>{};
    for (final row in rows) {
      final day = row['day'];
      final count = row['c'];
      if (day is String && count is int) {
        out[day] = count;
      }
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>> topFavoriteHotspots({int limit = 5}) async {
    await _ensureInitialized();

    if (_useDesktopSembast) {
      final db = _sembastDb!;
      final recs = await _statusStore.find(
        db,
        finder: sembast.Finder(
          filter: sembast.Filter.equals('status', 'Favorite'),
          sortOrders: [sembast.SortOrder('timestamp', false)],
        ),
      );

      final counts = <int, int>{};
      final lastAt = <int, String>{};
      for (final rec in recs) {
        final qid = rec['question_id'];
        final ts = rec['timestamp'];
        if (qid is! int) continue;
        counts[qid] = (counts[qid] ?? 0) + 1;
        if (ts is String && (lastAt[qid] == null || ts.compareTo(lastAt[qid]!) > 0)) {
          lastAt[qid] = ts;
        }
      }

      final sortedIds = counts.keys.toList()
        ..sort((a, b) {
          final c = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
          if (c != 0) return c;
          return (lastAt[b] ?? '').compareTo(lastAt[a] ?? '');
        });

      final out = <Map<String, dynamic>>[];
      for (final qid in sortedIds.take(limit)) {
        final q = await _questionStore.record(qid.toString()).get(db);
        out.add({
          'question_id': qid,
          'q_num': q?['q_num']?.toString() ?? qid.toString(),
          'stem_zh': q?['stem_zh']?.toString() ?? '',
          'c': counts[qid] ?? 0,
          'last_at': lastAt[qid] ?? '',
        });
      }
      return out;
    }

    return _sqfliteDb!.rawQuery(
      '''
      SELECT us.question_id, q.q_num, q.stem_zh, COUNT(*) AS c, MAX(us.updated_at) AS last_at
      FROM user_status us
      LEFT JOIN questions q ON q.id = us.question_id
      WHERE us.status = ?
      GROUP BY us.question_id
      ORDER BY c DESC, last_at DESC
      LIMIT ?
      ''',
      ['Favorite', limit],
    );
  }

  static Future<String?> getChatHistory(int questionId) async {
    await _ensureInitialized();

    if (_useDesktopSembast) {
      final rec = await _chatStore.record(questionId).get(_sembastDb!);
      if (rec == null) return null;
      final content = rec['content'];
      return content is String ? content : null;
    }

    final res = await _sqfliteDb!.query(
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
    await _ensureInitialized();

    if (_useDesktopSembast) {
      final recs = await _chatStore.find(_sembastDb!);
      final map = <int, String>{};
      for (final record in recs) {
        final qid = record.key;
        final content = record.value['content'];
        if (content is String && content.trim().isNotEmpty) {
          map[qid] = content;
        }
      }
      return map;
    }

    final rows = await _sqfliteDb!.query('chat_history');
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
    await _ensureInitialized();

    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      await clearChatHistory(questionId);
      return;
    }

    if (_useDesktopSembast) {
      await _chatStore.record(questionId).put(_sembastDb!, {
        'content': content,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return;
    }

    await _sqfliteDb!.insert(
      'chat_history',
      {
        'question_id': questionId,
        'content': content,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  static Future<void> clearChatHistory(int questionId) async {
    await _ensureInitialized();

    if (_useDesktopSembast) {
      await _chatStore.record(questionId).delete(_sembastDb!);
      return;
    }

    await _sqfliteDb!.delete('chat_history', where: 'question_id = ?', whereArgs: [questionId]);
  }

  static Future<void> clearAllChatHistories() async {
    await _ensureInitialized();

    if (_useDesktopSembast) {
      await _chatStore.drop(_sembastDb!);
      return;
    }

    await _sqfliteDb!.delete('chat_history');
  }

  static Future<void> importChatHistories(
    Map<int, String> histories, {
    bool clearExisting = false,
  }) async {
    await _ensureInitialized();

    if (_useDesktopSembast) {
      final db = _sembastDb!;
      if (clearExisting) {
        await _chatStore.drop(db);
      }
      for (final entry in histories.entries) {
        final content = entry.value.trim();
        if (content.isEmpty) continue;
        await _chatStore.record(entry.key).put(db, {
          'content': entry.value,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      return;
    }

    final db = _sqfliteDb!;
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
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
      }
    });
  }
}
