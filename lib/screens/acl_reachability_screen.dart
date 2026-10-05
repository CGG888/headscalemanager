import 'package:flutter/material.dart';
import 'package:headscalemanager/l10n/l10n.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/acl/acl_reachability_service.dart';
import 'package:provider/provider.dart';

/// ACL 可达性视图：把策略折算成"谁能访问谁"，并列出高风险规则。
///
/// 策略一多就没人看得懂，这个页面回答两个问题：
///  1. 有没有危险规则（全通、对所有人开放互联网/SSH、放行出口节点全流量）；
///  2. 每个源实际能到达哪些目标、开在哪些端口。
class AclReachabilityScreen extends StatefulWidget {
  const AclReachabilityScreen({super.key});

  @override
  State<AclReachabilityScreen> createState() => _AclReachabilityScreenState();
}

class _AclReachabilityScreenState extends State<AclReachabilityScreen> {
  bool _isLoading = true;
  String? _error;
  AclReachability? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final policy = await context.read<AppProvider>().apiService.getAclPolicy();
      if (!mounted) return;
      setState(() {
        _result = AclReachabilityService.analyze(policy);
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('Visibilité ACL', 'ACL visibility', 'ACL 可达性')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(L10n l10n) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
              '${l10n.t('Échec du chargement', 'Failed to load', '加载失败')}: $_error',
              textAlign: TextAlign.center),
        ),
      );
    }
    final result = _result!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _sectionTitle(l10n.t('Risques', 'Risks', '风险'), theme),
        if (result.risks.isEmpty)
          ListTile(
            leading: Icon(Icons.verified_outlined,
                color: theme.colorScheme.primary),
            title: Text(l10n.t('Aucun risque détecté.',
                'No risk detected.', '未发现风险。')),
          )
        else
          for (final risk in result.risks) _buildRisk(l10n, risk, theme),
        const Divider(height: 24),
        _sectionTitle(
            l10n.t('Qui peut accéder à quoi', 'Who can reach what', '谁能访问谁'),
            theme),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            l10n.t(
              '${result.sourceCount} source(s), ${result.edges.length} relation(s).',
              '${result.sourceCount} source(s), ${result.edges.length} relation(s).',
              '${result.sourceCount} 个源、${result.edges.length} 条关系。',
            ),
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (result.edges.isEmpty)
          ListTile(
            title: Text(l10n.t('Aucune règle d\'accès.',
                'No access rule.', '没有访问规则。')),
          )
        else
          for (final edge in result.edges) _buildEdge(l10n, edge, theme),
      ],
    );
  }

  Widget _sectionTitle(String text, ThemeData theme) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(text,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _buildRisk(L10n l10n, AclRisk risk, ThemeData theme) {
    final color = switch (risk.severity) {
      AclRiskSeverity.critical => theme.colorScheme.error,
      AclRiskSeverity.warning => Colors.orange,
      AclRiskSeverity.info => theme.disabledColor,
    };
    final icon = switch (risk.severity) {
      AclRiskSeverity.critical => Icons.error,
      AclRiskSeverity.warning => Icons.warning_amber,
      AclRiskSeverity.info => Icons.info_outline,
    };
    final text = switch (risk.code) {
      AclRiskCode.allowAll => l10n.t(
          'Règle « tout vers tout » : tout le monde peut joindre tout le monde.',
          'Allow-all rule: everyone can reach everything.',
          '「全通」规则：任何人都能访问任何目标。'),
      AclRiskCode.internetOpenToAll => l10n.t(
          'Accès Internet (autogroup:internet) ouvert à tous les appareils.',
          'Internet access (autogroup:internet) is open to every device.',
          '互联网出口（autogroup:internet）对所有设备开放。'),
      AclRiskCode.sshOpenToAll => l10n.t(
          'SSH (port 22) ouvert à tous les appareils.',
          'SSH (port 22) is open to every device.',
          'SSH（22 端口）对所有设备开放。'),
      AclRiskCode.exitNodeOpen => l10n.t(
          'Accès à tous les itinéraires (0.0.0.0/0 ou ::/0) : les nœuds de sortie ne sont pas restreints.',
          'Access to every route (0.0.0.0/0 or ::/0): exit nodes are unrestricted.',
          '放行全部路由（0.0.0.0/0 或 ::/0）：出口节点未被限制。'),
      AclRiskCode.wildcardDestination => l10n.t(
          'Destination générique « * » : vérifiez que c\'est voulu.',
          'Wildcard destination "*": make sure it is intended.',
          '目标使用通配「*」：请确认这是有意为之。'),
      AclRiskCode.noRules => l10n.t(
          'Aucune règle d\'accès dans la politique.',
          'The policy contains no access rule.',
          '策略里没有任何访问规则。'),
    };

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(text),
      subtitle: risk.detail == null ? null : Text(risk.detail!),
    );
  }

  Widget _buildEdge(L10n l10n, ReachabilityEdge edge, ThemeData theme) => ListTile(
        dense: true,
        leading: Icon(Icons.arrow_forward,
            size: 16, color: theme.colorScheme.primary),
        title: Text('${edge.source}  →  ${edge.destination}'),
        subtitle: Text(
            '${l10n.t('Ports', 'Ports', '端口')}: ${edge.ports.join(', ')}'),
      );
}
