import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 策略变更的三种情况。
enum PolicyChangeKind { added, removed, changed }

class PolicyChange {
  const PolicyChange(this.kind, this.path, this.detail);

  final PolicyChangeKind kind;

  /// 位置：`acls[]`、`groups.devops`、`tagOwners.server` 等。
  final String path;

  /// 具体内容（规则原文或"旧值 → 新值"）。
  final String detail;

  @override
  String toString() => '${kind.name} $path: $detail';
}

class PolicySnapshot {
  const PolicySnapshot(this.json, this.savedAt);

  final String json;
  final DateTime savedAt;
}

/// 策略快照与差异。
///
/// 用途：**保存前看清"相对上一次基线改了什么"**。ACL 策略是纯文本、动辄几十行，
/// 手工比对极易误删规则；这里把两份策略折算成"新增/删除/修改"的清单。
///
/// 快照存在本地（Headscale 只保留当前策略，没有历史），因此基线的语义是
/// "我上次在这里点过『设为基线』的那一刻"，界面会明说这一点。
class PolicyDiffService {
  const PolicyDiffService._();

  static const String snapshotKey = 'policySnapshot';
  static const String snapshotAtKey = 'policySnapshotAt';

  /// 计算两份策略的差异（纯函数）。
  ///
  /// 比较粒度：
  ///  * 列表（`acls`/`grants`/`ssh`…）：逐条按规范化 JSON 比对，报告新增/删除；
  ///  * 映射（`groups`/`tagOwners`/`autoApprovers`/`hosts`…）：逐键比对，
  ///    报告新增键、删除键与值变化。
  static List<PolicyChange> diff(String beforeJson, String afterJson) {
    final before = _decode(beforeJson);
    final after = _decode(afterJson);
    if (before == null || after == null) return const [];

    final changes = <PolicyChange>[];
    final keys = <String>{...before.keys, ...after.keys};

    for (final key in keys) {
      final a = before[key];
      final b = after[key];

      if (a is List || b is List) {
        final listA = (a as List? ?? const []).map(_canonical).toList();
        final listB = (b as List? ?? const []).map(_canonical).toList();
        for (final item in listA.where((e) => !listB.contains(e))) {
          changes.add(PolicyChange(
              PolicyChangeKind.removed, '$key[]', _pretty(item)));
        }
        for (final item in listB.where((e) => !listA.contains(e))) {
          changes.add(
              PolicyChange(PolicyChangeKind.added, '$key[]', _pretty(item)));
        }
      } else if (a is Map && b is Map) {
        for (final sub in <String>{...a.keys.map((e) => '$e'), ...b.keys.map((e) => '$e')}) {
          final x = a[sub];
          final y = b[sub];
          if (_canonical(x) == _canonical(y)) continue;
          changes.add(PolicyChange(
            x == null
                ? PolicyChangeKind.added
                : y == null
                    ? PolicyChangeKind.removed
                    : PolicyChangeKind.changed,
            '$key.$sub',
            x == null
                ? _pretty(_canonical(y))
                : y == null
                    ? _pretty(_canonical(x))
                    : '${_pretty(_canonical(x))} → ${_pretty(_canonical(y))}',
          ));
        }
      } else if (_canonical(a) != _canonical(b)) {
        changes.add(PolicyChange(
          a == null
              ? PolicyChangeKind.added
              : b == null
                  ? PolicyChangeKind.removed
                  : PolicyChangeKind.changed,
          key,
          '${a ?? '-'} → ${b ?? '-'}',
        ));
      }
    }
    return changes;
  }

  static Future<PolicySnapshot?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(snapshotKey);
      if (json == null) return null;
      final at = DateTime.tryParse(prefs.getString(snapshotAtKey) ?? '');
      return PolicySnapshot(json, at ?? DateTime.now());
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String policyJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(snapshotKey, policyJson);
    await prefs.setString(snapshotAtKey, DateTime.now().toIso8601String());
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(snapshotKey);
    await prefs.remove(snapshotAtKey);
  }

  /// 规范化：键排序后重新编码，避免键顺序差异被当成变更。
  static String _canonical(Object? value) {
    if (value is Map) {
      final sorted = <String, Object?>{};
      for (final key in value.keys.map((e) => '$e').toList()..sort()) {
        sorted[key] = value[key];
      }
      return json.encode(sorted);
    }
    return json.encode(value);
  }

  /// 规则原文过长时截断，保证列表可读。
  static String _pretty(String raw) =>
      raw.length <= 160 ? raw : '${raw.substring(0, 157)}...';

  static Map<String, dynamic>? _decode(String json_) {
    if (json_.trim().isEmpty) return null;
    try {
      final decoded = json.decode(json_);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
