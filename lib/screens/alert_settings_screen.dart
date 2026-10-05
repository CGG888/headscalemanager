import 'package:flutter/material.dart';
import 'package:headscalemanager/l10n/l10n.dart';
import 'package:headscalemanager/services/alert_settings_service.dart';

/// 告警设置：把离线阈值、密钥到期提前量与各类通知开关交给用户。
///
/// 每台网络的运维节奏不同——家庭网络"离线 30 天"算异常，实验室可能 3 天就算；
/// 因此这些不该写死。
class AlertSettingsScreen extends StatefulWidget {
  const AlertSettingsScreen({super.key});

  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends State<AlertSettingsScreen> {
  bool _isLoading = true;
  AlertSettings _settings = const AlertSettings();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final settings = await AlertSettingsService.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _update(AlertSettings next) async {
    setState(() => _settings = next);
    await AlertSettingsService.save(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
          title: Text(l10n.t('Alertes', 'Alerts', '告警设置'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                SwitchListTile(
                  value: _settings.notifyKeyExpiry,
                  onChanged: (v) =>
                      _update(_settings.copyWith(notifyKeyExpiry: v)),
                  title: Text(l10n.t('Expiration des clés',
                      'Key expiry', '密钥到期提醒')),
                  subtitle: Text(l10n.t(
                    'Prévenir par paliers avant l\'expiration d\'une clé.',
                    'Warn in steps before a key expires.',
                    '密钥到期前分档提醒。',
                  )),
                ),
                if (_settings.notifyKeyExpiry)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t(
                          'Commencer à prévenir ${_settings.keyExpiryWarnDays} jours avant (paliers : ${_settings.effectiveThresholds.join(', ')})',
                          'Start warning ${_settings.keyExpiryWarnDays} days before (steps: ${_settings.effectiveThresholds.join(', ')})',
                          '提前 ${_settings.keyExpiryWarnDays} 天开始提醒（档位：${_settings.effectiveThresholds.join('、')}）',
                        )),
                        Slider(
                          value: _settings.keyExpiryWarnDays.toDouble(),
                          min: AlertSettings.minWarnDays.toDouble(),
                          max: AlertSettings.maxWarnDays.toDouble(),
                          divisions: AlertSettings.maxWarnDays -
                              AlertSettings.minWarnDays,
                          label: '${_settings.keyExpiryWarnDays}',
                          onChanged: (v) => _update(_settings.copyWith(
                              keyExpiryWarnDays:
                                  AlertSettings.clampWarnDays(v.round()))),
                        ),
                      ],
                    ),
                  ),
                SwitchListTile(
                  value: _settings.notifyStatusChange,
                  onChanged: (v) =>
                      _update(_settings.copyWith(notifyStatusChange: v)),
                  title: Text(l10n.t('Changement d\'état d\'un nœud',
                      'Node status change', '节点上下线变化')),
                  subtitle: Text(l10n.t(
                    'Pour les nœuds que vous suivez.',
                    'For the nodes you monitor.',
                    '针对你监护的节点。',
                  )),
                ),
                SwitchListTile(
                  value: _settings.notifyPendingRoutes,
                  onChanged: (v) =>
                      _update(_settings.copyWith(notifyPendingRoutes: v)),
                  title: Text(l10n.t('Routes en attente',
                      'Pending routes', '待批准路由')),
                  subtitle: Text(l10n.t(
                    'Lorsqu\'un nœud demande de nouvelles routes.',
                    'When a node requests new routes.',
                    '当节点申请新路由时。',
                  )),
                ),
                const Divider(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t(
                          'Nœud considéré comme abandonné après ${_settings.offlineDays} jours hors ligne',
                          'Node treated as abandoned after ${_settings.offlineDays} days offline',
                          '离线超过 ${_settings.offlineDays} 天视为可清理节点',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Slider(
                        value: _settings.offlineDays.toDouble(),
                        min: AlertSettings.minOfflineDays.toDouble(),
                        max: AlertSettings.maxOfflineDays.toDouble(),
                        divisions: (AlertSettings.maxOfflineDays -
                                AlertSettings.minOfflineDays) ~/
                            7,
                        label: '${_settings.offlineDays}',
                        onChanged: (v) => _update(_settings.copyWith(
                            offlineDays:
                                AlertSettings.clampOfflineDays(v.round()))),
                      ),
                      Text(
                        l10n.t(
                          'Utilisé par le bilan réseau pour le nettoyage groupé.',
                          'Used by the network health page for grouped cleanup.',
                          '网络体检页据此聚合"长期离线"并可一键清理。',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
