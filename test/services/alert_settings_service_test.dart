import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/services/alert_rules_service.dart';
import 'package:headscalemanager/services/alert_settings_service.dart';

/// 构造一个仅关心到期时间的节点。
Node _node({required DateTime expiry}) => Node(
      id: '1',
      machineKey: 'mk1',
      hostname: 'n1',
      name: 'n1',
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

/// 告警设置：范围收敛、档位推导，以及自定义档位对规则引擎的影响。
void main() {
  group('AlertSettings', () {
    test('默认值保守：离线 30 天、提前 30 天提醒', () {
      const s = AlertSettings();
      expect(s.offlineDays, 30);
      expect(s.keyExpiryWarnDays, 30);
      expect(s.notifyKeyExpiry, isTrue);
    });

    test('范围收敛，避免存进离谱的值', () {
      expect(AlertSettings.clampOfflineDays(0), AlertSettings.minOfflineDays);
      expect(AlertSettings.clampOfflineDays(9999), AlertSettings.maxOfflineDays);
      expect(AlertSettings.clampWarnDays(0), AlertSettings.minWarnDays);
      expect(AlertSettings.clampWarnDays(999), AlertSettings.maxWarnDays);
      expect(AlertSettings.clampOfflineDays(45), 45);
    });

    test('实际生效档位不超过提前量', () {
      const wide = AlertSettings(keyExpiryWarnDays: 30);
      expect(wide.effectiveThresholds, [30, 7, 3, 1]);

      const narrow = AlertSettings(keyExpiryWarnDays: 7);
      expect(narrow.effectiveThresholds, [7, 3, 1]);

      const urgent = AlertSettings(keyExpiryWarnDays: 1);
      expect(urgent.effectiveThresholds, [1]);
    });

    test('copyWith 只改指定字段', () {
      const s = AlertSettings();
      final updated = s.copyWith(notifyKeyExpiry: false, offlineDays: 90);
      expect(updated.notifyKeyExpiry, isFalse);
      expect(updated.offlineDays, 90);
      expect(updated.keyExpiryWarnDays, s.keyExpiryWarnDays);
      expect(updated.notifyStatusChange, s.notifyStatusChange);
    });
  });

  group('自定义档位对引擎的影响', () {
    test('提前量缩到 7 天后，20 天后到期的密钥不再提醒', () {
      final alerts = AlertRulesService.keyAlerts(
        [_node(expiry: DateTime.now().add(const Duration(days: 20, hours: 12)))],
        alertThresholds: const AlertSettings(keyExpiryWarnDays: 7)
            .effectiveThresholds,
      );
      expect(alerts, isEmpty);
    });

    test('提前量缩到 7 天后，仍在档位内的照常提醒', () {
      final alerts = AlertRulesService.keyAlerts(
        [_node(expiry: DateTime.now().add(const Duration(days: 6, hours: 12)))],
        alertThresholds: const AlertSettings(keyExpiryWarnDays: 7)
            .effectiveThresholds,
      );
      expect(alerts, hasLength(1));
      expect(alerts.first.dedupeKey, 'keyExpiry:1:d7');
    });
  });
}
