import 'dart:convert';

/// ACL 策略的**本地**预检与自动修复。
///
/// 与服务端 `/api/v1/policy/check` 的分工：
///  * **服务端检查是权威的**——它能发现所有解析错误（包括 Headscale 版本差异），
///    但需要一次往返，而且只回一句错误文本；
///  * **本地检查是离线可提示、可自动修的**——覆盖我们已知的高频坑，
///    最重要的是 **`groups` 成员必须是含 `@` 的用户引用**：
///    Headscale 里 `alice@` 表示「alice 名下的设备」，写成 `alice` 会被服务端拒绝
///    （`username must contain @,got:"alice"`）。这个报错只在保存时出现，
///    本地预检可以把"保存失败"提前成"保存前提示 + 一键修复"。
///
/// 只返回**问题代码**（不返回本地化文案），由 UI 用 `L10n` 渲染，逻辑与文案解耦。
enum AclIssueCode {
  /// 不是合法 JSON（可能是 huJSON 注释、或语法错误）。
  notJson,

  /// 组员不是合法用户引用（缺少 `@`）。
  groupMemberNeedsAt,

  /// 组名缺少 `group:` 前缀。
  invalidGroupName,
}

class AclIssue {
  const AclIssue(this.code, this.path, this.value);

  final AclIssueCode code;

  /// 出问题的位置，例如 `groups."group:lcmyhome"[0]`。
  final String path;

  /// 出问题的原始值，例如 `lcmyhome`。
  final String value;

  @override
  String toString() => '${code.name} @ $path = "$value"';
}

class AclPolicyCheck {
  const AclPolicyCheck._();

  /// 本地可离线发现的问题（不联网）。空列表表示本地没看出问题——
  /// 但仍应交给服务端 `policy/check` 做权威校验。
  static List<AclIssue> localIssues(String policyJson) {
    final decoded = _decode(policyJson);
    if (decoded == null) {
      return const [AclIssue(AclIssueCode.notJson, '', '')];
    }

    final issues = <AclIssue>[];
    final groups = decoded['groups'];
    if (groups is Map) {
      for (final entry in groups.entries) {
        final name = entry.key.toString();
        if (!name.startsWith('group:')) {
          issues.add(AclIssue(AclIssueCode.invalidGroupName, 'groups."$name"', name));
        }
        final members = entry.value;
        if (members is List) {
          for (var i = 0; i < members.length; i++) {
            final member = members[i];
            if (member is! String) continue;
            if (!member.contains('@')) {
              issues.add(AclIssue(
                AclIssueCode.groupMemberNeedsAt,
                'groups."$name"[$i]',
                member,
              ));
            }
          }
        }
      }
    }
    return issues;
  }

  /// 自动修复：给缺少 `@` 的组员补上 `@`（`alice` → `alice@`），已经含 `@`
  /// 的名字（如 OIDC 邮箱）保持原样。
  ///
  /// 返回修复后的 JSON 字符串；**没有任何改动时返回 null**（调用方据此判断
  /// 是否有可修复项）。注意：会用 `jsonEncode` 重新序列化，因此格式会被规范化、
  /// huJSON 注释会丢失——UI 需要提示这一点。
  static String? autoFix(String policyJson) {
    final decoded = _decode(policyJson);
    if (decoded == null) return null;

    var changed = false;
    final groups = decoded['groups'];
    if (groups is Map) {
      for (final entry in groups.entries) {
        final members = entry.value;
        if (members is! List) continue;
        for (var i = 0; i < members.length; i++) {
          final member = members[i];
          if (member is String && !member.contains('@')) {
            members[i] = '$member@';
            changed = true;
          }
        }
      }
    }
    if (!changed) return null;
    return jsonEncode(decoded);
  }

  /// 解析策略；失败返回 null（调用方按"不是合法 JSON"处理）。
  static Map<String, dynamic>? _decode(String policyJson) {
    if (policyJson.trim().isEmpty) return null;
    try {
      final decoded = json.decode(policyJson);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
