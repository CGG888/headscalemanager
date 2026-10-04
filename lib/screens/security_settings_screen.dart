import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/security_service.dart';
import 'package:headscalemanager/screens/setup_pin_screen.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _securityService = SecurityService();
  bool _isPinConfigured = false;
  bool _biometricsEnabled = false;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isPinConfigured = await _securityService.isPinConfigured();
    final biometricsEnabled = await _securityService.isBiometricsEnabled();
    final canCheckBiometrics = await _securityService.canCheckBiometrics();
    if (mounted) {
      setState(() {
        _isPinConfigured = isPinConfigured;
        _biometricsEnabled = biometricsEnabled;
        _canCheckBiometrics = canCheckBiometrics;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('Sécurité de l\'application', 'App Security', '应用安全')),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: Text(l10n.t('Gérer le code PIN', 'Manage PIN Code', '管理 PIN 码')),
            subtitle: Text(_isPinConfigured
                ? (l10n.t('Un code PIN est configuré.', 'A PIN code is configured.', '已配置 PIN 码。'))
                : (l10n.t('Aucun code PIN configuré.', 'No PIN code configured.', '未配置 PIN 码。'))),
            leading: const Icon(Icons.pin),
            onTap: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SetupPinScreen()),
              );
              if (result == true) {
                _loadSettings();
              }
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text(l10n.t('Activer l\'authentification biométrique', 'Enable Biometric Authentication', '启用生物识别认证')),
            subtitle: Text(_canCheckBiometrics
                ? (l10n.t('Utiliser l\'empreinte digitale ou la reconnaissance faciale.', 'Use fingerprint or face recognition.', '使用指纹或面部识别。'))
                : (l10n.t('Aucun capteur biométrique compatible trouvé.', 'No compatible biometric sensor found.', '未找到兼容的生物识别传感器。'))),
            value: _biometricsEnabled,
            secondary: const Icon(Icons.fingerprint),
            onChanged: (_isPinConfigured && _canCheckBiometrics)
                ? (bool value) async {
                    await _securityService.saveBiometricsEnabled(value);
                    if (!context.mounted) return;
                    setState(() {
                      _biometricsEnabled = value;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(l10n.t('Authentification biométrique ${value ? "activée" : "désactivée"}.', 'Biometric authentication ${value ? "enabled" : "disabled"}.', '生物识别认证${value ? "已启用" : "已禁用"}。'))),
                    );
                  }
                : null,
          ),
          if (!_isPinConfigured)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
              child: Text(
                l10n.t('Vous devez configurer un code PIN avant de pouvoir activer l\'authentification biométrique.', 'You must set up a PIN before you can enable biometric authentication.', '必须先设置 PIN 码才能启用生物识别认证。'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: theme.disabledColor),
              ),
            ),
        ],
      ),
    );
  }
}
