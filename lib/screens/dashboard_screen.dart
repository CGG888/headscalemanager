import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:headscalemanager/services/route_conflict_service.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/screens/node_detail_screen.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<({List<Node> nodes, List<User> users})> _dataFuture;
  String _filterStatus = 'all'; // 'all', 'online', 'offline'

  @override
  void initState() {
    super.initState();
    _refreshNodes();
  }

  Future<void> _refreshNodes() async {
    if (mounted) {
      setState(() {
        _dataFuture = _fetchData();
      });
    }
    // Return a completed future to satisfy RefreshIndicator
    return Future.value();
  }

  Future<({List<Node> nodes, List<User> users})> _fetchData() async {
    final api = context.read<AppProvider>().apiService;
    final results = await Future.wait([
      api.getNodes(),
      api.getUsers(),
    ]);
    return (
      nodes: results[0] as List<Node>,
      users: results[1] as List<User>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FutureBuilder<({List<Node> nodes, List<User> users})>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child:
                      Text('${l10n.t('Erreur', 'Error', '错误')}: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.nodes.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refreshNodes,
                child: ListView(
                  children: [
                    Center(
                        child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child:
                          Text(l10n.t('Aucun nœud trouvé.', 'No node found.', '未找到节点。')),
                    ))
                  ],
                ),
              );
            }

            final allNodes = snapshot.data!.nodes;
            final allUsers = snapshot.data!.users;
            final connectedNodesCount =
                allNodes.where((node) => node.online).length;
            final disconnectedNodesCount =
                allNodes.length - connectedNodesCount;

            final filteredNodes = allNodes.where((node) {
              if (_filterStatus == 'online') return node.online;
              if (_filterStatus == 'offline') return !node.online;
              return true;
            }).toList();

            final filteredNodesByUser = <String, List<Node>>{};
            final orphanNodes = <Node>[];

            for (var node in filteredNodes) {
              final owner = node.getNormalizedOwner();
              User? matchedUser;
              for (var u in allUsers) {
                if (normalizeUserName(u.name) == owner) {
                  matchedUser = u;
                  break;
                }
              }
              if (matchedUser != null) {
                (filteredNodesByUser[matchedUser.name] ??= []).add(node);
              } else {
                orphanNodes.add(node);
              }
            }

            if (orphanNodes.isNotEmpty) {
              final orphanKey = l10n.t('Nœuds Orphelins', 'Orphan Nodes', '孤儿节点');
              filteredNodesByUser[orphanKey] = orphanNodes;
            }

            final users = filteredNodesByUser.keys.toList();

            // Détecte les nœuds dont l'utilisateur a un nom vide côté serveur
            // (créés automatiquement par OIDC sans nom) — avant que UsersScreen
            // ait eu le temps de corriger via renameUser.
            final oidcUsersMissingName = allNodes
                .where((n) => n.user.isEmpty || n.user == 'N/A')
                .toList();

            return RefreshIndicator(
              onRefresh: _refreshNodes,
              child: Column(
                children: [
                  if (oidcUsersMissingName.isNotEmpty)
                    _buildOidcWarningBanner(context, l10n),
                  _buildSummarySection(users.length, connectedNodesCount,
                      disconnectedNodesCount, l10n),
                  _buildFilterChips(l10n),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final userNodes = filteredNodesByUser[user]!;
                        return _UserNodeCard(
                          user: user,
                          nodes: userNodes,
                          allNodes: allNodes,
                          refreshNodes: _refreshNodes,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOidcWarningBanner(BuildContext context, L10n l10n) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_off_outlined, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.t('Un ou plusieurs nœuds OIDC ont un utilisateur sans nom. Ouvrez l\'écran Utilisateurs pour corriger automatiquement.', 'One or more OIDC nodes have a nameless user. Open the Users screen to auto-fix.', '一个或多个 OIDC 节点的用户没有名称。打开用户界面可自动修复。'),
              style: const TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
      int userCount, int connectedCount, int disconnectedCount, L10n l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        elevation: 0,
        color: Theme.of(context).cardColor,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                  title: l10n.t('Utilisateurs', 'Users', '用户'),
                  value: userCount.toString(),
                  color: Theme.of(context).textTheme.bodyMedium!.color!,
                  icon: Icons.people),
              SizedBox(
                  height: 40,
                  child: VerticalDivider(
                      thickness: 1, color: Theme.of(context).dividerColor)),
              _StatItem(
                  title: l10n.t('Connectés', 'Connected', '已连接'),
                  value: connectedCount.toString(),
                  color: Colors.green,
                  icon: Icons.lan),
              SizedBox(
                  height: 40,
                  child: VerticalDivider(
                      thickness: 1, color: Theme.of(context).dividerColor)),
              _StatItem(
                  title: l10n.t('Déconnectés', 'Disconnected', '已断开'),
                  value: disconnectedCount.toString(),
                  color: Colors.red,
                  icon: Icons.phonelink_off),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(L10n l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilterChip(
            label: Text(l10n.t('Tous', 'All', '全部')),
            selected: _filterStatus == 'all',
            onSelected: (selected) {
              if (selected) setState(() => _filterStatus = 'all');
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(l10n.t('En ligne', 'Online', '在线')),
            selected: _filterStatus == 'online',
            onSelected: (selected) {
              if (selected) setState(() => _filterStatus = 'online');
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(l10n.t('Hors ligne', 'Offline', '离线')),
            selected: _filterStatus == 'offline',
            onSelected: (selected) {
              if (selected) setState(() => _filterStatus = 'offline');
            },
          ),
        ],
      ),
    );
  }
}

// Helper functions for tag management - accessible by all classes in this file
List<String> _addCapabilities(List<String> tags,
    {bool addExitNode = false, bool addLanSharer = false}) {
  List<String> newTags = List.from(tags);
  int clientTagIndex = newTags.indexWhere((t) => t.contains('-client'));

  if (clientTagIndex != -1) {
    final oldClientTag = newTags[clientTagIndex];
    final parts = oldClientTag
        .replaceFirst('tag:', '')
        .split(';')
        .where((p) => p.isNotEmpty)
        .toSet();

    if (addExitNode) parts.add('exit-node');
    if (addLanSharer) parts.add('lan-sharer');

    final clientPart =
        parts.firstWhere((p) => p.contains('-client'), orElse: () => '');
    if (clientPart.isEmpty) return newTags; // Should not happen

    final otherParts = parts.where((p) => p != clientPart).toList()..sort();

    final newClientTagBuilder = StringBuffer('tag:$clientPart');
    if (otherParts.isNotEmpty) {
      newClientTagBuilder.write(';${otherParts.join(';')}');
    }
    newTags[clientTagIndex] = newClientTagBuilder.toString();

    // Remove standalone tags if they exist, as they are now consolidated
    if (addExitNode) newTags.removeWhere((t) => t == 'tag:exit-node');
    if (addLanSharer) newTags.removeWhere((t) => t == 'tag:lan-sharer');
  } else {
    if (addExitNode && !newTags.contains('tag:exit-node')) {
      newTags.add('tag:exit-node');
    }
    if (addLanSharer && !newTags.contains('tag:lan-sharer')) {
      newTags.add('tag:lan-sharer');
    }
  }
  return newTags;
}

List<String> _removeCapabilities(List<String> tags,
    {bool removeExitNode = false, bool removeLanSharer = false}) {
  List<String> newTags = List.from(tags);
  int clientTagIndex = newTags.indexWhere((t) => t.contains('-client'));

  if (clientTagIndex != -1) {
    final oldClientTag = newTags[clientTagIndex];
    final parts = oldClientTag
        .replaceFirst('tag:', '')
        .split(';')
        .where((p) => p.isNotEmpty)
        .toSet();

    if (removeExitNode) parts.remove('exit-node');
    if (removeLanSharer) parts.remove('lan-sharer');

    final clientPart =
        parts.firstWhere((p) => p.contains('-client'), orElse: () => '');
    if (clientPart.isEmpty) return newTags;

    final otherParts = parts.where((p) => p != clientPart).toList()..sort();

    final newClientTagBuilder = StringBuffer('tag:$clientPart');
    if (otherParts.isNotEmpty) {
      newClientTagBuilder.write(';${otherParts.join(';')}');
    }
    newTags[clientTagIndex] = newClientTagBuilder.toString();
  } else {
    if (removeExitNode) newTags.remove('tag:exit-node');
    if (removeLanSharer) newTags.remove('tag:lan-sharer');
  }
  return newTags;
}

/// Clean up obsolete lan-sharer tags from nodes that no longer have shared routes
/// This prevents orphaned route warnings and VPN disconnections
/// This function needs to be called from a State class with access to mounted and context
Future<List<Node>> _cleanupObsoleteLanSharerTags(
    BuildContext context, List<Node> nodes) async {
  final appProvider = context.read<AppProvider>();
  final apiService = appProvider.apiService;
  
  // Find nodes with lan-sharer tags but no shared routes
  final nodesToCleanup = nodes.where((node) {
    final hasLanSharerTag = node.tags.any((tag) => 
      tag.contains(';lan-sharer') || 
      tag == 'tag:lan-sharer' ||
      (tag.startsWith('tag:') && tag.contains('lan-sharer'))
    );
    return hasLanSharerTag && node.sharedRoutes.isEmpty;
  }).toList();
  
  // Clean up each affected node
  for (final node in nodesToCleanup) {
    final newTags = _removeCapabilities(List.from(node.tags), removeLanSharer: true);
    await apiService.setTags(node.id, newTags);
  }
  
  // Return refreshed nodes list
  return await apiService.getNodes();
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
              color: color, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _UserNodeCard extends StatelessWidget {
  final String user;
  final List<Node> nodes;
  final List<Node> allNodes;
  final VoidCallback refreshNodes;

  const _UserNodeCard(
      {required this.user,
      required this.nodes,
      required this.allNodes,
      required this.refreshNodes});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(user, style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.only(bottom: 8.0),
        children: nodes
            .map((node) => _buildNodeTile(context, node, allNodes))
            .toList(),
      ),
    );
  }

  Widget _buildNodeTile(BuildContext context, Node node, List<Node> allNodes) {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    final trailingIcon = _buildTrailingIcon(context, node, allNodes);

    return ListTile(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => NodeDetailScreen(node: node))),
      leading: Icon(Icons.circle,
          color: node.online ? Colors.green : Theme.of(context).disabledColor,
          size: 12),
      title: Row(
        children: [
          Flexible(
              child: Text(node.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis)),
          if (node.isExitNode)
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.exit_to_app, size: 16, color: Colors.orange),
            ),
          ..._buildKeyExpiryBadge(context, node, l10n),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(node.hostname, style: Theme.of(context).textTheme.bodySmall),
          Text(node.ipAddresses.join(', '),
              style: Theme.of(context).textTheme.bodySmall),
          if (node.sharedRoutes.isNotEmpty)
            Text(
              '${l10n.t('Routes', 'Routes', '路由')}: ${node.sharedRoutes.join(', ')}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
          Text(
              '${l10n.t('Dernière connexion', 'Last seen', '最后在线')}: ${node.lastSeen.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall),
          if (node.isExpired || node.isExpirySoon)
            Text(
              node.isExpired
                  ? l10n.t(
                      'Clé expirée — le nœud ne pourra plus se connecter',
                      'Key expired — this node can no longer connect',
                      '密钥已过期——该节点将无法再连接')
                  : l10n.t(
                      'Clé expire dans ${node.daysUntilExpiry} j',
                      'Key expires in ${node.daysUntilExpiry} d',
                      '密钥 ${node.daysUntilExpiry} 天后到期'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: node.isExpired
                      ? Theme.of(context).colorScheme.error
                      : Colors.orange),
            ),
        ],
      ),
      trailing: trailingIcon,
    );
  }

  /// 节点密钥临期/过期的列表标记。
  ///
  /// Headscale 的节点密钥默认有有效期（常为 180 天），**过期后节点会掉线**，
  /// 所以这是列表里少数值得主动提示的信息之一。返回空列表表示无需标记——
  /// 用列表是为了能在 Row 的 children 里直接用展开语法。
  List<Widget> _buildKeyExpiryBadge(
      BuildContext context, Node node, L10n l10n) {
    if (!node.isExpired && !node.isExpirySoon) return const [];
    final theme = Theme.of(context);
    final color = node.isExpired ? theme.colorScheme.error : Colors.orange;
    final days = node.daysUntilExpiry ?? 0;
    final label = node.isExpired
        ? l10n.t('Clé expirée', 'Key expired', '密钥已过期')
        : l10n.t('Clé expire dans $days j', 'Key expires in $days d',
            '密钥 $days 天后到期');
    final date = node.expiry?.toLocal().toString().split(' ').first ?? '';
    return [
      Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Tooltip(
          message: '$label  ($date)',
          child: Icon(
            node.isExpired ? Icons.key_off : Icons.key,
            size: 16,
            color: color,
          ),
        ),
      ),
    ];
  }

  Widget? _buildTrailingIcon(
      BuildContext context, Node node, List<Node> allNodes) {
    final l10n = L10n(context.read<AppProvider>().locale);
    final List<Widget> icons = [];

    // 1. Logique pour les routes en attente (approbation ou conflit)
    final pendingRoutes = node.availableRoutes
        .where((r) => !node.sharedRoutes.contains(r))
        .toList();

    if (pendingRoutes.isNotEmpty) {
      final pendingLanRoutes =
          pendingRoutes.where((r) => r != '0.0.0.0/0' && r != '::/0').toList();

      Map<String, Node> conflicts = {};
      List<String> approvableLanRoutes = [];

      for (var route in pendingLanRoutes) {
        final validation = RouteConflictService.validateRouteApproval(
            route, node.id, allNodes);
        if (validation.isConflict) {
          conflicts[route] = validation.conflictingNode!;
        } else {
          approvableLanRoutes.add(route);
        }
      }

      final hasPendingExitNode =
          pendingRoutes.any((r) => r == '0.0.0.0/0' || r == '::/0');

      if (conflicts.isNotEmpty) {
        icons.add(
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.red),
            tooltip: l10n.t('Certaines routes sont en conflit', 'Some routes are in conflict', '部分路由存在冲突'),
            onPressed: () => _showConflictInfoDialog(context, node, conflicts),
          ),
        );
      }

      if (approvableLanRoutes.isNotEmpty || hasPendingExitNode) {
        icons.add(
          IconButton(
            icon: const Icon(Icons.warning, color: Colors.amber),
            tooltip: l10n.t('Approbation requise', 'Approval required', '需要批准'),
            onPressed: () => _showApprovalDialog(context, node, allNodes),
          ),
        );
      }
    }

    // 2. Icône de désynchronisation
    final hasDesync =
        node.sharedRoutes.any((r) => !node.availableRoutes.contains(r));
    if (hasDesync) {
      icons.add(
        Container(
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.warning, color: Colors.blue),
            tooltip: l10n.t('Nettoyage de la configuration requis', 'Configuration cleanup required', '需要清理配置'),
            onPressed: () => _showCleanupDialog(context, node),
          ),
        ),
      );
    }

    if (icons.isEmpty) {
      return const SizedBox.shrink();
    }
    if (icons.length == 1) {
      return icons.first;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }

  void _showConflictInfoDialog(
      BuildContext context, Node node, Map<String, Node> conflicts) {
    final l10n = L10n(context.read<AppProvider>().locale);

    String content = l10n.t('Le nœud "${node.name}" ne peut pas partager les réseaux suivants car ils sont déjà utilisés :\n\n', 'Node "${node.name}" cannot share the following networks as they are already in use:\n\n', '节点 "${node.name}" 无法共享以下网络，因为它们已被占用：\n\n');

    conflicts.forEach((route, conflictingNode) {
      content += l10n.t('• Le réseau $route est déjà partagé par "${conflictingNode.name}".\n', '• Network $route is already shared by "${conflictingNode.name}".\n', '• 网络 $route 已由 "${conflictingNode.name}" 共享。\n');
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            l10n.t('Conflit de Routes Détecté', 'Route Conflict Detected', '检测到路由冲突')),
        content: Text(content),
        actions: [
          TextButton(
            child: Text(l10n.t('Fermer', 'Close', '关闭')),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showApprovalDialog(
      BuildContext context, Node node, List<Node> allNodes) {
    final appProvider = context.read<AppProvider>();
    final l10n = L10n(appProvider.locale);

    final pendingRoutes = node.availableRoutes
        .where((r) => !node.sharedRoutes.contains(r))
        .toList();
    final isExitNodeRequest =
        pendingRoutes.any((r) => r == '0.0.0.0/0' || r == '::/0');
    final lanRoutes =
        pendingRoutes.where((r) => r != '0.0.0.0/0' && r != '::/0').toList();

    String title = l10n.t('Approbation Requise', 'Approval Required', '需要批准');
    String content = '';

    final approvableLanRoutes = lanRoutes.where((route) {
      final validation =
          RouteConflictService.validateRouteApproval(route, node.id, allNodes);
      return !validation.isConflict;
    }).toList();

    if (approvableLanRoutes.isEmpty && !isExitNodeRequest) {
      // Ce cas ne devrait pas se produire car l'icône d'approbation n'est affichée
      // que si des routes approuvables existent. C'est une sécurité.
      return;
    }

    // Construire le message d'approbation
    if (isExitNodeRequest) {
      content += l10n.t('Le nœud "${node.name}" demande à devenir un Exit Node.', 'Node "${node.name}" is requesting to be an exit node.', '节点 "${node.name}" 请求成为出口节点。');
    }

    if (approvableLanRoutes.isNotEmpty) {
      if (content.isNotEmpty) content += '\n\n';
      content += l10n.isFr ? 'Routes qui seront approuvées :\n• ${approvableLanRoutes.join('\n• ')}\n\n'
          : 'Routes that will be approved:\n• ${approvableLanRoutes.join('\n• ')}\n\n';
    }

    content += l10n.t('Voulez-vous approuver cette (ces) demande(s) ?', 'Do you want to approve this (these) request(s)?', '要批准此（这些）请求吗？');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.t('Non', 'No', '否')),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text(l10n.t('Oui', 'Yes', '是')),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                if (!context.mounted) return;
                showSafeSnackBar(
                    context, l10n.t('Traitement en cours...', 'Processing...', '处理中……'));

                bool aclMode = true;
                try {
                  await appProvider.apiService.getAclPolicy();
                } catch (e) {
                  aclMode = false;
                }

                try {
                  final routesToApprove = [...approvableLanRoutes];
                  if (isExitNodeRequest) {
                    routesToApprove.addAll(pendingRoutes
                        .where((r) => r == '0.0.0.0/0' || r == '::/0'));
                  }

                  if (aclMode) {
                    // Full logic: Tags + Routes + ACLs
                    final newTags = _addCapabilities(
                      List.from(node.tags),
                      addExitNode: isExitNodeRequest,
                      addLanSharer: approvableLanRoutes.isNotEmpty,
                    );
                    await appProvider.apiService.setTags(node.id, newTags);

                    await appProvider.apiService
                        .setNodeRoutes(node.id, routesToApprove);

                    final allUsers = await appProvider.apiService.getUsers();
                    final updatedNodes =
                        await appProvider.apiService.getNodes();
                    final serverId = appProvider.activeServer?.id;
                    if (serverId == null) {
                      if (!context.mounted) return;
                      showSafeSnackBar(
                          context,
                          l10n.t('Aucun serveur actif sélectionné.', 'No active server selected.', '未选择活动服务器。'));
                      return;
                    }
                    final tempRules = await appProvider.storageService
                        .getTemporaryRules(serverId);
                    
                    if (!context.mounted) return;
                    // Clean up obsolete lan-sharer tags before ACL generation
                    final cleanedNodes = await _cleanupObsoleteLanSharerTags(context, updatedNodes);
                    
                    if (!context.mounted) return;
                    
                    final aclOrchestrator = AclPolicyOrchestrator();
                    final newPolicyMap = aclOrchestrator.generatePolicy(
                        engineMode: appProvider.aclEngineMode,
                        users: allUsers,
                        nodes: cleanedNodes,
                        temporaryRules: tempRules,
                        taildriveShares: appProvider.taildriveShares,
                        serverVersion: appProvider.serverVersion);
                    final newPolicyJson = jsonEncode(newPolicyMap);
                    await appProvider.apiService.setAclPolicy(newPolicyJson);

                    if (!context.mounted) return;
                    showSafeSnackBar(
                        context,
                        l10n.t('Nœud approuvé et ACLs mises à jour !', 'Node approved and ACLs updated!', '节点已批准，ACL 已更新！'));
                  } else {
                    // Simplified logic: Routes only
                    await appProvider.apiService
                        .setNodeRoutes(node.id, routesToApprove);
                    if (!context.mounted) return;
                    showSafeSnackBar(
                        context,
                        l10n.t('Routes approuvées (ACLs non gérées).', 'Routes approved (ACLs not managed).', '已批准路由（ACL 未管理）。'));
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  showSafeSnackBar(
                      context,
                      l10n.t('Échec de lapprrobation: $e', 'Approval failed: $e', '审批失败：$e'));
                } finally {
                  refreshNodes();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showCleanupDialog(BuildContext context, Node node) {
    final appProvider = context.read<AppProvider>();
    final l10n = L10n(appProvider.locale);

    final routesToClean = node.sharedRoutes
        .where((r) => !node.availableRoutes.contains(r))
        .toList();
    final hadExitNode =
        routesToClean.any((r) => r == '0.0.0.0/0' || r == '::/0');
    final lanRoutes =
        routesToClean.where((r) => r != '0.0.0.0/0' && r != '::/0').toList();
    final hadLanSharing = lanRoutes.isNotEmpty;

    String title =
        l10n.t('Attention : Suppression de Routes', 'Warning: Route Deletion', '警告：删除路由');
    String content = l10n.t('La configuration du nœud "${node.name}" est désynchronisée.\n\n', 'Node "${node.name}" configuration is out of sync.\n\n', '节点「${node.name}」配置已不同步。\n\n');

    if (hadExitNode) {
      content += l10n.t('Le client a désactivé sa fonction de Nœud de Sortie.\n', 'The client has disabled its Exit Node function.\n', '客户端已停用其出口节点功能。\n');
    }
    if (hadLanSharing) {
      content += l10n.isFr ? 'Le client a arrêté de partager le(s) sous-réseau(x) : ${lanRoutes.join(', ')}.\n'
          : 'The client has stopped sharing the subnet(s): ${lanRoutes.join(', ')}.\n';
    }
    content += l10n.t('\nATTENTION : Ces routes orphelines vont être SUPPRIMÉES de la configuration.\n\nVoulez-vous confirmer cette suppression ?', '\nWARNING: These orphaned routes will be DELETED from the configuration.\n\nDo you want to confirm this deletion?', '\n警告：这些孤立路由将从配置中删除。\n\n要确认此删除吗？');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.t('Non', 'No', '否')),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text(l10n.t('Oui, Supprimer', 'Yes, Delete', '是，删除')),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                if (!context.mounted) return;
                showSafeSnackBar(
                    context, l10n.t('Nettoyage en cours...', 'Cleaning up...', '正在清理……'));

                bool aclMode = true;
                try {
                  await appProvider.apiService.getAclPolicy();
                } catch (e) {
                  aclMode = false;
                }

                try {
                  final remainingRoutes = node.sharedRoutes
                      .where((r) => node.availableRoutes.contains(r))
                      .toList();

                  if (aclMode) {
                    // Full logic: Tags + Routes + ACLs
                    final newTags = _removeCapabilities(
                      List.from(node.tags),
                      removeExitNode: hadExitNode,
                      removeLanSharer: hadLanSharing,
                    );
                    await appProvider.apiService.setTags(node.id, newTags);

                    await appProvider.apiService
                        .setNodeRoutes(node.id, remainingRoutes);

                    final allUsers = await appProvider.apiService.getUsers();
                    final updatedNodes =
                        await appProvider.apiService.getNodes();
                    final serverId = appProvider.activeServer?.id;
                    if (serverId == null) {
                      if (!context.mounted) return;
                      showSafeSnackBar(
                          context,
                          l10n.t('Aucun serveur actif sélectionné.', 'No active server selected.', '未选择活动服务器。'));
                      return;
                    }
                    final tempRules = await appProvider.storageService
                        .getTemporaryRules(serverId);
                    
                    if (!context.mounted) return;
                    // Clean up obsolete lan-sharer tags before ACL generation
                    final cleanedNodes = await _cleanupObsoleteLanSharerTags(context, updatedNodes);
                    
                    if (!context.mounted) return;
                    
                    final aclOrchestrator = AclPolicyOrchestrator();
                    final newPolicyMap = aclOrchestrator.generatePolicy(
                        engineMode: appProvider.aclEngineMode,
                        users: allUsers,
                        nodes: cleanedNodes,
                        temporaryRules: tempRules,
                        taildriveShares: appProvider.taildriveShares,
                        serverVersion: appProvider.serverVersion);
                    final newPolicyJson = jsonEncode(newPolicyMap);
                    await appProvider.apiService.setAclPolicy(newPolicyJson);

                    if (!context.mounted) return;
                    showSafeSnackBar(
                        context,
                        l10n.t('Configuration nettoyée et ACLs mises à jour !', 'Configuration cleaned up and ACLs updated!', '配置已清理，ACL 已更新！'));
                  } else {
                    // Simplified logic: Routes only
                    await appProvider.apiService
                        .setNodeRoutes(node.id, remainingRoutes);
                    if (!context.mounted) return;
                    showSafeSnackBar(
                        context,
                        l10n.t('Configuration des routes nettoyée (ACLs non gérées).', 'Route configuration cleaned up (ACLs not managed).', '路由配置已清理（未管理 ACL）。'));
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  showSafeSnackBar(context,
                      l10n.t('Échec du nettoyage: $e', 'Cleanup failed: $e', '清理失败：$e'));
                } finally {
                  refreshNodes();
                }
              },
            ),
          ],
        );
      },
    );
  }
}
