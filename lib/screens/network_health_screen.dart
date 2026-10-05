import 'package:flutter/material.dart';
import 'package:headscalemanager/l10n/l10n.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/acl_screen.dart';
import 'package:headscalemanager/screens/node_detail_screen.dart';
import 'package:headscalemanager/screens/acl_reachability_screen.dart';
import 'package:headscalemanager/screens/audit_log_screen.dart';
import 'package:headscalemanager/screens/policy_diff_screen.dart';
import 'package:headscalemanager/screens/device_authorization_screen.dart';
import 'package:headscalemanager/screens/batch_operations_screen.dart';
import 'package:headscalemanager/services/derp_service.dart';
import 'package:headscalemanager/services/network_health_service.dart';
import 'package:provider/provider.dart';

/// 网络体检：把所有异常聚合成一页，并给出可操作的修复入口。
///
/// 数据全部来自 App 已经能拿到的东西（节点列表、ACL 策略、DERP 探测），
/// 因此不需要任何服务端新接口。
class NetworkHealthScreen extends StatefulWidget {
  const NetworkHealthScreen({super.key});

  @override
  State<NetworkHealthScreen> createState() => _NetworkHealthScreenState();
}

class _NetworkHealthScreenState extends State<NetworkHealthScreen> {
  bool _isLoading = true;
  String? _error;
  List<HealthFinding> _findings = const [];
  final Map<String, Node> _nodesById = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = context.read<AppProvider>();
    final api = provider.apiService;
    final serverUrl = provider.activeServer?.url ?? '';

    try {
      final nodes = await api.getNodes();
      // 策略读取失败不应让整页失败：策略相关检查会自动跳过。
      String policy = '';
      try {
        policy = await api.getAclPolicy();
      } catch (_) {
        policy = '';
      }

      // DERP 探测是可选加料：服务器未启用内嵌 DERP 或反代未放行时会为空。
      var probes = const <DerpProbe>[];
      if (serverUrl.isNotEmpty) {
        final service = DerpService(baseUrl: serverUrl);
        try {
          probes = await service.probeAll();
        } catch (_) {
          probes = const [];
        } finally {
          service.close();
        }
      }

      final findings = NetworkHealthService.analyze(
        nodes: nodes,
        policyJson: policy,
        derpProbes: probes,
      );

      if (!mounted) return;
      setState(() {
        _nodesById
          ..clear()
          ..addEntries(nodes.map((n) => MapEntry(n.id, n)));
        _findings = findings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 用 `backfillips` 给没有 IP 的节点补全地址。
  Future<void> _backfillIps() async {
    final api = context.read<AppProvider>().apiService;
    final l10n = context.l10n;
    try {
      await api.backfillIps();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.t('Adresses IP complétées.', 'IP addresses backfilled.',
            '已补全节点 IP。')),
      ));
      await _run();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${l10n.t('Échec', 'Failed', '操作失败')}: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('Bilan du réseau', 'Network health', '网络体检')),
        actions: [
          IconButton(
            icon: const Icon(Icons.gpp_maybe_outlined),
            tooltip: l10n.t('Appareils non autorisés', 'Unauthorized devices', '未授权设备'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const DeviceAuthorizationScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            tooltip: l10n.t('Visibilité ACL', 'ACL visibility', 'ACL 可达性'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AclReachabilityScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.difference_outlined),
            tooltip: l10n.t('Changements de politique', 'Policy changes', '策略变更对比'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PolicyDiffScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: l10n.t('Historique des opérations', 'Operation history', '操作记录'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AuditLogScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _run,
          ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(L10n l10n) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.t('Analyse…', 'Analysing…', '正在体检……')),
          ],
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text('${l10n.t('Échec de l\'analyse', 'Analysis failed', '体检失败')}: $_error',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _run, child: Text(l10n.t('Réessayer', 'Retry', '重试'))),
          ],
        ),
      );
    }
    if (_findings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(l10n.t('Aucun problème détecté.', 'No issues detected.', '未发现问题。')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _findings.length,
      itemBuilder: (context, index) => _buildFinding(context, l10n, _findings[index]),
    );
  }

  Widget _buildFinding(BuildContext context, L10n l10n, HealthFinding finding) {
    final theme = Theme.of(context);
    final color = switch (finding.severity) {
      HealthSeverity.critical => theme.colorScheme.error,
      HealthSeverity.warning => Colors.orange,
      HealthSeverity.info => theme.disabledColor,
    };
    final text = _describe(l10n, finding);
    final action = _buildAction(context, l10n, finding);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          switch (finding.severity) {
            HealthSeverity.critical => Icons.error,
            HealthSeverity.warning => Icons.warning_amber,
            HealthSeverity.info => Icons.info_outline,
          },
          color: color,
        ),
        title: Text(text.title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: text.detail == null ? null : Text(text.detail!),
        trailing: action,
      ),
    );
  }

  Widget? _buildAction(BuildContext context, L10n l10n, HealthFinding finding) {
    // 节点相关的问题：能跳到节点就直接跳
    if (finding.nodeId != null && finding.code != HealthCode.nodeWithoutIp) {
      final node = _nodesById[finding.nodeId];
      if (node != null) {
        return TextButton(
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => NodeDetailScreen(node: node))),
          child: Text(l10n.t('Voir', 'View', '查看')),
        );
      }
    }
    switch (finding.code) {
      case HealthCode.zombieNodes:
        // 聚合类问题：带着这批节点直接进入批量操作页预选，一键清理。
        return TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BatchOperationsScreen(
                  initialSelection: finding.relatedNodeIds))),
          child: Text(l10n.t('Nettoyer', 'Clean up', '清理')),
        );
      case HealthCode.nodeWithoutIp:
        return TextButton(
          onPressed: _backfillIps,
          child: Text(l10n.t('Compléter les IP', 'Backfill IPs', '补全 IP')),
        );
      case HealthCode.policyInvalidJson:
      case HealthCode.policyGroupMemberNeedsAt:
      case HealthCode.policyGroupNameInvalid:
        return TextButton(
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AclScreen())),
          child: Text(l10n.t('Ouvrir les ACL', 'Open ACL', '打开 ACL')),
        );
      case HealthCode.derpAllUnreachable:
      case HealthCode.nodeKeyExpired:
      case HealthCode.nodeKeyExpiringSoon:
      case HealthCode.routesPendingApproval:
      case HealthCode.routeConflict:
      case HealthCode.tagWithoutOwner:
        return null;
    }
  }

  /// 把问题代码渲染成标题 + 说明（本地化在这里完成，逻辑里只有代码）。
  ({String title, String? detail}) _describe(L10n l10n, HealthFinding finding) {
    switch (finding.code) {
      case HealthCode.nodeKeyExpired:
        return (
          title: l10n.t('Clé expirée : ${finding.nodeName}',
              'Key expired: ${finding.nodeName}', '密钥已过期：${finding.nodeName}'),
          detail: l10n.t('Ce nœud ne pourra plus se connecter.',
              'This node can no longer connect.', '该节点将无法再连接。'),
        );
      case HealthCode.nodeKeyExpiringSoon:
        return (
          title: l10n.t('Clé bientôt expirée : ${finding.nodeName}',
              'Key expiring soon: ${finding.nodeName}', '密钥即将到期：${finding.nodeName}'),
          detail: l10n.t('Dans ${finding.detail} jours.',
              'In ${finding.detail} days.', '${finding.detail} 天后到期。'),
        );
      case HealthCode.zombieNodes:
        final parts = (finding.detail ?? '0|0').split('|');
        final total = parts.isNotEmpty ? parts[0] : '0';
        final sharing = parts.length > 1 ? parts[1] : '0';
        return (
          title: l10n.t('$total nœuds hors ligne depuis longtemps',
              '$total nodes offline for a long time',
              '$total 台节点长期离线'),
          detail: sharing == '0'
              ? l10n.t('Candidats au nettoyage — ils ne se sont pas connectés depuis plus de ${NetworkHealthService.offlineDaysThreshold} jours.',
                  'Cleanup candidates — they have not connected for over ${NetworkHealthService.offlineDaysThreshold} days.',
                  '可考虑清理——已超过 ${NetworkHealthService.offlineDaysThreshold} 天未连接。')
              : l10n.t('$sharing d\'entre eux partagent encore des routes ou sont des nœuds de sortie : à vérifier avant de supprimer.',
                  '$sharing of them still share routes or act as exit nodes: check before deleting.',
                  '其中 $sharing 台仍在共享路由或作为出口节点，删除前请确认。'),
        );
      case HealthCode.routesPendingApproval:
        return (
          title: l10n.t('Routes en attente d\'approbation : ${finding.nodeName}',
              'Routes awaiting approval: ${finding.nodeName}',
              '待批准的路由：${finding.nodeName}'),
          detail: finding.detail,
        );
      case HealthCode.nodeWithoutIp:
        return (
          title: l10n.t('Nœud sans adresse IP : ${finding.nodeName}',
              'Node without an IP: ${finding.nodeName}', '节点没有 IP 地址：${finding.nodeName}'),
          detail: null,
        );
      case HealthCode.routeConflict:
        return (
          title: l10n.t('Conflit de routes', 'Route conflict', '路由冲突'),
          detail: finding.detail,
        );
      case HealthCode.policyInvalidJson:
        return (
          title: l10n.t('Politique ACL illisible',
              'ACL policy is not valid JSON', 'ACL 策略不是合法 JSON'),
          detail: l10n.t('Le serveur refusera toute sauvegarde dans cet état.',
              'The server will reject any save in this state.', '当前状态下服务端会拒绝保存。'),
        );
      case HealthCode.policyGroupMemberNeedsAt:
        return (
          title: l10n.t('Référence utilisateur invalide dans la politique',
              'Invalid user reference in the policy', '策略中的用户引用非法'),
          detail: l10n.t('${finding.detail} doit contenir « @ » (ex. alice@).',
              '${finding.detail} must contain "@" (e.g. alice@).',
              '${finding.detail} 必须含「@」（例如 alice@）。'),
        );
      case HealthCode.policyGroupNameInvalid:
        return (
          title: l10n.t('Groupe sans préfixe « group: »',
              'Group missing the "group:" prefix', '分组缺少 group: 前缀'),
          detail: finding.detail,
        );
      case HealthCode.tagWithoutOwner:
        return (
          title: l10n.t('Tags non déclarés dans tagOwners',
              'Tags not declared in tagOwners', '标签未在 tagOwners 中声明'),
          detail: finding.detail,
        );
      case HealthCode.derpAllUnreachable:
        return (
          title: l10n.t('Aucun relais DERP joignable',
              'No DERP relay reachable', '没有可达的 DERP 中继'),
          detail: l10n.t(
            'Vérifiez le DERP intégré et que le proxy inverse laisse passer /bootstrap-dns et /derp/*.',
            'Check embedded DERP and that the reverse proxy allows /bootstrap-dns and /derp/*.',
            '请确认已启用内嵌 DERP，且反向代理放行了 /bootstrap-dns 与 /derp/*。',
          ),
        );
    }
  }
}
