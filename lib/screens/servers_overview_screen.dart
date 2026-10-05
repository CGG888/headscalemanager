import 'package:flutter/material.dart';
import 'package:headscalemanager/api/headscale_api_service.dart';
import 'package:headscalemanager/l10n/l10n.dart';
import 'package:headscalemanager/models/server.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/server_summary_service.dart';
import 'package:provider/provider.dart';

/// 多服务器总览：一页看到所有已配置 Headscale 的状态。
///
/// 每台服务器用**自己的 API 密钥**并行拉取，因此一台不可达不会影响其他台；
/// 汇总只做"哪个服务器有异常"这一件事，点一下即可切换过去处理。
class ServersOverviewScreen extends StatefulWidget {
  const ServersOverviewScreen({super.key});

  @override
  State<ServersOverviewScreen> createState() => _ServersOverviewScreenState();
}

class _ServerState {
  bool loading = true;
  ServerNodeSummary? summary;
  String? version;
  String? error;
}

class _ServersOverviewScreenState extends State<ServersOverviewScreen> {
  final Map<String, _ServerState> _states = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    final provider = context.read<AppProvider>();
    final servers = provider.servers;
    if (!mounted) return;
    setState(() {
      _states
        ..clear()
        ..addEntries(servers.map((s) => MapEntry(s.id, _ServerState())));
    });

    await Future.wait(servers.map((server) async {
      final state = _ServerState();
      try {
        final api = HeadscaleApiService(
          apiKey: server.apiKey,
          baseUrl: server.url,
          locale: provider.locale,
        );
        final nodes = await api.getNodes();
        state.summary = ServerNodeSummary.of(nodes);
        try {
          state.version = (await api.getVersion()).version;
        } catch (_) {
          state.version = null; // 版本取不到不影响概览
        }
      } catch (e) {
        state.error = e.toString();
      }
      state.loading = false;
      if (!mounted) return;
      setState(() => _states[server.id] = state);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<AppProvider>();
    final servers = provider.servers;

    // 有问题的服务器排在前面（同一台异常越多越靠前），方便一眼看到要处理的
    final sorted = [...servers]..sort((a, b) {
        final ia = _states[a.id]?.summary?.issueCount ?? -1;
        final ib = _states[b.id]?.summary?.issueCount ?? -1;
        if (ia != ib) return ib.compareTo(ia);
        return a.name.compareTo(b.name);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('Serveurs', 'Servers', '服务器总览')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
        ],
      ),
      body: servers.isEmpty
          ? Center(
              child: Text(l10n.t('Aucun serveur configuré.',
                  'No server configured.', '尚未配置服务器。')))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sorted.length,
              itemBuilder: (context, index) =>
                  _buildServerCard(l10n, sorted[index], provider),
            ),
    );
  }

  Widget _buildServerCard(L10n l10n, Server server, AppProvider provider) {
    final state = _states[server.id];
    final theme = Theme.of(context);
    final isActive = provider.activeServer?.id == server.id;
    final summary = state?.summary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await provider.switchServer(server.id);
          if (mounted) Navigator.of(context).pop();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      server.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isActive)
                    Chip(
                      label: Text(l10n.t('Actif', 'Active', '当前')),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              Text(server.url, style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              if (state == null || state.loading)
                Row(
                  children: [
                    const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text(l10n.t('Chargement…', 'Loading…', '加载中……')),
                  ],
                )
              else if (state.error != null)
                Text(
                  '${l10n.t('Injoignable', 'Unreachable', '无法连接')}: ${state.error}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                )
              else if (summary != null) ...[
                Text(
                  l10n.t(
                    '${summary.total} nœuds · ${summary.online} en ligne',
                    '${summary.total} nodes · ${summary.online} online',
                    '${summary.total} 个节点 · ${summary.online} 在线',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                if (state.version != null)
                  Text('v${state.version}',
                      style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                if (!summary.hasIssues)
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(l10n.t('Aucun problème détecté.',
                          'No issue detected.', '未发现问题。')),
                    ],
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (summary.expiredKeys > 0)
                        _issueChip(l10n.t('${summary.expiredKeys} clés expirées',
                            '${summary.expiredKeys} expired keys',
                            '${summary.expiredKeys} 个密钥已过期'), theme.colorScheme.error),
                      if (summary.expiringSoon > 0)
                        _issueChip(l10n.t('${summary.expiringSoon} clés bientôt expirées',
                            '${summary.expiringSoon} expiring soon',
                            '${summary.expiringSoon} 个密钥临期'), Colors.orange),
                      if (summary.pendingRoutes > 0)
                        _issueChip(l10n.t('${summary.pendingRoutes} routes en attente',
                            '${summary.pendingRoutes} pending routes',
                            '${summary.pendingRoutes} 个节点待批路由'), Colors.orange),
                      if (summary.withoutIp > 0)
                        _issueChip(l10n.t('${summary.withoutIp} nœuds sans IP',
                            '${summary.withoutIp} nodes without IP',
                            '${summary.withoutIp} 个节点无 IP'), Colors.orange),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _issueChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: color)),
      );
}
