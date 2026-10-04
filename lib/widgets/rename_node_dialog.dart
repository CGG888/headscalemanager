import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'dart:convert';
import 'package:headscalemanager/l10n/l10n.dart';

/// Dialogue pour renommer un nœud.
///
/// Permet à l'utilisateur de saisir un nouveau nom pour le nœud.
/// Valide le nouveau nom et appelle l'API pour renommer le nœud.
class RenameNodeDialog extends StatefulWidget {
  /// Le nœud à renommer.
  final Node node;

  /// Fonction de rappel appelée après le renommage du nœud.
  final VoidCallback onNodeRenamed;

  const RenameNodeDialog({
    super.key,
    required this.node,
    required this.onNodeRenamed,
  });

  @override
  State<RenameNodeDialog> createState() => _RenameNodeDialogState();
}

class _RenameNodeDialogState extends State<RenameNodeDialog> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.node.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return AlertDialog(
      title: Text(l10n.t('Renommer l\'appareil', 'Rename Device', '重命名设备')),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.t('Nouveau nom', 'New name', '新名称'),
            hintText: l10n.t('Entrez le nouveau nom de l\'appareil', 'Enter the new device name', '输入新的设备名称'),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.t('Le nom ne peut pas être vide.', 'Name cannot be empty.', '名称不能为空。');
            }
            return null;
          },
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          child: Text(l10n.t('Annuler', 'Cancel', '取消')),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(l10n.t('Renommer', 'Rename', '重命名')),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final newName = _nameController.text.trim();

              // Validation RFC 1123 stricte
              if (!isValidDns1123Subdomain(newName)) {
                final sanitized = sanitizeDns1123Subdomain(newName);
                showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                          title:
                              Text(l10n.t('Format Invalide', 'Invalid Format', '格式无效')),
                          content: Text(l10n.t('Le nom "$newName" ne respecte pas le format DNS (RFC 1123).\n\nCaractères autorisés : a-z, 0-9 et tirets.\nPas de majuscules ni de caractères spéciaux.\n\nVoulez-vous utiliser "$sanitized" à la place ?', 'The name "$newName" does not match DNS format (RFC 1123).\n\nAllowed: a-z, 0-9, and dashes.\nNo uppercase or special characters.\n\nDo you want to use "$sanitized" instead?', '名称 "$newName" 不符合 DNS 格式（RFC 1123）。\n\n允许的字符：a-z、0-9 和连字符。\n不能使用大写字母或特殊字符。\n\n是否改用 "$sanitized"？')),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(l10n.t('Annuler', 'Cancel', '取消'))),
                            TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _nameController.text = sanitized;
                                },
                                child: Text(l10n.t('Utiliser corrigé', 'Use corrected', '使用修正后的值'))),
                          ],
                        ));
                return;
              }

              try {
                final appProvider = context.read<AppProvider>();
                final apiService = appProvider.apiService;

                // 1. Renommer le nœud
                await apiService.renameNode(widget.node.id, newName);

                // 2. Régénérer les ACLs pour garantir la cohérence
                final serverId = appProvider.activeServer?.id;
                if (serverId != null) {
                  if (!context.mounted) return;
                  showSafeSnackBar(context,
                      l10n.t('Mise à jour des ACLs...', 'Updating ACLs...', '正在更新 ACL……'));
                  final allUsers = await apiService.getUsers();
                  final allNodes = await apiService.getNodes();
                  final tempRules = await appProvider.storageService
                      .getTemporaryRules(serverId);

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
                }

                if (!context.mounted) return;
                widget.onNodeRenamed();
                Navigator.of(context).pop();
                showSafeSnackBar(
                    context,
                    l10n.t('Appareil renommé et ACLs mises à jour.', 'Device renamed and ACLs updated.', '设备已重命名并更新 ACL。'));
              } catch (e) {
                showSafeSnackBar(
                    context,
                    l10n.t('Erreur lors du renommage: $e', 'Error while renaming: $e', '重命名时出错：$e'));
              }
            }
          },
        ),
      ],
    );
  }
}
