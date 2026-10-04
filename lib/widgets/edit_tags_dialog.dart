import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/api/headscale_api_service.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class EditTagsDialog extends StatefulWidget {
  final Node node;
  final VoidCallback onTagsUpdated;
  final String? fallbackUser;

  const EditTagsDialog({
    super.key,
    required this.node,
    required this.onTagsUpdated,
    this.fallbackUser,
  });

  @override
  State<EditTagsDialog> createState() => _EditTagsDialogState();
}

class _EditTagsDialogState extends State<EditTagsDialog> {
  late List<String> _currentTags;

  @override
  void initState() {
    super.initState();
    // In legacy mode, we consolidate tags on load to present them cleanly.
    // In standard mode, we treat tags as they are.
    final useStandardEngine = context.read<AppProvider>().useStandardAclEngine;
    if (useStandardEngine) {
      _currentTags = List.from(widget.node.tags);
    } else {
      _currentTags = _consolidateTags(List.from(widget.node.tags));
    }
  }

  List<String> _consolidateTags(List<String> tags) {
    // Only used in Legacy Mode
    final clientTagIndex = tags.indexWhere((t) => t.contains('-client'));

    if (clientTagIndex == -1) {
      return tags;
    }

    final clientTag = tags[clientTagIndex];
    final clientTagParts = clientTag
        .replaceFirst('tag:', '')
        .split(';')
        .where((p) => p.isNotEmpty)
        .toSet();

    final otherTags = <String>[];

    for (int i = 0; i < tags.length; i++) {
      if (i == clientTagIndex) continue;
      final tag = tags[i];
      final cleanTag = tag.replaceFirst('tag:', '');

      if (cleanTag == 'exit-node' || cleanTag == 'lan-sharer') {
        clientTagParts.add(cleanTag);
      } else {
        otherTags.add(tag);
      }
    }

    final clientPart = clientTagParts.firstWhere((p) => p.contains('-client'),
        orElse: () => '');
    if (clientPart.isEmpty) return tags;

    final capabilities = clientTagParts.where((p) => p != clientPart).toList()
      ..sort();

    final newClientTagBuilder = StringBuffer('tag:$clientPart');
    if (capabilities.isNotEmpty) {
      newClientTagBuilder.write(';${capabilities.join(';')}');
    }

    return [newClientTagBuilder.toString(), ...otherTags.toSet()];
  }

  String get baseTag {
    // Finds the "main" user tag, e.g. tag:bob-client
    return _currentTags
        .firstWhere((t) => t.contains('-client') && !t.contains(';'),
            orElse: () => _currentTags.firstWhere((t) => t.contains('-client'),
                orElse: () => ''))
        .split(';')
        .first // In case of legacy tag, take the first part
        .replaceFirst('tag:', '');
  }

  bool hasCapabilityTag(String capability) {
    final useStandardEngine = context.read<AppProvider>().useStandardAclEngine;
    if (useStandardEngine) {
      // Check for explicit tag:user-capability
      final userBase = baseTag.replaceAll('-client', ''); // e.g. 'bob'
      return _currentTags.contains('tag:$userBase-$capability');
    } else {
      // Legacy check inside fused tag
      final clientTag = _currentTags.firstWhere((t) => t.contains('-client'),
          orElse: () => '');
      return clientTag.split(';').contains(capability);
    }
  }

  void _updateCapability(String capability, {required bool add}) {
    final useStandardEngine = context.read<AppProvider>().useStandardAclEngine;

    setState(() {
      if (useStandardEngine) {
        // STANDARD MODE: Add/Remove separate tags
        final userBase = baseTag.replaceAll('-client', '');
        final capabilityTag = 'tag:$userBase-$capability'.toLowerCase();

        if (add) {
          if (!_currentTags.contains(capabilityTag)) {
            _currentTags.add(capabilityTag);
          }
        } else {
          _currentTags.remove(capabilityTag);
        }
      } else {
        // LEGACY MODE: Merge into semicolon tag
        final clientTagIndex =
            _currentTags.indexWhere((t) => t.contains('-client'));
        if (clientTagIndex == -1) return;

        final oldClientTag = _currentTags[clientTagIndex];
        final parts = oldClientTag
            .replaceFirst('tag:', '')
            .split(';')
            .where((p) => p.isNotEmpty)
            .toSet();

        if (add) {
          parts.add(capability.toLowerCase());
        } else {
          parts.remove(capability.toLowerCase());
        }

        final clientPart =
            parts.firstWhere((p) => p.contains('-client'), orElse: () => '');
        if (clientPart.isEmpty) return;

        final otherParts = parts.where((p) => p != clientPart).toList()..sort();

        final newClientTagBuilder = StringBuffer('tag:$clientPart');
        if (otherParts.isNotEmpty) {
          newClientTagBuilder.write(';${otherParts.join(';')}');
        }

        _currentTags[clientTagIndex] = newClientTagBuilder.toString();
      }
    });
  }

  void _addCapability(String capability) {
    _updateCapability(capability, add: true);
  }

  void _removeCapability(String capability) {
    _updateCapability(capability, add: false);
  }

  Future<void> _handleSave() async {
    final appProvider = context.read<AppProvider>();
    final apiService = appProvider.apiService;
    final l10n = L10n(appProvider.locale);

    try {
      // Tenter d'enregistrer les tags directement
      try {
        await apiService.setTags(widget.node.id, _currentTags);
      } catch (tagError) {
        // 逻辑判断只依赖服务端原始响应体（rawBody），
        // 不依赖面向用户的展示文案——后者将来会被本地化。
        final raw = tagError is HeadscaleApiException
            ? tagError.rawBody.toLowerCase()
            : tagError.toString().toLowerCase();
        // Si Headscale rejette car le tag n'est pas encore dans tagOwners de l'ACL active
        if (raw.contains('not permitted')) {
          final serverId = appProvider.activeServer?.id;
          if (serverId != null) {
            final allUsers = await apiService.getUsers();
            final allNodes = await apiService.getNodes();
            final tempRules =
                await appProvider.storageService.getTemporaryRules(serverId);

            final aclOrchestrator = AclPolicyOrchestrator();
            final newPolicyMap = aclOrchestrator.generatePolicy(
              engineMode: appProvider.aclEngineMode,
              users: allUsers,
              nodes: allNodes,
              temporaryRules: tempRules,
              taildriveShares: appProvider.taildriveShares,
              serverVersion: appProvider.serverVersion,
            );

            await apiService.setAclPolicy(jsonEncode(newPolicyMap));
            // Retenter l'assignation des tags maintenant que tagOwners est à jour
            await apiService.setTags(widget.node.id, _currentTags);
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      showSafeSnackBar(context, l10n.t('Tags mis à jour.', 'Tags updated.', '标签已更新。'));

      // Check for ACL mode
      bool aclMode = true;
      try {
        await apiService.getAclPolicy();
      } catch (e) {
        aclMode = false;
      }

      if (aclMode && mounted) {
        // Ask for ACL update
        final bool? updateAcls = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.t('Mettre à jour les ACLs ?', 'Update ACLs?', '更新 ACL？')),
            content: Text(l10n.t('Voulez-vous régénérer et appliquer la politique ACL pour que ces changements prennent effet ?', 'Do you want to regenerate and apply the ACL policy for these changes to take effect?', '要重新生成并应用 ACL 策略以使这些更改生效吗？')),
            actions: [
              TextButton(
                child: Text(l10n.t('Non', 'No', '否')),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              TextButton(
                child: Text(l10n.t('Oui', 'Yes', '是')),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        );

        if (updateAcls == true && mounted) {
          showSafeSnackBar(
              context, l10n.t('Mise à jour des ACLs...', 'Updating ACLs...', '正在更新 ACL……'));
          final allUsers = await apiService.getUsers();
          final allNodes = await apiService.getNodes();
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

          final aclOrchestrator = AclPolicyOrchestrator();
          final newPolicyMap = aclOrchestrator.generatePolicy(
            engineMode: appProvider.aclEngineMode,
            users: allUsers,
            nodes: allNodes,
            temporaryRules: tempRules,
            taildriveShares: appProvider.taildriveShares,
            serverVersion: appProvider.serverVersion,
          );

          final newPolicyJson = jsonEncode(newPolicyMap);
          await apiService.setAclPolicy(newPolicyJson);

          if (!mounted) return;
          showSafeSnackBar(
              context, l10n.t('ACLs mises à jour !', 'ACLs updated!', 'ACL 已更新！'));
        }
      }

      // Final actions
      widget.onTagsUpdated();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      showSafeSnackBar(context, l10n.t('Échec: $e', 'Failed: $e', '失败：$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n(context.watch<AppProvider>().locale);

    final clientTag = baseTag;
    final hasExitNode = hasCapabilityTag('exit-node');
    final hasLanSharer = hasCapabilityTag('lan-sharer');

    return AlertDialog(
      title: Text(l10n.t('Modifier les tags', 'Edit tags', '编辑标签')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.t('Note : Avec Headscale v0.26+, les tags sont stricts. Un appareil ne peut plus être "dé-tagué" une fois tagué.', 'Note: With Headscale v0.26+, tags are strict. A device cannot be "un-tagged" once tagged.', '注意：在 Headscale v0.26+ 中，标签是严格的。设备一旦打上标签，就无法再「取消标签」。'),
                      style: const TextStyle(color: Colors.blue, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            Text(l10n.t('Tags Actuels', 'Current Tags', '当前标签'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children:
                  _currentTags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
            const SizedBox(height: 24),
            Text(l10n.t('Suggestions', 'Suggestions', '建议'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (clientTag.isNotEmpty) ...[
              if (!hasExitNode)
                ElevatedButton.icon(
                  onPressed: () => _addCapability('exit-node'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.t('Ajouter ;exit-node', 'Add ;exit-node', '添加 ;exit-node')),
                ),
              if (hasExitNode)
                ElevatedButton.icon(
                  onPressed: () => _removeCapability('exit-node'),
                  icon: const Icon(Icons.remove),
                  label:
                      Text(l10n.t('Retirer ;exit-node', 'Remove ;exit-node', '移除 ;exit-node')),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              const SizedBox(height: 8),
              if (!hasLanSharer)
                ElevatedButton.icon(
                  onPressed: () => _addCapability('lan-sharer'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.t('Ajouter ;lan-sharer', 'Add ;lan-sharer', '添加 ;lan-sharer')),
                ),
              if (hasLanSharer)
                ElevatedButton.icon(
                  onPressed: () => _removeCapability('lan-sharer'),
                  icon: const Icon(Icons.remove),
                  label:
                      Text(l10n.t('Retirer ;lan-sharer', 'Remove ;lan-sharer', '移除 ;lan-sharer')),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
            ] else ...[
              Text(
                  l10n.t('Aucun tag trouvé. Pour intégrer cet appareil aux ACLs, il doit avoir un tag d\'identité.', 'No tags found. To include this device in ACLs, it must have an identity tag.', '未找到标签。要将此设备纳入 ACL，它必须具有身份标签。'),
                  style: const TextStyle(color: Colors.orange)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  // Auto-generate tag based on User Name
                  String rawName = widget.node.getNormalizedOwner();
                  // Si le nom du noeud est invalide (ex: N/A sur OIDC ou tagged-devices sur v0.28), on utilise le fallback (nom de l'utilisateur parent)
                  if (rawName == 'N/A' || rawName.isEmpty || rawName == 'tagged-devices' || rawName == 'n-a' || rawName == 'na') {
                    rawName = widget.fallbackUser ?? 'user';
                  }

                  // Optimize: supports email-style names (jean@domain.com -> jean)
                  // normalizeUserName vient de string_utils.dart
                  String userName = normalizeUserName(rawName);
                  if (userName.isEmpty) userName = 'user';

                  final defaultTag = 'tag:$userName-client';

                  setState(() {
                    _currentTags.add(defaultTag);
                  });
                },
                icon: const Icon(Icons.auto_fix_high),
                label: Builder(builder: (context) {
                  // Calculer le nom affiché sur le bouton dynamiquement pour que l'utilisateur voit ce qu'il va obtenir
                  String rawName = widget.node.getNormalizedOwner();
                  if (rawName == 'N/A' || rawName.isEmpty || rawName == 'tagged-devices' || rawName == 'n-a' || rawName == 'na') {
                    rawName = widget.fallbackUser ?? 'user';
                  }
                  String userName = normalizeUserName(rawName);
                  if (userName.isEmpty) userName = 'user';

                  return Text(l10n.t('Initialiser le Tag (tag:$userName-client)', 'Initialize Tag (tag:$userName-client)', '初始化标签（tag:$userName-client）'));
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text(l10n.t('Annuler', 'Cancel', '取消')),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          onPressed: _handleSave,
          child: Text(l10n.t('Sauvegarder', 'Save', '保存')),
        ),
      ],
    );
  }
}
