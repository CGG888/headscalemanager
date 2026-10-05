import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/services/alert_rules_service.dart';

/// 规则化告警：关键行为是**按档位去重**——跨过 30/7/3/1 天各提醒一次，
/// 而不是每天重复推送（否则用户会把通知关掉）。
void main() {
  Node node(String id, String name, {DateTime? expiry}) => Node(
        id: id,
        machineKey: 'mk$id',
        hostname: name,
        name: name,
        user: 'u',
        userId: '1',
        ipAddresses: const ['100.64.0.1'],
        online: true,
        lastSeen: DateTime.now(),
        sharedRoutes: const [],
        availableRoutes: const [],
        isExitNode: false,
        isLanSharer: false,
        tags: const [],
        baseDomain: 'example.com',
        endpoint: '',
        expiry: expiry,
      );

  // 关键：必须避开"整天边界"。`DateTime.now()` 与计算时刻之间会差几毫秒，
  // 若到期时间正好是 N 天整，`difference(...).inDays` 可能是 N-1，导致档位
  // 从 d3 变成 d1 —— 本地通过、CI 失败（本仓库真发生过）。
  // 因此统一加 12 小时偏移，让天数取整稳定。
  DateTime inDays(int days) =>
      DateTime.now().add(Duration(days: days, hours: 12));

  group('keyAlerts', () {
    test('永不过期的节点不告警', () {
      expect(AlertRulesService.keyAlerts([node('1', 'a')]), isEmpty);
    });

    test('还早（>30 天）不打扰', () {
      expect(AlertRulesService.keyAlerts([node('1', 'a', expiry: inDays(100))]),
          isEmpty);
    });

    test('30 天内提醒一次，档位为 d30', () {
      final alerts =
          AlertRulesService.keyAlerts([node('1', 'a', expiry: inDays(20))]);
      expect(alerts, hasLength(1));
      expect(alerts.first.rule, AlertRule.keyExpiringSoon);
      expect(alerts.first.dedupeKey, 'keyExpiry:1:d30');
      expect(alerts.first.days, inInclusiveRange(19, 20));
    });

    test('跨到更紧的档位会再提醒一次（d7 → d3）', () {
      final sevenDay = AlertRulesService.keyAlerts(
          [node('1', 'a', expiry: inDays(6))]).first;
      expect(sevenDay.dedupeKey, 'keyExpiry:1:d7');

      final threeDays = AlertRulesService.keyAlerts(
          [node('1', 'a', expiry: inDays(2))]).first;
      expect(threeDays.dedupeKey, 'keyExpiry:1:d3');
    });

    test('已经提醒过的档位不再重复', () {
      final alerts = AlertRulesService.keyAlerts(
        [node('1', 'a', expiry: inDays(6))],
        alreadyNotified: {'keyExpiry:1:d7'},
      );
      expect(alerts, isEmpty);
    });

    test('已过期单独一档，且只提醒一次', () {
      final expired = AlertRulesService.keyAlerts(
          [node('1', 'a', expiry: inDays(-2))]);
      expect(expired, hasLength(1));
      expect(expired.first.rule, AlertRule.keyExpired);
      expect(expired.first.dedupeKey, 'keyExpiry:1:expired');

      expect(
        AlertRulesService.keyAlerts([node('1', 'a', expiry: inDays(-2))],
            alreadyNotified: {'keyExpiry:1:expired'}),
        isEmpty,
      );
    });

    test('多个节点按剩余天数升序（最紧急在前）', () {
      final alerts = AlertRulesService.keyAlerts([
        node('1', 'later', expiry: inDays(25)),
        node('2', 'sooner', expiry: inDays(1)),
      ]);
      expect(alerts.map((a) => a.nodeName).toList(), ['sooner', 'later']);
    });

    test('dedupeKeys 可直接交给调用方持久化', () {
      final alerts =
          AlertRulesService.keyAlerts([node('1', 'a', expiry: inDays(25))]);
      expect(AlertRulesService.dedupeKeys(alerts), ['keyExpiry:1:d30']);
    });
  });
}
