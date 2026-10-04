import 'dart:ui' show Locale;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:headscalemanager/api/headscale_api_service.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const String backgroundTaskName = "headscaleManager.checkNodeStatus";
const String taskUniqueName = "checkNodeStatusTask";

const String languageKey = 'APP_LANGUAGE';

// Helper function to get translations
Map<String, String> _getTranslations(String lang, String nodeName,
    {bool? isOnline}) {
  final onlineStatus = isOnline ?? false;
  switch (lang) {
    case 'en':
      return {
        'approval_title': 'Approval Required',
        'approval_body': 'Node "$nodeName" is requesting new permissions.',
        'cleanup_title': 'Route Deletion Warning',
        'cleanup_body':
            'Node "$nodeName" has orphaned routes that need to be deleted.',
        'status_title': 'Status Change',
        'status_body':
            'Node "$nodeName" is now ${onlineStatus ? 'online' : 'offline'}.',
      };
    case 'zh':
      return {
        'approval_title': '需要审批',
        'approval_body': '节点 "$nodeName" 正在申请新的权限。',
        'cleanup_title': '路由删除提醒',
        'cleanup_body': '节点 "$nodeName" 存在需要删除的孤立路由。',
        'status_title': '状态变化',
        'status_body': '节点 "$nodeName" 现在${onlineStatus ? '在线' : '离线'}。',
      };
    default:
      // Default to French
      return {
        'approval_title': 'Approbation Requise',
        'approval_body':
            'Le nœud "$nodeName" demande de nouvelles permissions.',
        'cleanup_title': 'Avertissement de Suppression',
        'cleanup_body':
            'Le nœud "$nodeName" a des routes orphelines à supprimer.',
        'status_title': 'Changement de Statut',
        'status_body':
            'Le nœud "$nodeName" est maintenant ${onlineStatus ? 'en ligne' : 'hors ligne'}.',
      };
  }
}

/// 通知渠道名与后台任务文案。
///
/// 通知运行在 Flutter 的 Localizations 体系之外（后台 isolate 里没有 context），
/// 因此这里单独维护一份三语文案。渠道 ID 必须保持 ASCII 常量不变，否则老用户
/// 会出现重复渠道、丢失已有的通知设置。
class _NotifText {
  final String foregroundChannel;
  final String foregroundChannelDesc;
  final String updateChannel;
  final String updateChannelDesc;
  final String persistentDesc;
  final String checking;
  final String analysing;

  const _NotifText({
    required this.foregroundChannel,
    required this.foregroundChannelDesc,
    required this.updateChannel,
    required this.updateChannelDesc,
    required this.persistentDesc,
    required this.checking,
    required this.analysing,
  });

  static _NotifText of(String lang) {
    switch (lang) {
      case 'en':
        return const _NotifText(
          foregroundChannel: 'Background tasks',
          foregroundChannelDesc: 'Notifications for active background tasks.',
          updateChannel: 'Headscale updates',
          updateChannelDesc: 'Notifications about Headscale network state.',
          persistentDesc: 'Persistent notification for background tasks.',
          checking: 'Checking in progress',
          analysing: 'Analysing network changes...',
        );
      case 'zh':
        return const _NotifText(
          foregroundChannel: '后台任务',
          foregroundChannelDesc: '正在运行的后台任务通知。',
          updateChannel: 'Headscale 更新',
          updateChannelDesc: 'Headscale 网络状态通知。',
          persistentDesc: '后台任务的常驻通知。',
          checking: '正在检查',
          analysing: '正在分析网络变化…',
        );
      default:
        return const _NotifText(
          foregroundChannel: 'Tâches de fond',
          foregroundChannelDesc:
              'Notifications pour les tâches de fond actives.',
          updateChannel: 'Mises à jour Headscale',
          updateChannelDesc:
              'Notifications sur l\'état du réseau Headscale.',
          persistentDesc:
              'Notification persistante pour les tâches de fond.',
          checking: 'Vérification en cours',
          analysing: 'Analyse des changements réseau...',
        );
    }
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == backgroundTaskName) {
      // 后台 isolate 拿不到 UI 的 AppProvider.locale，只能读持久化的语言码。
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString(languageKey) ?? 'fr';
      final notifText = _NotifText.of(lang);

      // print("Background task started: Checking node statuses...");
      await NotificationService.showPersistentNotification(
        notifText.checking,
        notifText.analysing,
        lang: lang,
      );
      try {
        final storageService = StorageService();
        await storageService.init(); // Important for migration

        final servers = await storageService.getServers();
        final activeServerId = await storageService.getActiveServerId();

        if (servers.isEmpty || activeServerId == null) {
          // print("No active server configured. Exiting background task.");
          // 直接 return true：外层是 async 回调，无需再包一层 Future（同时消除
          // unawaited_return_in_try_block 警告，让 CI 的 flutter analyze 保持 0 问题）。
          return true;
        }

        final activeServer = servers.firstWhere((s) => s.id == activeServerId);

        final apiService = HeadscaleApiService(
          apiKey: activeServer.apiKey,
          baseUrl: activeServer.url,
          locale: Locale(lang),
        );
        final List<Node> nodes = await apiService.getNodes();

        // --- Logic for Approval/Cleanup notifications ---
        final approvalNotifiedIds =
            prefs.getStringList('approvalNotifiedIds') ?? [];
        final cleanupNotifiedIds =
            prefs.getStringList('cleanupNotifiedIds') ?? [];
        List<String> newApprovalIds = [];
        List<String> newCleanupIds = [];

        // --- Logic for Status Monitoring notifications ---
        final monitoredNodeIds = prefs.getStringList('monitoredNodeIds') ?? [];

        for (final node in nodes) {
          final translations =
              _getTranslations(lang, node.name, isOnline: node.online);

          // 1. Check for pending approvals
          final hasPendingApproval =
              node.availableRoutes.any((r) => !node.sharedRoutes.contains(r));
          if (hasPendingApproval) {
            newApprovalIds.add(node.id);
            if (!approvalNotifiedIds.contains(node.id)) {
              // print("Found new pending node: ${node.name}");
              await NotificationService.showNotification(
                translations['approval_title']!,
                translations['approval_body']!,
              );
            }
          }

          // 2. Check for desynchronization (cleanup needed)
          final hasDesync =
              node.sharedRoutes.any((r) => !node.availableRoutes.contains(r));
          if (hasDesync) {
            newCleanupIds.add(node.id);
            if (!cleanupNotifiedIds.contains(node.id)) {
              // print("Found desynchronized node: ${node.name}");
              await NotificationService.showNotification(
                translations['cleanup_title']!,
                translations['cleanup_body']!,
              );
            }
          }

          // 3. Check for status change on monitored nodes
          if (monitoredNodeIds.contains(node.id)) {
            final lastKnownStatusKey = 'monitoredNode_${node.id}_status';
            final lastKnownStatus = prefs.getBool(lastKnownStatusKey);

            if (lastKnownStatus != null && node.online != lastKnownStatus) {
              // print("Status change for ${node.name}: now ${node.online ? 'online' : 'offline'}");
              await NotificationService.showNotification(
                translations['status_title']!,
                translations['status_body']!,
              );
              // Update the status to prevent re-notifying
              await prefs.setBool(lastKnownStatusKey, node.online);
            }
          }
        }

        // Save the new state lists back to storage
        await prefs.setStringList('approvalNotifiedIds', newApprovalIds);
        await prefs.setStringList('cleanupNotifiedIds', newCleanupIds);
        // print("Background task finished.");
      } catch (e) {
        // print("Error in background task: $e");
        return Future.value(false);
      } finally {
        await NotificationService.hidePersistentNotification();
      }
    }
    return Future.value(true);
  });
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int _persistentNotificationId = 0;
  static const String _foregroundChannelId = 'headscale_foreground_channel';
  // 渠道 ID 保持不变（ASCII），只本地化可见的名称与描述。
  static const String _updateChannelId = 'headscale_manager_channel';

  /// 当前语言下的通知文案（后台 isolate 没有 context，只能读持久化语言码）。
  static Future<_NotifText> _currentText() async {
    final prefs = await SharedPreferences.getInstance();
    return _NotifText.of(prefs.getString(languageKey) ?? 'fr');
  }

  static Future<void> initialize() async {
    // Create a separate channel for the foreground service
    final notifText = await _currentText();
    final AndroidNotificationChannel foregroundChannel =
        AndroidNotificationChannel(
      _foregroundChannelId,
      notifText.foregroundChannel, // title
      description: notifText.foregroundChannelDesc, // description
      importance: Importance.low, // Use low importance to be less intrusive
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(foregroundChannel);
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings);

    // Request notification permissions on Android
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    await Workmanager().initialize(
      callbackDispatcher,
      // isInDebugMode: true, // Removed deprecated parameter
    );
  }

  static Future<void> enableBackgroundTask(bool enabled) async {
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        taskUniqueName,
        backgroundTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
      // print("Background task enabled and registered.");
    } else {
      await Workmanager().cancelByUniqueName(taskUniqueName);
      // print("Background task cancelled.");
    }
  }

  static Future<void> showNotification(String title, String body) async {
    final int id = title.hashCode + body.hashCode;
    final notifText = await _currentText();
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _updateChannelId,
      notifText.updateChannel,
      channelDescription: notifText.updateChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
    );
    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }

  static Future<void> showPersistentNotification(
      String title, String body, {String? lang}) async {
    final notifText = lang == null ? await _currentText() : _NotifText.of(lang);
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _foregroundChannelId,
      notifText.foregroundChannel,
      channelDescription: notifText.persistentDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
    );
    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      _persistentNotificationId,
      title,
      body,
      notificationDetails,
    );
  }

  static Future<void> hidePersistentNotification() async {
    await _notificationsPlugin.cancel(_persistentNotificationId);
  }
}
