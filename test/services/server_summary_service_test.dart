import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/services/server_summary_service.dart';

/// 多服务器总览的单台汇总计算（纯逻辑）。
void main() {
  Node node({
    String id = '1',
    bool online = true,
    List<String> approved = const [],
    List<String> available = const [],
    List<String> ipAddresses = const ['100.64.0.1'],
    DateTime? expiry,
  }) =>
      Node(
        id: id,
        machineKey: 'mk$id',
        hostname: 'n$id',
        name: 'n$id',
        user: 'u',
        userId: '1',
        ipAddresses: ipAddresses,
        online: online,
        lastSeen: DateTime.now(),
        sharedRoutes: approved,
        availableRoutes: available,
        isExitNode: false,
        isLanSharer: false,
        tags: const [],
        baseDomain: 'example.com',
        endpoint: '',
        expiry: expiry,
      );

  test('统计节点总数与在线数', () {
    final s = ServerNodeSummary.of([
      node(id: '1', online: true),
      node(id: '2', online: false),
    ]);
    expect(s.total, 2);
    expect(s.online, 1);
  });

  test('密钥已过期与临期分别计数（互斥）', () {
    final s = ServerNodeSummary.of([
      node(id: '1', expiry: DateTime.now().subtract(const Duration(days: 1))),
      node(id: '2', expiry: DateTime.now().add(const Duration(days: 5))),
      node(id: '3', expiry: DateTime.now().add(const Duration(days: 300))),
    ]);
    expect(s.expiredKeys, 1);
    expect(s.expiringSoon, 1);
  });

  test('待批准路由与无 IP 的节点会被计入问题数', () {
    final s = ServerNodeSummary.of([
      node(id: '1', approved: const ['10.0.0.0/8'], available: const ['10.0.0.0/8', '192.168.1.0/24']),
      node(id: '2', ipAddresses: const []),
      node(id: '3'),
    ]);
    expect(s.pendingRoutes, 1);
    expect(s.withoutIp, 1);
    expect(s.issueCount, 2);
    expect(s.hasIssues, isTrue);
  });

  test('一切正常时没有问题', () {
    final s = ServerNodeSummary.of([node(id: '1')]);
    expect(s.hasIssues, isFalse);
    expect(s.issueCount, 0);
  });

  test('空服务器（零节点）不报问题', () {
    final s = ServerNodeSummary.of(const []);
    expect(s.total, 0);
    expect(s.hasIssues, isFalse);
  });
}
