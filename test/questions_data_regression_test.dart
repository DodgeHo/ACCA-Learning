import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('question mapping stays stable for 270/276 and garbled text is fixed', () {
    final file = File('assets/questions.json');
    expect(file.existsSync(), isTrue);

    final raw = file.readAsStringSync();
    final rows = jsonDecode(raw) as List<dynamic>;

    final q270 = rows.cast<Map<String, dynamic>>().firstWhere((q) => q['q_num'] == '270');
    final q276 = rows.cast<Map<String, dynamic>>().firstWhere((q) => q['q_num'] == '276');

    expect(q270['id'], 1290);
    expect(q276['id'], 1296);

    final stem270 = (q270['stem_zh'] as String?) ?? '';
    final stem276 = (q276['stem_zh'] as String?) ?? '';
    final opts270 = (q270['options_zh'] as String?) ?? '';
    final opts276 = (q276['options_zh'] as String?) ?? '';

    expect(stem270, isNot(contains('卷网关存储卷D.')));
    expect(stem276, isNot(contains('AuroraMySQL')));
    expect(stem276, isNot(contains('MySQLRDS')));

    expect(opts270, isNot(contains('�')));
    expect(opts276, isNot(contains('�')));
    expect(opts270, contains('D. AWS 存储网关卷网关缓存卷'));
    expect(opts276, contains('B. Amazon Aurora MySQL 无服务器版'));
  });
}
