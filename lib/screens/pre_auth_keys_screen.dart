import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/widgets/create_pre_auth_key_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Importation pour le QR code
import 'package:headscalemanager/l10n/l10n.dart';

class PreAuthKeysScreen extends StatefulWidget {
  const PreAuthKeysScreen({super.key});

  @override
  State<PreAuthKeysScreen> createState() => _PreAuthKeysScreenState();
}

class _PreAuthKeysScreenState extends State<PreAuthKeysScreen> {
  late Future<List<PreAuthKey>> _preAuthKeysFuture;
  late Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _preAuthKeysFuture =
          context.read<AppProvider>().apiService.getPreAuthKeys();
      _usersFuture = context.read<AppProvider>().apiService.getUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
            l10n.t('Clés de Pré-authentification', 'Pre-authentication Keys', '预认证密钥'),
            style: theme.appBarTheme.titleTextStyle),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: FutureBuilder<List<PreAuthKey>>(
        future: _preAuthKeysFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(
                    color: theme.colorScheme.primary));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('${l10n.t('Erreur', 'Error', '错误')}: ${snapshot.error}',
                    style: theme.textTheme.bodyMedium));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text(
                    l10n.t('Aucune clé de pré-authentification trouvée.', 'No pre-authentication keys found.', '未找到预认证密钥。'),
                    style: theme.textTheme.bodyMedium));
          }

          final allKeys = snapshot.data!;
          final activeKeys = allKeys.where((key) {
            final isExpired = key.expiration != null &&
                key.expiration!.isBefore(DateTime.now());
            return !isExpired && !key.used;
          }).toList();

          if (activeKeys.isEmpty) {
            return Center(
                child: Text(
                    l10n.t('Aucune clé de pré-authentification active.', 'No active pre-authentication keys.', '无活动的预认证密钥。'),
                    style: theme.textTheme.bodyMedium));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: activeKeys.length,
            itemBuilder: (context, index) {
              final key = activeKeys[index];
              return _PreAuthKeyCard(
                apiKey: key,
                onAction: _refreshData,
                onShowQrCode: _showQrCodeDialog, // Passer la fonction ici
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewKey,
        tooltip: l10n.t('Créer une clé de pré-authentification', 'Create a pre-authentication key', '创建预认证密钥'),
        backgroundColor: theme.colorScheme.primary,
        child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
      ),
    );
  }

  Future<void> _createNewKey() async {
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);
    final result = await showDialog<PreAuthKey?>(
      context: context,
      builder: (ctx) => CreatePreAuthKeyDialog(usersFuture: _usersFuture),
    );
    if (result != null) {
      if (!mounted) return;
      _refreshData();
      showSafeSnackBar(
          context,
          l10n.t('Clé de pré-authentification créée.', 'Pre-authentication key created.', '预认证密钥已创建。'));
      final appProvider = context.read<AppProvider>();
      final serverUrl = appProvider.activeServer?.url;
      final String loginServer = serverUrl?.endsWith('/') == true
          ? serverUrl!.substring(0, serverUrl.length - 1)
          : serverUrl ?? '';
      _showTailscaleUpCommandDialog(context, result, loginServer);
    }
  }

  void _showTailscaleUpCommandDialog(
      BuildContext context, PreAuthKey key, String loginServer) {
    final theme = Theme.of(context);
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);
    final fullCommand =
        'tailscale up --login-server=$loginServer --authkey=${key.key}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            l10n.t('Commande d\'enregistrement', 'Registration Command', '注册命令'),
            style: theme.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                l10n.t('Copiez et exécutez cette commande sur votre appareil pour vous connecter.', 'Copy and run this command on your device to connect.', '在你的设备上复制并运行此命令即可连接。'),
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            SelectableText(fullCommand,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontFamily: 'monospace')),
          ],
        ),
        actions: [
          TextButton(
            child: Text(l10n.t('Expirer la clé', 'Expire Key', '使密钥过期'),
                style: theme.textTheme.labelLarge?.copyWith(color: Colors.red)),
            onPressed: () async {
              try {
                final apiService = context.read<AppProvider>().apiService;
                await apiService.expirePreAuthKey(key.user!.id, key.key);
                if (!context.mounted) return;
                _refreshData();
                Navigator.of(context).pop();
                showSafeSnackBar(
                    context,
                    l10n.t('Clé expirée avec succès.', 'Key expired successfully.', '密钥已成功过期。'));
              } catch (e) {
                showSafeSnackBar(context,
                    '${l10n.t('Erreur lors de l\'expiration de la clé', 'Error expiring key', '密钥过期时出错')}: $e');
              }
            },
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.qr_code, color: theme.colorScheme.onPrimary),
            label: Text(context.l10n.t('QR Code', 'QR code', '二维码'),
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onPrimary)),
            onPressed: () {
              Navigator.of(context).pop(); // Ferme le dialogue actuel
              _showQrCodeDialog(
                  context, fullCommand); // Ouvre le dialogue QR Code
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.copy, color: theme.colorScheme.onPrimary),
            label: Text(l10n.t('Copier', 'Copy', '复制'),
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onPrimary)),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullCommand));
              if (!context.mounted) return;
              showSafeSnackBar(
                  context,
                  l10n.t('Commande copiée dans le presse-papiers !', 'Command copied to clipboard!', '命令已复制到剪贴板！'));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  void _showQrCodeDialog(BuildContext context, String data) {
    final theme = Theme.of(context);
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('QR Code pour la commande', 'QR Code for command', '命令二维码'),
            style: theme.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: data,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
              // foregroundColor is deprecated, verify if QrImageView needs replacement or update
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
              errorStateBuilder: (cxt, err) {
                return Center(
                  child: Text(
                    context.l10n.t(
                        'Oups ! Une erreur est survenue : ($err)',
                        'Uh oh! Something went wrong: ($err)', '出错了：（$err）'),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
                l10n.t('Scannez ce QR code avec votre appareil mobile pour obtenir la commande.', 'Scan this QR code with your mobile device to get the command.', '用移动设备扫描此二维码即可获取命令。'),
                style: theme.textTheme.bodyMedium),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.t('Fermer', 'Close', '关闭'),
                style: theme.textTheme.labelLarge),
          ),
        ],
      ),
    );
  }
}

class _PreAuthKeyCard extends StatelessWidget {
  final PreAuthKey apiKey;
  final VoidCallback onAction;
  final Function(BuildContext, String) onShowQrCode; // Nouveau callback

  const _PreAuthKeyCard({
    required this.apiKey,
    required this.onAction,
    required this.onShowQrCode, // Requis
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    return Card(
      elevation: 0,
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text(
            apiKey.key.startsWith('hskey-auth-')
                ? 'Prefix: ${apiKey.key}'
                : '${l10n.t('Clé', 'Key', '密钥')}: ...${apiKey.key.length > 6 ? apiKey.key.substring(apiKey.key.length - 6) : apiKey.key}',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500, fontFamily: 'monospace')),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
                '${l10n.t('Utilisateur', 'User', '用户')}: ${apiKey.user?.name ?? 'N/A'}',
                style: theme.textTheme.bodyMedium),
            Text(
                '${l10n.t('Expiration', 'Expiration', '有效期')}: ${apiKey.expiration?.toLocal() ?? (l10n.t('Jamais', 'Never', '从未'))}',
                style: theme.textTheme.bodyMedium),
            Row(
              children: [
                Text(
                    '${l10n.t('Réutilisable', 'Reusable', '可复用')}: ${apiKey.reusable ? (l10n.t('Oui', 'Yes', '是')) : (l10n.t('Non', 'No', '否'))}',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(width: 8),
                Text(
                    '${l10n.t('Éphémère', 'Ephemeral', '临时')}: ${apiKey.ephemeral ? (l10n.t('Oui', 'Yes', '是')) : (l10n.t('Non', 'No', '否'))}',
                    style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.timer_off, color: Colors.redAccent),
          tooltip: l10n.t('Expirer la clé', 'Expire key', '使密钥过期'),
          onPressed: () => _expireKey(context),
        ),
        onTap: () => _handleTap(context),
      ),
    );
  }

  Future<void> _expireKey(BuildContext context) async {
    final theme = Theme.of(context);
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.t('Expirer la clé ?', 'Expire key?', '使密钥过期？'),
                style: theme.textTheme.titleLarge),
            content: Text(
                l10n.t('Voulez-vous vraiment faire expirer cette clé ? L\'action est irréversible.', 'Do you really want to expire this key? The action is irreversible.', '确定要让此密钥过期吗？该操作不可撤销。'),
                style: theme.textTheme.bodyMedium),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.t('Annuler', 'Cancel', '取消'),
                      style: theme.textTheme.labelLarge)),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.t('Expirer', 'Expire', '设为过期'),
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm && context.mounted) {
      try {
        final provider = context.read<AppProvider>();
        await provider.apiService.expirePreAuthKey(apiKey.user!.id, apiKey.key,
            serverVersion: provider.serverVersion, keyId: apiKey.id);
        if (!context.mounted) return;
        showSafeSnackBar(context,
            l10n.t('Clé expirée avec succès.', 'Key expired successfully.', '密钥已成功过期。'));
        onAction(); // This will trigger the refresh
      } catch (e) {
        showSafeSnackBar(context,
            '${l10n.t('Erreur lors de l\'expiration de la clé', 'Error expiring key', '密钥过期时出错')}: $e');
      }
    }
  }

  void _handleTap(BuildContext context) async {
    final theme = Theme.of(context);
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);
    final appProvider = context.read<AppProvider>();
    final serverUrl = appProvider.activeServer?.url;
    final String loginServer = serverUrl?.endsWith('/') == true
        ? serverUrl!.substring(0, serverUrl.length - 1)
        : serverUrl ?? '';
    final fullCommand =
        'tailscale up --login-server=$loginServer --authkey=${apiKey.key}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            l10n.t('Commande d\'enregistrement', 'Registration Command', '注册命令'),
            style: theme.textTheme.titleLarge),
        content: SelectableText(fullCommand,
            style:
                theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
        actions: [
          ElevatedButton.icon(
            icon: Icon(Icons.qr_code, color: theme.colorScheme.onPrimary),
            label: Text(context.l10n.t('QR Code', 'QR code', '二维码'),
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onPrimary)),
            onPressed: () {
              Navigator.of(context).pop(); // Ferme le dialogue actuel
              onShowQrCode(context, fullCommand); // Utilise le callback
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.copy, color: theme.colorScheme.onPrimary),
            label: Text(l10n.t('Copier', 'Copy', '复制'),
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onPrimary)),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullCommand));
              if (!context.mounted) return;
              showSafeSnackBar(
                  context, l10n.t('Commande copiée !', 'Command copied!', '命令已复制！'));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.t('Fermer', 'Close', '关闭'),
                style: theme.textTheme.labelLarge),
          ),
        ],
      ),
    );
  }
}
