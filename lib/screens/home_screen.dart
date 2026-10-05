import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/acl_screen.dart';
import 'package:headscalemanager/screens/dashboard_screen.dart';
import 'package:headscalemanager/screens/network_overview_screen.dart';
import 'package:headscalemanager/screens/settings_screen.dart';
import 'package:headscalemanager/screens/users_screen.dart';
import 'package:headscalemanager/screens/dns_screen.dart';
import 'package:headscalemanager/screens/help_screen.dart';
import 'package:headscalemanager/screens/network_health_screen.dart';
import 'package:headscalemanager/screens/batch_operations_screen.dart';
import 'package:headscalemanager/screens/servers_overview_screen.dart';
import 'package:provider/provider.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/version_info.dart';
import 'package:headscalemanager/widgets/grants_migration_dialog.dart';
import 'package:headscalemanager/widgets/legacy_migration_dialog.dart';
import 'package:headscalemanager/widgets/whats_new_dialog.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForWhatsNew();
      _checkForLegacyTags();
      _checkForGrantsMigration();
    });
  }

  Future<void> _checkForWhatsNew() async {
    final provider = context.read<AppProvider>();
    // Update this version when releasing a new update with relevant "What's New" content
    const currentVersion = '2.4.0';
    const lastVersionKey = 'LAST_SEEN_VERSION';

    try {
      final lastSeenVersion =
          await provider.storageService.getData(lastVersionKey);

      if (lastSeenVersion != currentVersion && mounted) {
        // Show the dialog
        await showDialog(
          barrierDismissible: false,
          context: context,
          builder: (_) => const WhatsNewDialog(),
        );

        // Update stored version after closing
        await provider.storageService.saveData(lastVersionKey, currentVersion);
      }
    } catch (e) {
      // Silent failure
      debugPrint('Error checking for whats new: $e');
    }
  }

  Future<void> _checkForLegacyTags() async {
    final provider = context.read<AppProvider>();
    // Check if migration is already needed based on tags
    try {
      // We explicitly fetch nodes to be sure we have fresh data
      final nodes = await provider.apiService.getNodes();
      final hasLegacyTags =
          nodes.any((n) => n.tags.any((t) => t.contains(';')));

      if (hasLegacyTags && mounted) {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (_) => const LegacyMigrationDialog(),
        );
      }
    } catch (e) {
      // Silent failure check
    }
  }

  Future<void> _checkForGrantsMigration() async {
    final provider = context.read<AppProvider>();
    final serverId = provider.activeServer?.id;
    if (serverId == null) return;
    if (!VersionInfo.checkVersionAtLeast(provider.serverVersion, '0.29.0')) {
      return;
    }
    if (provider.aclEngineMode == AclEngineMode.grantsV29) return;

    try {
      final dismissed =
          await provider.storageService.isGrantsMigrationDismissed(serverId);
      final completed =
          await provider.storageService.isGrantsMigrationCompleted(serverId);
      if (dismissed || completed) return;

      final nodes = await provider.apiService.getNodes();
      final hasLegacyTags =
          nodes.any((n) => n.tags.any((t) => t.contains(';')));
      if (hasLegacyTags) return;

      if (mounted) {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (_) => const GrantsMigrationDialog(),
        );
      }
    } catch (e) {
      debugPrint('Error checking grants migration: $e');
    }
  }

  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    UsersScreen(),
    AclScreen(),
    NetworkOverviewScreen(),
    DnsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    final titles = [
      l10n.t('Tableau de bord', 'Dashboard', '仪表盘'),
      l10n.t('Utilisateurs', 'Users', '用户'),
      'ACLs',
      l10n.t('Réseau', 'Network', '网络'),
      'DNS',
    ];

    final items = <Widget>[
      Icon(Icons.dashboard, size: 30, color: theme.colorScheme.onPrimary),
      Icon(Icons.people, size: 30, color: theme.colorScheme.onPrimary),
      Icon(Icons.shield, size: 30, color: theme.colorScheme.onPrimary),
      Icon(Icons.public,
          size: 30, color: theme.colorScheme.onPrimary),
      Icon(Icons.dns_rounded, size: 30, color: theme.colorScheme.onPrimary),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          if (_selectedIndex == 1) // Users Screen tab
            IconButton(
              icon: Icon(
                context.watch<AppProvider>().usersViewMode == 'grid'
                    ? Icons.list_rounded
                    : Icons.grid_view_rounded,
                color: theme.colorScheme.primary,
              ),
              onPressed: () {
                final provider = context.read<AppProvider>();
                provider.setUsersViewMode(
                  provider.usersViewMode == 'grid' ? 'list' : 'grid',
                );
              },
              tooltip: l10n.t('Changer l\'affichage', 'Change layout', '切换视图'),
            ),
          IconButton(
            icon: Icon(Icons.dns_outlined, color: theme.colorScheme.primary),
            tooltip: l10n.t('Serveurs', 'Servers', '服务器总览'),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ServersOverviewScreen()));
            },
          ),
          IconButton(
            icon: Icon(Icons.checklist, color: theme.colorScheme.primary),
            tooltip: l10n.t('Opérations groupées', 'Batch operations', '批量操作'),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const BatchOperationsScreen()));
            },
          ),
          IconButton(
            icon: Icon(Icons.health_and_safety_outlined,
                color: theme.colorScheme.primary),
            tooltip: l10n.t('Bilan du réseau', 'Network health', '网络体检'),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const NetworkHealthScreen()));
            },
          ),
          IconButton(
            icon: Icon(Icons.help_outline, color: theme.colorScheme.primary),
            onPressed: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpScreen()));
            },
          ),
          IconButton(
            icon: Icon(Icons.settings, color: theme.colorScheme.primary),
            onPressed: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: SafeArea(
        top: false,
        child: CurvedNavigationBar(
          index: _selectedIndex,
          height: 60.0,
          items: items,
          color: theme.colorScheme.primary,
          buttonBackgroundColor: theme.colorScheme.primary,
          backgroundColor: theme.scaffoldBackgroundColor,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 400),
          onTap: _onItemTapped,
          letIndexChange: (index) => true,
        ),
      ),
    );
  }
}
