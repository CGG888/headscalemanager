import 'package:headscalemanager/models/node.dart';

/// 规则化告警引擎（纯逻辑，可离线测试）。
///
/// 设计要点：**按"档位"去重**，而不是按天重复通知。
/// 节点密钥默认 180 天到期，过期后节点直接掉线，所以值得提醒；但每天推一条
/// 只会让人关掉通知。这里的做法是：只在跨过某个阈值（30/7/3/1 天、已过期）时
/// 各提醒一次，用 [Alert.dedupeKey] 记录已提醒过的档位。
enum AlertRule {
  /// 密钥已过期（节点已无法连接）。
  keyExpired,

  /// 密钥在阈值内即将到期。
  keyExpiringSoon,
}

class Alert {
  const Alert({
    required this.rule,
    required this.dedupeKey,
    required this.nodeId,
    required this.nodeName,
    this.days,
  });

  final AlertRule rule;

  /// 已提醒过的档位标识：同一节点同一档位只提醒一次。
  final String dedupeKey;
  final String nodeId;
  final String nodeName;

  /// 剩余天数（已过期为负）。
  final int? days;

  @override
  String toString() => '${rule.name}:$nodeName'
      '${days == null ? '' : ' ($days j)'}';
}

class AlertRulesService {
  const AlertRulesService._();

  /// 即将到期的提醒档位（天）。跨过某一档就提醒一次。
  static const List<int> thresholds = [30, 7, 3, 1];

  /// 计算密钥相关的告警。
  ///
  /// [alreadyNotified] 是历史上已经提醒过的 [Alert.dedupeKey] 集合。
  static List<Alert> keyAlerts(
    Iterable<Node> nodes, {
    Set<String> alreadyNotified = const {},
    List<int> alertThresholds = thresholds,
  }) {
    final alerts = <Alert>[];

    for (final node in nodes) {
      final days = node.daysUntilExpiry;
      if (days == null) continue; // 永不过期

      final String bucket;
      if (days < 0) {
        bucket = 'expired';
      } else {
        final matched = alertThresholds.where((t) => days <= t).toList();
        if (matched.isEmpty) continue; // 还早，不打扰
        bucket = 'd${matched.last}'; // 取最紧的一档
      }

      final key = 'keyExpiry:${node.id}:$bucket';
      if (alreadyNotified.contains(key)) continue;

      alerts.add(Alert(
        rule: days < 0 ? AlertRule.keyExpired : AlertRule.keyExpiringSoon,
        dedupeKey: key,
        nodeId: node.id,
        nodeName: node.name,
        days: days,
      ));
    }

    alerts.sort((a, b) => (a.days ?? 0).compareTo(b.days ?? 0));
    return alerts;
  }

  /// 从一批告警中抽取需要加入"已提醒"集合的键（供调用方持久化）。
  static List<String> dedupeKeys(Iterable<Alert> alerts) =>
      alerts.map((a) => a.dedupeKey).toList();
}
