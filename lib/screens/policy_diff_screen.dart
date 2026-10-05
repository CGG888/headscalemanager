import 'package:flutter/material.dart';
import 'package:headscalemanager/l10n/l10n.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/policy_diff_service.dart';
import 'package:provider/provider.dart';

/// 策略变更对比：**当前策略 vs 本地基线**。
///
/// Headscale 只保留当前策略、没有历史，所以基线是"我上次点『设为基线』的那一刻"，
/// 页面会明确显示基线的保存时间，避免让人误以为它是服务端历史。
class PolicyDiffScreen extends StatefulWidget {
  const PolicyDiffScreen({super.key});

  @override
  State<PolicyDiffScreen> createState() => _PolicyDiffScreenState();
}

class _PolicyDiffScreenState extends State<PolicyDiffScreen> {
  bool _isLoading = true;
  String? _error;
  String? _current;
  PolicySnapshot? _snapshot;
  List<PolicyChange> _changes = const [];

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
      final current = await context.read<AppProvider>().apiService.getAclPolicy();
      final snapshot = await PolicyDiffService.load();
      if (!mounted) return;
      setState(() {
        _current = current;
        _snapshot = snapshot;
        _changes = snapshot == null
            ? const []
            : PolicyDiffService.diff(snapshot.json, current);
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

  Future<void> _setBaseline() async {
    final l10n = context.l10n;
    final current = _current;
    if (current == null) return;
    await PolicyDiffService.save(current);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.t('Politique actuelle définie comme référence.',
            'Current policy set as the baseline.', '已将当前策略设为基线。'))));
    await _load();
  }

  String _time(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('Changements de politique',
            'Policy changes', '策略变更对比')),
        actions: [
          IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: l10n.t('Définir comme référence',
                  'Set as baseline', '设为基线'),
              onPressed: _isLoading || _current == null ? null : _setBaseline),
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

    final snapshot = _snapshot;
    if (snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flag_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                l10n.t(
                  'Aucune référence enregistrée. Définissez la politique actuelle comme référence, puis modifiez-la : les différences apparaîtront ici.',
                  'No baseline yet. Set the current policy as the baseline, then edit it: the differences will show up here.',
                  '尚无基线。把当前策略设为基线，之后修改策略时这里会显示差异。',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.t('Référence du ${_time(snapshot.savedAt)}',
              'Baseline from ${_time(snapshot.savedAt)}',
              '基线时间：${_time(snapshot.savedAt)}'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (_changes.isEmpty)
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(l10n.t('Aucun changement par rapport à la référence.',
                      'No change since the baseline.', '与基线相比没有变化。'))),
            ],
          )
        else ...[
          Text(
            l10n.t('${_changes.length} changement(s)',
                '${_changes.length} change(s)', '${_changes.length} 处变更'),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final change in _changes) _buildChange(change, theme),
        ],
      ],
    );
  }

  Widget _buildChange(PolicyChange change, ThemeData theme) {
    final l10n = context.l10n;
    final (color, icon, label) = switch (change.kind) {
      PolicyChangeKind.added => (
          Colors.green,
          Icons.add_circle_outline,
          l10n.t('Ajouté', 'Added', '新增')
        ),
      PolicyChangeKind.removed => (
          theme.colorScheme.error,
          Icons.remove_circle_outline,
          l10n.t('Supprimé', 'Removed', '删除')
        ),
      PolicyChangeKind.changed => (
          Colors.orange,
          Icons.edit_outlined,
          l10n.t('Modifié', 'Changed', '修改')
        ),
    };

    return Card(
      elevation: 0,
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text('$label · ${change.path}'),
        subtitle: Text(change.detail,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
      ),
    );
  }
}
