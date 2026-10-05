import 'package:flutter/material.dart';
import 'package:headscalemanager/api/headscale_api_service.dart';
import 'package:headscalemanager/l10n/l10n.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/audit_log_service.dart';
import 'package:headscalemanager/services/batch_operation_service.dart';
import 'package:provider/provider.dart';

/// 批量操作页：一页扁平列出所有节点，勾选后批量执行。
///
/// 为什么单开一页而不是改造仪表盘：仪表盘的节点列表按用户分组（每用户一个
/// ExpansionTile），多选状态需要穿透多层结构；批量操作本身就是"跨用户"的，
/// 扁平列表 + 搜索反而更直接。
///
/// 批量动作都会**逐个执行并记录成功/失败**（见 [BatchOperationService]），
/// 结束后给出汇总，而不是"一失败就中断、什么也没说"。
enum _BatchAction { approveRoutes, expireKeys, delete }

class BatchOperationsScreen extends StatefulWidget {
  const BatchOperationsScreen({super.key, this.initialSelection = const []});

  /// 进入时预选的节点 id（例如从"网络体检"的僵尸节点一键带过来）。
  final List<String> initialSelection;

  @override
  State<BatchOperationsScreen> createState() => _BatchOperationsScreenState();
}

class _BatchOperationsScreenState extends State<BatchOperationsScreen> {
  bool _isLoading = true;
  bool _isRunning = false;
  String? _error;
  String _search = '';
  List<Node> _nodes = const [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    // 预选（来自体检页的"清理"入口）
    _selected.addAll(widget.initialSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  HeadscaleApiService get _api => context.read<AppProvider>().apiService;

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final nodes = await _api.getNodes();
      if (!mounted) return;
      setState(() {
        _nodes = nodes;
        _selected.removeWhere((id) => !nodes.any((n) => n.id == id));
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

  List<Node> get _visible {
    if (_search.trim().isEmpty) return _nodes;
    final q = _search.trim().toLowerCase();
    return _nodes
        .where((n) =>
            n.name.toLowerCase().contains(q) ||
            n.hostname.toLowerCase().contains(q) ||
            n.ipAddresses.any((ip) => ip.contains(q)))
        .toList();
  }

  List<Node> get _selectedNodes =>
      _nodes.where((n) => _selected.contains(n.id)).toList();

  Future<void> _runBatch(_BatchAction action) async {
    final l10n = context.l10n;
    var targets = _selectedNodes;

    // 批准路由：没有待批路由的节点会被跳过，避免无意义的请求。
    if (action == _BatchAction.approveRoutes) {
      targets = BatchOperationService.nodesWithPendingRoutes(targets);
      if (targets.isEmpty) {
        _snack(l10n.t('Aucune route en attente.', 'No pending routes.',
            '没有待批准的路由。'));
        return;
      }
    }
    if (targets.isEmpty) {
      _snack(l10n.t('Sélectionnez au moins un nœud.',
          'Select at least one node.', '请至少选择一个节点。'));
      return;
    }

    final confirmed = await _confirm(action, targets);
    if (confirmed != true) return;

    final api = _api;
    setState(() => _isRunning = true);
    try {
      final result = await BatchOperationService.run(
        targets,
        (node) => switch (action) {
          _BatchAction.approveRoutes => api.setNodeRoutes(
              node.id,
              [...node.sharedRoutes, ...BatchOperationService.pendingRoutes(node)],
            ),
          _BatchAction.expireKeys => api.expireNode(node.id),
          _BatchAction.delete => api.deleteNode(node.id),
        },
      );
      if (!mounted) return;
      // 本地留痕：Headscale 没有审计 API，破坏性批量操作必须自己记一笔。
      await AuditLogService.record(
        switch (action) {
          _BatchAction.approveRoutes => 'batchApproveRoutes',
          _BatchAction.expireKeys => 'batchExpireKeys',
          _BatchAction.delete => 'batchDeleteNodes',
        },
        targets.map((n) => n.name).join(', '),
        detail: l10n.t(
          '${result.succeeded.length} réussis, ${result.failures.length} échoués',
          '${result.succeeded.length} succeeded, ${result.failures.length} failed',
          '成功 ${result.succeeded.length} 个，失败 ${result.failures.length} 个',
        ),
        success: result.failures.isEmpty,
      );
      await _showSummary(action, result);
      setState(() => _selected.clear());
      await _load();
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<bool?> _confirm(_BatchAction action, List<Node> targets) {
    final l10n = context.l10n;
    final count = targets.length;
    // 安全提示：这些机器仍在为网络提供服务，删掉/过期会立刻影响流量。
    final risky = targets
        .where((n) => n.sharedRoutes.isNotEmpty || n.isExitNode)
        .length;
    final (title, body) = switch (action) {
      _BatchAction.approveRoutes => (
          l10n.t('Approuver les routes', 'Approve routes', '批准路由'),
          l10n.t(
            'Approuver toutes les routes en attente sur $count nœud(s) ?',
            'Approve every pending route on $count node(s)?',
            '批准所选 $count 个节点上所有待批准的路由？',
          ),
        ),
      _BatchAction.expireKeys => (
          l10n.t('Expirer les clés', 'Expire keys', '过期密钥'),
          l10n.t(
            'Expirer la clé de $count nœud(s) ? Ces appareils devront se reconnecter.',
            'Expire the key of $count node(s)? Those devices will have to reconnect.',
            '使 $count 个节点的密钥过期？这些设备需要重新认证才能回来。',
          ),
        ),
      _BatchAction.delete => (
          l10n.t('Supprimer les nœuds', 'Delete nodes', '删除节点'),
          l10n.t(
            'Supprimer définitivement $count nœud(s) ? Cette action est irréversible.',
            'Permanently delete $count node(s)? This cannot be undone.',
            '永久删除 $count 个节点？此操作不可撤销。',
          ),
        ),
    };

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body),
            if (risky > 0 && action != _BatchAction.approveRoutes) ...[
              const SizedBox(height: 12),
              Text(
                l10n.t(
                  'Attention : $risky de ces nœuds partagent des routes ou sont des nœuds de sortie.',
                  'Warning: $risky of these nodes share routes or act as exit nodes.',
                  '注意：其中 $risky 台正在共享路由或作为出口节点。',
                ),
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.error,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('Annuler', 'Cancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: action == _BatchAction.delete
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error)
                : null,
            child: Text(l10n.t('Confirmer', 'Confirm', '确认')),
          ),
        ],
      ),
    );
  }

  Future<void> _showSummary(_BatchAction action, BatchResult result) {
    final l10n = context.l10n;
    final title = switch (action) {
      _BatchAction.approveRoutes =>
        l10n.t('Routes approuvées', 'Routes approved', '已批准路由'),
      _BatchAction.expireKeys =>
        l10n.t('Clés expirées', 'Keys expired', '已过期密钥'),
      _BatchAction.delete => l10n.t('Nœuds supprimés', 'Nodes deleted', '已删除节点'),
    };

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.t(
                '${result.succeeded.length} réussis, ${result.failures.length} échoués.',
                '${result.succeeded.length} succeeded, ${result.failures.length} failed.',
                '成功 ${result.succeeded.length} 个，失败 ${result.failures.length} 个。',
              )),
              if (result.hasFailures) ...[
                const SizedBox(height: 12),
                Text(l10n.t('Échecs', 'Failures', '失败项'),
                    style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 4),
                for (final entry in result.failures.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${entry.key}: ${entry.value}',
                        style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('Fermer', 'Close', '关闭')),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visible = _visible;
    final allSelected =
        visible.isNotEmpty && visible.every((n) => _selected.contains(n.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('Opérations groupées', 'Batch operations', '批量操作')),
        actions: [
          if (_isRunning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _load,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.t('Rechercher un nœud', 'Search a node', '搜索节点'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text(l10n.t('${_selected.length} sélectionnés',
                    '${_selected.length} selected', '已选 ${_selected.length} 个')),
                const Spacer(),
                TextButton(
                  onPressed: visible.isEmpty
                      ? null
                      : () => setState(() {
                            if (allSelected) {
                              _selected.removeAll(visible.map((n) => n.id));
                            } else {
                              _selected.addAll(visible.map((n) => n.id));
                            }
                          }),
                  child: Text(allSelected
                      ? l10n.t('Tout désélectionner', 'Clear', '清空')
                      : l10n.t('Tout sélectionner', 'Select all', '全选')),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList(l10n, visible)),
        ],
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isRunning
                            ? null
                            : () => _runBatch(_BatchAction.approveRoutes),
                        icon: const Icon(Icons.route, size: 18),
                        label: Text(l10n.t('Routes', 'Routes', '批准路由')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isRunning
                            ? null
                            : () => _runBatch(_BatchAction.expireKeys),
                        icon: const Icon(Icons.key_off, size: 18),
                        label: Text(l10n.t('Expirer', 'Expire', '过期密钥')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _isRunning ? null : () => _runBatch(_BatchAction.delete),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error),
                        label: Text(l10n.t('Supprimer', 'Delete', '删除')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildList(L10n l10n, List<Node> visible) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${l10n.t('Échec du chargement', 'Failed to load', '加载失败')}: $_error',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(l10n.t('Réessayer', 'Retry', '重试'))),
          ],
        ),
      );
    }
    if (visible.isEmpty) {
      return Center(child: Text(l10n.t('Aucun nœud trouvé', 'No node found', '未找到节点')));
    }

    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final node = visible[index];
        final pending = BatchOperationService.pendingRoutes(node).length;
        return CheckboxListTile(
          value: _selected.contains(node.id),
          onChanged: _isRunning
              ? null
              : (checked) => setState(() {
                    if (checked == true) {
                      _selected.add(node.id);
                    } else {
                      _selected.remove(node.id);
                    }
                  }),
          title: Text(node.name),
          subtitle: Text([
            node.hostname,
            node.user,
            node.ipAddresses.join(', '),
            if (pending > 0)
              l10n.t('$pending route(s) en attente', '$pending pending route(s)',
                  '$pending 条待批准路由'),
          ].where((s) => s.isNotEmpty).join(' · ')),
          secondary: Icon(Icons.circle,
              size: 10,
              color: node.online
                  ? Colors.green
                  : Theme.of(context).disabledColor),
        );
      },
    );
  }
}
