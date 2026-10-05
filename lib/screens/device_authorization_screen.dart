import 'package:flutter/material.dart';
import 'package:headscalemanager/l10n/l10n.dart';
import 'package:headscalemanager/models/device_details.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/node_detail_screen.dart';
import 'package:headscalemanager/services/api_capability_service.dart';
import 'package:provider/provider.dart';

/// 设备授权视图：列出 **`authorized == false`** 的设备。
///
/// 背景：Headscale 的审批接口（`AuthApprove/Reject`）用的是注册流程里的
/// `auth_id`，**服务端无法枚举待审批请求**，所以"待审批列表"做不出来。
/// 但 device API 的 `authorized` 字段能告诉我们**哪些设备尚未被授权**——
/// 这才是可落地、且有同样价值的替代。
///
/// 代价：需要**逐节点**查询 `GET /api/v1/device/{id}`，因此这里做了并发上限，
/// 并对不支持的旧服务端（404）给出明确提示而不是报错。
class DeviceAuthorizationScreen extends StatefulWidget {
  const DeviceAuthorizationScreen({super.key});

  @override
  State<DeviceAuthorizationScreen> createState() =>
      _DeviceAuthorizationScreenState();
}

/// 并发上限：逐节点查询时避免一次性打出几十个请求。
const int _concurrency = 6;

class _DeviceAuthorizationScreenState extends State<DeviceAuthorizationScreen> {
  bool _isLoading = true;
  String? _error;

  /// 未授权的设备（节点 + device 详情）。
  final List<({Node node, DeviceDetails details})> _unauthorized = [];

  /// 成功读取到的设备数（用于判断"是否全都已授权"）。
  int _checked = 0;
  bool _apiUnsupported = false;

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
      _unauthorized.clear();
      _checked = 0;
      _apiUnsupported = false;
    });

    try {
      final provider = context.read<AppProvider>();
      final api = provider.apiService;

      // 先探能力：不支持时不必对每个节点各发一次注定 404 的请求。
      final supported = await ApiCapabilityService.supportsDeviceApi(
        provider.activeServer?.url ?? '',
        provider.activeServer?.apiKey ?? '',
      );
      if (!mounted) return;
      if (supported == false) {
        setState(() {
          _apiUnsupported = true;
          _isLoading = false;
        });
        return;
      }

      final nodes = await api.getNodes();

      var unsupported = 0;
      for (var i = 0; i < nodes.length; i += _concurrency) {
        final chunk = nodes.skip(i).take(_concurrency);
        final results = await Future.wait(chunk.map((node) async {
          try {
            final details = await api.getDeviceDetails(node.id);
            return (node: node, details: details);
          } catch (_) {
            unsupported++;
            return null;
          }
        }));
        if (!mounted) return;
        for (final result in results) {
          if (result == null) continue;
          setState(() => _checked++);
          if (!result.details.authorized) _unauthorized.add(result);
        }
      }

      if (!mounted) return;
      setState(() {
        _apiUnsupported = unsupported == nodes.length && nodes.isNotEmpty;
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

  Future<void> _expire(String nodeId) async {
    await _act(() => context.read<AppProvider>().apiService.expireNode(nodeId));
  }

  Future<void> _delete(String nodeId) async {
    await _act(() => context.read<AppProvider>().apiService.deleteNode(nodeId));
  }

  Future<void> _act(Future<void> Function() action) async {
    final l10n = context.l10n;
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('Fait.', 'Done.', '已完成。'))));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${l10n.t('Échec', 'Failed', '操作失败')}: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title:
            Text(l10n.t('Appareils non autorisés', 'Unauthorized devices', '未授权设备')),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _load),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(L10n l10n) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.t('Vérification des appareils…',
                'Checking devices…', '正在检查设备……')),
          ],
        ),
      );
    }
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
    if (_apiUnsupported) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.t(
              'Ce serveur ne fournit pas l\'API "device" (Headscale 0.29+ requis).',
              'This server does not provide the device API (Headscale 0.29+ required).',
              '该服务端不提供 device API（需要 Headscale 0.29+）。',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_unauthorized.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined,
                size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(l10n.t('Tous les appareils sont autorisés ($_checked vérifiés).',
                'All devices are authorized ($_checked checked).',
                '所有设备均已授权（已检查 $_checked 台）。')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _unauthorized.length,
      itemBuilder: (context, index) {
        final entry = _unauthorized[index];
        final details = entry.details;
        final theme = Theme.of(context);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          elevation: 0,
          color: theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(Icons.gpp_maybe, color: theme.colorScheme.error),
            title: Text(details.name.isEmpty ? entry.node.name : details.name),
            subtitle: Text([
              if (details.os.isNotEmpty) details.os,
              if (details.clientVersion.isNotEmpty) 'v${details.clientVersion}',
              if (details.connectivity?.derp.isNotEmpty ?? false)
                'derp${details.connectivity!.derp}',
              entry.node.user,
            ].join(' · ')),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'view') {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => NodeDetailScreen(node: entry.node)));
                } else if (value == 'expire') {
                  _expire(entry.node.id);
                } else if (value == 'delete') {
                  _delete(entry.node.id);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                    value: 'view',
                    child: Text(l10n.t('Voir', 'View', '查看'))),
                PopupMenuItem(
                    value: 'expire',
                    child: Text(l10n.t('Expirer la clé', 'Expire key', '过期密钥'))),
                PopupMenuItem(
                    value: 'delete',
                    child: Text(l10n.t('Supprimer', 'Delete', '删除'))),
              ],
            ),
          ),
        );
      },
    );
  }
}
