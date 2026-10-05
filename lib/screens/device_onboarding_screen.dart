import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/l10n/l10n.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/audit_log_service.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 新设备接入向导：**一步把新设备接进网络**。
///
/// 流程刻意做短：选用户 → 选有效期/属性 → 生成密钥 → 出现大二维码与一行命令，
/// 在新设备上扫码或粘贴命令即可。
///
/// 命令形态：`tailscale up --login-server=<你的服务器> --authkey=<密钥>`
/// —— 这正是自建 Headscale 场景下新设备的标准接入方式。
class DeviceOnboardingScreen extends StatefulWidget {
  const DeviceOnboardingScreen({super.key});

  @override
  State<DeviceOnboardingScreen> createState() => _DeviceOnboardingScreenState();
}

class _DeviceOnboardingScreenState extends State<DeviceOnboardingScreen> {
  bool _isLoading = true;
  bool _isCreating = false;
  String? _error;
  List<User> _users = const [];
  User? _selectedUser;

  bool _reusable = false;
  bool _ephemeral = false;

  /// 有效期（null 表示永不过期）。
  Duration? _expiry = const Duration(hours: 24);

  PreAuthKey? _created;
  String? _command;

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
    });
    try {
      final users = await context.read<AppProvider>().apiService.getUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _selectedUser = users.isNotEmpty ? users.first : null;
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

  Future<void> _create() async {
    final user = _selectedUser;
    if (user == null) return;
    final l10n = context.l10n;
    setState(() {
      _isCreating = true;
      _error = null;
    });
    try {
      // 服务器地址要在 await 之前取好（避免跨异步边界使用 BuildContext）
      final serverUrl =
          context.read<AppProvider>().activeServer?.url ?? '';
      final api = context.read<AppProvider>().apiService;
      final key = await api.createPreAuthKey(
            user.id,
            _reusable,
            _ephemeral,
            expiration: _expiry == null ? null : DateTime.now().add(_expiry!),
          );
      if (!mounted) return;
      // 本地留痕：密钥创建是接入新设备的起点，值得记录。
      await AuditLogService.record(
        'createPreAuthKey',
        user.name,
        detail:
            'reusable=$_reusable ephemeral=$_ephemeral expiry=${_expiry ?? 'never'}',
      );
      setState(() {
        _created = key;
        _command =
            'tailscale up --login-server=$serverUrl --authkey=${key.key}';
        _isCreating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isCreating = false;
      });
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
        title: Text(l10n.t('Ajouter un appareil', 'Add a device', '接入新设备')),
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(L10n l10n) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),

        // 1) 归属用户
        Text(l10n.t('Utilisateur', 'User', '归属用户'),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        DropdownButtonFormField<User>(
          initialValue: _selectedUser,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final user in _users)
              DropdownMenuItem(value: user, child: Text(user.name)),
          ],
          onChanged: _created == null
              ? (user) => setState(() => _selectedUser = user)
              : null,
        ),

        // 2) 属性
        SwitchListTile(
          value: _reusable,
          onChanged: _created == null
              ? (v) => setState(() => _reusable = v)
              : null,
          title: Text(l10n.t('Clé réutilisable', 'Reusable key', '可复用密钥')),
          subtitle: Text(l10n.t(
            'Une même clé peut enregistrer plusieurs appareils.',
            'One key can register several devices.',
            '同一密钥可注册多台设备。',
          )),
        ),
        SwitchListTile(
          value: _ephemeral,
          onChanged: _created == null
              ? (v) => setState(() => _ephemeral = v)
              : null,
          title: Text(l10n.t('Appareil éphémère', 'Ephemeral device', '临时设备')),
          subtitle: Text(l10n.t(
            'L\'appareil est supprimé automatiquement hors ligne.',
            'The device is removed automatically once offline.',
            '离线后自动删除该设备。',
          )),
        ),

        // 3) 有效期
        const SizedBox(height: 8),
        Text(l10n.t('Validité', 'Validity', '有效期'),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            _expiryChip(l10n, const Duration(hours: 1), l10n.t('1 h', '1 h', '1 小时')),
            _expiryChip(
                l10n, const Duration(hours: 24), l10n.t('24 h', '24 h', '24 小时')),
            _expiryChip(l10n, const Duration(days: 7), l10n.t('7 j', '7 d', '7 天')),
            _expiryChip(
                l10n, const Duration(days: 30), l10n.t('30 j', '30 d', '30 天')),
            _expiryChip(
                l10n, null, l10n.t('Jamais', 'Never', '永不过期')),
          ],
        ),

        const SizedBox(height: 16),
        if (_created == null)
          FilledButton.icon(
            onPressed: _isCreating || _selectedUser == null ? null : _create,
            icon: _isCreating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.vpn_key),
            label: Text(l10n.t('Générer la clé d\'accès',
                'Generate the access key', '生成接入密钥')),
          )
        else
          _buildResult(l10n),
      ],
    );
  }

  Widget _expiryChip(L10n l10n, Duration? value, String label) {
    final selected = _expiry == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _created == null ? (_) => setState(() => _expiry = value) : null,
    );
  }

  Widget _buildResult(L10n l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          color: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(l10n.t('Scannez ce code sur le nouvel appareil',
                    'Scan this code on the new device', '在新设备上扫描此二维码'),
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                // 二维码内容就是那行命令，扫码后可直接执行/复制
                Center(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: _command ?? '',
                      size: 220,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  _command ?? '',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _command ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(l10n.t('Commande copiée',
                                'Command copied', '命令已复制'))));
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(l10n.t('Copier', 'Copy', '复制')),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _created = null;
                        _command = null;
                      }),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.t('Une autre clé',
                          'Another key', '再生成一个')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.t(
            'Sur l\'appareil : installez Tailscale, puis exécutez la commande ci-dessus (ou scannez le code depuis l\'application Tailscale).',
            'On the device: install Tailscale, then run the command above (or scan the code from the Tailscale app).',
            '在该设备上：安装 Tailscale 后执行上面的命令（也可以在 Tailscale 应用里扫码）。',
          ),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
