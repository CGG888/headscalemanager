import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/services/acl/acl_reachability_service.dart';

/// ACL 可达性分析与风险审计（纯离线计算）。
void main() {
  group('可达性折算', () {
    test('经典 acls：src → dst，端口被拆出并合并', () {
      final r = AclReachabilityService.analyze('''
      {"acls":[
        {"action":"accept","src":["tag:home"],"dst":["tag:server:22","tag:server:443"]}
      ]}''');
      expect(r.edges, hasLength(1));
      expect(r.edges.first.source, 'tag:home');
      expect(r.edges.first.destination, 'tag:server');
      expect(r.edges.first.ports, ['22', '443']);
    });

    test('action 为 drop 的规则不构成可达', () {
      final r = AclReachabilityService.analyze('''
      {"acls":[{"action":"drop","src":["*"],"dst":["*:*"]}]}''');
      expect(r.edges, isEmpty);
      expect(r.risks.map((x) => x.code), isNot(contains(AclRiskCode.allowAll)));
    });

    test('v0.29 grants：src/dst 与 ip 都算可达', () {
      final r = AclReachabilityService.analyze('''
      {"grants":[
        {"src":["group:admins"],"dst":["tag:server"],"ip":["10.0.0.0/8"]}
      ]}''');
      expect(r.edges.map((e) => e.destination).toList(),
          containsAll(['tag:server', '10.0.0.0/8']));
      expect(r.sourceCount, 1);
    });

    test('多源多目标展开成多条边并按源排序', () {
      final r = AclReachabilityService.analyze('''
      {"acls":[
        {"action":"accept","src":["b","a"],"dst":["x:*","y:80"]}
      ]}''');
      expect(r.edges.map((e) => '${e.source}->${e.destination}').toList(),
          ['a->x', 'a->y', 'b->x', 'b->y']);
    });

    test('策略不可解析时返回空结果而不抛异常', () {
      expect(AclReachabilityService.analyze('{ // comment').edges, isEmpty);
      expect(AclReachabilityService.analyze('').edges, isEmpty);
    });
  });

  group('风险审计', () {
    test('src=* 且 dst=*:* → allowAll（critical）', () {
      final r = AclReachabilityService.analyze('''
      {"acls":[{"action":"accept","src":["*"],"dst":["*:*"]}]}''');
      final risk = r.risks.firstWhere((x) => x.code == AclRiskCode.allowAll);
      expect(risk.severity, AclRiskSeverity.critical);
      expect(risk.detail, 'acls[0]');
    });

    test('对所有人放开 autogroup:internet → warning', () {
      final r = AclReachabilityService.analyze('''
      {"acls":[{"action":"accept","src":["*"],"dst":["autogroup:internet:*"]}]}''');
      expect(r.risks.map((x) => x.code),
          contains(AclRiskCode.internetOpenToAll));
    });

    test('仅对特定组放开 internet 不算风险', () {
      final r = AclReachabilityService.analyze('''
      {"acls":[{"action":"accept","src":["group:exit"],"dst":["autogroup:internet:*"]}]}''');
      expect(r.risks.map((x) => x.code),
          isNot(contains(AclRiskCode.internetOpenToAll)));
    });

    test('SSH 对所有人开放 → warning', () {
      final r = AclReachabilityService.analyze('''
      {"acls":[{"action":"accept","src":["*"],"dst":["tag:server:22"]}]}''');
      expect(r.risks.map((x) => x.code), contains(AclRiskCode.sshOpenToAll));
    });

    test('放行 0.0.0.0/0 或 ::/0 → exitNodeOpen', () {
      final r = AclReachabilityService.analyze('''
      {"acls":[{"action":"accept","src":["group:admins"],"dst":["0.0.0.0/0"]}]}''');
      expect(r.risks.map((x) => x.code), contains(AclRiskCode.exitNodeOpen));
    });

    test('没有 acls/grants → noRules（info）', () {
      final r = AclReachabilityService.analyze('{"groups":{}}');
      expect(r.risks.single.code, AclRiskCode.noRules);
      expect(r.risks.single.severity, AclRiskSeverity.info);
    });

    test('正常的策略没有风险', () {
      final r = AclReachabilityService.analyze('''
      {"acls":[
        {"action":"accept","src":["group:admins"],"dst":["tag:server:443"]},
        {"action":"accept","src":["group:users"],"dst":["tag:server:80"]}
      ]}''');
      expect(r.risks, isEmpty);
      expect(r.edges, hasLength(2));
    });

    test('grants 里的 * 也会被判为 allowAll', () {
      final r = AclReachabilityService.analyze('''
      {"grants":[{"src":["*"],"dst":["*"]}]}''');
      expect(r.risks.map((x) => x.code), contains(AclRiskCode.allowAll));
    });
  });
}
