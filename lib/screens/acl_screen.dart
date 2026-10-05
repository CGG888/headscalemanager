import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/acl_manager_screen.dart';
import 'package:headscalemanager/screens/taildrive_manager_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:headscalemanager/services/acl/acl_policy_check.dart';
import 'package:headscalemanager/widgets/shared_routes_access_dialog.dart';
import 'package:headscalemanager/utils/ip_utils.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/widgets/acl/acl_engine_banner.dart';
import 'package:headscalemanager/widgets/acl/acls_list_view.dart';
import 'package:headscalemanager/widgets/acl/grants_list_view.dart';
import 'package:headscalemanager/widgets/acl/policy_diff_dialog.dart';
import 'package:headscalemanager/services/acl/grant_composer_service.dart';
import 'package:headscalemanager/utils/grants_v29_gate.dart';
import 'package:headscalemanager/widgets/acl/grant_composer_sheet.dart';
import 'package:headscalemanager/widgets/acl/grant_edit_sheet.dart';
import 'package:headscalemanager/widgets/acl/grants_migration_banner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:headscalemanager/services/acl/policy_file_service.dart';
import 'package:headscalemanager/widgets/acl/acl_workflow_guide.dart';
import 'package:headscalemanager/screens/acl_puzzle_screen.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class AclScreen extends StatefulWidget {
  const AclScreen({super.key});

  @override
  State<AclScreen> createState() => _AclScreenState();
}

class _AclScreenState extends State<AclScreen> {
  final TextEditingController _aclController = TextEditingController();
  bool _isLoading = true;
  Map<String, dynamic> _currentAclPolicy = {};
  final AclPolicyOrchestrator _aclOrchestrator = AclPolicyOrchestrator();

  List<Node> _allNodes = [];
  List<User> _users = [];
  Map<String, dynamic> _lastGeneratedPolicy = {};
  List<Node> _destinationNodes = [];
  Node? _selectedSourceNode;
  Node? _selectedDestinationNode;
  final TextEditingController _portController = TextEditingController();
  final List<Map<String, dynamic>> _temporaryRules = [];
  String _selectedProtocol = 'any'; // 'any', 'tcp', 'udp'
  String? _activeServerId;
  AclEngineMode? _lastAclEngineMode;
  bool _isLocalDraft = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appProvider = context.watch<AppProvider>();
    bool shouldReload = false;

    if (_activeServerId != appProvider.activeServer?.id) {
      _activeServerId = appProvider.activeServer?.id;
      shouldReload = true;
    }

    if (_lastAclEngineMode != appProvider.aclEngineMode) {
      _lastAclEngineMode = appProvider.aclEngineMode;
      shouldReload = true;
    }

    if (shouldReload) {
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final appProvider = context.read<AppProvider>();
    final storage = appProvider.storageService;
    final serverId = appProvider.activeServer?.id;

    if (serverId == null) {
      setState(() {
        _isLoading = false;
        // Handle error: no active server
      });
      return;
    }

    await _fetchNodes();
    final loadedRules = await storage.getTemporaryRules(serverId);
    if (mounted) {
      setState(() {
        _temporaryRules.clear();
        _temporaryRules.addAll(loadedRules);
      });
      await _generateNewAclPolicy(showSnackbar: false);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchNodes() async {
    try {
      final apiService = context.read<AppProvider>().apiService;
      _allNodes = await apiService.getNodes();
      _destinationNodes = List.from(_allNodes);
    } catch (e) {
      debugPrint('Error fetching nodes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.t(
                'Échec de la récupération des nœuds : $e',
                'Failed to fetch nodes: $e', '获取节点失败：$e'))),
        );
      }
    }
  }

  void _updateAclControllerText() {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    _aclController.text = encoder.convert(_currentAclPolicy);
    if (mounted) {
      setState(() {});
    }
  }

  bool _isComposerAvailable(AppProvider provider) {
    return GrantsV29Gate.isAvailable(
      engineMode: provider.aclEngineMode,
      serverVersion: provider.serverVersion,
    );
  }

  Future<void> _openGrantComposer({Node? prefilledRouter}) async {
    final provider = context.read<AppProvider>();
    final locale = provider.locale;
    final l10n = L10n(locale);

    if (!_isComposerAvailable(provider)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.t('Composeur disponible uniquement en mode Grants V29 (Headscale ≥ 0.29).', 'Composer available only in Grants V29 mode (Headscale ≥ 0.29).', '编排器仅在 Grants V29 模式（Headscale ≥ 0.29）下可用。')),
      ));
      return;
    }

    if (_users.isEmpty) {
      try {
        _users = await provider.apiService.getUsers();
      } catch (_) {}
    }

    if (!mounted) return;

    final result = await GrantComposerSheet.show(
      context,
      users: _users,
      nodes: _allNodes,
      l10n: l10n,
      prefilledRouterNode: prefilledRouter,
    );

    if (result == null || !mounted) return;

    setState(() {
      if (result.containsKey('action')) {
        _currentAclPolicy =
            GrantComposerService.appendExceptionAcl(_currentAclPolicy, result);
      } else {
        _currentAclPolicy =
            GrantComposerService.appendNetworkGrant(_currentAclPolicy, result);
      }
      _isLocalDraft = true;
      _updateAclControllerText();
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.t('Règle ajoutée à la policy locale. Exportez pour appliquer au serveur.', 'Rule added to local policy. Export to apply to server.', '规则已添加到本地策略。导出以应用到服务器。')),
    ));
  }

  Future<void> _onEditGrant(int networkIndex, Map<String, dynamic> grant) async {
    final provider = context.read<AppProvider>();
    final l10n = L10n(provider.locale);

    if (!_isComposerAvailable(provider)) return;

    final updated = await GrantEditSheet.show(
      context,
      grant: grant,
      users: _users,
      nodes: _allNodes,
      l10n: l10n,
    );

    if (updated == null || !mounted) return;

    setState(() {
      _currentAclPolicy = GrantComposerService.updateNetworkGrantAt(
        _currentAclPolicy,
        networkIndex,
        updated,
      );
      _isLocalDraft = true;
      _updateAclControllerText();
    });
  }

  void _onDeleteGrant(int networkIndex) {
    setState(() {
      _currentAclPolicy = GrantComposerService.removeNetworkGrantAt(
        _currentAclPolicy,
        networkIndex,
      );
      _isLocalDraft = true;
      _updateAclControllerText();
    });
  }

  Widget _buildScrollHeader({
    required L10n l10n,
    required AppProvider appProvider,
    required int grantCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AclEngineBanner(
                engineMode: appProvider.aclEngineMode,
                serverVersion: appProvider.serverVersion,
                users: _users,
                nodes: _allNodes,
                l10n: l10n,
                compact: true,
              ),
            ),
            if (_isLocalDraft) AclWorkflowGuide(l10n: l10n),
          ],
        ),
        if (!_isLocalDraft)
          GrantsMigrationBanner(
            l10n: l10n,
            grantCount: grantCount,
          ),
      ],
    );
  }

  Widget _buildGrantsTab({
    required L10n l10n,
    required AppProvider appProvider,
    required bool composerAvailable,
  }) {
    final grantCount =
        GrantComposerService.countNetworkGrants(_currentAclPolicy);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScrollHeader(
              l10n: l10n,
              appProvider: appProvider,
              grantCount: grantCount,
            ),
            _buildComposerButton(l10n, appProvider),
            if (composerAvailable)
              _buildAdvancedExceptionsSection(l10n)
            else
              _buildTemporaryRulesSection(),
            const SizedBox(height: 8),
            GrantsListView(
              grants: (_currentAclPolicy['grants'] as List?) ?? const [],
              l10n: l10n,
              onEditGrant: composerAvailable ? _onEditGrant : null,
              onDeleteGrant: composerAvailable ? _onDeleteGrant : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAclsTab({
    required L10n l10n,
    required AppProvider appProvider,
  }) {
    final grantCount =
        GrantComposerService.countNetworkGrants(_currentAclPolicy);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildScrollHeader(
            l10n: l10n,
            appProvider: appProvider,
            grantCount: grantCount,
          ),
          AclsListView(
            acls: (_currentAclPolicy['acls'] as List?) ?? const [],
            l10n: l10n,
          ),
        ],
      ),
    );
  }

  Widget _buildJsonTab({required L10n l10n}) {
    final appProvider = context.read<AppProvider>();
    final grantCount =
        GrantComposerService.countNetworkGrants(_currentAclPolicy);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScrollHeader(
              l10n: l10n,
              appProvider: appProvider,
              grantCount: grantCount,
            ),
            TextField(
              controller: _aclController,
              maxLines: null,
              minLines: 16,
              onChanged: (_) {
                try {
                  _currentAclPolicy =
                      json.decode(_aclController.text) as Map<String, dynamic>;
                } catch (_) {}
                setState(() => _isLocalDraft = true);
              },
              decoration: _buildInputDecoration('Politique ACL', '')
                  .copyWith(
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedExceptionsSection(L10n l10n) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        l10n.t('Mode avancé : exceptions manuelles', 'Advanced: manual exceptions', '高级模式：手动例外'),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(
        l10n.t('Ancien formulaire nœud à nœud — le composeur suffit en général', 'Legacy node-to-node form — composer is usually enough', '旧版节点到节点表单——通常用编写器就够了'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      children: [
        _buildTemporaryRulesSection(),
      ],
    );
  }

  Widget _buildComposerButton(L10n l10n, AppProvider provider) {
    if (!_isComposerAvailable(provider)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.icon(
        onPressed: () => _openGrantComposer(),
        icon: const Icon(Icons.auto_fix_high),
        label: Text(l10n.t('Composer une règle', 'Compose a rule', '编写规则')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final locale = appProvider.locale;
    final l10n = L10n(locale);
    final composerAvailable = _isComposerAvailable(appProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.t('Gestion des ACLs', 'ACL Management', 'ACL 管理'),
            style: Theme.of(context).appBarTheme.titleTextStyle),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
        actions: [
          _buildActionsMenu(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: l10n.t('Grants', 'Grants', '授权（Grants）')),
                      Tab(text: l10n.t('ACLs', 'ACLs', 'ACL')),
                      Tab(text: l10n.t('JSON', 'JSON', 'JSON')),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildGrantsTab(
                          l10n: l10n,
                          appProvider: appProvider,
                          composerAvailable: composerAvailable,
                        ),
                        _buildAclsTab(l10n: l10n, appProvider: appProvider),
                        _buildJsonTab(l10n: l10n),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        backgroundColor: Theme.of(context).colorScheme.primary,
        children: [
          if (composerAvailable)
            SpeedDialChild(
              child: const Icon(Icons.auto_fix_high),
              label: l10n.t('Composeur de grants', 'Grant composer', '授权编写器'),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              onTap: () => _openGrantComposer(),
            ),
          SpeedDialChild(
            child: const Icon(Icons.account_tree_outlined),
            label: l10n.t('Vue Graphe', 'Graph View', '图形视图'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AclManagerScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.extension),
            label: l10n.t('Vue Puzzle (Builder)', 'Puzzle View (Builder)', '拼图视图（构建器）'),
            backgroundColor: Colors.purple,
            labelBackgroundColor: Colors.purple,
            labelStyle: const TextStyle(color: Colors.white),
            foregroundColor: Colors.white,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AclPuzzleScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.folder_shared),
            label: l10n.t('Partages Taildrive', 'Taildrive Shares', 'Taildrive 分享'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            labelBackgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            labelStyle: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
            foregroundColor: Theme.of(context).colorScheme.onTertiary,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TaildriveManagerScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.settings_backup_restore),
            label: l10n.t('Générer Politique', 'Generate Policy', '生成策略'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            onTap: () => _generateNewAclPolicy(showSnackbar: true),
          ),
        ],
      ),
    );
  }

  PopupMenuButton<String> _buildActionsMenu() {
    // This is inside build, so watch is fine. The onSelected callback is the issue.
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return PopupMenuButton<String>(
      onSelected: (value) {
        // We use context.read inside the callbacks
        switch (value) {
          case 'export':
            _exportAclPolicyToServer();
            break;
          case 'fetch':
            _fetchAclPolicyFromServer();
            break;
          case 'backup':
            _exportPolicyBackup();
            break;
          case 'import':
            _importPolicyFromFile();
            break;
          case 'share':
            _shareAclFile();
            break;
          case 'staging':
            _showPolicyStagingDialog();
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'export',
          child: ListTile(
              leading: const Icon(Icons.cloud_upload),
              title:
                  Text(l10n.t('Exporter vers le serveur', 'Export to Server', '导出到服务器'))),
        ),
        PopupMenuItem<String>(
          value: 'fetch',
          child: ListTile(
              leading: const Icon(Icons.cloud_download),
              title: Text(l10n.t('Récupérer du serveur', 'Fetch from Server', '从服务器获取'))),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'backup',
          child: ListTile(
            leading: const Icon(Icons.save_alt),
            title: Text(l10n.t('Exporter backup JSON', 'Export JSON Backup', '导出 JSON 备份')),
          ),
        ),
        PopupMenuItem<String>(
          value: 'import',
          child: ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(l10n.t('Importer depuis JSON', 'Import from JSON', '从 JSON 导入')),
          ),
        ),
        PopupMenuItem<String>(
          value: 'share',
          child: ListTile(
              leading: const Icon(Icons.share),
              title: Text(l10n.t('Partager en fichier', 'Share as File', '分享为文件'))),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'staging',
          child: ListTile(
            leading: const Icon(Icons.lock_open, color: Colors.orange),
            title: Text(
                l10n.t('Repartir : tout autoriser…', 'Start over: allow all…', '重新开始：全部允许……'),
                style: const TextStyle(color: Colors.orange)),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleItem(Map<String, dynamic> rule, int index) {
    final src = rule['src'] as String;
    final dst = rule['dst'] as String;
    final port = rule['port'] as String?;
    final proto = rule['proto'] as String? ?? 'any';
    final portDisplay =
        (port == null || port.isEmpty || port == '*') ? 'All ports' : port;
    final protoDisplay = proto.toUpperCase();

    return ListTile(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.outbound, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(context.l10n.t('Src: $src', 'Src: $src', '源：$src'),
                      style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.login, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(context.l10n.t('Dst: $dst', 'Dst: $dst', '目标：$dst'),
                      style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
      subtitle: Text(context.l10n.t(
            'Port: $portDisplay | Proto: $protoDisplay',
            'Port: $portDisplay | Proto: $protoDisplay',
            '端口：$portDisplay｜协议：$protoDisplay')),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () async {
          setState(() {
            _temporaryRules.removeAt(index);
          });

          final appProvider = context.read<AppProvider>();
          final storage = appProvider.storageService;
          final serverId = appProvider.activeServer?.id;
          if (serverId != null) {
            await storage.saveTemporaryRules(serverId, _temporaryRules);
          }

          final locale = appProvider.locale;
          final l10n = L10n(locale);
          await _generateAndExportPolicy(
              message: l10n.t('Règle supprimée et politique mise à jour.', 'Rule deleted and policy updated.', '规则已删除并更新策略。'));
        },
      ),
    );
  }

  Widget _buildTemporaryRulesSection() {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('Autorisations Spécifiques', 'Specific Permissions', '特定权限'),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              l10n.t('Créez ici des exceptions pour autoriser la communication entre les appareils de différents utilisateurs.', 'Create exceptions here to allow communication between devices of different users.', '在此创建例外，以允许不同用户的设备之间通信。'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildNodeDropdown(
                    'Source (Node)',
                    _selectedSourceNode,
                    _allNodes,
                    (node) {
                      setState(() {
                        _selectedSourceNode = node;
                        _selectedDestinationNode = null;
                        if (node != null) {
                          _destinationNodes = _allNodes
                              .where((n) => n.getNormalizedOwner() != node.getNormalizedOwner())
                              .toList();
                        } else {
                          _destinationNodes = List.from(_allNodes);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildNodeDropdown(
                    'Destination (Node)',
                    _selectedDestinationNode,
                    _destinationNodes,
                    (node) => setState(() => _selectedDestinationNode = node),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _portController,
                    decoration: InputDecoration(
                      labelText: l10n.t('Port (Optionnel)', 'Port (Optional)', '端口（选填）'),
                      hintText: context.l10n.t('ex: 80, 443', 'e.g. 80, 443', '例如：80, 443'),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedProtocol,
                    decoration: InputDecoration(
                      labelText: l10n.t('Protocole', 'Protocol', '协议'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'any',
                          child: Text(l10n.t('Tous (Any)', 'Any', '全部（Any）'))),
                      const DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                      const DropdownMenuItem(value: 'udp', child: Text('UDP')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedProtocol = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _addTemporaryRule,
                icon: const Icon(Icons.add_link, color: Colors.white),
                label: Text(l10n.t('Ajouter et Appliquer', 'Add and Apply', '添加并应用'),
                    style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.t('Règles actives:', 'Active Rules:', '已启用规则：'),
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: Icon(Icons.delete_sweep,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)),
                  tooltip:
                      l10n.t('Effacer toutes les règles', 'Clear All Rules', '清除所有规则'),
                  onPressed: _clearTemporaryRules,
                )
              ],
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _temporaryRules.length,
              itemBuilder: (context, index) {
                return _buildRuleItem(_temporaryRules[index], index);
              },
            ),
          ],
        ),
      ),
    );
  }

  DropdownButtonFormField<Node> _buildNodeDropdown(String label,
      Node? selectedNode, List<Node> nodes, ValueChanged<Node?> onChanged) {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return DropdownButtonFormField<Node>(
      initialValue: selectedNode,
      decoration: _buildInputDecoration(
          label, l10n.t('Choisir un nœud', 'Choose a node', '选择节点')),
      items: nodes.map((Node node) {
        return DropdownMenuItem<Node>(
          value: node,
          child: Text(node.name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
      isExpanded: true,
    );
  }

  InputDecoration _buildInputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).inputDecorationTheme.fillColor ??
          Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
    );
  }

  String? _getMatchingSourceIp(Node sourceNode, String destinationIp) {
    try {
      // Determine destination type (IPv4 or IPv6)
      // Check if it's a CIDR or plain IP
      final cleanDest = destinationIp.split('/')[0];
      final destAddress = InternetAddress(cleanDest);
      final isDestIPv6 = destAddress.type == InternetAddressType.IPv6;

      // Find matching source
      return sourceNode.ipAddresses.firstWhere((ip) {
        // Remove CIDR if present (shouldn't be for source IPs usually but safe to check)
        final cleanIp = ip.split('/')[0];
        try {
          final address = InternetAddress(cleanIp);
          return (address.type == InternetAddressType.IPv6) == isDestIPv6;
        } catch (_) {
          return false;
        }
      }, orElse: () => '');
    } catch (_) {
      // Fallback: if destination is invalid or parsing fails, return first IP (legacy behavior) or null?
      // Let's assume default behavior if check fails
      return sourceNode.ipAddresses.isNotEmpty
          ? sourceNode.ipAddresses.first
          : null;
    }
  }

  void _showIpMismatchError(BuildContext context, L10n l10n, String dest) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            l10n.t('Impossible de trouver une IP source compatible (IPv4/IPv6) pour la destination: $dest', 'Could not find a compatible source IP (IPv4/IPv6) for destination: $dest', '找不到与目标 $dest 兼容的源 IP（IPv4/IPv6）'),
            style: TextStyle(color: Theme.of(context).colorScheme.onError)),
        backgroundColor: Theme.of(context).colorScheme.error));
  }

  bool _ruleExists(Map<String, dynamic> newRule) {
    return _temporaryRules.any((rule) {
      final bool srcMatch = rule['src'] == newRule['src'];
      final bool dstMatch = rule['dst'] == newRule['dst'];
      final bool portMatch = (rule['port'] ?? '') == (newRule['port'] ?? '');
      final bool protoMatch =
          (rule['proto'] ?? 'any') == (newRule['proto'] ?? 'any');
      return srcMatch && dstMatch && portMatch && protoMatch;
    });
  }

  Future<void> _addTemporaryRule() async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);

    if (_selectedSourceNode == null || _selectedDestinationNode == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              l10n.t('Veuillez sélectionner un nœud source et un nœud destination.', 'Please select a source and a destination node.', '请选择源节点和目标节点。'),
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }

    if (_selectedSourceNode!.ipAddresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              l10n.t('Le nœud source doit avoir au moins une adresse IP.', 'Source node must have at least one IP address.', '源节点必须至少有一个 IP 地址。'),
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }
    // final sourceIp = _selectedSourceNode!.ipAddresses.first; // REMOVED

    List<Map<String, dynamic>> newRulesToAdd = [];

    final sharedLanRoutes = _selectedDestinationNode!.sharedRoutes
        .where((r) => r != '0.0.0.0/0' && r != '::/0')
        .toList();

    if (sharedLanRoutes.isNotEmpty) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SharedRoutesAccessDialog(
          destinationNode: _selectedDestinationNode!,
        ),
      );

      if (!mounted) return;

      // Debug: Afficher le résultat reçu du dialogue
      debugPrint('DEBUG: Résultat reçu du dialogue: $result');

      if (result == null) {
        debugPrint('DEBUG: Résultat est null, arrêt du processus');
        return;
      }

      try {
        final choice = result['choice'] as RouteAccessChoice;
        final rules = result['rules'] as Map<String, dynamic>;

        // Debug: Afficher le choix et les règles extraites
        debugPrint('DEBUG: Choix extrait: $choice');
        debugPrint('DEBUG: Règles extraites: $rules');

        if (choice == RouteAccessChoice.none) {
          // Fallback: add rule for the node itself if subnet access is denied
          if (_selectedDestinationNode!.ipAddresses.isNotEmpty) {
            String? fallbackDest;
            String? fallbackSrc;

            // Try to find a pair that works
            // check destination IPs
            for (var destIp in _selectedDestinationNode!.ipAddresses) {
              final src = _getMatchingSourceIp(_selectedSourceNode!, destIp);
              if (src != null && src.isNotEmpty) {
                fallbackDest = destIp;
                fallbackSrc = src;
                break;
              }
            }

            if (fallbackDest != null && fallbackSrc != null) {
              final port = _portController.text.trim();
              newRulesToAdd.add({
                'src': fallbackSrc,
                'dst': fallbackDest,
                'port': port.isEmpty ? '*' : port,
                'proto': _selectedProtocol,
              });
            } else {
              _showIpMismatchError(context, l10n, "Fallback IP");
              return;
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.t('Accès au sous-réseau non configuré et le nœud n\'a pas d\'IP pour une règle de base.', 'Subnet access not configured and the node has no IP for a fallback rule.', '未配置子网访问，且节点没有 IP 可用于兜底规则。')),
            ));
            return;
          }
        } else if (choice == RouteAccessChoice.full) {
          for (var route in sharedLanRoutes) {
            final src = _getMatchingSourceIp(_selectedSourceNode!, route);
            if (src == null || src.isEmpty) {
              _showIpMismatchError(context, l10n, route);
              return;
            }
            newRulesToAdd.add({
              'src': src,
              'dst': route,
              'port': '*',
              'proto': _selectedProtocol,
            });
          }
        } else if (choice == RouteAccessChoice.custom) {
          // rules.forEach loop logic
          for (var entry in rules.entries) {
            final ruleDetails = entry.value;
            final startIp = (ruleDetails['startIp'] as String).trim();
            final endIp = (ruleDetails['endIp'] as String).trim();
            final ports = (ruleDetails['ports'] as String).trim();

            if (startIp.isEmpty) continue;

            String dst;
            if (endIp.isNotEmpty) {
              // Range logic - assume range is same IP version as startIp
              // Note: Generating full list of IPs might be heavy if range is huge.
              // Logic assumes startIp and endIp are safe.
              final range = IpUtils.generateIpRange(startIp, endIp);
              dst = range.join(',');
            } else {
              dst = startIp;
            }

            if (dst.isNotEmpty) {
              // Note: if dst is comma separated list, check first one for version?
              // Or check each?
              // The generateIpRange ensures same type.
              final firstDest = dst.split(',').first;
              final src = _getMatchingSourceIp(_selectedSourceNode!, firstDest);

              if (src == null || src.isEmpty) {
                _showIpMismatchError(context, l10n, firstDest);
                return;
              }

              newRulesToAdd.add({
                'src': src,
                'dst': dst,
                'port': ports.isEmpty ? '*' : ports,
                'proto': _selectedProtocol,
              });
            }
          }
        }
      } catch (e) {
        debugPrint('DEBUG: Erreur lors de l\'extraction du choix/règles: $e');
        return;
      }
    } else {
      if (_selectedDestinationNode!.ipAddresses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                l10n.t('Le nœud destination doit avoir au moins une adresse IP.', 'Destination node must have at least one IP address.', '目标节点必须至少有一个 IP 地址。'),
                style: TextStyle(color: Theme.of(context).colorScheme.onError)),
            backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }

      // Single node destination (no shared routes)
      // Try to match IPs
      String? validDest;
      String? validSrc;

      // Prefer IPv4 if available? Or depend on what dest has.
      // Strategy: Try IPv4 match first, then IPv6? Or just first available pair?
      // Let's iterate dest IPs.
      for (var destIp in _selectedDestinationNode!.ipAddresses) {
        final src = _getMatchingSourceIp(_selectedSourceNode!, destIp);
        if (src != null && src.isNotEmpty) {
          validDest = destIp;
          validSrc = src;
          // Stop if found?
          // If User wants specifically IPv6, he might be disappointed if we pick IPv4.
          // But here we are selecting a Node, so any connectivity is good?
          // But wait, the previous logic just picked first IP (IPv4 usually).
          // If we find IPv4 pair, good. If not, IPv6 pair.
          // Let's prioritize IPv4 to match legacy behavior if possible.
          final cleanDest = destIp.split('/')[0];
          if (InternetAddress(cleanDest).type == InternetAddressType.IPv4) {
            break; // Found IPv4 pair, awesome.
          }
        }
      }

      if (validDest != null && validSrc != null) {
        if (validSrc == validDest) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  l10n.t('Les nœuds source et destination ne peuvent pas être identiques.', 'Source and destination nodes cannot be the same.', '源节点和目标节点不能相同。'),
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error));
          return;
        }

        final port = _portController.text.trim();
        newRulesToAdd.add({
          'src': validSrc,
          'dst': validDest,
          'port': port,
          'proto': _selectedProtocol,
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                l10n.t('Impossible de trouver une paire d\'adresses IP compatibles (IPv4/IPv6) entre la source et la destination.', 'Could not find a compatible IP pair (IPv4/IPv6) between source and destination.', '在源和目标之间找不到兼容的 IP 地址对（IPv4/IPv6）。'),
                style: TextStyle(color: Theme.of(context).colorScheme.onError)),
            backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }
    }

    int addedCount = 0;

    // Debug: Afficher les règles à ajouter
    debugPrint('DEBUG: Nombre de règles à ajouter: ${newRulesToAdd.length}');
    for (var rule in newRulesToAdd) {
      debugPrint('DEBUG: Règle à ajouter: $rule');
    }

    for (var newRule in newRulesToAdd) {
      if (!_ruleExists(newRule)) {
        setState(() {
          _temporaryRules.add(newRule);
          addedCount++;
        });
        debugPrint('DEBUG: Règle ajoutée: $newRule');
      } else {
        debugPrint('DEBUG: Règle ignorée (existe déjà): $newRule');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${l10n.t('Règle ignorée car elle existe déjà:', 'Skipped existing rule:', '规则已存在，已跳过：')} ${newRule['dst']}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer)),
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer));
      }
    }

    debugPrint('DEBUG: Nombre de règles ajoutées: $addedCount');

    if (addedCount > 0) {
      final appProvider = context.read<AppProvider>();
      final storage = appProvider.storageService;
      final serverId = appProvider.activeServer?.id;
      if (serverId != null) {
        await storage.saveTemporaryRules(serverId, _temporaryRules);
      }
      await _generateAndExportPolicy(
          message: l10n.t('$addedCount règle(s) ajoutée(s) et politique appliquée.', '$addedCount rule(s) added and policy applied.', '已添加 $addedCount 条规则并应用策略。'));
    } else {
      // Debug: Afficher un message si aucune règle n'a été ajoutée
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              l10n.t('Aucune règle n\'a été ajoutée.', 'No rules were added.', '未添加任何规则。'),
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  Future<void> _generateNewAclPolicy({bool showSnackbar = true}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final appProvider = context.read<AppProvider>();
      final apiService = appProvider.apiService;

      final users = await apiService.getUsers();
      final nodes =
          _allNodes.isNotEmpty ? _allNodes : await apiService.getNodes();
      if (_allNodes.isEmpty) _allNodes = nodes;
      
      // Clean up obsolete lan-sharer tags before ACL generation
      final cleanedNodes = await _cleanupObsoleteLanSharerTags(nodes);

      _currentAclPolicy = _aclOrchestrator.generatePolicy(
        engineMode: appProvider.aclEngineMode,
        users: users,
        nodes: cleanedNodes,
        temporaryRules: _temporaryRules,
        taildriveShares: appProvider.taildriveShares,
        serverVersion: appProvider.serverVersion,
      );
      _users = users;
      _lastGeneratedPolicy =
          Map<String, dynamic>.from(_currentAclPolicy);

      _updateAclControllerText();
      if (mounted) setState(() => _isLocalDraft = true);

      final locale = appProvider.locale;
      final l10n = L10n(locale);

      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    l10n.t('Politique ACL avancée générée dans le champ de texte.', 'Advanced ACL policy generated in the text field.', '已在文本框中生成高级 ACL 策略。'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary)),
                const SizedBox(height: 4),
                Text(
                    l10n.t('Utilisez le menu (⋮) pour l\'exporter.', 'Use the menu (⋮) to export it.', '使用菜单（⋮）导出。'),
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.7),
                        fontSize: 12)),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint(
          'Erreur lors de la génération de la politique ACL avancée : $e');
      if (mounted) {
        final locale = context.read<AppProvider>().locale;
        final l10n = L10n(locale);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${l10n.t('Échec de la génération de la politique ACL avancée', 'Failed to generate advanced ACL policy', '生成高级 ACL 策略失败')}: $e',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearTemporaryRules() async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);

    final bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.t('Confirmer la suppression', 'Confirm Deletion', '确认删除')),
            content: Text(l10n.t('Cela va supprimer TOUTES les règles et appliquer la nouvelle politique au serveur. Continuer ?', 'This will delete ALL rules and apply the new policy to the server. Continue?', '这将删除所有规则并将新策略应用到服务器。是否继续？')),
            actions: [
              TextButton(
                  child: Text(l10n.t('Annuler', 'Cancel', '取消')),
                  onPressed: () => Navigator.of(ctx).pop(false)),
              TextButton(
                  child: Text(l10n.t('Confirmer', 'Confirm', '确认'),
                      style: const TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(ctx).pop(true)),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    setState(() {
      _temporaryRules.clear();
    });
    final appProvider = context.read<AppProvider>();
    final storage = appProvider.storageService;
    final serverId = appProvider.activeServer?.id;
    if (serverId != null) {
      await storage.saveTemporaryRules(serverId, _temporaryRules);
    }
    await _generateAndExportPolicy(
        message: l10n.t('Toutes les règles ont été supprimées et la politique a été mise à jour.', 'All rules have been deleted and the policy has been updated.', '已删除所有规则并更新策略。'));
  }

  Future<void> _generateAndExportPolicy({String? message}) async {
    await _generateNewAclPolicy(showSnackbar: false);
    await _exportAclPolicyToServer(
        showConfirmation: false, successMessage: message);
  }

  Future<void> _exportAclPolicyToServer(
      {bool showConfirmation = true, String? successMessage}) async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);

    if (showConfirmation) {
      Map<String, dynamic> editedPolicy;
      try {
        editedPolicy =
            json.decode(_aclController.text) as Map<String, dynamic>;
      } catch (_) {
        editedPolicy = _currentAclPolicy;
      }

      final confirmed = await PolicyDiffDialog.show(
        context,
        currentPolicy: _lastGeneratedPolicy.isNotEmpty
            ? _lastGeneratedPolicy
            : _currentAclPolicy,
        newPolicy: editedPolicy,
        l10n: l10n,
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    final apiService = context.read<AppProvider>().apiService;

    setState(() => _isLoading = true);
    try {
      // 保存前**本地**预检：把已知会导致服务端拒绝的问题（最典型的是 groups
      // 成员缺少 `@`）提前暴露，并提供一键修复。服务端的权威校验
      // （POST /policy/check）由 API 层的 setAclPolicy 负责。
      final localIssues = AclPolicyCheck.localIssues(_aclController.text);
      if (localIssues.isNotEmpty) {
        final proceed = await _offerAclAutoFix(l10n, localIssues);
        if (!proceed) return;
      }
      await apiService.setAclPolicy(_aclController.text);
      if (mounted) {
        setState(() => _isLocalDraft = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  successMessage ??
                      (l10n.t('Politique ACL exportée avec succès vers le serveur.', 'ACL policy successfully exported to the server.', 'ACL 策略已成功导出到服务器。')),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
              backgroundColor: Theme.of(context).colorScheme.primary),
        );
      }
    } catch (e) {
      debugPrint(
          'Erreur lors de l\'exportation de la politique ACL vers le serveur : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${l10n.t('Échec de l\'exportation de la politique ACL', 'Failed to export ACL policy', '导出 ACL 策略失败')}: $e',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// ACL 预检发现问题时的对话框：列出问题并提供"一键修复"。
  ///
  /// 返回 true 表示调用方应带着（可能已修复的）策略继续保存；false 表示用户取消。
  Future<bool> _offerAclAutoFix(
    L10n l10n,
    List<AclIssue> issues, {
    String? serverMessage,
  }) async {
    final fixed = AclPolicyCheck.autoFix(_aclController.text);
    final theme = Theme.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('La politique ACL a été refusée',
            'The ACL policy was rejected', 'ACL 策略未通过校验')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (serverMessage != null) ...[
                Text(
                    l10n.t('Réponse du serveur', 'Server response', '服务端返回'),
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                SelectableText(serverMessage,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                const SizedBox(height: 12),
              ],
              if (issues.isNotEmpty) ...[
                Text(
                    l10n.t('Problèmes détectés localement',
                        'Issues found locally', '本地发现的问题'),
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                for (final issue in issues.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${_describeAclIssue(l10n, issue)}'),
                  ),
              ],
              if (fixed != null) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.t(
                    'La réparation normalise le format JSON (les commentaires sont perdus).',
                    'Fixing normalizes the JSON formatting (comments are lost).',
                    '自动修复会规范化 JSON 格式（注释会丢失）。',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('Annuler', 'Cancel', '取消')),
          ),
          if (fixed == null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.t('Sauvegarder quand même', 'Save anyway', '仍然保存')),
            ),
          if (fixed != null)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text(l10n.t('Réparer et sauvegarder', 'Fix and save', '修复并保存')),
            ),
        ],
      ),
    );

    if (result != true) return false;
    if (fixed != null) {
      _aclController.text = fixed;
      try {
        _currentAclPolicy = json.decode(fixed) as Map<String, dynamic>;
      } catch (_) {
        // 修复后的内容一定是合法 JSON；这里只是防御性处理。
      }
      setState(() => _isLocalDraft = true);
    }
    return true;
  }

  String _describeAclIssue(L10n l10n, AclIssue issue) {
    switch (issue.code) {
      case AclIssueCode.notJson:
        return l10n.t('Le contenu n\'est pas un JSON valide.',
            'The content is not valid JSON.', '内容不是合法的 JSON。');
      case AclIssueCode.groupMemberNeedsAt:
        return l10n.t(
          '« ${issue.value} » doit être une référence utilisateur contenant « @ » (ex. ${issue.value}@).',
          '"${issue.value}" must be a user reference containing "@" (e.g. ${issue.value}@).',
          '「${issue.value}」必须是含 @ 的用户引用（例如 ${issue.value}@）。',
        );
      case AclIssueCode.invalidGroupName:
        return l10n.t(
          'Le groupe « ${issue.value} » doit être préfixé par « group: ».',
          'Group "${issue.value}" must be prefixed with "group:".',
          '分组「${issue.value}」必须以 group: 为前缀。',
        );
    }
  }

  Future<void> _fetchAclPolicyFromServer() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final appProvider = context.read<AppProvider>();
      final apiService = appProvider.apiService;
      final aclJsonString = await apiService.getAclPolicy();
      _currentAclPolicy = json.decode(aclJsonString);
      _updateAclControllerText();
      final locale = appProvider.locale;
      final l10n = L10n(locale);
      if (mounted) {
        setState(() => _isLocalDraft = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  l10n.t('Politique ACL récupérée du serveur.', 'ACL policy fetched from the server.', '已从服务器获取 ACL 策略。'),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
              backgroundColor: Theme.of(context).colorScheme.primary),
        );
      }
    } catch (e) {
      debugPrint(
          'Erreur lors de la récupération de la politique ACL du serveur : $e');
      if (mounted) {
        final locale = context.read<AppProvider>().locale;
        final l10n = L10n(locale);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${l10n.t('Échec de la récupération de la politique ACL', 'Failed to fetch ACL policy', '获取 ACL 策略失败')}: $e',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyPolicyLocally(
    Map<String, dynamic> policy, {
    bool markAsDraft = true,
    bool clearTemporaryRules = false,
  }) {
    setState(() {
      _currentAclPolicy = Map<String, dynamic>.from(policy);
      _aclController.text = PolicyFileService.encodePolicy(_currentAclPolicy);
      _isLocalDraft = markAsDraft;
      if (clearTemporaryRules) {
        _temporaryRules.clear();
      }
    });
  }

  Future<void> _persistClearedTemporaryRules() async {
    final serverId = context.read<AppProvider>().activeServer?.id;
    if (serverId != null) {
      await context
          .read<AppProvider>()
          .storageService
          .saveTemporaryRules(serverId, _temporaryRules);
    }
  }

  Future<void> _showPolicyStagingDialog() async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('Repartir de zéro', 'Start from scratch', '从头开始')),
        content: SingleChildScrollView(
          child: Text(
            l10n.isFr ? 'Approche recommandée :\n\n'
                    '1. Chargez un brouillon « tout autoriser » (local uniquement — le serveur reste inchangé)\n'
                    '2. Ajoutez vos grants spécifiques via le composeur\n'
                    '3. Supprimez la règle « tout autoriser » quand vos règles sont prêtes\n'
                    '4. Exportez vers le serveur uniquement quand vous êtes prêt\n\n'
                    'Ainsi personne n\'est coupé brutalement pendant que vous construisez la nouvelle policy.'
                : 'Recommended approach:\n\n'
                    '1. Load an « allow all » draft (local only — server unchanged)\n'
                    '2. Add specific grants via the composer\n'
                    '3. Remove the « allow all » rule when your rules are ready\n'
                    '4. Export to server only when you are ready\n\n'
                    'Nobody gets cut off while you build the new policy.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.t('Annuler', 'Cancel', '取消')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('local'),
            child: Text(
              l10n.t('Brouillon local', 'Local draft', '本地草稿'),
              style: const TextStyle(color: Colors.orange),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('publish'),
            child: Text(
              l10n.t('Publier tout autoriser', 'Publish allow all', '发布「全部允许」'),
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (!mounted || choice == null) return;

    if (choice == 'local') {
      await _loadAllowAllDraftLocal();
    } else if (choice == 'publish') {
      await _publishAllowAllToServer();
    }
  }

  Future<void> _loadAllowAllDraftLocal() async {
    if (!mounted) return;
    final l10n = L10n(context.read<AppProvider>().locale);

    _applyPolicyLocally(
      PolicyFileService.allowAllTemplate(),
      clearTemporaryRules: true,
    );
    await _persistClearedTemporaryRules();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('Brouillon « tout autoriser » chargé localement. Le serveur n\'a pas été modifié.', '« Allow all » draft loaded locally. Server was not changed.', '已加载「全部允许」草稿到本地。服务器未被修改。'),
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _publishAllowAllToServer() async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);

    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.t('Publier tout autoriser', 'Publish allow all', '发布「全部允许」')),
            content: Text(
              l10n.t('La policy actuelle du serveur sera remplacée par « tout autoriser » immédiatement. Continuer ?', 'The server policy will be replaced with « allow all » immediately. Continue?', '服务器当前的策略将立即替换为「全部允许」。是否继续？'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.t('Annuler', 'Cancel', '取消')),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  l10n.t('Publier', 'Publish', '发布'),
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    _applyPolicyLocally(
      PolicyFileService.allowAllTemplate(),
      markAsDraft: false,
      clearTemporaryRules: true,
    );
    await _persistClearedTemporaryRules();

    if (!mounted) return;

    final serverId = context.read<AppProvider>().activeServer?.id;
    if (serverId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('Aucun serveur actif sélectionné.', 'No active server selected.', '未选择活动服务器。')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await _exportAclPolicyToServer(
      showConfirmation: false,
      successMessage: l10n.t('Policy publiée : tout le trafic est maintenant autorisé.', 'Policy published: all traffic is now allowed.', '策略已发布：现在允许所有流量。'),
    );
  }

  Future<void> _exportPolicyBackup() async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);

    try {
      Map<String, dynamic> policy;
      try {
        policy = json.decode(_aclController.text) as Map<String, dynamic>;
      } catch (_) {
        policy = _currentAclPolicy;
      }

      PolicyFileService.validatePolicy(policy);
      final aclJsonString = PolicyFileService.encodePolicy(policy);

      final directory = await getTemporaryDirectory();
      final fileName = PolicyFileService.backupFileName();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(aclJsonString);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: l10n.t('Backup de votre policy Headscale.', 'Backup of your Headscale policy.', '你的 Headscale 策略的备份。'),
        ),
      );
    } catch (e) {
      debugPrint('Erreur export backup policy : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.t('Échec de l\'export backup', 'Backup export failed', '备份导出失败')}: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _importPolicyFromFile() async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      );

      if (result == null || result.files.isEmpty || !mounted) return;

      final picked = result.files.single;
      final path = picked.path;
      if (path == null) {
        throw Exception(l10n.t('Chemin fichier inaccessible', 'File path unavailable', '文件路径不可访问'));
      }

      final raw = await File(path).readAsString();
      final policy = PolicyFileService.parsePolicyContent(raw);

      if (!mounted) return;

      final publish = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.t('Importer la policy', 'Import policy', '导入策略')),
              content: Text(
                l10n.t('Charger en brouillon local (recommandé) ou publier immédiatement sur le serveur ?', 'Load as local draft (recommended) or publish immediately to the server?', '作为本地草稿加载（推荐），还是立即发布到服务器？'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.t('Annuler', 'Cancel', '取消')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    l10n.t('Brouillon local', 'Local draft', '本地草稿'),
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l10n.t('Publier', 'Publish', '发布')),
                ),
              ],
            ),
          );

      if (!mounted || publish == null) return;

      _applyPolicyLocally(policy, markAsDraft: !publish);

      if (publish) {
        await _exportAclPolicyToServer(
          showConfirmation: true,
          successMessage: l10n.t('Policy importée et publiée sur le serveur.', 'Policy imported and published to the server.', '策略已导入并发布到服务器。'),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.t('Policy importée en brouillon local. Le serveur n\'a pas été modifié.', 'Policy imported as local draft. Server was not changed.', '策略已导入为本地草稿。服务器未改动。'),
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur import policy : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.t('Échec de l\'import', 'Import failed', '导入失败')}: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _shareAclFile() async {
    await _exportPolicyBackup();
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
