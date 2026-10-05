import 'package:headscalemanager/models/node.dart';

/// 单台 Headscale 的节点概览（纯计算，便于测试）。
///
/// 用于「多服务器总览」：一次性回答"哪个服务器有异常"，
/// 而不是逐个切换服务器去看。
class ServerNodeSummary {
  const ServerNodeSummary({
    required this.total,
    required this.online,
    required this.expiredKeys,
    required this.expiringSoon,
    required this.pendingRoutes,
    required this.withoutIp,
  });

  final int total;
  final int online;
  final int expiredKeys;
  final int expiringSoon;
  final int pendingRoutes;
  final int withoutIp;

  /// 需要处理的问题总数（用于排序与徽标）。
  int get issueCount =>
      expiredKeys + expiringSoon + pendingRoutes + withoutIp;

  bool get hasIssues => issueCount > 0;

  static ServerNodeSummary of(Iterable<Node> nodes) {
    var total = 0, online = 0, expired = 0, soon = 0, pending = 0, noIp = 0;
    for (final node in nodes) {
      total++;
      if (node.online) online++;
      if (node.isExpired) {
        expired++;
      } else if (node.isExpirySoon) {
        soon++;
      }
      if (node.availableRoutes.any((r) => !node.sharedRoutes.contains(r))) {
        pending++;
      }
      if (node.ipAddresses.isEmpty) noIp++;
    }
    return ServerNodeSummary(
      total: total,
      online: online,
      expiredKeys: expired,
      expiringSoon: soon,
      pendingRoutes: pending,
      withoutIp: noIp,
    );
  }
}
