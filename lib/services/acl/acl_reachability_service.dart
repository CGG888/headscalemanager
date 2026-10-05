import 'dart:convert';

/// ACL 策略的**可达性分析**与**风险审计**。
///
/// 目标：策略一多就没人看得懂"到底谁能访问谁"。这里把策略折算成
/// 「源 → 目标（端口）」的可达关系，并标出高风险规则。
///
/// 完全离线计算（只依赖策略文本），因此可单元测试、无需服务端。
/// 支持两种策略形态：
///  * 经典 `acls`: `{action, src[], dst[]}`，dst 形如 `tag:x:22` / `*:*` / `10.0.0.0/8:*`
///  * v0.29 `grants`: `{src[], dst[], ip[]}`（`ip` 为 CIDR 列表）
enum AclRiskCode {
  /// `src: ["*"]` 且 `dst: ["*:*"]` —— 完全放开。
  allowAll,

  /// 目标包含 `autogroup:internet`，且源过于宽泛。
  internetOpenToAll,

  /// SSH（22 端口）对所有人开放。
  sshOpenToAll,

  /// 允许访问任意出口节点（`0.0.0.0/0` 或 `::/0`）。
  exitNodeOpen,

  /// 出现通配目标（`*`），但未到"完全放开"的程度。
  wildcardDestination,

  /// 策略里既没有 acls 也没有 grants。
  noRules,
}

enum AclRiskSeverity { critical, warning, info }

class AclRisk {
  const AclRisk(this.code, this.severity, {this.detail});

  final AclRiskCode code;
  final AclRiskSeverity severity;

  /// 具体值：源、目标、规则序号等。
  final String? detail;

  @override
  String toString() => '${severity.name}/${code.name}${detail == null ? '' : ' ($detail)'}';
}

/// 一条可达关系：某个源可以访问某个目标。同一对源/目标会合并端口。
class ReachabilityEdge {
  const ReachabilityEdge({
    required this.source,
    required this.destination,
    required this.ports,
  });

  final String source;
  final String destination;

  /// 端口列表；`*` 表示全部端口。
  final List<String> ports;

  /// 是否"任意源"或"任意目标"。
  bool get isBroad => source == '*' || destination == '*';

  @override
  String toString() => '$source → $destination:${ports.join(',')}';
}

class AclReachability {
  const AclReachability({required this.edges, required this.risks});

  /// 按"源"分组排序后的可达关系。
  final List<ReachabilityEdge> edges;
  final List<AclRisk> risks;

  bool get hasRisks => risks.isNotEmpty;

  /// 参与策略的源数量（用于概览显示）。
  int get sourceCount => edges.map((e) => e.source).toSet().length;
}

class AclReachabilityService {
  const AclReachabilityService._();

  static AclReachability analyze(String policyJson) {
    final decoded = _decode(policyJson);
    if (decoded == null) {
      return const AclReachability(edges: [], risks: []);
    }

    final merged = <String, Set<String>>{}; // "src\u0000dst" -> ports
    final risks = <AclRisk>[];

    final acls = decoded['acls'];
    if (acls is List) {
      for (var i = 0; i < acls.length; i++) {
        final rule = acls[i];
        if (rule is! Map) continue;
        final action = rule['action']?.toString() ?? 'accept';
        if (action != 'accept') continue; // drop/reject 不构成可达
        final srcs = _stringList(rule['src']);
        final dsts = _stringList(rule['dst']);
        if (srcs.contains('*') && dsts.any(_isEverything)) {
          risks.add(AclRisk(AclRiskCode.allowAll, AclRiskSeverity.critical,
              detail: 'acls[$i]'));
        }
        _collectRisks(risks, srcs, dsts, 'acls[$i]');
        for (final src in srcs) {
          for (final dst in dsts) {
            _merge(merged, src, _host(dst), _port(dst));
          }
        }
      }
    }

    final grants = decoded['grants'];
    if (grants is List) {
      for (var i = 0; i < grants.length; i++) {
        final grant = grants[i];
        if (grant is! Map) continue;
        final srcs = _stringList(grant['src']);
        final dsts = _stringList(grant['dst']);
        final ips = _stringList(grant['ip']);
        if (srcs.contains('*') && (dsts.contains('*') || ips.contains('*'))) {
          risks.add(AclRisk(AclRiskCode.allowAll, AclRiskSeverity.critical,
              detail: 'grants[$i]'));
        }
        _collectRisks(risks, srcs, [...dsts, ...ips], 'grants[$i]');
        for (final src in srcs) {
          for (final dst in dsts) {
            _merge(merged, src, dst, '*');
          }
          for (final ip in ips) {
            _merge(merged, src, ip, '*');
          }
        }
      }
    }

    if (acls is! List && grants is! List) {
      risks.add(const AclRisk(AclRiskCode.noRules, AclRiskSeverity.info));
    }

    final edges = merged.entries.map((entry) {
      final parts = entry.key.split('\u0000');
      final ports = entry.value.toList()..sort();
      return ReachabilityEdge(
        source: parts[0],
        destination: parts.length > 1 ? parts[1] : '',
        ports: ports,
      );
    }).toList()
      ..sort((a, b) {
        final bySrc = a.source.compareTo(b.source);
        return bySrc != 0 ? bySrc : a.destination.compareTo(b.destination);
      });

    return AclReachability(edges: edges, risks: risks);
  }

  /// 与 `src` / `dst` 相关的风险（跨规则的检查在这里集中）。
  static void _collectRisks(
      List<AclRisk> risks, List<String> srcs, List<String> dsts, String where) {
    final srcIsEveryone = srcs.contains('*');

    for (final dst in dsts) {
      if (dst.startsWith('autogroup:internet') && srcIsEveryone) {
        risks.add(AclRisk(AclRiskCode.internetOpenToAll, AclRiskSeverity.warning,
            detail: where));
      }
      if (_port(dst) == '22' && srcIsEveryone) {
        risks.add(AclRisk(AclRiskCode.sshOpenToAll, AclRiskSeverity.warning,
            detail: where));
      }
      if (dst == '0.0.0.0/0' || dst == '::/0' || dst == '0.0.0.0/0:*') {
        risks.add(AclRisk(AclRiskCode.exitNodeOpen, AclRiskSeverity.warning,
            detail: where));
      }
      if (dst == '*' && !_isEverything(dst)) {
        risks.add(AclRisk(AclRiskCode.wildcardDestination, AclRiskSeverity.info,
            detail: where));
      }
    }
  }

  static bool _isEverything(String dst) => dst == '*:*' || dst == '*';

  static void _merge(
      Map<String, Set<String>> merged, String src, String dst, String port) {
    merged.putIfAbsent('$src\u0000$dst', () => <String>{}).add(port);
  }

  /// `tag:home:22` → `tag:home`；`*:*` → `*`。
  static String _host(String dst) {
    final index = dst.lastIndexOf(':');
    if (index <= 0) return dst;
    // 形如 `2001:db8::1:22` 的 IPv6 目标不在此处处理（策略里极少出现）
    return dst.substring(0, index);
  }

  /// 取出端口；没有端口时按 `*` 处理。
  static String _port(String dst) {
    final index = dst.lastIndexOf(':');
    if (index <= 0 || index == dst.length - 1) return '*';
    return dst.substring(index + 1);
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const [];
  }

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
