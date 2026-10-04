import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:headscalemanager/services/route_conflict_service.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:dart_ping/dart_ping.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:headscalemanager/utils/grants_v29_gate.dart';
import 'package:headscalemanager/widgets/acl/grant_composer_sheet.dart';
import 'package:headscalemanager/services/acl/grant_composer_service.dart';
import 'package:headscalemanager/widgets/rename_node_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class NodeDetailScreen extends StatefulWidget {
  final Node node;

  const NodeDetailScreen({super.key, required this.node});

  @override
  State<NodeDetailScreen> createState() => _NodeDetailScreenState();
}

class _NodeDetailScreenState extends State<NodeDetailScreen> {
  bool _isPingingContinuously = false;
  StreamSubscription<PingData>? _pingSubscription;
  late Node _currentNode;
  late Set<String> _selectedRoutes;
  final List<PingData> _pingResponses = [];
  bool _isMonitoringEnabled = false;

  @override
  void initState() {
    super.initState();
    _currentNode = widget.node;
    _selectedRoutes = Set<String>.from(_currentNode.sharedRoutes);
    _loadMonitoringStatus();
  }

  Future<void> _loadMonitoringStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final monitoredNodes = prefs.getStringList('monitoredNodeIds') ?? [];
    if (!mounted) return;
    setState(() {
      _isMonitoringEnabled = monitoredNodes.contains(_currentNode.id);
    });
  }

  Future<void> _toggleMonitoring(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> monitoredNodes = prefs.getStringList('monitoredNodeIds') ?? [];
    String lastKnownStatusKey = 'monitoredNode_${_currentNode.id}_status';
    if (!mounted) return;
    setState(() {
      _isMonitoringEnabled = value;
    });

    if (value) {
      if (!monitoredNodes.contains(_currentNode.id)) {
        monitoredNodes.add(_currentNode.id);
      }
      // Store the current status to avoid immediate notification
      await prefs.setBool(lastKnownStatusKey, _currentNode.online);
    } else {
      monitoredNodes.remove(_currentNode.id);
      // Clean up the stored status
      await prefs.remove(lastKnownStatusKey);
    }
    await prefs.setStringList('monitoredNodeIds', monitoredNodes);
  }

  String get _ipv4 {
    return _currentNode.ipAddresses
        .firstWhere((ip) => !ip.contains(':'), orElse: () => '');
  }

  String get _ipv6 {
    return _currentNode.ipAddresses
        .firstWhere((ip) => ip.contains(':'), orElse: () => '');
  }

  @override
  void dispose() {
    _pingSubscription?.cancel();
    super.dispose();
  }

  void _toggleContinuousPing(bool value) {
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);
    setState(() {
      _isPingingContinuously = value;
      _pingResponses.clear();
    });

    if (_isPingingContinuously) {
      if (_ipv4.isEmpty) {
        setState(() => _isPingingContinuously = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.t('Aucune adresse IPv4 trouvée pour ce nœud.', 'No IPv4 address found for this node.', '未找到此节点的 IPv4 地址。'))),
        );
        return;
      }

      final ping = Ping(_ipv4, count: 10000); // Effectively continuous
      _pingSubscription = ping.stream.listen((event) {
        if (mounted) setState(() => _pingResponses.add(event));
      }, onDone: () {
        if (mounted) setState(() => _isPingingContinuously = false);
      });
    } else {
      _pingSubscription?.cancel();
    }
  }

  Future<void> _openGrantComposer(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final l10n = L10n(provider.locale);

    if (!GrantsV29Gate.isAvailable(
      engineMode: provider.aclEngineMode,
      serverVersion: provider.serverVersion,
    )) {
      return;
    }

    try {
      final users = await provider.apiService.getUsers();
      final nodes = await provider.apiService.getNodes();
      if (!context.mounted) return;

      final result = await GrantComposerSheet.show(
        context,
        users: users,
        nodes: nodes,
        l10n: l10n,
        prefilledRouterNode: _currentNode,
      );

      if (result == null || !context.mounted) return;

      final tempRules = await provider.storageService
          .getTemporaryRules(provider.activeServer!.id);
      final orchestrator = AclPolicyOrchestrator();
      var policy = orchestrator.generatePolicy(
        engineMode: provider.aclEngineMode,
        users: users,
        nodes: nodes,
        temporaryRules: tempRules,
        taildriveShares: provider.taildriveShares,
        serverVersion: provider.serverVersion,
      );

      if (result.containsKey('action')) {
        policy = GrantComposerService.appendExceptionAcl(policy, result);
      } else {
        policy = GrantComposerService.appendNetworkGrant(policy, result);
      }

      final jsonPolicy = const JsonEncoder.withIndent('  ').convert(policy);
      await provider.apiService.setAclPolicy(jsonPolicy);

      if (context.mounted) {
        showSafeSnackBar(
          context,
          l10n.t('Grant ajouté et policy mise à jour sur le serveur.', 'Grant added and policy updated on server.', '已添加授权并更新服务器上的策略。'),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showSafeSnackBar(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AppProvider>();
    final l10n = L10n(provider.locale);
    final showComposer = GrantsV29Gate.isAvailable(
      engineMode: provider.aclEngineMode,
      serverVersion: provider.serverVersion,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.node.name, style: theme.appBarTheme.titleTextStyle),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.appBarTheme.iconTheme,
        actions: [
          if (showComposer)
            IconButton(
              icon: const Icon(Icons.auto_fix_high),
              tooltip: l10n.t('Composer une règle', 'Compose a rule', '编写规则'),
              onPressed: () => _openGrantComposer(context),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildMainInfoCard(context),
            const SizedBox(height: 16),
            _buildMonitoringCard(context),
            const SizedBox(height: 16),
            _buildIpAddressesCard(context),
            const SizedBox(height: 16),
            _buildIdentifiersCard(context),
            const SizedBox(height: 16),
            _buildRoutesCard(context),
            const SizedBox(height: 16),
            _buildTagsAndRoutesCard(context),
            const SizedBox(height: 16),
            _buildPingCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMainInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle,
                  color: _currentNode.online
                      ? Colors.green
                      : theme.colorScheme.onPrimary.withValues(alpha: 0.5),
                  size: 16),
              const SizedBox(width: 8),
              Text(
                  _currentNode.online
                      ? (l10n.t('En ligne', 'Online', '在线'))
                      : (l10n.t('Hors ligne', 'Offline', '离线')),
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: _currentNode.online
                          ? Colors.green
                          : theme.colorScheme.onPrimary.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (widget.node.isExitNode)
                Chip(
                    label: Text('Exit Node',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.primary)),
                    backgroundColor: theme.colorScheme.onPrimary,
                    labelStyle: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () => _showDeviceIconPickerDialog(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Tooltip(
                    message: l10n.t('Changer le type d\'appareil', 'Change device type', '更改设备类型'),
                    child: Icon(
                      context.watch<AppProvider>().getDeviceIcon(_currentNode),
                      color: theme.colorScheme.onPrimary,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(_currentNode.hostname,
                    style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary)),
              ),
              if (!isValidDns1123Subdomain(_currentNode.name))
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 24),
                    tooltip: l10n.t('Nom invalide (v0.27+)', 'Invalid name (v0.27+)', '名称无效（v0.27+）'),
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (dialogContext) => RenameNodeDialog(
                              node: _currentNode,
                              onNodeRenamed: () async {
                                // Refresh local node details
                                final updated = await context
                                    .read<AppProvider>()
                                    .apiService
                                    .getNodeDetails(_currentNode.id);
                                if (context.mounted) {
                                  setState(() => _currentNode = updated);
                                }
                              }));
                    },
                  ),
                )
            ],
          ),
          const SizedBox(height: 4),
          Text('${l10n.t('Utilisateur', 'User', '用户')}: ${_currentNode.user}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onPrimary)),
          const SizedBox(height: 8),
          Text(
              '${l10n.t('Dernière connexion', 'Last seen', '最后在线')}: ${_currentNode.lastSeen.toLocal()}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  void _showDeviceIconPickerDialog(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.read<AppProvider>();
    final l10n = L10n(provider.locale);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.t('Sélectionner le type d\'appareil', 'Select Device Type', '选择设备类型'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 280,
                  height: 160,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: deviceIconsPalette.length,
                    itemBuilder: (context, index) {
                      final key = deviceIconsPalette.keys.elementAt(index);
                      final iconData = deviceIconsPalette[key]!;
                      final isSelected = provider.getDeviceIconKey(_currentNode) == key;

                      String label = key;
                      if (l10n.isFr) {
                        if (key == 'generic') label = 'Générique';
                        if (key == 'server') label = 'Serveur';
                      }

                      return InkWell(
                        onTap: () async {
                          await provider.setDeviceTypeIcon(_currentNode.id, key);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          setState(() {});
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: theme.colorScheme.onPrimary, width: 2)
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                iconData,
                                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                label.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.t('Annuler', 'Cancel', '取消')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonitoringCard(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n(context.watch<AppProvider>().locale);

    return _SectionCard(
      child: SwitchListTile(
        title: Text(l10n.t('Surveiller le statut', 'Monitor Status', '监控状态'),
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.onPrimary)),
        subtitle: Text(
            l10n.t('Recevoir une notification si le nœud se connecte ou se déconnecte.', 'Receive a notification if the node goes online or offline.', '节点上线或离线时接收通知。'),
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.7))),
        value: _isMonitoringEnabled,
        onChanged: _toggleMonitoring,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildIpAddressesCard(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('Adresses IP', 'IP Addresses', 'IP 地址'),
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary)),
          Divider(
              height: 20,
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.5)),
          if (_ipv4.isNotEmpty) _DetailRowWithCopy(label: 'IPv4', value: _ipv4),
          if (_ipv6.isNotEmpty) _DetailRowWithCopy(label: 'IPv6', value: _ipv6),
        ],
      ),
    );
  }

  Widget _buildIdentifiersCard(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('Identifiants', 'Identifiers', '标识符'),
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary)),
          Divider(
              height: 20,
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.5)),
          _DetailRowWithCopy(
              label: l10n.t('ID Nœud', 'Node ID', '节点 ID'), value: _currentNode.id),
          _DetailRowWithCopy(
              label: l10n.t('Clé Machine', 'Machine Key', '设备密钥'),
              value: _currentNode.machineKey),
          _DetailRowWithCopy(label: 'FQDN', value: _currentNode.fqdn),
        ],
      ),
    );
  }

  Widget _buildRoutesCard(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    final allPossibleRoutes = (Set<String>.from(_currentNode.availableRoutes)
          ..addAll(_currentNode.sharedRoutes))
        .toList();

    if (allPossibleRoutes.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('Gestion des Routes', 'Route Management', '路由管理'),
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary)),
          Divider(
              height: 20,
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.5)),
          Text(
              l10n.t('Cochez les routes que vous souhaitez approuver pour ce nœud.', 'Check the routes you want to approve for this node.', '勾选要为此节点批准的路由。'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onPrimary)),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allPossibleRoutes.length,
            itemBuilder: (context, index) {
              final route = allPossibleRoutes[index];
              return CheckboxListTile(
                title: Text(route,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onPrimary)),
                value: _selectedRoutes.contains(route),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedRoutes.add(route);
                    } else {
                      _selectedRoutes.remove(route);
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                checkColor: theme.colorScheme.primary,
                activeColor: theme.colorScheme.onPrimary,
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _saveRoutes,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(l10n.t('Appliquer les changements', 'Apply Changes', '应用更改'),
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsAndRoutesCard(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tags',
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary)),
          Divider(
              height: 20,
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.5)),
          Text('Tags:',
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: _currentNode.tags.isEmpty
                ? [
                    Text(l10n.t('Aucun tag', 'No tags', '无标签'),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onPrimary))
                  ]
                : _currentNode.tags
                    .map((tag) => Chip(
                          label: Text(tag,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: theme.colorScheme.primary)),
                          backgroundColor: theme.colorScheme.onPrimary,
                        ))
                    .toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRoutes() async {
    final appProvider = context.read<AppProvider>();
    final apiService = appProvider.apiService;
    final l10n = L10n(appProvider.locale);

    try {
      // Obtenir tous les nœuds pour la validation
      final allNodes = await apiService.getNodes();

      // Vérifier les conflits pour les nouvelles routes sélectionnées
      final newRoutes =
          _selectedRoutes.difference(Set.from(_currentNode.sharedRoutes));
      List<String> conflictRoutes = [];

      for (var route in newRoutes) {
        // Ignorer les routes exit node
        if (route == '0.0.0.0/0' || route == '::/0') continue;

        final validation = RouteConflictService.validateRouteApproval(
            route, _currentNode.id, allNodes);

        if (validation.isConflict) {
          conflictRoutes.add(route);
        }
      }

      // Si il y a des conflits, afficher un message d'erreur et empêcher la sauvegarde
      if (conflictRoutes.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(l10n.t('Conflit Détecté', 'Conflict Detected', '检测到冲突')),
                content: Text(l10n.isFr ? 'Impossible d\'approuver les routes suivantes car elles sont déjà utilisées par d\'autres utilisateurs :\n\n• ${conflictRoutes.join('\n• ')}\n\nVeuillez décocher ces routes avant de continuer.'
                    : 'Cannot approve the following routes as they are already used by other users:\n\n• ${conflictRoutes.join('\n• ')}\n\nPlease uncheck these routes before continuing.'),
                actions: <Widget>[
                  TextButton(
                    child: Text(l10n.t('Compris', 'Understood', '知道了')),
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Décocher automatiquement les routes en conflit
                      setState(() {
                        for (var route in conflictRoutes) {
                          _selectedRoutes.remove(route);
                        }
                      });
                    },
                  ),
                ],
              );
            },
          );
        }
        return;
      }

      // Procéder à la sauvegarde si aucun conflit
      if (!mounted) return;
      showSafeSnackBar(
          context, l10n.t('Mise à jour des routes...', 'Updating routes...', '正在更新路由……'));
      await apiService.setNodeRoutes(_currentNode.id, _selectedRoutes.toList());

      // Régénérer et appliquer les ACLs
      if (!mounted) return;
      showSafeSnackBar(
          context, l10n.t('Mise à jour des ACLs...', 'Updating ACLs...', '正在更新 ACL……'));
      final allUsers = await apiService.getUsers();
      final updatedNodes = await apiService.getNodes(); // Re-fetch nodes
      final serverId = appProvider.activeServer?.id;
      if (serverId == null) {
        if (!mounted) return;
        showSafeSnackBar(
            context,
            l10n.t('Aucun serveur actif sélectionné.', 'No active server selected.', '未选择活动服务器。'));
        return;
      }
      final tempRules =
          await appProvider.storageService.getTemporaryRules(serverId);
      
      // Clean up obsolete lan-sharer tags before ACL generation
      final cleanedNodes = await _cleanupObsoleteLanSharerTags(updatedNodes);

      final aclOrchestrator = AclPolicyOrchestrator();
      final newPolicyMap = aclOrchestrator.generatePolicy(
        engineMode: appProvider.aclEngineMode,
        users: allUsers,
        nodes: cleanedNodes,
        temporaryRules: tempRules,
        taildriveShares: appProvider.taildriveShares,
        serverVersion: appProvider.serverVersion,
      );
      final newPolicyJson = jsonEncode(newPolicyMap);
      await apiService.setAclPolicy(newPolicyJson);

      if (mounted) {
        showSafeSnackBar(
            context,
            l10n.t('Routes et ACLs mises à jour avec succès !', 'Routes and ACLs updated successfully!', '路由与 ACL 更新成功！'));

        // Rafraîchir l'état local
        final freshlyUpdatedNode =
            await apiService.getNodeDetails(_currentNode.id);
        setState(() {
          _currentNode = freshlyUpdatedNode;
          _selectedRoutes = Set<String>.from(_currentNode.sharedRoutes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.t('Erreur', 'Error', '错误')}: $e')));
      }
    }
  }

  Widget _buildPingCard(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ExpansionTile(
        title: Text(l10n.t('Outils de diagnostic', 'Diagnostic Tools', '诊断工具'),
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimary)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(l10n.t("Ping en continu", "Continuous Ping", '持续 ping'),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onPrimary)),
                    const Spacer(),
                    Switch(
                      value: _isPingingContinuously,
                      onChanged: _toggleContinuousPing,
                      activeThumbColor: theme.colorScheme.onPrimary,
                      inactiveTrackColor:
                          theme.colorScheme.onPrimary.withValues(alpha: 0.3),
                      inactiveThumbColor:
                          theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                (() {
                  final provider = context.watch<AppProvider>();
                  final threshold = provider.getPingLatencyThresholdSync(_currentNode.id);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.t("Seuil d'alerte latence", "Latency alert threshold", '延迟告警阈值'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${threshold.round()} ms",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: theme.colorScheme.onPrimary,
                          inactiveTrackColor: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                          thumbColor: theme.colorScheme.onPrimary,
                          overlayColor: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
                          valueIndicatorColor: theme.colorScheme.secondary,
                          valueIndicatorTextStyle: TextStyle(color: theme.colorScheme.onSecondary),
                        ),
                        child: Slider(
                          value: threshold,
                          min: 10.0,
                          max: 500.0,
                          divisions: 49,
                          label: "${threshold.round()} ms",
                          onChanged: (val) {
                            provider.setPingLatencyThreshold(_currentNode.id, val);
                          },
                        ),
                      ),
                    ],
                  );
                })(),
                const SizedBox(height: 10),
                if (_isPingingContinuously)
                  _buildContinuousPingResults(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinuousPingResults(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    if (_pingResponses.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }

    final responses = _pingResponses
        .where((e) => e.response != null)
        .map((e) => e.response!)
        .toList();
    final transmitted = _pingResponses.length;
    final received = responses.length;
    final loss = transmitted > 0 ? (1 - received / transmitted) * 100 : 0;

    final latencies = responses
        .where((e) => e.time != null)
        .map((e) => e.time!.inMilliseconds)
        .toList();
    final avgLatency = latencies.isNotEmpty
        ? latencies.reduce((a, b) => a + b) / latencies.length
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            "${l10n.t('Latence moyenne', 'Average latency', '平均延迟')}: ${avgLatency.toStringAsFixed(2)} ms",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onPrimary)),
        Text(
            "${l10n.t('Paquets perdus', 'Packet loss', '丢包')}: ${loss.toStringAsFixed(0)}% ($received/$transmitted ${l10n.t('reçus', 'received', '已接收')})",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onPrimary)),
        const SizedBox(height: 20),
        _buildPingChart(context),
        const SizedBox(height: 20),
        Text(l10n.t("Journal du ping:", "Ping Log:", 'Ping 日志：'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onPrimary)),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
            border: Border.all(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            reverse: true,
            itemCount: _pingResponses.length,
            itemBuilder: (context, index) {
              final data = _pingResponses.reversed.toList()[index];
              final threshold = context.read<AppProvider>().getPingLatencyThresholdSync(_currentNode.id);
              if (data.response != null) {
                final latency = data.response!.time?.inMilliseconds ?? 0;
                final isExceeded = latency > threshold;
                return Text(
                    "${l10n.t('Réponse de', 'Reply from', '来自')} ${data.response!.ip}: ${l10n.t('temps', 'time', '时间')}=${latency}ms${isExceeded ? ' (⚠️)' : ''}",
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: isExceeded ? FontWeight.bold : FontWeight.normal,
                        color: isExceeded ? Colors.orangeAccent : theme.colorScheme.onPrimary));
              } else if (data.error != null) {
                return Text(
                    "${l10n.t('Erreur', 'Error', '错误')}: ${data.error!.error.toString()}",
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.red, fontFamily: 'monospace'));
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPingChart(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    final List<FlSpot> spots = [];
    final relevantPings =
        _pingResponses.where((p) => p.response?.time != null).toList();

    final start = relevantPings.length > 30 ? relevantPings.length - 30 : 0;
    for (int i = start; i < relevantPings.length; i++) {
      final ping = relevantPings[i];
      spots.add(
          FlSpot(i.toDouble(), ping.response!.time!.inMilliseconds.toDouble()));
    }

    if (spots.isEmpty) {
      return SizedBox(
          height: 150,
          child: Center(
              child: Text(
                  l10n.t("En attente de données de ping...", "Waiting for ping data...", '正在等待 ping 数据……'),
                  style: theme.textTheme.bodyMedium)));
    }

    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.5),
                  strokeWidth: 0.1),
              getDrawingVerticalLine: (value) => FlLine(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.5),
                  strokeWidth: 0.1)),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
              show: true,
              border: Border.all(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.5),
                  width: 1)),
          minX: spots.first.x,
          maxX: spots.last.x,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: theme.colorScheme.secondary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, barData) {
                  final threshold = context.read<AppProvider>().getPingLatencyThresholdSync(_currentNode.id);
                  return spot.y > threshold;
                },
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.orangeAccent,
                    strokeWidth: 1.5,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                  show: true,
                  color: theme.colorScheme.secondary.withValues(alpha: 0.3)),
            ),
          ],
        ),
      ),
    );
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
  Future<List<Node>> _cleanupObsoleteLanSharerTags(List<Node> nodes) async {
    if (!mounted) return nodes;
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
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primary,
      margin: const EdgeInsets.symmetric(vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }
}

class _DetailRowWithCopy extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRowWithCopy({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary)),
          ),
          Expanded(
            child: SelectableText(value,
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onPrimary)),
          ),
          IconButton(
            icon:
                Icon(Icons.copy, size: 18, color: theme.colorScheme.onPrimary),
            tooltip: l10n.t('Copier', 'Copy', '复制'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        l10n.t('Copié dans le presse-papiers', 'Copied to clipboard', '已复制到剪贴板'),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.primary)),
                    backgroundColor: theme.colorScheme.onPrimary),
              );
            },
          ),
        ],
      ),
    );
  }
}

