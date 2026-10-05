import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 本地操作审计。
///
/// 背景：Headscale **没有审计 API**，服务端不记录"谁在何时改了什么"。
/// 因此这里由 App 在**执行破坏性操作时**本地留痕：删节点、过期密钥、
/// 改策略、建预认证密钥、改路由。目的不是合规，而是**可回溯**——
/// "昨天那台机器是谁删的、什么时候"这类问题有答案。
class AuditEntry {
  const AuditEntry({
    required this.timestamp,
    required this.action,
    required this.target,
    this.detail,
    this.success = true,
  });

  final DateTime timestamp;

  /// 动作标识（如 `deleteNode`、`setAclPolicy`）。
  final String action;

  /// 作用对象（节点名/用户/策略）。
  final String target;

  final String? detail;
  final bool success;

  Map<String, dynamic> toJson() => {
        't': timestamp.toUtc().toIso8601String(),
        'a': action,
        'g': target,
        if (detail != null) 'd': detail,
        'ok': success,
      };

  static AuditEntry? fromJson(Object? value) {
    if (value is! String) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map) return null;
      return AuditEntry(
        timestamp:
            DateTime.tryParse('${json['t']}')?.toLocal() ?? DateTime.now(),
        action: '${json['a'] ?? ''}',
        target: '${json['g'] ?? ''}',
        detail: json['d'] == null ? null : '${json['d']}',
        success: json['ok'] as bool? ?? true,
      );
    } catch (_) {
      return null; // 单条损坏不影响其余记录
    }
  }
}

class AuditLogService {
  const AuditLogService._();

  static const String storageKey = 'auditLog';

  /// 保留上限：超出后丢弃**最旧**的记录（App 本地存储不适合无限增长）。
  static const int maxEntries = 200;

  /// 记录一条操作。**失败不应影响主流程**，因此异常被吞掉。
  static Future<void> record(
    String action,
    String target, {
    String? detail,
    bool success = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(storageKey) ?? <String>[];
      list.insert(
        0,
        jsonEncode(AuditEntry(
          timestamp: DateTime.now(),
          action: action,
          target: target,
          detail: detail,
          success: success,
        ).toJson()),
      );
      await prefs.setStringList(storageKey, trim(list));
    } catch (_) {
      // 审计写入失败不能阻断用户正在做的操作
    }
  }

  /// 读取记录（最新在前）。
  static Future<List<AuditEntry>> entries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(storageKey) ?? <String>[];
      return list.map(AuditEntry.fromJson).whereType<AuditEntry>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }

  /// 只保留最新的 [maxEntries] 条（纯函数，便于测试）。
  static List<String> trim(List<String> list) =>
      list.length <= maxEntries ? list : list.sublist(0, maxEntries);
}
