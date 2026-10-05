import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/services/derp_service.dart';
import 'package:headscalemanager/services/network_health_service.dart';

/// 网络体检的聚合逻辑（纯函数，不联网）。
///
/// 输入只有 App 已经能拿到的三样东西：节点列表、ACL 策略、DERP 探测结果。
void main() {
  Node node({
    String id = '1',
    String name = 'n1',
    bool online = true,
    DateTime? lastSeen,
    List<String> ipAddresses = const ['100.64.0.1'],
    List<String> approved = const [],
    List<String> available = const [],
    List<String> tags = const [],
    DateTime? expiry,
  }) =>
      Node(
        id: id,
        machineKey: 'mk',
        hostname: name,
        name: name,
        user: 'u',
        userId: '1',
        ipAddresses: ipAddresses,
        online: online,
        lastSeen: lastSeen ?? DateTime.now(),
        sharedRoutes: approved,
        availableRoutes: available,
        isExitNode: false,
        isLanSharer: false,
        tags: tags,
        baseDomain: 'example.com',
        endpoint: '',
        expiry: expiry,
      );

  List<HealthCode> codes(List<HealthFinding> f) =>
      f.map((e) => e.code).toList();

  group('密钥与在线状态', () {
    test('密钥已过期是 critical', () {
      final f = NetworkHealthService.analyze(nodes: [
        node(expiry: DateTime.now().subtract(const Duration(days: 2))),
      ]);
      expect(codes(f), contains(HealthCode.nodeKeyExpired));
      expect(f.first.severity, HealthSeverity.critical);
    });

    test('密钥 30 天内到期是 warning，且带剩余天数', () {
      final f = NetworkHealthService.analyze(nodes: [
        node(expiry: DateTime.now().add(const Duration(days: 10))),
      ]);
      final finding =
          f.firstWhere((e) => e.code == HealthCode.nodeKeyExpiringSoon);
      expect(finding.severity, HealthSeverity.warning);
      expect(int.parse(finding.detail!), inInclusiveRange(9, 11));
    });

    test('长期离线聚合为一条僵尸节点提示；刚离线不报', () {
      final old = DateTime.now().subtract(const Duration(days: 45));
      final recent = DateTime.now().subtract(const Duration(days: 2));
      final withZombie = NetworkHealthService.analyze(
          nodes: [node(id: 'z', online: false, lastSeen: old)]);
      final finding =
          withZombie.firstWhere((e) => e.code == HealthCode.zombieNodes);
      expect(finding.detail, '1|0');
      expect(finding.relatedNodeIds, ['z']);
      expect(
        codes(NetworkHealthService.analyze(
            nodes: [node(online: false, lastSeen: recent)])),
        isNot(contains(HealthCode.zombieNodes)),
      );
    });

    test('僵尸节点同时给出"仍在共享路由"的数量（删除前的安全提示）', () {
      final old = DateTime.now().subtract(const Duration(days: 60));
      final f = NetworkHealthService.analyze(nodes: [
        node(
            id: '1',
            name: 'a',
            online: false,
            lastSeen: old,
            approved: const ['192.168.1.0/24']),
        node(id: '2', name: 'b', online: false, lastSeen: old),
      ]);
      final finding = f.firstWhere((e) => e.code == HealthCode.zombieNodes);
      expect(finding.detail, '2|1');
      expect(finding.relatedNodeIds, hasLength(2));
    });

    test('zombieNodes 按最久未上线排序', () {
      final z = NetworkHealthService.zombieNodes([
        node(
            id: '1',
            online: false,
            lastSeen: DateTime.now().subtract(const Duration(days: 40))),
        node(
            id: '2',
            online: false,
            lastSeen: DateTime.now().subtract(const Duration(days: 90))),
      ]);
      expect(z.map((n) => n.id).toList(), ['2', '1']);
    });
  });

  group('路由与 IP', () {
    test('申请但未批准的路由会被列出，并带具体网段', () {
      final f = NetworkHealthService.analyze(nodes: [
        node(approved: ['10.0.0.0/8'], available: ['10.0.0.0/8', '192.168.1.0/24']),
      ]);
      final finding =
          f.firstWhere((e) => e.code == HealthCode.routesPendingApproval);
      expect(finding.detail, '192.168.1.0/24');
    });

    test('同一网段被两个节点批准 → 路由冲突', () {
      final f = NetworkHealthService.analyze(nodes: [
        node(id: '1', name: 'a', approved: ['192.168.1.0/24']),
        node(id: '2', name: 'b', approved: ['192.168.1.0/24']),
      ]);
      final conflict = f.firstWhere((e) => e.code == HealthCode.routeConflict);
      expect(conflict.detail, contains('192.168.1.0/24'));
      expect(conflict.detail, contains('a'));
      expect(conflict.detail, contains('b'));
    });

    test('没有 IP 的节点会被提示（可用 backfillips 修复）', () {
      expect(
        codes(NetworkHealthService.analyze(nodes: [node(ipAddresses: const [])])),
        contains(HealthCode.nodeWithoutIp),
      );
    });
  });

  group('ACL 策略', () {
    test('组员缺少 @ → critical（这是保存时才会报 500 的那类问题）', () {
      final f = NetworkHealthService.analyze(
        nodes: const [],
        policyJson: '{"groups":{"group:a":["bob"]}}',
      );
      final finding = f
          .firstWhere((e) => e.code == HealthCode.policyGroupMemberNeedsAt);
      expect(finding.severity, HealthSeverity.critical);
      expect(finding.detail, 'groups."group:a"[0]');
    });

    test('策略不是合法 JSON → critical', () {
      expect(
        codes(NetworkHealthService.analyze(
            nodes: const [], policyJson: '{ // comment\n}')),
        contains(HealthCode.policyInvalidJson),
      );
    });

    test('节点用了 tagOwners 未声明的标签 → warning', () {
      final f = NetworkHealthService.analyze(
        nodes: [node(tags: const ['tag:home-client', 'tag:unknown'])],
        policyJson: '{"tagOwners":{"tag:home-client":["group:a"]}}',
      );
      final finding = f.firstWhere((e) => e.code == HealthCode.tagWithoutOwner);
      expect(finding.detail, 'tag:unknown');
    });

    test('策略为空/不可解析时不误报标签问题', () {
      expect(
        codes(NetworkHealthService.analyze(
            nodes: [node(tags: const ['tag:x'])], policyJson: '')),
        isNot(contains(HealthCode.tagWithoutOwner)),
      );
    });
  });

  group('DERP 与排序', () {
    test('所有中继都不可达时提示', () {
      final f = NetworkHealthService.analyze(
        nodes: const [],
        derpProbes: const [DerpProbe(host: 'a', latencyMs: null)],
      );
      expect(codes(f), contains(HealthCode.derpAllUnreachable));
    });

    test('至少一个中继可达就正常', () {
      final f = NetworkHealthService.analyze(
        nodes: const [],
        derpProbes: const [
          DerpProbe(host: 'a', latencyMs: null),
          DerpProbe(host: 'b', latencyMs: 30),
        ],
      );
      expect(codes(f), isNot(contains(HealthCode.derpAllUnreachable)));
    });

    test('结果按 critical → warning → info 排序', () {
      final f = NetworkHealthService.analyze(
        nodes: [
          node(id: '1', online: false,
              lastSeen: DateTime.now().subtract(const Duration(days: 60))),
          node(id: '2', expiry: DateTime.now().subtract(const Duration(days: 1))),
          node(id: '3', approved: const [], available: const ['10.0.0.0/8']),
        ],
        policyJson: '{"groups":{"group:a":["bob"]}}',
      );
      final severities = f.map((e) => e.severity.index).toList();
      expect(severities, orderedEquals(List.of(severities)..sort()));
      expect(f.first.severity, HealthSeverity.critical);
    });

    test('一切正常时返回空清单', () {
      expect(
        NetworkHealthService.analyze(
          nodes: [node(expiry: DateTime.now().add(const Duration(days: 200)))],
          policyJson: '{"groups":{"group:a":["a@"]}}',
        ),
        isEmpty,
      );
    });
  });
}
