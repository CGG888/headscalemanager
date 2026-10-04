import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class ManageSpecificRulesDialog extends StatefulWidget {
  final List<Node> allNodes;

  const ManageSpecificRulesDialog({super.key, required this.allNodes});

  @override
  State<ManageSpecificRulesDialog> createState() =>
      _ManageSpecificRulesDialogState();
}

class _ManageSpecificRulesDialogState extends State<ManageSpecificRulesDialog> {
  List<Map<String, dynamic>> _temporaryRules = [];
  bool _isLoading = true;
  bool _rulesChanged = false;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
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
    final loadedRules = await storage.getTemporaryRules(serverId);
    if (mounted) {
      setState(() {
        _temporaryRules = loadedRules;
        _isLoading = false;
      });
    }
  }

  String _getNodeNameFromIpOrSubnet(String ipOrSubnet) {
    try {
      return widget.allNodes
          .firstWhere((node) =>
              node.ipAddresses.contains(ipOrSubnet) ||
              node.sharedRoutes.contains(ipOrSubnet))
          .name;
    } catch (e) {
      return ipOrSubnet;
    }
  }

  Future<void> _removeTemporaryRule(int index) async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);

    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.t('Confirmer la suppression', 'Confirm Deletion', '确认删除')),
            content: Text(l10n.t('Cela va supprimer la règle et appliquer immédiatement la nouvelle politique au serveur. Continuer ?', 'This will delete the rule and immediately apply the new policy to the server. Continue?', '这将删除该规则并立即将新策略应用到服务器。是否继续？')),
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
      _temporaryRules.removeAt(index);
      _rulesChanged = true;
    });

    final appProvider = context.read<AppProvider>();
    final storage = appProvider.storageService;
    final serverId = appProvider.activeServer?.id;
    if (serverId != null) {
      await storage.saveTemporaryRules(serverId, _temporaryRules);
    }
    await _generateAndExportPolicy(
        message: l10n.t('Règle supprimée et politique mise à jour.', 'Rule deleted and policy updated.', '规则已删除并更新策略。'));
  }

  Future<void> _generateAndExportPolicy({String? message}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);

    try {
      final appProvider = context.read<AppProvider>();
      final apiService = appProvider.apiService;
      final users = await apiService.getUsers();
      final nodes = widget.allNodes;

      final aclOrchestrator = AclPolicyOrchestrator();
      final newPolicy = aclOrchestrator.generatePolicy(
        engineMode: appProvider.aclEngineMode,
        users: users,
        nodes: nodes,
        temporaryRules: _temporaryRules,
        taildriveShares: appProvider.taildriveShares,
        serverVersion: appProvider.serverVersion,
      );

      const encoder = JsonEncoder.withIndent('  ');
      final policyString = encoder.convert(newPolicy);

      await apiService.setAclPolicy(policyString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(message ??
                  (l10n.t('Politique mise à jour.', 'Policy updated.', '策略已更新。'))),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${l10n.t("Erreur lors de la mise à jour de la politique", "Error updating policy", '更新策略时出错')}: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return AlertDialog(
      title:
          Text(l10n.t('Règles Spécifiques Actives', 'Active Specific Rules', '已启用的特定规则')),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _temporaryRules.isEmpty
                ? Center(
                    child: Text(l10n.t('Aucune règle spécifique active.', 'No active specific rules.', '无活动的特定规则。')))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _temporaryRules.length,
                    itemBuilder: (context, index) {
                      final rule = _temporaryRules[index];
                      final src = rule['src'] as String;
                      final dst = rule['dst'] as String;
                      final port = rule['port'] as String?;

                      final srcNodeName = _getNodeNameFromIpOrSubnet(src);
                      final dstNodeName = _getNodeNameFromIpOrSubnet(dst);

                      final label =
                          '$srcNodeName -> $dstNodeName:${port != null && port.isNotEmpty ? port : '*'}';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4.0, horizontal: 8.0),
                        child: ListTile(
                          title: Text(label, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeTemporaryRule(index),
                          ),
                          onTap: () => _showRuleDetails(rule),
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_rulesChanged),
          child: Text(l10n.t('Fermer', 'Close', '关闭')),
        ),
      ],
    );
  }

  void _showRuleDetails(Map<String, dynamic> rule) {
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);

    final srcIp = rule['src'] as String;
    final dstIpOrSubnet = rule['dst'] as String;
    final port = rule['port'] as String?;

    Node? srcNode;
    Node? dstNode;
    try {
      srcNode =
          widget.allNodes.firstWhere((n) => n.ipAddresses.contains(srcIp));
    } catch (e) {
      // Node not found
    }
    try {
      dstNode = widget.allNodes.firstWhere((n) =>
          n.ipAddresses.contains(dstIpOrSubnet) ||
          n.sharedRoutes.contains(dstIpOrSubnet));
    } catch (e) {
      // Node not found
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('Détails de la Règle', 'Rule Details', '规则详情')),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              _buildDetailRow(l10n.t('Source', 'Source', '源'),
                  srcNode?.name ?? (l10n.t('Inconnu', 'Unknown', '未知'))),
              _buildDetailRow(context.l10n.t('IP Source', 'Source IP', '源 IP'), srcIp),
              if (srcNode != null)
                _buildDetailRow(context.l10n.t('IPs Source', 'Source IPs', '源 IP（多个）'), srcNode.ipAddresses.join(', ')),
              const Divider(),
              _buildDetailRow(l10n.t('Destination', 'Destination', '目标'),
                  dstNode?.name ?? dstIpOrSubnet),
              _buildDetailRow(
                    context.l10n.t('IP/Subnet Dest.', 'Dest. IP/Subnet', '目标 IP/子网'), dstIpOrSubnet),
              if (dstNode != null)
                _buildDetailRow(context.l10n.t('IPs Dest.', 'Dest. IPs', '目标 IP（多个）'), dstNode.ipAddresses.join(', ')),
              if (dstNode != null && dstNode.sharedRoutes.isNotEmpty)
                _buildDetailRow(
                    context.l10n.t('Routes Partagées', 'Shared routes', '已共享路由'), dstNode.sharedRoutes.join(', ')),
              const Divider(),
              _buildDetailRow(
                  context.l10n.t('Port(s)', 'Port(s)', '端口'), port != null && port.isNotEmpty ? port : '*'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(l10n.t('Fermer', 'Close', '关闭')),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(context.l10n.t('$label :', '$label: ', '$label：'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
