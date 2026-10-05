import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/node.dart';

/// 覆盖 Node 新增的网络/密钥字段解析，以及 expiry 的几种边界值。
///
/// 这些字段 Headscale v1 API 早就在返回（`expiry`、`createdAt`、
/// `registerMethod`、`discoKey`、`nodeKey`、`subnetRoutes`），此前 App 全部忽略。
/// 参考 Headplane：它把 expiry 的空值判为「无过期」，并且把 Go 的零值时间
/// （`0001-01-01T00:00:00Z`）同样视为无过期。
void main() {
  Map<String, dynamic> baseJson({
    Object? expiry,
    Object? createdAt,
    String? registerMethod,
    List<String>? subnetRoutes,
  }) =>
      {
        'id': '1',
        'machineKey': 'mk',
        'nodeKey': 'nk',
        'discoKey': 'dk',
        'name': 'node-1',
        'givenName': 'node-1',
        'ipAddresses': ['100.64.0.1'],
        'online': true,
        'lastSeen': '2026-01-01T00:00:00Z',
        'user': {'id': '1', 'name': 'lcmyhome'},
        'approvedRoutes': ['192.168.1.0/24'],
        'availableRoutes': ['192.168.1.0/24'],
        if (expiry != null) 'expiry': expiry,
        if (createdAt != null) 'createdAt': createdAt,
        if (registerMethod != null) 'registerMethod': registerMethod,
        if (subnetRoutes != null) 'subnetRoutes': subnetRoutes,
      };

  group('Node 网络字段解析', () {
    test('解析 expiry / createdAt / registerMethod / 密钥 / 子网路由', () {
      final node = Node.fromJson(
        baseJson(
          expiry: '2026-06-01T00:00:00Z',
          createdAt: '2025-12-01T00:00:00Z',
          registerMethod: 'REGISTER_METHOD_CLI',
          subnetRoutes: ['10.0.0.0/8'],
        ),
        'example.com',
      );

      expect(node.expiry, DateTime.parse('2026-06-01T00:00:00Z'));
      expect(node.createdAt, DateTime.parse('2025-12-01T00:00:00Z'));
      expect(node.registerMethod, 'REGISTER_METHOD_CLI');
      expect(node.discoKey, 'dk');
      expect(node.nodeKey, 'nk');
      expect(node.subnetRoutes, ['10.0.0.0/8']);
    });

    test('expiry 为 null 表示无过期', () {
      final node = Node.fromJson(baseJson(expiry: null), 'example.com');
      expect(node.expiry, isNull);
      expect(node.daysUntilExpiry, isNull);
      expect(node.isExpired, isFalse);
      expect(node.isExpirySoon, isFalse);
    });

    test('Go 零值时间（0001-01-01）同样视为无过期', () {
      final node = Node.fromJson(
          baseJson(expiry: '0001-01-01T00:00:00Z'), 'example.com');
      expect(node.expiry, isNull);
      expect(node.isExpired, isFalse);
    });

    test('无法解析的时间不会导致加载失败，只当作无过期', () {
      final node =
          Node.fromJson(baseJson(expiry: 'not-a-date'), 'example.com');
      expect(node.expiry, isNull);
    });

    test('缺失的新字段有安全默认值', () {
      // 刻意给一个"老版本 API 返回"的最小 JSON（只有必需字段）
      final node = Node.fromJson({
        'id': '9',
        'name': 'legacy-node',
        'user': {'id': '2', 'name': 'bob'},
        'ipAddresses': ['100.64.0.9'],
        'lastSeen': '2026-01-02T00:00:00Z',
      }, 'example.com');

      expect(node.registerMethod, '');
      expect(node.discoKey, '');
      expect(node.nodeKey, '');
      expect(node.subnetRoutes, isEmpty);
      expect(node.createdAt, isNull);
      expect(node.expiry, isNull);
      expect(node.sharedRoutes, isEmpty);
      expect(node.tags, isEmpty);
    });

    test('已过期 / 临期判定', () {
      final expired = Node.fromJson(
        baseJson(expiry: DateTime.now()
            .subtract(const Duration(days: 1))
            .toUtc()
            .toIso8601String()),
        'example.com',
      );
      expect(expired.isExpired, isTrue);

      final soon = Node.fromJson(
        baseJson(expiry: DateTime.now()
            .add(const Duration(days: 10))
            .toUtc()
            .toIso8601String()),
        'example.com',
      );
      expect(soon.isExpirySoon, isTrue);
      expect(soon.isExpired, isFalse);

      final far = Node.fromJson(
        baseJson(expiry: DateTime.now()
            .add(const Duration(days: 200))
            .toUtc()
            .toIso8601String()),
        'example.com',
      );
      expect(far.isExpirySoon, isFalse);
    });
  });
}
