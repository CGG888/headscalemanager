import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class MoveNodeDialog extends StatefulWidget {
  final Node node;
  final VoidCallback onNodeMoved;

  const MoveNodeDialog(
      {super.key, required this.node, required this.onNodeMoved});

  @override
  State<MoveNodeDialog> createState() => _MoveNodeDialogState();
}

class _MoveNodeDialogState extends State<MoveNodeDialog> {
  User? _selectedUser;
  late Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = context.read<AppProvider>().apiService.getUsers();
  }

  Future<void> _handleMove() async {
    if (_selectedUser == null) {
      Navigator.of(context).pop(false);
      return;
    }

    final provider = context.read<AppProvider>();
    final l10n = L10n(provider.locale);

    try {
      // 1. Move node to the new user
      await provider.apiService.moveNode(widget.node.id, _selectedUser!);
      if (!mounted) return;

      // 2. Update tags to reflect the new owner
      final List<String> oldTags = List.from(widget.node.tags);
      String capabilities = '';
      final clientTag =
          oldTags.firstWhere((t) => t.contains('-client'), orElse: () => '');

      if (clientTag.isNotEmpty) {
        if (clientTag.contains(';')) {
          capabilities = clientTag.substring(clientTag.indexOf(';'));
        }
      }

      final newUserName = normalizeUserName(_selectedUser!.name);
      final newClientTag = 'tag:$newUserName-client$capabilities';

      final newTags = oldTags.where((tag) => !tag.contains('-client')).toList();
      newTags.add(newClientTag);

      await provider.apiService.setTags(widget.node.id, newTags);
      if (!mounted) return;

      // 3. Handle ACLs if necessary
      bool aclMode = true;
      try {
        await provider.apiService.getAclPolicy();
      } catch (e) {
        aclMode = false;
      }

      if (aclMode && mounted) {
        final bool? updateAcls = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.t('Mettre à jour les ACLs ?', 'Update ACLs?')),
            content: Text(l10n.t('Voulez-vous aussi régénérer la politique ACL pour refléter ce changement ?', 'Do you also want to regenerate the ACL policy to reflect this change?')),
            actions: [
              TextButton(
                child: Text(l10n.t('Non', 'No')),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              TextButton(
                child: Text(l10n.t('Oui', 'Yes')),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        );

        if (updateAcls == true && mounted) {
          showSafeSnackBar(
              context, l10n.t('Mise à jour des ACLs...', 'Updating ACLs...'));

          final allUsers = await provider.apiService.getUsers();
          final allNodes = await provider.apiService.getNodes();
          final serverId = provider.activeServer?.id;
          if (serverId == null) {
            if (!mounted) return;
            showSafeSnackBar(
                context,
                l10n.t('Aucun serveur actif sélectionné.', 'No active server selected.'));
            return;
          }
          final tempRules =
              await provider.storageService.getTemporaryRules(serverId);
          final aclOrchestrator = AclPolicyOrchestrator();
          final newPolicyMap = aclOrchestrator.generatePolicy(
            engineMode: provider.aclEngineMode,
            users: allUsers,
            nodes: allNodes,
            temporaryRules: tempRules,
            taildriveShares: provider.taildriveShares,
            serverVersion: provider.serverVersion,
          );
          final newPolicyJson = jsonEncode(newPolicyMap);
          await provider.apiService.setAclPolicy(newPolicyJson);

          if (!mounted) return;
          showSafeSnackBar(
              context, l10n.t('ACLs mises à jour !', 'ACLs updated!'));
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
      widget.onNodeMoved();
    } catch (e) {
      if (mounted) {
        // Show error and then pop
        showSafeSnackBar(
            context, l10n.t('Échec du déplacement: $e', 'Failed to move: $e'));
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n(context.watch<AppProvider>().locale);

    return AlertDialog(
      title: Text(l10n.t('Déplacer l\'appareil', 'Move Device')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            margin: const EdgeInsets.only(bottom: 16.0),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.t('Attention : Cette fonctionnalité est incompatible avec Headscale v0.26+ (commande supprimée).', 'Warning: This feature is incompatible with Headscale v0.26+ (command removed).'),
                    style: const TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: FutureBuilder<List<User>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text(l10n.t('Échec du chargement des utilisateurs : ${snapshot.error}', 'Failed to load users: ${snapshot.error}'));
                }
                final users = snapshot.data ?? [];
                final selectedOwner = widget.node.getNormalizedOwner();
                final otherUsers = users
                    .where((u) => normalizeUserName(u.name) != selectedOwner)
                    .toList();

                if (otherUsers.isEmpty) {
                  return Text(l10n.t('Aucun autre utilisateur disponible.', 'No other users available.'));
                }

                _selectedUser ??= otherUsers.first;

                return DropdownButtonFormField<User>(
                  initialValue: _selectedUser,
                  isExpanded: true,
                  items: otherUsers.map((user) {
                    return DropdownMenuItem<User>(
                      value: user,
                      child: Text(user.name),
                    );
                  }).toList(),
                  onChanged: (user) {
                    setState(() {
                      _selectedUser = user;
                    });
                  },
                  decoration: InputDecoration(
                    labelText:
                        l10n.t('Sélectionner un utilisateur', 'Select a user'),
                    border: const OutlineInputBorder(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: Text(l10n.t('Annuler', 'Cancel')),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          onPressed: _handleMove,
          child: Text(l10n.t('Déplacer', 'Move')),
        ),
      ],
    );
  }
}
