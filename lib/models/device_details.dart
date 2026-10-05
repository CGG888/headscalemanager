/// Headscale **device API**（`GET /api/v1/device/{id}`）返回的设备详情。
///
/// 为什么单独建模型：v1 的 `Node` 模型**没有**这些字段（`host_info`/`endpoints`
/// 在 node.proto 里是 `reserved`），而 device.proto 提供了它们——包括
/// **每台机器当前使用的 DERP 中继**（`client_connectivity.derp`）与
/// **客户端自己测得的各区域延迟**（`latency`）。这是"机器网络详情"的真正来源。
///
/// 需要注意版本：该接口在 Headscale 0.29.x 起提供，老服务端会返回 404，
/// 调用方应据此隐藏相关界面（而不是报错）。
class DeviceDetails {
  const DeviceDetails({
    required this.id,
    required this.name,
    required this.hostname,
    required this.user,
    required this.os,
    required this.clientVersion,
    required this.updateAvailable,
    required this.authorized,
    required this.keyExpiryDisabled,
    required this.isExternal,
    required this.blocksIncomingConnections,
    required this.addresses,
    required this.enabledRoutes,
    required this.advertisedRoutes,
    this.created,
    this.lastSeen,
    this.expires,
    this.connectivity,
  });

  final String id;
  final String name;
  final String hostname;
  final String user;

  /// 操作系统（例如 `linux`、`android`）。
  final String os;

  /// Tailscale 客户端版本。
  final String clientVersion;

  /// 客户端有新版本可用。
  final bool updateAvailable;

  /// 设备是否已被授权（`authorized`）。false 通常意味着等待批准。
  final bool authorized;

  /// 是否禁用了密钥过期（长期在线的服务器常用）。
  final bool keyExpiryDisabled;

  /// 是否为外部设备。
  final bool isExternal;

  /// 是否阻止入站连接（如 Tailscale 的 `--shields-up`）。
  final bool blocksIncomingConnections;

  final List<String> addresses;
  final List<String> enabledRoutes;
  final List<String> advertisedRoutes;

  final DateTime? created;
  final DateTime? lastSeen;
  final DateTime? expires;

  final DeviceConnectivity? connectivity;

  factory DeviceDetails.fromJson(Map<String, dynamic> json) {
    final connectivity = json['clientConnectivity'];
    return DeviceDetails(
      id: '${json['id'] ?? ''}',
      name: json['name'] as String? ?? '',
      hostname: json['hostname'] as String? ?? '',
      user: json['user'] as String? ?? '',
      os: json['os'] as String? ?? '',
      clientVersion: json['clientVersion'] as String? ?? '',
      updateAvailable: json['updateAvailable'] as bool? ?? false,
      authorized: json['authorized'] as bool? ?? true,
      keyExpiryDisabled: json['keyExpiryDisabled'] as bool? ?? false,
      isExternal: json['isExternal'] as bool? ?? false,
      blocksIncomingConnections:
          json['blocksIncomingConnections'] as bool? ?? false,
      addresses: _stringList(json['addresses']),
      enabledRoutes: _stringList(json['enabledRoutes']),
      advertisedRoutes: _stringList(json['advertisedRoutes']),
      created: _time(json['created']),
      lastSeen: _time(json['lastSeen']),
      expires: _time(json['expires']),
      connectivity: connectivity is Map<String, dynamic>
          ? DeviceConnectivity.fromJson(connectivity)
          : null,
    );
  }

  /// 该设备实际使用的路由中，尚未启用的部分。
  List<String> get pendingRoutes => advertisedRoutes
      .where((r) => !enabledRoutes.contains(r))
      .toList();

  static List<String> _stringList(Object? value) =>
      value is List ? value.map((e) => '$e').toList() : const [];

  static DateTime? _time(Object? value) {
    if (value is! String || value.isEmpty) return null;
    if (value.startsWith('0001-01-01')) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
}

/// `client_connectivity`：客户端上报的**真实网络状态**。
class DeviceConnectivity {
  const DeviceConnectivity({
    required this.endpoints,
    required this.derp,
    required this.mappingVariesByDestIp,
    required this.latency,
    required this.clientSupports,
  });

  /// 节点的公网端点（IP:port 候选）。
  final List<String> endpoints;

  /// **当前使用的 DERP 中继 ID**（区域号，例如 `1`）。
  final String derp;

  /// 映射随目标地址变化 → 说明处在对称型 NAT 之后（影响直连能力）。
  final bool mappingVariesByDestIp;

  /// 各 DERP 区域的延迟（区域 ID → 延迟），由**客户端自己测量并上报**。
  final Map<String, DerpRegionLatency> latency;

  /// 客户端支持的能力（hair pinning / ipv6 / pcp / pmp / udp / upnp）。
  final Map<String, bool> clientSupports;

  factory DeviceConnectivity.fromJson(Map<String, dynamic> json) {
    final latencyJson = json['latency'];
    final latency = <String, DerpRegionLatency>{};
    if (latencyJson is Map) {
      latencyJson.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          latency['$key'] = DerpRegionLatency.fromJson(value);
        } else if (value is num) {
          latency['$key'] = DerpRegionLatency(latencyMs: value.toDouble(), preferred: false);
        }
      });
    }

    final supportsJson = json['clientSupports'];
    final supports = <String, bool>{};
    if (supportsJson is Map) {
      supportsJson.forEach((key, value) {
        if (value is bool) supports['$key'] = value;
      });
    }

    return DeviceConnectivity(
      endpoints: DeviceDetails._stringList(json['endpoints']),
      derp: '${json['derp'] ?? ''}',
      mappingVariesByDestIp: json['mappingVariesByDestIp'] as bool? ?? false,
      latency: latency,
      clientSupports: supports,
    );
  }

  /// 延迟最低的区域 ID（无数据时返回 null）。
  String? get fastestRegion {
    String? best;
    double? bestMs;
    latency.forEach((region, value) {
      if (bestMs == null || value.latencyMs < bestMs!) {
        bestMs = value.latencyMs;
        best = region;
      }
    });
    return best;
  }

  /// 客户端标记为"首选"的区域（`preferred: true`）。
  String? get preferredRegion {
    for (final entry in latency.entries) {
      if (entry.value.preferred) return entry.key;
    }
    return null;
  }
}

class DerpRegionLatency {
  const DerpRegionLatency({required this.latencyMs, required this.preferred});

  final double latencyMs;
  final bool preferred;

  factory DerpRegionLatency.fromJson(Map<String, dynamic> json) =>
      DerpRegionLatency(
        latencyMs: (json['latencyMs'] as num?)?.toDouble() ?? 0,
        preferred: json['preferred'] as bool? ?? false,
      );
}
