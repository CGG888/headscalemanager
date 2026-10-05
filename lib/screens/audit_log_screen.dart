import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/l10n/l10n.dart';
import 'package:headscalemanager/services/audit_log_service.dart';

/// 本地操作记录：App 自己记下的破坏性操作（Headscale 无审计 API）。
///
/// 记录在设备本地，随 App 卸载而消失——用途是**回溯**（"那台机器是谁删的"），
/// 而不是合规审计。
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  bool _isLoading = true;
  List<AuditEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final entries = await AuditLogService.entries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  Future<void> _clear() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('Effacer l\'historique ?', 'Clear the history?', '清空操作记录？')),
        content: Text(l10n.t(
          'Les entrées enregistrées sur cet appareil seront supprimées.',
          'The entries stored on this device will be deleted.',
          '将删除保存在本机的所有记录。',
        )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.t('Annuler', 'Cancel', '取消'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.t('Effacer', 'Clear', '清空'))),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuditLogService.clear();
    await _load();
  }

  /// 动作标识 → 可读文案。
  String _describe(L10n l10n, String action) => switch (action) {
        'batchDeleteNodes' =>
          l10n.t('Suppression groupée de nœuds', 'Batch delete nodes', '批量删除节点'),
        'batchExpireKeys' => l10n.t(
            'Expiration groupée de clés', 'Batch expire keys', '批量过期密钥'),
        'batchApproveRoutes' => l10n.t(
            'Approbation groupée de routes', 'Batch approve routes', '批量批准路由'),
        'createPreAuthKey' => l10n.t(
            'Création d\'une clé de pré-authentification',
            'Created a pre-auth key',
            '创建预认证密钥'),
        _ => action,
      };

  String _formatTime(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 导出为纯文本（复制到剪贴板）：便于贴到工单/聊天里留档。
  String _exportText(L10n l10n) {
    final buffer = StringBuffer()
      ..writeln(l10n.t('Historique des opérations — Headscale Manager',
          'Operation history — Headscale Manager', '操作记录 — Headscale Manager'))
      ..writeln(_formatTime(DateTime.now()))
      ..writeln();
    for (final entry in _entries) {
      buffer.writeln(
          '${_formatTime(entry.timestamp)}  ${entry.success ? 'OK ' : 'FAIL'}  '
          '${_describe(l10n, entry.action)}  ${entry.target}'
          '${entry.detail == null ? '' : '  (${entry.detail})'}');
    }
    return buffer.toString();
  }

  Future<void> _export() async {
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: _exportText(l10n)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.t('Historique copié (${_entries.length} entrées)',
          'History copied (${_entries.length} entries)',
          '已复制 ${_entries.length} 条记录')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('Historique des opérations',
            'Operation history', '操作记录')),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_all),
              tooltip: l10n.t('Copier tout', 'Copy all', '复制全部'),
              onPressed: _export,
            ),
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _load),
          if (_entries.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.delete_outline), onPressed: _clear),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.t(
                        'Aucune opération enregistrée pour le moment. Les suppressions, expirations de clés et changements de routes apparaîtront ici.',
                        'No operation recorded yet. Deletions, key expirations and route changes will appear here.',
                        '暂无记录。删除节点、过期密钥、批准路由等操作会显示在这里。',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final theme = Theme.of(context);
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        entry.success ? Icons.check_circle_outline : Icons.error_outline,
                        size: 18,
                        color: entry.success
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                      title: Text(_describe(l10n, entry.action)),
                      subtitle: Text([
                        _formatTime(entry.timestamp),
                        entry.target,
                        if (entry.detail != null) entry.detail!,
                      ].join(' · ')),
                    );
                  },
                ),
    );
  }
}
