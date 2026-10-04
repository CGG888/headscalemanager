import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/version_info.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/help_screen.dart';
import 'package:headscalemanager/screens/help_screen_en.dart';
import 'package:headscalemanager/screens/security_settings_screen.dart';
import 'package:headscalemanager/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:headscalemanager/screens/add_edit_server_screen.dart';
import 'package:headscalemanager/services/tag_migration_service.dart';
import 'package:headscalemanager/widgets/server_list_tile.dart';
import 'package:headscalemanager/widgets/grants_migration_dialog.dart';
import 'package:headscalemanager/screens/api_keys_screen.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appProvider = context.watch<AppProvider>();
    final l10n = L10n(appProvider.locale);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.t('Paramètres', 'Settings', '设置'),
            style: theme.appBarTheme.titleTextStyle),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.t('Serveurs', 'Servers', '服务器'),
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              Expanded(
                flex: 1, // Give 1/3 of space to server list (adjust as needed)
                child: _buildServerList(context),
              ),
              const Divider(height: 16),
              Expanded(
                flex: 2, // Give 2/3 of space to scrollable settings
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            l10n.t('Notifications en arrière-plan', 'Background Notifications', '后台通知'),
                            style: theme.textTheme.titleMedium),
                        subtitle: Text(
                            l10n.t('Vérifie périodiquement les nouvelles demandes d\'approbation.', 'Periodically check for new approval requests.', '定期检查新的审批请求。'),
                            style: theme.textTheme.bodySmall),
                        value: _notificationsEnabled,
                        onChanged: (bool value) async {
                          setState(() {
                            _notificationsEnabled = value;
                          });
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('notificationsEnabled', value);
                          await NotificationService.enableBackgroundTask(value);
                        },
                      ),
                      const Divider(height: 16),
                      // --- Grouped ACL & Migration Section ---
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with Help
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      l10n.t('Moteur ACL & Migration', 'ACL Engine & Migration', 'ACL 引擎与迁移'),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.help_outline,
                                        color: Colors.blue),
                                    onPressed: () =>
                                        _showMigrationHelpDialog(context, l10n),
                                    tooltip: l10n.t('Aide', 'Help', '帮助'),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Text(
                                l10n.t('Moteur de génération ACL', 'ACL Generation Engine', 'ACL 生成引擎'),
                                style: theme.textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              _AclEngineModeTile(
                                l10n: l10n,
                                mode: AclEngineMode.legacy,
                                groupValue: appProvider.aclEngineMode,
                                title: l10n.t('Legacy', 'Legacy', '旧版'),
                                subtitle: l10n.t('Tags fusionnés (ancien format).', 'Merged tags (legacy format).', '标签已合并（旧格式）。'),
                                onChanged: (mode) =>
                                    appProvider.setAclEngineMode(mode),
                              ),
                              _AclEngineModeTile(
                                l10n: l10n,
                                mode: AclEngineMode.standard,
                                groupValue: appProvider.aclEngineMode,
                                title: l10n.t('Standard', 'Standard', 'Standard'),
                                subtitle: l10n.t('Tags séparés (Identity vs Capability).', 'Split tags (Identity vs Capability).', '标签分离（Identity 与 Capability）。'),
                                onChanged: (mode) =>
                                    appProvider.setAclEngineMode(mode),
                              ),
                              _AclEngineModeTile(
                                l10n: l10n,
                                mode: AclEngineMode.grantsV29,
                                groupValue: appProvider.aclEngineMode,
                                title: l10n.t('Grants V29 (via)', 'Grants V29 (via)', 'Grants V29（via）'),
                                subtitle: l10n.t('Headscale ≥ 0.29 — routage via pour LAN/exit.', 'Headscale ≥ 0.29 — via routing for LAN/exit.', 'Headscale ≥ 0.29——为 LAN/出口提供 via 路由。'),
                                enabled: VersionInfo.checkVersionAtLeast(
                                  appProvider.serverVersion,
                                  '0.29.0',
                                ),
                                onChanged: (mode) =>
                                    appProvider.setAclEngineMode(mode),
                              ),
                              if (!VersionInfo.checkVersionAtLeast(
                                appProvider.serverVersion,
                                '0.29.0',
                              ))
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 16, bottom: 8),
                                  child: Text(
                                    l10n.t('Grants V29 nécessite Headscale 0.29.0+.', 'Grants V29 requires Headscale 0.29.0+.', 'Grants V29 需要 Headscale 0.29.0+。'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              const Divider(),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.info_outline,
                                    color: Colors.blue),
                                title: Text(
                                  l10n.t('Version du serveur', 'Server Version', '服务器版本'),
                                  style: theme.textTheme.bodyLarge,
                                ),
                                trailing: Text(
                                  appProvider.serverVersion,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Danger Zone Header inside Card
                              Text(
                                l10n.t('Zone de Danger / Migration', 'Danger / Migration Zone', '危险区 / 迁移'),
                                style: theme.textTheme.titleSmall?.copyWith(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.t('Migrer vers Grants V29', 'Migrate to Grants V29', '迁移到 Grants V29')),
                                subtitle: Text(l10n.t('Régénère la politique avec routage via.', 'Regenerates policy with via routing.', '使用 via 路由重新生成策略。')),
                                trailing: const Icon(Icons.alt_route,
                                    color: Colors.green),
                                enabled: VersionInfo.checkVersionAtLeast(
                                  appProvider.serverVersion,
                                  '0.29.0',
                                ),
                                onTap: VersionInfo.checkVersionAtLeast(
                                  appProvider.serverVersion,
                                  '0.29.0',
                                )
                                    ? () => showDialog(
                                          context: context,
                                          builder: (_) =>
                                              const GrantsMigrationDialog(),
                                        )
                                    : null,
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.t('Rollback Grants → Standard', 'Rollback Grants → Standard', '回滚 Grants → Standard')),
                                subtitle: Text(l10n.t('Revient au moteur Standard (tags séparés).', 'Reverts to Standard engine (split tags).', '恢复为标准引擎（标签拆分）。')),
                                trailing: const Icon(Icons.undo,
                                    color: Colors.orange),
                                onTap: appProvider.aclEngineMode ==
                                        AclEngineMode.grantsV29
                                    ? () => _confirmAction(
                                          context,
                                          l10n.t('Revenir au moteur Standard ?', 'Revert to Standard engine?', '恢复为标准引擎？'),
                                          l10n.t('Les grants via ne seront plus générés. Régénérez la politique ACL ensuite.', 'Via grants will no longer be generated. Regenerate ACL policy afterwards.', '将不再生成 via 授权，之后请重新生成 ACL 策略。'),
                                          () async {
                                            await appProvider.setAclEngineMode(
                                                AclEngineMode.standard);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(l10n.t('Moteur Standard activé.', 'Standard engine enabled.', '标准引擎已启用。')),
                                                ),
                                              );
                                            }
                                          },
                                        )
                                    : null,
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.t('Migrer vers Standard', 'Migrate to Standard', '迁移到标准引擎')),
                                subtitle: Text(l10n.t('Convertit les tags fusionnés.', 'Converts merged tags.', '转换已合并的标签。')),
                                trailing: const Icon(Icons.arrow_forward,
                                    color: Colors.orange),
                                onTap: () => _confirmAction(
                                    context,
                                    l10n.t('Migrer tous les nœuds ?', 'Migrate all nodes?', '迁移所有节点？'),
                                    l10n.t('Ceci va modifier les tags de TOUS vos nœuds. Assurez-vous d\'avoir activé le moteur Standard avant.', 'This will modify tags for ALL nodes. Ensure Standard Engine is enabled first.', '这将修改所有节点的标签。请先确保已启用标准引擎。'),
                                    () => _performMigration(
                                        context, appProvider)),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.t('Rollback vers Legacy', 'Rollback to Legacy', '回滚到 Legacy')),
                                subtitle: Text(l10n.t('Re-fusionne les tags.', 'Re-merges tags.', '重新合并标签。')),
                                trailing: const Icon(Icons.history,
                                    color: Colors.red),
                                onTap: () => _confirmAction(
                                    context,
                                    l10n.t('Annuler la migration ?', 'Rollback migration?', '取消迁移？'),
                                    l10n.t('Ceci va remettre les tags au format fusionné (legacy).', 'This will revert tags to the merged format.', '这会将标签恢复为合并格式（legacy）。'),
                                    () =>
                                        _performRollback(context, appProvider)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          final locale = context.read<AppProvider>().locale;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => locale.languageCode == 'fr'
                                  ? const HelpScreen()
                                  : const HelpScreenEn(),
                            ),
                          );
                        },
                        child: Text(l10n.t('Besoin d\'aide ?', 'Need help?', '需要帮助？'),
                            style: theme.textTheme.labelLarge
                                ?.copyWith(color: theme.colorScheme.primary)),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: Text(l10n.t('Fermer', 'Close', '关闭'),
                            style: theme.textTheme.labelLarge?.copyWith(
                                fontSize: 16,
                                color: theme.colorScheme.onPrimary)),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.menu,
        activeIcon: Icons.close,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.add),
            label: l10n.t('Ajouter un serveur', 'Add Server', '添加服务器'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddEditServerScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.security),
            label: l10n.t('Sécurité', 'Security', '安全'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SecuritySettingsScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.vpn_key),
            label: l10n.t('Clés API', 'API Keys', 'API 密钥'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ApiKeysScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: Text(l10n.languageCode.toUpperCase()),
            label: l10n.t('Langue', 'Language', '语言'),
            onTap: () => _showLanguagePicker(context, appProvider),
          ),
        ],
      ),
    );
  }

  /// 语言选择：法语 / 英语 / 中文（原来是 fr<->en 的二元开关）。
  Future<void> _showLanguagePicker(
      BuildContext context, AppProvider appProvider) async {
    final l10n = L10n(appProvider.locale);
    // 语言名一律用其本族语书写，避免用户看不懂当前语言的选项。
    const options = <String, String>{
      'fr': 'Français',
      'en': 'English',
      'zh': '中文',
    };

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.t('Langue', 'Language', '语言')),
        children: options.entries.map((entry) {
          final isCurrent = appProvider.locale.languageCode == entry.key;
          return SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(entry.key),
            child: Row(
              children: [
                Icon(
                  isCurrent
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: Theme.of(dialogContext).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(entry.value),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected != null) {
      await appProvider.setLocale(Locale(selected));
    }
  }

  Widget _buildServerList(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final servers = appProvider.servers;

    if (servers.isEmpty) {
      return Center(
        child: Text(
          appProvider.locale.languageCode == 'fr'
              ? 'Aucun serveur configuré.'
              : 'No servers configured.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.builder(
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final server = servers[index];
        return ServerListTile(server: server);
      },
    );
  }

  Future<void> _confirmAction(BuildContext context, String title,
      String content, VoidCallback onConfirm) async {
    final l10n = L10n(context.read<AppProvider>().locale);
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              child: Text(l10n.t('Annuler', 'Cancel', '取消')),
              onPressed: () => Navigator.of(ctx).pop()),
          TextButton(
              child: Text(l10n.t('Confirmer', 'Confirm', '确认')),
              onPressed: () {
                Navigator.of(ctx).pop();
                onConfirm();
              }),
        ],
      ),
    );
  }

  Future<void> _performMigration(
      BuildContext context, AppProvider appProvider) async {
    final migrationService = TagMigrationService(appProvider.apiService);
    final l10n = L10n(appProvider.locale);

    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    final result = await migrationService.migrateToStandard();

    if (context.mounted) Navigator.of(context).pop(); // Close loader

    if (context.mounted) {
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: Text(l10n.t('Résultat Migration', 'Migration Result', '迁移结果')),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Succès: ${result.successCount}'),
                      Text('Echecs: ${result.failureCount}'),
                      if (result.errors.isNotEmpty) ...[
                        const Divider(),
                        ...result.errors.map((e) => Text(e,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12))),
                      ]
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'))
                ],
              ));
    }
  }

  Future<void> _performRollback(
      BuildContext context, AppProvider appProvider) async {
    final migrationService = TagMigrationService(appProvider.apiService);
    final l10n = L10n(appProvider.locale);

    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    final result = await migrationService.rollbackToLegacy();

    if (context.mounted) Navigator.of(context).pop(); // Close loader

    if (context.mounted) {
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: Text(l10n.t('Résultat Rollback', 'Rollback Result', '回滚结果')),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Succès: ${result.successCount}'),
                      Text('Echecs: ${result.failureCount}'),
                      if (result.errors.isNotEmpty) ...[
                        const Divider(),
                        ...result.errors.map((e) => Text(e,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12))),
                      ]
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'))
                ],
              ));
    }
  }

  void _showMigrationHelpDialog(BuildContext context, L10n l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('Aide Migration ACL', 'ACL Migration Help', 'ACL 迁移帮助')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpSection(
                context,
                l10n.t('1. Principe', '1. Principle', '1. 原理'),
                l10n.t('Le moteur Legacy utilise des tags "fusionnés" (ex: tag:user;exit-node). Le moteur Standard sépare l\'identité (tag:user-client) des capacités (tag:user-exit-node) pour une meilleure gestion.', 'Legacy engine uses "merged" tags (e.g. tag:user;exit-node). Standard engine splits identity (tag:user-client) from capabilities (tag:user-exit-node) for better management.', 'Legacy 引擎使用「合并」标签（如 tag:user;exit-node）。标准引擎将身份（tag:user-client）与能力（tag:user-exit-node）分离，便于更好地管理。'),
              ),
              _buildHelpSection(
                context,
                l10n.t('2. Procédure de Migration', '2. Migration Procedure', '2. 迁移步骤'),
                l10n.t('A. Activez "Utiliser le moteur ACL standard".\nB. Cliquez sur "Migrer vers Standard".\nC. Redémarrez si nécessaire et vérifiez la connectivité.', 'A. Enable "Use Standard ACL Engine".\nB. Click "Migrate to Standard".\nC. Restart if needed and check connectivity.', 'A. 启用「使用标准 ACL 引擎」。\nB. 点击「迁移到标准」。\nC. 如有需要请重启，并检查连通性。'),
              ),
              _buildHelpSection(
                context,
                l10n.t('3. Procédure de Rollback', '3. Rollback Procedure', '3. 回滚步骤'),
                l10n.t('A. Cliquez sur "Rollback vers Legacy".\nB. Désactivez "Utiliser le moteur ACL standard".\nC. Vérifiez que vos anciens tags sont revenus.', 'A. Click "Rollback to Legacy".\nB. Disable "Use Standard ACL Engine".\nC. Verify your old tags are back.', 'A. 点击「回滚到旧版」。\nB. 禁用「使用标准 ACL 引擎」。\nC. 确认旧标签已恢复。'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  Widget _buildHelpSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(content),
        ],
      ),
    );
  }
}

class _AclEngineModeTile extends StatelessWidget {
  final L10n l10n;
  final AclEngineMode mode;
  final AclEngineMode groupValue;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<AclEngineMode> onChanged;

  const _AclEngineModeTile({
    required this.l10n,
    required this.mode,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final selected = groupValue == mode;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : Icon(Icons.circle_outlined,
              color: Theme.of(context).colorScheme.outline),
      onTap: enabled ? () => onChanged(mode) : null,
    );
  }
}
