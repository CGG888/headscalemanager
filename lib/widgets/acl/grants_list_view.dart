import 'package:flutter/material.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class GrantsListView extends StatelessWidget {
  final List<dynamic> grants;
  final L10n l10n;
  final void Function(int networkIndex, Map<String, dynamic> grant)? onEditGrant;
  final void Function(int networkIndex)? onDeleteGrant;

  const GrantsListView({
    super.key,
    required this.grants,
    required this.l10n,
    this.onEditGrant,
    this.onDeleteGrant,
  });

  static bool isTaildriveGrant(Map<String, dynamic> grant) {
    final app = grant['app'];
    if (app is! Map) return false;
    return app.containsKey('tailscale.com/cap/drive') ||
        app.containsKey('tailscale.com/cap/taildrive');
  }

  static bool isNetworkGrant(Map<String, dynamic> grant) {
    return grant.containsKey('ip') && !isTaildriveGrant(grant);
  }

  @override
  Widget build(BuildContext context) {
    final networkEntries = <({int index, Map<String, dynamic> grant})>[];
    for (var i = 0; i < grants.length; i++) {
      final g = grants[i];
      if (g is Map<String, dynamic> && isNetworkGrant(g)) {
        networkEntries.add((index: networkEntries.length, grant: g));
      } else if (g is Map && isNetworkGrant(Map<String, dynamic>.from(g))) {
        networkEntries.add(
            (index: networkEntries.length, grant: Map<String, dynamic>.from(g)));
      }
    }

    final taildriveGrants = grants
        .whereType<Map<String, dynamic>>()
        .where(isTaildriveGrant)
        .toList();

    if (networkEntries.isEmpty && taildriveGrants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.t('Aucun grant réseau dans la politique.', 'No network grants in policy.', '策略中无网络授权。'),
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (networkEntries.isNotEmpty) ...[
          Text(
            l10n.t('Grants réseau (ip + via)', 'Network grants (ip + via)', '网络授权（ip + via）'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...networkEntries.map((e) => _GrantTile(
                grant: e.grant,
                l10n: l10n,
                onTap: onEditGrant != null
                    ? () => onEditGrant!(e.index, e.grant)
                    : null,
                onDelete: onDeleteGrant != null
                    ? () => onDeleteGrant!(e.index)
                    : null,
              )),
        ],
        if (taildriveGrants.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.t('Grants Taildrive', 'Taildrive grants', 'Taildrive 授权'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...taildriveGrants.map((g) => _GrantTile(
                grant: g,
                l10n: l10n,
                isTaildrive: true,
              )),
        ],
      ],
    );
  }
}

class _GrantTile extends StatelessWidget {
  final Map<String, dynamic> grant;
  final L10n l10n;
  final bool isTaildrive;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _GrantTile({
    required this.grant,
    required this.l10n,
    this.isTaildrive = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final src = (grant['src'] as List?)?.join(', ') ?? '?';
    final dst = (grant['dst'] as List?)?.join(', ') ?? '?';
    final via = (grant['via'] as List?)?.join(', ');
    final ip = (grant['ip'] as List?)?.join(', ') ?? '*';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isTaildrive ? Icons.folder_shared : Icons.route,
          color: via != null ? Colors.purple : Colors.blue,
        ),
        title: Text('$src → $dst'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (via != null)
              Text(
                l10n.t('Via : $via', 'Via: $via', 'Via：$via'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.purple),
              ),
            Text(l10n.t('IP : $ip', 'IP: $ip', 'IP：$ip')),
            if (onTap != null)
              Text(
                l10n.t('Appuyer pour modifier', 'Tap to edit', '点击编辑'),
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
