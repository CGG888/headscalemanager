import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/l10n/l10n.dart';

/// Dialogue pour configurer un nœud comme nœud de sortie.
///
/// Affiche les commandes Tailscale nécessaires et les instructions spécifiques
/// à la plateforme pour activer la fonctionnalité de nœud de sortie.
class ExitNodeCommandDialog extends StatefulWidget {
  /// Le nœud à configurer comme nœud de sortie.
  final Node node;

  /// Fonction de rappel appelée après la confirmation de l'activation du nœud de sortie.
  final VoidCallback onExitNodeEnabled;

  const ExitNodeCommandDialog({
    super.key,
    required this.node,
    required this.onExitNodeEnabled,
  });

  @override
  State<ExitNodeCommandDialog> createState() => _ExitNodeCommandDialogState();
}

class _ExitNodeCommandDialogState extends State<ExitNodeCommandDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    final serverUrl = appProvider.activeServer?.url;

    if (serverUrl == null) {
      return AlertDialog(
        title: Text(l10n.t('Erreur', 'Error', '错误')),
        content: Text(l10n.t('URL du serveur non configurée.', 'Server URL not configured.', '未配置服务器 URL。')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.t('Fermer', 'Close', '关闭')),
          ),
        ],
      );
    }

    final String loginServer = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    final String tailscaleCommand =
        'tailscale up --advertise-exit-node --login-server=$loginServer';

    return AlertDialog(
      // Changed from SubnetCommandDialog to AlertDialog
      title: Text(l10n.t('Étape 1 : Configurer le nœud de sortie', 'Step 1: Configure Exit Node', '第 1 步：配置出口节点')),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Linux'),
                Tab(text: 'Windows'),
                Tab(text: 'Mobile'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Instructions Linux
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('Sur votre appareil Linux, assurez-vous que le transfert IP est activé si vous souhaitez acheminer le trafic d\'autres appareils via ce nœud de sortie. Exécutez ensuite la commande Tailscale :', 'On your Linux device, ensure IP forwarding is enabled if you want to route traffic from other devices through this exit node. Then run the Tailscale command:', '在 Linux 设备上，如需通过此出口节点转发其他设备的流量，请确保已启用 IP 转发。然后执行 Tailscale 命令：')),
                        const SizedBox(height: 8),
                        const SelectableText(
                            'sudo sysctl -w net.ipv4.ip_forward=1',
                            style: TextStyle(
                                fontFamily: 'monospace', fontSize: 14)),
                        const SizedBox(height: 8),
                        SelectableText(
                          tailscaleCommand,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  // Instructions Windows
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('Sur votre appareil Windows, assurez-vous que le transfert IP est activé si vous souhaitez acheminer le trafic d\'autres appareils via ce nœud de sortie. Exécutez ensuite la commande Tailscale :', 'On your Windows device, ensure IP forwarding is enabled if you want to route traffic from other devices through this exit node. Then run the Tailscale command:', '在 Windows 设备上，如需通过此出口节点转发其他设备的流量，请确保已启用 IP 转发。然后执行 Tailscale 命令：')),
                        const SizedBox(height: 8),
                        const SelectableText(
                            '# Activer le transfert IP (PowerShell en tant qu\'administrateur)\nSet-NetIPInterface -InterfaceAlias "Ethernet" -Forwarding Enabled',
                            style: TextStyle(
                                fontFamily: 'monospace', fontSize: 14)),
                        const SizedBox(height: 8),
                        SelectableText(
                          tailscaleCommand,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  // Instructions mobiles
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(l10n.t('Sur votre appareil mobile (Android/iOS), allez dans les paramètres du client Tailscale, sélectionnez l\'option "Exit nodes", puis activez l\'option "Run as exit node". Aucune ligne de commande n\'est nécessaire.', 'On your mobile device (Android/iOS), go to the Tailscale client settings, select the "Exit nodes" option, then enable the "Run as exit node" option. No command line is necessary.', '在移动设备（Android/iOS）上，进入 Tailscale 客户端设置，选择「Exit nodes」选项，然后启用「Run as exit node」选项。无需命令行。')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text(l10n.t('Fermer', 'Close', '关闭')),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(
              l10n.t('Copier la commande Tailscale', 'Copy Tailscale Command', '复制 Tailscale 命令')),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: tailscaleCommand));
            if (!context.mounted) return;
            showSafeSnackBar(
                context,
                l10n.t('Commande Tailscale copiée dans le presse-papiers !', 'Tailscale command copied to clipboard!', 'Tailscale 命令已复制到剪贴板！'));
          },
        ),
        ElevatedButton(
            child: Text(l10n.t('Procéder à la confirmation', 'Proceed to Confirmation', '前往确认')),
            onPressed: () async {
              // Show loading or just wait
              try {
                // 1. Update Tags (add exit-node capability)
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
                    final capTag = 'tag:$normUser-exit-node';
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
                    if (!oldTag.contains('exit-node')) {
                      newTags = List.from(currentTags);
                      newTags[clientTagIndex] = '$oldTag;exit-node';
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
                if (!combinedRoutes.contains('0.0.0.0/0')) {
                  combinedRoutes.add('0.0.0.0/0');
                }
                if (!combinedRoutes.contains('::/0')) {
                  combinedRoutes.add('::/0');
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
                  showSafeSnackBar(context,
                      l10n.t('Nœud de sortie activé.', 'Exit node enabled.', '出口节点已启用。'));
                  Navigator.of(context).pop();
                }

                widget.onExitNodeEnabled();
              } catch (e) {
                debugPrint('Error enabling exit node: $e');
                if (context.mounted) {
                  showSafeSnackBar(context, l10n.t('Erreur: $e', 'Error: $e', '错误：$e'));
                  Navigator.of(context).pop();
                }
              }
            }),
      ],
    );
  }
}
