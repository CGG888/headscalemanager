import 'dart:convert';

import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/services/acl/acl_policy_check.dart';
import 'package:headscalemanager/services/derp_service.dart';

/// 网络体检：把散落在各页面的异常聚合成一份可操作清单。
///
/// 全部使用**已经能拿到的数据**（节点列表、ACL 策略、DERP 探测结果），不依赖任何
/// 服务端新接口。返回的是**问题代码**而非文案——由 UI 用 `L10n` 渲染，
/// 逻辑与本地化解耦，也便于单元测试。
enum HealthSeverity {
  /// 会导致网络或设备不可用（密钥过期、策略无法解析）。
  critical,

  /// 需要处理，但不紧急（未批准的路由、临期密钥、无 IP）。
  warning,

  /// 提示性信息。
  info,
}

enum HealthCode {
  nodeKeyExpired,
  nodeKeyExpiringSoon,

  /// 长期离线的节点**聚合为一条**：它们通常是要批量清理的对象。
  zombieNodes,
  routesPendingApproval,
  nodeWithoutIp,
  routeConflict,
  policyInvalidJson,
  policyGroupMemberNeedsAt,
  policyGroupNameInvalid,
  tagWithoutOwner,
  derpAllUnreachable,
}

class HealthFinding {
  const HealthFinding({
    required this.code,
    required this.severity,
    this.nodeId,
    this.nodeName,
    this.detail,
    this.relatedNodeIds = const [],
  });

  final HealthCode code;
  final HealthSeverity severity;

  /// 便于 UI 跳转到节点详情。
  final String? nodeId;
  final String? nodeName;

  /// 具体值：路由、标签、错误位置、数量等。
  final String? detail;

  /// 聚合类问题涉及的节点（例如僵尸节点清单），供"批量操作"预选。
  final List<String> relatedNodeIds;

  @override
  String toString() => '${severity.name}/${code.name}'
      '${nodeName != null ? ' ($nodeName)' : ''}'
      '${detail != null ? ' $detail' : ''}';
}

class NetworkHealthService {
  const NetworkHealthService._();

  /// 超过这个天数仍然离线，视为需要清理的节点。
  static const int offlineDaysThreshold = 30;

  /// 分析：返回按严重程度排序的问题清单（critical → warning → info）。
  static List<HealthFinding> analyze({
    required List<Node> nodes,
    String policyJson = '',
    List<DerpProbe> derpProbes = const [],
  }) {
    final findings = <HealthFinding>[];

    for (final node in nodes) {
      if (node.isExpired) {
        findings.add(HealthFinding(
          code: HealthCode.nodeKeyExpired,
          severity: HealthSeverity.critical,
          nodeId: node.id,
          nodeName: node.name,
        ));
      } else if (node.isExpirySoon) {
        findings.add(HealthFinding(
          code: HealthCode.nodeKeyExpiringSoon,
          severity: HealthSeverity.warning,
          nodeId: node.id,
          nodeName: node.name,
          detail: '${node.daysUntilExpiry}',
        ));
      }

      final pending = node.availableRoutes
          .where((r) => !node.sharedRoutes.contains(r))
          .toList();
      if (pending.isNotEmpty) {
        findings.add(HealthFinding(
          code: HealthCode.routesPendingApproval,
          severity: HealthSeverity.warning,
          nodeId: node.id,
          nodeName: node.name,
          detail: pending.join(', '),
        ));
      }

      if (node.ipAddresses.isEmpty) {
        findings.add(HealthFinding(
          code: HealthCode.nodeWithoutIp,
          severity: HealthSeverity.warning,
          nodeId: node.id,
          nodeName: node.name,
        ));
      }
    }

    // 僵尸节点：**聚合为一条**（而不是每台一句），因为处置方式就是批量清理。
    // detail 的格式固定为 "<总数>|<仍在共享路由的数量>"——后者是删除前的安全提示：
    // 删掉仍在共享子网或作为出口节点的机器会立刻影响网络。
    final zombies = zombieNodes(nodes);
    if (zombies.isNotEmpty) {
      final sharingRoutes =
          zombies.where((n) => n.sharedRoutes.isNotEmpty || n.isExitNode).length;
      findings.add(HealthFinding(
        code: HealthCode.zombieNodes,
        severity: HealthSeverity.info,
        detail: '${zombies.length}|$sharingRoutes',
        relatedNodeIds: zombies.map((n) => n.id).toList(),
      ));
    }

    // 同一子网被多个节点批准：路由冲突，流量走向不确定。
    final routeOwners = <String, List<String>>{};
    for (final node in nodes) {
      for (final route in node.sharedRoutes) {
        routeOwners.putIfAbsent(route, () => []).add(node.name);
      }
    }
    routeOwners.forEach((route, owners) {
      if (owners.length > 1) {
        findings.add(HealthFinding(
          code: HealthCode.routeConflict,
          severity: HealthSeverity.warning,
          detail: '$route ← ${owners.join(', ')}',
        ));
      }
    });

    // 策略：复用保存前预检的那套本地检查。
    findings.addAll(_policyFindings(policyJson, nodes));

    // DERP：全部不可达说明中继探测（或到中继的网络）有问题。
    if (derpProbes.isNotEmpty && !derpProbes.any((p) => p.reachable)) {
      findings.add(const HealthFinding(
        code: HealthCode.derpAllUnreachable,
        severity: HealthSeverity.warning,
      ));
    }

    findings.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return findings;
  }

  /// 僵尸节点：离线超过 [offlineDays] 天，按"最久没上线"排在前面。
  ///
  /// 离线本身是正常的，但长期离线通常意味着设备已废弃——Headscale 的节点密钥默认
  /// 180 天到期，这些记录会一直堆着。返回结果可直接交给"批量操作"做清理。
  static List<Node> zombieNodes(
    List<Node> nodes, {
    int offlineDays = offlineDaysThreshold,
  }) {
    final list = nodes
        .where((n) =>
            !n.online &&
            DateTime.now().difference(n.lastSeen).inDays >= offlineDays)
        .toList();
    list.sort((a, b) => a.lastSeen.compareTo(b.lastSeen));
    return list;
  }

  static List<HealthFinding> _policyFindings(String policyJson, List<Node> nodes) {
    final findings = <HealthFinding>[];

    for (final issue in AclPolicyCheck.localIssues(policyJson)) {
      switch (issue.code) {
        case AclIssueCode.notJson:
          findings.add(const HealthFinding(
            code: HealthCode.policyInvalidJson,
            severity: HealthSeverity.critical,
          ));
        case AclIssueCode.groupMemberNeedsAt:
          findings.add(HealthFinding(
            code: HealthCode.policyGroupMemberNeedsAt,
            severity: HealthSeverity.critical,
            detail: issue.path,
          ));
        case AclIssueCode.invalidGroupName:
          findings.add(HealthFinding(
            code: HealthCode.policyGroupNameInvalid,
            severity: HealthSeverity.warning,
            detail: issue.value,
          ));
      }
    }

    // 节点使用的标签是否在策略的 tagOwners 里被声明：未声明的标签将被策略忽略。
    final owners = _tagOwners(policyJson);
    if (owners != null) {
      final unknown = <String>{};
      for (final node in nodes) {
        for (final tag in node.tags) {
          if (tag.startsWith('tag:') && !owners.contains(tag)) unknown.add(tag);
        }
      }
      if (unknown.isNotEmpty) {
        findings.add(HealthFinding(
          code: HealthCode.tagWithoutOwner,
          severity: HealthSeverity.warning,
          detail: (unknown.toList()..sort()).join(', '),
        ));
      }
    }

    return findings;
  }

  /// 解析策略中的 tagOwners 键；策略不可解析时返回 null（表示"无法判断"，不报问题）。
  static Set<String>? _tagOwners(String policyJson) {
    final parsed = _tryDecode(policyJson);
    if (parsed == null) return null;
    final owners = parsed['tagOwners'];
    if (owners is! Map) return null;
    return owners.keys.map((k) => k.toString()).toSet();
  }

  static Map<String, dynamic>? _tryDecode(String policyJson) {
    if (policyJson.trim().isEmpty) return null;
    try {
      final decoded = json.decode(policyJson);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
