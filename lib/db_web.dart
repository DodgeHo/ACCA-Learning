import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sembast_web/sembast_web.dart';

// simple web database using sembast; questions are loaded from a JSON asset
class AppDatabase {
  static Database? _db;
  static const String _dbAssetVersion = '2026-03-26-multibank-v3';
  static final _questionStore = stringMapStoreFactory.store('questions');
  static final _statusStore = intMapStoreFactory.store('user_status');
  static final _chatStore = intMapStoreFactory.store('chat_history');
  static final _metaStore = stringMapStoreFactory.store('meta');

  static Future<Database> getInstance() async {
    if (_db != null) return _db!;

    // open sembast database; on web it uses IndexedDB automatically
    _db = await databaseFactoryWeb.openDatabase('aws_saa_trainer.db');

    final version = await _metaStore.record('questions_version').get(_db!) as Map<String, dynamic>?;
    final currentVersion = version?['value'] as String?;

    final count = await _questionStore.count(_db!);
    final needsRepair = await _needsWebRepair();
    if (count == 0 || currentVersion != _dbAssetVersion || needsRepair) {
      await _questionStore.drop(_db!);
      await _importQuestionsFromJson();
      await _metaStore.record('questions_version').put(_db!, {'value': _dbAssetVersion});
    }
    return _db!;
  }

  static Future<bool> _needsWebRepair() async {
    final sample = await _questionStore.findFirst(_db!, finder: Finder(limit: 1));
    if (sample == null) return false;
    final stem = (sample['stem_zh'] as String?) ?? '';
    return stem.contains('�') || stem.contains('һ�') || stem.contains('��');
  }

  static Future<void> _importQuestionsFromJson() async {
    final data = await rootBundle.loadString('assets/questions.json');
    final List<dynamic> list = json.decode(data);
    final records = list.map((e) => Map<String, dynamic>.from(e)).toList();
    await _questionStore.records(records.map((r) => r['id'].toString()).toList()).put(_db!, records);
  }

  static Future<List<Map<String, dynamic>>> fetchQuestions({String? filterStatus}) async {
    final db = await getInstance();
    final finder = Finder();
    if (filterStatus != null) {
      // join by status; perform separate query
      final statusMap = await _statusStore.find(db, finder: Finder(filter: Filter.equals('status', filterStatus)));
      final ids = statusMap.map((e) => e['question_id'].toString()).toList();
      if (ids.isEmpty) return [];
      finder.filter = Filter.inList('id', ids);
    }
    final records = await _questionStore.find(db, finder: finder);
    return records.map((r) => Map<String, dynamic>.from(r.value)).toList();
  }

  static Future<String?> getStatus(int questionId) async {
    final db = await getInstance();
    final recs = await _statusStore.find(db, finder: Finder(filter: Filter.equals('question_id', questionId), sortOrders: [SortOrder('timestamp', false)], limit: 1));
    if (recs.isNotEmpty) return recs.first.value['status'] as String;
    return null;
  }

  static Future<void> setStatus(int questionId, String status) async {
    final db = await getInstance();
    await _statusStore.add(db, {'question_id': questionId, 'status': status, 'timestamp': DateTime.now().toIso8601String()});
  }

  static Future<void> clearStatuses() async {
    final db = await getInstance();
    await _statusStore.drop(db);
  }

  static Future<Map<int, String>> getLatestStatuses() async {
    final db = await getInstance();
    final recs = await _statusStore.find(
      db,
      finder: Finder(sortOrders: [SortOrder('timestamp')]),
    );
    final map = <int, String>{};
    for (final record in recs) {
      final value = record.value;
      final qid = value['question_id'];
      final status = value['status'];
      if (qid is int && status is String) {
        map[qid] = status;
      }
    }
    return map;
  }

  /// status counts
  static Future<Map<String,int>> countByStatus() async {
    final latest = await getLatestStatuses();
    final Map<String,int> m = {};
    for (final st in latest.values) {
      m[st] = (m[st] ?? 0) + 1;
    }
    return m;
  }

  static Future<Map<String, int>> recentDontKnowTrend({int days = 7}) async {
    final db = await getInstance();
    final recs = await _statusStore.find(
      db,
      finder: Finder(
        filter: Filter.equals('status', 'DontKnow'),
        sortOrders: [SortOrder('timestamp', false)],
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

  static Future<List<Map<String, dynamic>>> topFavoriteHotspots({int limit = 5}) async {
    final db = await getInstance();
    final recs = await _statusStore.find(
      db,
      finder: Finder(
        filter: Filter.equals('status', 'Favorite'),
        sortOrders: [SortOrder('timestamp', false)],
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

    final topIds = sortedIds.take(limit);
    final out = <Map<String, dynamic>>[];
    for (final qid in topIds) {
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

  static Future<String?> getChatHistory(int questionId) async {
    final db = await getInstance();
    final rec = await _chatStore.record(questionId).get(db);
    if (rec == null) return null;
    final content = rec['content'];
    return content is String ? content : null;
  }

  static Future<Map<int, String>> getAllChatHistories() async {
    final db = await getInstance();
    final recs = await _chatStore.find(db);
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

  static Future<void> setChatHistory(int questionId, String content) async {
    final db = await getInstance();
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      await clearChatHistory(questionId);
      return;
    }
    await _chatStore.record(questionId).put(db, {
      'content': content,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> clearChatHistory(int questionId) async {
    final db = await getInstance();
    await _chatStore.record(questionId).delete(db);
  }

  static Future<void> clearAllChatHistories() async {
    final db = await getInstance();
    await _chatStore.drop(db);
  }

  static Future<void> importChatHistories(
    Map<int, String> histories, {
    bool clearExisting = false,
  }) async {
    final db = await getInstance();
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
  }
}
