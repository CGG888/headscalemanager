import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/services/audit_log_service.dart';

/// 本地操作审计：序列化要稳（历史记录不能因一条损坏而整体失效），
/// 且必须有保留上限（本地存储不适合无限增长）。
void main() {
  group('AuditEntry', () {
    test('JSON 往返保留全部字段', () {
      final entry = AuditEntry(
        timestamp: DateTime(2026, 3, 4, 5, 6),
        action: 'batchDeleteNodes',
        target: 'phone, laptop',
        detail: '2 réussis, 0 échoués',
        success: false,
      );
      final restored = AuditEntry.fromJson(jsonEncode(entry.toJson()))!;
      expect(restored.action, 'batchDeleteNodes');
      expect(restored.target, 'phone, laptop');
      expect(restored.detail, '2 réussis, 0 échoués');
      expect(restored.success, isFalse);
      // 时间以 UTC 存储、读回本地时间，因此比较到秒
      expect(
        restored.timestamp.difference(entry.timestamp).inSeconds.abs() < 2,
        isTrue,
      );
    });

    test('损坏或非字符串条目返回 null，而不是抛异常', () {
      expect(AuditEntry.fromJson('{ not json'), isNull);
      expect(AuditEntry.fromJson(42), isNull);
      expect(AuditEntry.fromJson(null), isNull);
      expect(AuditEntry.fromJson('[1,2,3]'), isNull);
    });

    test('缺少可选字段也能解析（旧记录向前兼容）', () {
      final json = jsonEncode({
        't': DateTime(2026, 1, 1).toUtc().toIso8601String(),
        'a': 'createPreAuthKey',
        'g': 'alice',
      });
      final entry = AuditEntry.fromJson(json)!;
      expect(entry.detail, isNull);
      expect(entry.success, isTrue); // 缺省视为成功
    });
  });

  group('保留上限', () {
    test('未超限时原样返回', () {
      final list = List.generate(10, (i) => '$i');
      expect(AuditLogService.trim(list), list);
    });

    test('超限时保留最新的 maxEntries 条', () {
      final list = List.generate(AuditLogService.maxEntries + 25, (i) => 'e$i');
      final trimmed = AuditLogService.trim(list);
      expect(trimmed, hasLength(AuditLogService.maxEntries));
      expect(trimmed.first, 'e0'); // 索引 0 是最新的一条
      expect(trimmed.contains('e${AuditLogService.maxEntries}'), isFalse);
    });
  });
}
