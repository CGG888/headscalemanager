import 'dart:convert';

import 'package:http/http.dart' as http;

/// 服务端能力探测。
///
/// 为什么需要它：Headscale 对**路由不存在**和**对象不存在**返回的都是
/// `{"code":5,"message":"Not Found"}`，仅凭 404 无法区分"服务端太旧没有这个接口"
/// 与"接口在、但查不到这个设备"。而 `GET /swagger/v1/openapiv2.json` 是服务端
/// 按自身 proto 生成的，**路由存在与否一目了然**。
///
/// 因此这里用它来判断 device API 是否可用，结果按服务器地址缓存
/// （同一台服务器一次进程内只探一次）。
class ApiCapabilityService {
  ApiCapabilityService._();

  static const String deviceRoute = '/api/v1/device/';

  static final Map<String, bool> _deviceApiCache = {};

  /// 已知结果时直接返回；未知返回 null（例如 swagger 也取不到）。
  static bool? cachedDeviceApi(String baseUrl) => _deviceApiCache[baseUrl];

  static void remember(String baseUrl, bool supported) =>
      _deviceApiCache[baseUrl] = supported;

  /// 探测服务端是否提供 device API。
  ///
  /// 返回 null 表示无法判断（swagger 取不到），调用方应"试一次再说"。
  static Future<bool?> supportsDeviceApi(String baseUrl, String apiKey) async {
    final cached = _deviceApiCache[baseUrl];
    if (cached != null) return cached;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/swagger/v1/openapiv2.json'),
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final spec = response.body.contains(deviceRoute)
          ? response.body
          : utf8.decode(response.bodyBytes, allowMalformed: true);
      final supported = spec.contains(deviceRoute);
      _deviceApiCache[baseUrl] = supported;
      return supported;
    } catch (_) {
      return null; // 网络失败等原因：不缓存、不阻断
    }
  }
}
