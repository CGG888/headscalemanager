import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
// For debugPrint
import 'package:headscalemanager/widgets/subnet_command_dialog.dart'; // Import the new dialog
import 'package:headscalemanager/l10n/l10n.dart';

/// Dialogue pour partager un sous-réseau local via un nœud Headscale.
///
/// Permet à l'utilisateur de saisir un sous-réseau au format CIDR et génère
/// la commande Tailscale correspondante pour annoncer cette route.
class ShareSubnetDialog extends StatefulWidget {
  /// Le nœud via lequel le sous-réseau sera partagé.
  final Node node;

  /// Fonction de rappel appelée après la confirmation du partage du sous-réseau.
  final VoidCallback onSubnetShared;

  const ShareSubnetDialog(
      {super.key, required this.node, required this.onSubnetShared});

  @override
  State<ShareSubnetDialog> createState() => _ShareSubnetDialogState();
}

class _ShareSubnetDialogState extends State<ShareSubnetDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _subnetController =
      TextEditingController(text: '192.168.1.0/24');

  @override
  void dispose() {
    _subnetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return AlertDialog(
      title:
          Text(l10n.t('Partager le sous-réseau local', 'Share Local Subnet', '共享本地子网')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.t('Entrez le sous-réseau à annoncer (par exemple, 192.168.1.0/24).\n\nNote : L\'appareil doit être configuré pour annoncer cette route.', 'Enter the subnet to advertise (e.g., 192.168.1.0/24).\n\nNote: The device must be configured to advertise this route.', '输入要通告的子网（例如 192.168.1.0/24）。\n\n注意：设备必须配置为通告此路由。')),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _subnetController,
                decoration: InputDecoration(
                    labelText: l10n.t('Sous-réseau (format CIDR)', 'Subnet (CIDR format)', '子网（CIDR 格式）')),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.t('Veuillez entrer un sous-réseau', 'Please enter a subnet', '请输入子网');
                  }
                  final regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}');
                  if (!regex.hasMatch(value)) {
                    return l10n.t('Format CIDR invalide', 'Invalid CIDR format', 'CIDR 格式无效');
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(l10n.t('Annuler', 'Cancel', '取消')),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(l10n.t('Partager', 'Share', '分享')),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final String newSubnet = _subnetController.text;

              try {
                // 1. Update Tags (add lan-sharer capability)
                final useStandardEngine = appProvider.useStandardAclEngine;
                List<String> currentTags = List.from(widget.node.tags);
                List<String> newTags = [];

                if (useStandardEngine) {
                  // Standard Mode
                  final clientTag = currentTags.firstWhere(
                      (t) => t.contains('-client'),
                      orElse: () => '');
                  if (clientTag.isNotEmpty) {
                    final normUser = widget.node.getNormalizedOwner();
                    final capTag = 'tag:$normUser-lan-sharer';
                    if (!currentTags.contains(capTag)) {
                      newTags = [...currentTags, capTag];
                    } else {
                      newTags = currentTags;
                    }
                  } else {
                    newTags = currentTags; // Fallback
                  }
                } else {
                  // Legacy Mode
                  final clientTagIndex =
                      currentTags.indexWhere((t) => t.contains('-client'));
                  if (clientTagIndex != -1) {
                    final oldTag = currentTags[clientTagIndex];
                    if (!oldTag.contains('lan-sharer')) {
                      newTags = List.from(currentTags);
                      newTags[clientTagIndex] = '$oldTag;lan-sharer';
                    } else {
                      newTags = currentTags;
                    }
                  } else {
                    newTags = currentTags;
                  }
                }

                if (newTags != currentTags) {
                  await appProvider.apiService.setTags(widget.node.id, newTags);
                }

                // 2. Set Routes
                final List<String> combinedRoutes =
                    List.from(widget.node.sharedRoutes);
                if (!combinedRoutes.contains(newSubnet)) {
                  combinedRoutes.add(newSubnet);
                }

                await appProvider.apiService
                    .setNodeRoutes(widget.node.id, combinedRoutes);

                // 3. Update ACLs if in ACL Mode
                bool aclMode = true;
                try {
                  await appProvider.apiService.getAclPolicy();
                } catch (e) {
                  aclMode = false;
                }

                if (aclMode) {
                  if (context.mounted) {
                    showSafeSnackBar(context,
                        l10n.t('Mise à jour des ACLs...', 'Updating ACLs...', '正在更新 ACL……'));
                  }
                  // Regenerate Policy
                  final allUsers = await appProvider.apiService.getUsers();
                  final allNodes = await appProvider.apiService.getNodes();
                  final serverId = appProvider.activeServer?.id;

                  if (serverId != null) {
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

                    final newPolicyJson = jsonEncode(newPolicyMap);
                    await appProvider.apiService.setAclPolicy(newPolicyJson);
                  }
                }

                if (context.mounted) {
                  showSafeSnackBar(
                      context,
                      l10n.t('Route de sous-réseau activée.', 'Subnet route enabled.', '子网路由已启用。'));
                }
                widget.onSubnetShared();

                if (!context.mounted) return;
                Navigator.of(context).pop();

                final serverUrl = appProvider.activeServer?.url;
                final String loginServer = serverUrl?.endsWith('/') == true
                    ? serverUrl!.substring(0, serverUrl.length - 1)
                    : serverUrl ?? '';

                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => SubnetCommandDialog(
                    title: l10n.t('Sur le client : Configurer le routage de sous-réseau', 'On the client: Configure subnet routing', '在客户端：配置子网路由'),
                    tailscaleCommand:
                        'tailscale up --advertise-routes=$newSubnet --login-server=$loginServer',
                    linuxInstructions: l10n.t('Sur votre appareil Linux, activez le transfert IP et le NAT, puis exécutez la commande Tailscale :', 'On your Linux device, enable IP forwarding and NAT, then run the Tailscale command:', '在 Linux 设备上启用 IP 转发和 NAT，然后执行 Tailscale 命令：'),
                    windowsInstructions: l10n.t('Sur votre appareil Windows, activez le transfert IP et le NAT (partage de connexion Internet), puis exécutez la commande Tailscale :', 'On your Windows device, enable IP forwarding and NAT (Internet Connection Sharing), then run the Tailscale command:', '在 Windows 设备上启用 IP 转发和 NAT（Internet 连接共享），然后执行 Tailscale 命令：'),
                    mobileInstructions: l10n.t('Sur votre appareil mobile (Android/iOS), allez dans les paramètres du client Tailscale et activez l\'option "Allow LAN access".', 'On your mobile device (Android/iOS), go to the Tailscale client settings and enable the "Allow LAN access" option.', '在移动设备（Android/iOS）上，进入 Tailscale 客户端设置并启用「Allow LAN access」选项。'),
                  ),
                );
              } catch (e) {
                debugPrint(
                    'Erreur lors de l\'activation de la route de sous-réseau : $e');
                if (!mounted) return;
                Navigator.of(context).pop();
                showSafeSnackBar(
                    context,
                    l10n.t('Échec de l\'activation de la route de sous-réseau : $e', 'Failed to enable subnet route: $e', '启用子网路由失败：$e'));
              }
            }
          },
        ),
      ],
    );
  }
}
