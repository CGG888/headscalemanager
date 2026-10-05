import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/device_details.dart';

/// device API（`GET /api/v1/device/{id}`）的解析。
///
/// 这些字段 v1 的 Node **没有**：OS、客户端版本、**当前使用的 DERP 中继**、
/// **客户端实测的各区域延迟**、公网端点、NAT 形态等。
void main() {
  const full = {
    'id': '42',
    'name': 'phone',
    'hostname': 'phone',
    'user': 'lcmyhome',
    'os': 'android',
    'clientVersion': '1.102.4',
    'updateAvailable': true,
    'authorized': false,
    'keyExpiryDisabled': true,
    'isExternal': false,
    'blocksIncomingConnections': true,
    'addresses': ['100.64.0.5'],
    'enabledRoutes': ['10.0.0.0/8'],
    'advertisedRoutes': ['10.0.0.0/8', '192.168.1.0/24'],
    'created': '2026-01-01T00:00:00Z',
    'expires': '0001-01-01T00:00:00Z',
    'clientConnectivity': {
      'endpoints': ['203.0.113.7:41641'],
      'derp': '9',
      'mappingVariesByDestIp': true,
      'latency': {
        '9': {'latencyMs': 23.5, 'preferred': true},
        '1': {'latencyMs': 88.0, 'preferred': false},
      },
      'clientSupports': {'udp': true, 'ipv6': false},
    },
  };

  group('DeviceDetails', () {
    test('解析设备与连通性字段', () {
      final d = DeviceDetails.fromJson(Map<String, dynamic>.from(full));
      expect(d.os, 'android');
      expect(d.clientVersion, '1.102.4');
      expect(d.updateAvailable, isTrue);
      expect(d.authorized, isFalse);
      expect(d.keyExpiryDisabled, isTrue);
      expect(d.blocksIncomingConnections, isTrue);
      expect(d.addresses, ['100.64.0.5']);
      expect(d.pendingRoutes, ['192.168.1.0/24']);
      expect(d.created, DateTime.parse('2026-01-01T00:00:00Z'));
    });

    test('Go 零值时间按"无"处理（不过期）', () {
      final d = DeviceDetails.fromJson(Map<String, dynamic>.from(full));
      expect(d.expires, isNull);
    });

    test('中继、区域延迟与首选标记', () {
      final d = DeviceDetails.fromJson(Map<String, dynamic>.from(full));
      final conn = d.connectivity!;
      expect(conn.derp, '9');
      expect(conn.endpoints, ['203.0.113.7:41641']);
      expect(conn.mappingVariesByDestIp, isTrue);
      expect(conn.latency['9']!.latencyMs, 23.5);
      expect(conn.preferredRegion, '9');
      expect(conn.fastestRegion, '9');
      expect(conn.clientSupports['udp'], isTrue);
      expect(conn.clientSupports['ipv6'], isFalse);
    });

    test('没有连通性数据时不为 null 崩溃，且无区域数据', () {
      final d = DeviceDetails.fromJson(const {'id': '1', 'name': 'n'});
      expect(d.connectivity, isNull);
      expect(d.os, '');
      expect(d.authorized, isTrue); // 缺省视为已授权
      expect(d.pendingRoutes, isEmpty);
    });

    test('fastestRegion 取延迟最小的区域', () {
      final d = DeviceDetails.fromJson(const {
        'id': '1',
        'clientConnectivity': {
          'latency': {
            'a': {'latencyMs': 120},
            'b': {'latencyMs': 30},
            'c': {'latencyMs': 60},
          },
        },
      });
      expect(d.connectivity!.fastestRegion, 'b');
      expect(d.connectivity!.preferredRegion, isNull);
    });
  });
}
