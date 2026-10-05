import 'package:shared_preferences/shared_preferences.dart';

/// 告警规则的可配置项。
///
/// 默认值刻意保守：长期离线按 30 天、密钥到期在 30 天内开始提醒。
/// 每台网络的运维节奏不同，所以这些不该写死在代码里。
class AlertSettings {
  const AlertSettings({
    this.notifyKeyExpiry = true,
    this.notifyStatusChange = true,
    this.notifyPendingRoutes = true,
    this.offlineDays = 30,
    this.keyExpiryWarnDays = 30,
  });

  /// 是否推送密钥到期提醒（分档）。
  final bool notifyKeyExpiry;

  /// 是否推送监护节点的上下线变化。
  final bool notifyStatusChange;

  /// 是否推送待批准路由的提醒。
  final bool notifyPendingRoutes;

  /// 长期末线多少天后视为"僵尸"节点。
  final int offlineDays;

  /// 密钥到期提前多少天开始提醒（档位不会超过这个值）。
  final int keyExpiryWarnDays;

  /// 允许范围（界面与读取都按此收敛，避免存进离谱的值）。
  static const int minOfflineDays = 3;
  static const int maxOfflineDays = 365;
  static const int minWarnDays = 1;
  static const int maxWarnDays = 90;

  /// 实际生效的提醒档位：不超过 [keyExpiryWarnDays]。
  List<int> get effectiveThresholds =>
      AlertSettings.allThresholds.where((t) => t <= keyExpiryWarnDays).toList();

  static const List<int> allThresholds = [30, 7, 3, 1];

  AlertSettings copyWith({
    bool? notifyKeyExpiry,
    bool? notifyStatusChange,
    bool? notifyPendingRoutes,
    int? offlineDays,
    int? keyExpiryWarnDays,
  }) =>
      AlertSettings(
        notifyKeyExpiry: notifyKeyExpiry ?? this.notifyKeyExpiry,
        notifyStatusChange: notifyStatusChange ?? this.notifyStatusChange,
        notifyPendingRoutes: notifyPendingRoutes ?? this.notifyPendingRoutes,
        offlineDays: offlineDays ?? this.offlineDays,
        keyExpiryWarnDays: keyExpiryWarnDays ?? this.keyExpiryWarnDays,
      );

  /// 收敛到合法范围（纯函数，便于测试）。
  static int clampOfflineDays(int value) =>
      value.clamp(minOfflineDays, maxOfflineDays);
  static int clampWarnDays(int value) =>
      value.clamp(minWarnDays, maxWarnDays);
}

class AlertSettingsService {
  const AlertSettingsService._();

  static const String _keyExpiry = 'alert.notifyKeyExpiry';
  static const String _status = 'alert.notifyStatusChange';
  static const String _routes = 'alert.notifyPendingRoutes';
  static const String _offlineDays = 'alert.offlineDays';
  static const String _warnDays = 'alert.keyExpiryWarnDays';

  static Future<AlertSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AlertSettings(
        notifyKeyExpiry: prefs.getBool(_keyExpiry) ?? true,
        notifyStatusChange: prefs.getBool(_status) ?? true,
        notifyPendingRoutes: prefs.getBool(_routes) ?? true,
        offlineDays: AlertSettings.clampOfflineDays(
            prefs.getInt(_offlineDays) ?? 30),
        keyExpiryWarnDays:
            AlertSettings.clampWarnDays(prefs.getInt(_warnDays) ?? 30),
      );
    } catch (_) {
      return const AlertSettings(); // 读不到就用默认值，不影响功能
    }
  }

  static Future<void> save(AlertSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyExpiry, settings.notifyKeyExpiry);
    await prefs.setBool(_status, settings.notifyStatusChange);
    await prefs.setBool(_routes, settings.notifyPendingRoutes);
    await prefs.setInt(_offlineDays, settings.offlineDays);
    await prefs.setInt(_warnDays, settings.keyExpiryWarnDays);
  }
}
