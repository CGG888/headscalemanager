import 'dart:convert';
import 'dart:ui' show Locale;
import 'package:headscalemanager/l10n/l10n.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:http/http.dart' as http;
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/models/api_key.dart';
import '../models/version_info.dart';

/// 与界面语言无关的 API 操作标识。
///
/// 逻辑只依赖枚举本身，展示文案由 [label] 交给 L10n —— 这样"把报错翻成中文"
/// 不会影响任何判断，也不会再像以前那样把法语动词短语硬编码进异常。
enum ApiOperation {
  loadNodes,
  loadNodeDetails,
  registerMachine,
  loadUsers,
  createUser,
  createPreAuthKey,
  loadAclPolicy,
  saveAclPolicy,
  deleteUser,
  deleteNode,
  setNodeRoutes,
  renameNode,
  moveNode,
  renameUser,
  loadKeys,
  expireKey,
  expirePreAuthKey,
  listApiKeys,
  createApiKey,
  expireApiKey,
  deleteApiKey,
  setTags,
  fetchVersion,
  serviceUnavailable;

  /// 操作名（动宾短语），用于拼「XX 失败」。
  String label(L10n l) => switch (this) {
        ApiOperation.loadNodes => l.t('charger les nœuds', 'load nodes', '加载节点'),
        ApiOperation.loadNodeDetails =>
          l.t('charger les détails du nœud', 'load node details', '加载节点详情'),
        ApiOperation.registerMachine =>
          l.t('enregistrer la machine', 'register the machine', '注册设备'),
        ApiOperation.loadUsers =>
          l.t('charger les utilisateurs', 'load users', '加载用户'),
        ApiOperation.createUser =>
          l.t('créer un utilisateur', 'create a user', '创建用户'),
        ApiOperation.createPreAuthKey => l.t('créer une clé de pré-authentification',
            'create a pre-auth key', '创建预认证密钥'),
        ApiOperation.loadAclPolicy =>
          l.t('charger la politique ACL', 'load the ACL policy', '加载 ACL 策略'),
        ApiOperation.saveAclPolicy =>
          l.t('sauvegarder la politique ACL', 'save the ACL policy', '保存 ACL 策略'),
        ApiOperation.deleteUser =>
          l.t('supprimer l\'utilisateur', 'delete the user', '删除用户'),
        ApiOperation.deleteNode =>
          l.t('supprimer le nœud', 'delete the node', '删除节点'),
        ApiOperation.setNodeRoutes =>
          l.t('définir les routes du nœud', 'set the node routes', '设置节点路由'),
        ApiOperation.renameNode =>
          l.t('renommer le nœud', 'rename the node', '重命名节点'),
        ApiOperation.moveNode => l.t('déplacer le nœud', 'move the node', '移动节点'),
        ApiOperation.renameUser =>
          l.t('renommer l\'utilisateur', 'rename the user', '重命名用户'),
        ApiOperation.loadKeys => l.t(
            'charger les clés (v0.28+)', 'load keys (v0.28+)', '加载密钥（v0.28+）'),
        ApiOperation.expireKey =>
          l.t('expirer la clé', 'expire the key', '使密钥过期'),
        ApiOperation.expirePreAuthKey => l.t('expirer la clé de pré-authentification',
            'expire the pre-auth key', '使预认证密钥过期'),
        ApiOperation.listApiKeys =>
          l.t('lister les clés API', 'list API keys', '列出 API 密钥'),
        ApiOperation.createApiKey =>
          l.t('créer la clé API', 'create the API key', '创建 API 密钥'),
        ApiOperation.expireApiKey =>
          l.t('expirer la clé API', 'expire the API key', '使 API 密钥过期'),
        ApiOperation.deleteApiKey =>
          l.t('supprimer la clé API', 'delete the API key', '删除 API 密钥'),
        ApiOperation.setTags => l.t('définir les tags', 'set the tags', '设置标签'),
        ApiOperation.fetchVersion => l.t('récupérer la version du serveur',
            'fetch the server version', '获取服务器版本'),
        ApiOperation.serviceUnavailable => l.t(
            'initialiser le client API', 'initialise the API client', '初始化 API 客户端'),
      };
}

/// API 调用失败时抛出的异常。
///
/// [rawBody] 是服务端原始响应体，**仅供逻辑判断**（例如判定某个 tag 尚未出现在
/// ACL 的 tagOwners 中），因此禁止本地化或改写；面向用户的文字由 [message] 依据
/// 传入的 [L10n] 现算，因此语言切换后新抛出的异常自然跟随界面语言。
class HeadscaleApiException implements Exception {
  final ApiOperation operation;

  /// 抛出时的界面语言，供 [toString] 使用。
  final L10n l10n;

  /// 语言无关的补充信息（如密钥 ID），会附在操作名后。
  final String? detail;

  final int statusCode;
  final String rawBody;

  const HeadscaleApiException({
    required this.operation,
    required this.l10n,
    this.detail,
    this.statusCode = 0,
    this.rawBody = '',
  });

  /// 按指定语言生成给用户看的消息。
  String message(L10n l) {
    final op = operation.label(l);
    final label = detail == null ? op : '$op（$detail）';
    if (statusCode == 0 && rawBody.isEmpty) {
      return l.t('Échec : $label', 'Failed: $label', '$label失败');
    }
    return l.t(
      'Échec : $label. Statut : $statusCode, Corps : $rawBody',
      'Failed: $label. Status: $statusCode, Body: $rawBody',
      '$label失败。状态码：$statusCode，响应：$rawBody',
    );
  }

  @override
  String toString() => message(l10n);
}

class HeadscaleApiService {
  final String _apiKey;
  final String _baseUrl;

  /// 生成错误消息所用的界面语言；由 AppProvider 在切换语言时更新。
  L10n _l10n;

  HeadscaleApiService(
      {required String apiKey, required String baseUrl, Locale? locale})
      : _apiKey = apiKey,
        _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _l10n = L10n(locale ?? const Locale('fr'));

  set locale(Locale value) => _l10n = L10n(value);

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };
  }

  HeadscaleApiException _handleError(ApiOperation operation,
      http.Response response, {String? detail}) {
    return HeadscaleApiException(
      operation: operation,
      l10n: _l10n,
      detail: detail,
      rawBody: response.body,
      statusCode: response.statusCode,
    );
  }

  Future<List<Node>> getNodes() async {
    final String baseDomain = _baseUrl.extractBaseDomain() ?? 'headscale.local';

    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/node'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> nodesJson = data['nodes'];
      return nodesJson
          .map((nodeJson) =>
              Node.fromJson(nodeJson as Map<String, dynamic>, baseDomain))
          .toList();
    } else {
      throw _handleError(ApiOperation.loadNodes, response);
    }
  }

  Future<Node> getNodeDetails(String nodeId) async {
    final String baseDomain = _baseUrl.extractBaseDomain() ?? 'headscale.local';

    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/node/$nodeId'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return Node.fromJson(json.decode(response.body)['node'], baseDomain);
    } else {
      throw _handleError(ApiOperation.loadNodeDetails, response);
    }
  }

  Future<Node> registerMachine(String machineKey, String userName) async {
    final String baseDomain = _baseUrl.extractBaseDomain() ?? 'headscale.local';

    final response = await http.post(
      Uri.parse(
          '$_baseUrl/api/v1/node/register?user=$userName&key=$machineKey'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Node.fromJson(data['node'], baseDomain);
    } else {
      throw _handleError(ApiOperation.registerMachine, response);
    }
  }

  Future<List<User>> getUsers() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/user'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> usersJson = data['users'];
      return usersJson.map((json) => User.fromJson(json)).toList();
    } else {
      throw _handleError(ApiOperation.loadUsers, response);
    }
  }

  Future<User> createUser(String name) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/user'),
      headers: _getHeaders(),
      body: jsonEncode(<String, String>{'name': name}),
    );

    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      throw _handleError(ApiOperation.createUser, response);
    }
  }

  Future<PreAuthKey> createPreAuthKey(
      String userId, bool reusable, bool ephemeral,
      {DateTime? expiration, List<String>? aclTags}) async {
    final body = {
      'user': userId,
      'reusable': reusable,
      'ephemeral': ephemeral,
    };

    if (expiration != null) {
      body['expiration'] = expiration.toUtc().toIso8601String();
    }

    if (aclTags != null && aclTags.isNotEmpty) {
      body['aclTags'] = aclTags;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/preauthkey'),
      headers: _getHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final preAuthKeyJson = data['preAuthKey'];
      return PreAuthKey.fromJson(preAuthKeyJson);
    } else {
      throw _handleError(ApiOperation.createPreAuthKey, response);
    }
  }

  Future<String> getAclPolicy() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/policy'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['policy'] != null) {
        return data['policy'];
      } else {
        return '';
      }
    } else {
      throw _handleError(ApiOperation.loadAclPolicy, response);
    }
  }

  Future<void> setAclPolicy(String aclPolicy) async {
    final body = jsonEncode({'policy': aclPolicy});

    final response = await http.put(
      Uri.parse('$_baseUrl/api/v1/policy'),
      headers: _getHeaders(),
      body: body,
    );

    if (response.statusCode != 200) {
      throw _handleError(ApiOperation.saveAclPolicy, response);
    }
  }

  Future<void> deleteUser(String userId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/v1/user/$userId'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw _handleError(ApiOperation.deleteUser, response);
    }
  }

  Future<void> deleteNode(String nodeId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/v1/node/$nodeId'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw _handleError(ApiOperation.deleteNode, response);
    }
  }

  Future<void> setNodeRoutes(String nodeId, List<String> routes) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/node/$nodeId/approve_routes'),
      headers: _getHeaders(),
      body: jsonEncode(<String, dynamic>{'routes': routes}),
    );

    if (response.statusCode != 200) {
      throw _handleError(ApiOperation.setNodeRoutes, response);
    }
  }

  Future<void> renameNode(String nodeId, String newName) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/node/$nodeId/rename/$newName'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw _handleError(ApiOperation.renameNode, response);
    }
  }

  Future<void> moveNode(String nodeId, User newUser) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/node/$nodeId/user'),
      headers: _getHeaders(),
      body: jsonEncode(<String, String>{'user': newUser.id}),
    );

    if (response.statusCode != 200) {
      throw _handleError(ApiOperation.moveNode, response);
    }
  }

  Future<void> renameUser(String oldId, String newName) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/user/$oldId/rename/$newName'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw _handleError(ApiOperation.renameUser, response);
    }
  }

  Future<List<PreAuthKey>> getPreAuthKeys({String? serverVersion}) async {
    final List<PreAuthKey> allPreAuthKeys = [];

    // HEADSCALE v0.28+ : Endpoint global /api/v1/preauthkey
    if (serverVersion != null &&
        VersionInfo.checkVersionAtLeast(serverVersion, '0.28.0')) {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/preauthkey'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> keysJson = data['preAuthKeys'] ?? [];
        allPreAuthKeys
            .addAll(keysJson.map((json) => PreAuthKey.fromJson(json)).toList());
      } else {
        throw _handleError(ApiOperation.loadKeys, response);
      }
      return allPreAuthKeys;
    }

    // HEADSCALE < v0.28 : Boucle sur chaque utilisateur
    final users = await getUsers();

    for (final user in users) {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/preauthkey?user=${user.id}'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> keysJson = data['preAuthKeys'] ?? [];
        allPreAuthKeys
            .addAll(keysJson.map((json) => PreAuthKey.fromJson(json)).toList());
      } else {
        // Log error but continue with other users
      }
    }

    return allPreAuthKeys;
  }

  Future<void> expirePreAuthKey(String userId, String key,
      {String? serverVersion, String? keyId}) async {
    // HEADSCALE v0.28+ : Expiration par ID
    if (serverVersion != null &&
        VersionInfo.checkVersionAtLeast(serverVersion, '0.28.0') &&
        keyId != null) {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/preauthkey/expire'),
        headers: _getHeaders(),
        body: jsonEncode(<String, dynamic>{
          'id': keyId, // Nouveau paramètre v0.28
        }),
      );
      if (response.statusCode != 200) {
        throw _handleError(ApiOperation.expireKey, response, detail: keyId);
      }
      return;
    }

    // LEGACY / v0.27 : Expiration par User + Key
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/preauthkey/expire'),
      headers: _getHeaders(),
      body: jsonEncode(<String, String>{
        'user': userId,
        'key': key,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(ApiOperation.expirePreAuthKey, response);
    }
  }

  Future<List<ApiKey>> listApiKeys() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/apikey'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> apiKeysJson = data['apiKeys'];
      return apiKeysJson.map((json) => ApiKey.fromJson(json)).toList();
    } else {
      throw _handleError(ApiOperation.listApiKeys, response);
    }
  }

  Future<String> createApiKey({DateTime? expiration}) async {
    final body = <String, dynamic>{};
    if (expiration != null) {
      body['expiration'] = expiration.toUtc().toIso8601String();
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/apikey'),
      headers: _getHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['apiKey'];
    } else {
      throw _handleError(ApiOperation.createApiKey, response);
    }
  }

  Future<void> expireApiKey(String prefix) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/apikey/expire'),
      headers: _getHeaders(),
      body: jsonEncode(<String, String>{'prefix': prefix}),
    );

    if (response.statusCode != 200) {
      throw _handleError(ApiOperation.expireApiKey, response);
    }
  }

  Future<void> deleteApiKey(String prefix) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/v1/apikey/$prefix'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw _handleError(ApiOperation.deleteApiKey, response);
    }
  }

  Future<Node> setTags(String nodeId, List<String> tags) async {
    final String baseDomain = _baseUrl.extractBaseDomain() ?? 'headscale.local';

    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/node/$nodeId/tags'),
      headers: _getHeaders(),
      body: jsonEncode(<String, dynamic>{'tags': tags}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Node.fromJson(data['node'], baseDomain);
    } else {
      throw _handleError(ApiOperation.setTags, response);
    }
  }

  Future<VersionInfo> getVersion() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/version'),
      headers: {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return VersionInfo.fromJson(json.decode(response.body));
    } else {
      throw HeadscaleApiException(
        operation: ApiOperation.fetchVersion,
        l10n: _l10n,
      );
    }
  }
}
