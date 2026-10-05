import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// DERP（中继）探测服务。
///
/// 背景（这也是 Headplane 的做法）：
///  * Headscale 的 REST API **不提供**任何 DERP 字段，也不提供节点的端点；
///    每个节点走哪个中继是由**客户端自己**测速后挑选的（pick a home relay），
///    服务端不参与、也不记录。
///  * 因此「某台机器当前用哪个中继」只能在该设备上查看
///    （`tailscale status` / `tailscale debug derp`）。
///  * 但「从中继服务器列表 + 从本机到每个中继的延迟」是**可以测**的：
///    Tailscale 的 netcheck（Headplane 把它编译成 WASM 跑在浏览器里）就是
///    对每个区域节点发 `HEAD https://<host>:<port>/derp/probe` 计时。
///    本服务用同样的手法在手机上做测量。
class DerpService {
  DerpService({required this.baseUrl, HttpClient? client})
      : _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 4);
    _client.userAgent = 'HeadscaleManager';
  }

  /// Headscale 服务器地址，例如 https://headscale.example.com
  final String baseUrl;
  final HttpClient _client;

  static const Duration _timeout = Duration(seconds: 5);
  static const int _rounds = 3;

  void close() => _client.close(force: true);

  /// 服务器自身的内嵌 DERP（Headscale 的 `/derp/latency-check`）。
  Uri get embeddedProbeUri => Uri.parse('$baseUrl/derp/latency-check');

  /// 服务器下发给客户端的 DERP map 中所有中继主机名。
  ///
  /// `GET /bootstrap-dns` 由 Headscale 用自身的 DERP map 生成，返回
  /// `{"<主机名>": ["<解析出的 IP>", ...]}`。该端点在鉴权中间件之外，
  /// 不需要 API 密钥；但**只有启用了内嵌 DERP（DERP.ServerEnabled）时才会注册**。
  Future<List<String>> fetchDerpHosts() async {
    final request = await _client
        .getUrl(Uri.parse('$baseUrl/bootstrap-dns'))
        .timeout(_timeout);
    final response = await request.close().timeout(_timeout);
    if (response.statusCode != 200) {
      throw DerpUnavailableException('bootstrap-dns HTTP ${response.statusCode}');
    }
    final body = await response.transform(utf8.decoder).join().timeout(_timeout);
    return parseBootstrapDns(body);
  }

  /// 解析 `/bootstrap-dns` 的响应；纯函数，便于测试。
  static List<String> parseBootstrapDns(String body) {
    Object? decoded;
    try {
      decoded = json.decode(body);
    } on FormatException {
      return const []; // 被劫持到门户页、空响应等情况
    }
    if (decoded is! Map) return const [];
    final hosts = <String>{};
    for (final entry in decoded.entries) {
      final host = entry.key.toString().trim();
      if (host.isEmpty) continue;
      // 只保留有解析结果的主机：解析失败的项在服务端会被跳过，
      // 这里再过滤一次空数组，避免探测注定失败的地址。
      final addresses = entry.value;
      if (addresses is List && addresses.isNotEmpty) hosts.add(host);
    }
    final list = hosts.toList()..sort();
    return list;
  }

  /// 逐个测量到中继的 HTTPS 往返时延。
  ///
  /// 每个中继先发一次"热身"请求建立连接（与 netcheck 一致），再取 [_rounds]
  /// 次测量中的最小值——最小值比平均值更能反映链路的最佳状态。
  Future<DerpProbe> probe(String host, {int? port}) async {
    final authority = port == null ? host : '$host:$port';
    final uri = Uri.parse('https://$authority/derp/probe');
    try {
      await _head(uri); // 热身：建立 TLS/HTTP 连接
      int? best;
      for (var i = 0; i < _rounds; i++) {
        final elapsed = await _head(uri);
        if (best == null || elapsed < best) best = elapsed;
      }
      return DerpProbe(host: authority, latencyMs: best);
    } catch (e) {
      return DerpProbe(host: authority, latencyMs: null, error: e.toString());
    }
  }

  Future<int> _head(Uri uri) async {
    final watch = Stopwatch()..start();
    final request = await _client.headUrl(uri).timeout(_timeout);
    final response = await request.close().timeout(_timeout);
    await response.drain<void>().timeout(_timeout);
    watch.stop();
    // 401/403 等也算连通（我们只关心往返时延），但要排除明显异常的状态码。
    if (response.statusCode >= 500) {
      throw DerpUnavailableException('HTTP ${response.statusCode}');
    }
    return watch.elapsedMilliseconds;
  }

  /// 完整探测：服务器内嵌 DERP + `bootstrap-dns` 列出的中继。
  ///
  /// 返回按延迟升序排列的结果（不可达的排在最后）。
  Future<List<DerpProbe>> probeAll() async {
    final results = <DerpProbe>[];

    // 1) 服务器自身的内嵌 DERP（用户已启用，最相关）
    results.add(await _probeUri(embeddedProbeUri, _serverHost));

    // 2) DERP map 中的其他中继
    List<String> hosts;
    try {
      hosts = await fetchDerpHosts();
    } on DerpUnavailableException {
      hosts = const [];
    }
    for (final host in hosts) {
      if (_isSameHost(host, _serverHost)) continue; // 上面已测过服务器自身
      results.add(await probe(host));
    }

    return sortByLatency(results);
  }

  Future<DerpProbe> _probeUri(Uri uri, String label) async {
    try {
      await _head(uri);
      int? best;
      for (var i = 0; i < _rounds; i++) {
        final elapsed = await _head(uri);
        if (best == null || elapsed < best) best = elapsed;
      }
      return DerpProbe(host: label, latencyMs: best, isServer: true);
    } catch (e) {
      return DerpProbe(
          host: label, latencyMs: null, isServer: true, error: e.toString());
    }
  }

  String get _serverHost => Uri.parse(baseUrl).host;

  bool _isSameHost(String a, String b) =>
      a.toLowerCase() == b.toLowerCase() ||
      a.toLowerCase().startsWith('${b.toLowerCase()}.');

  /// 延迟升序；不可达的排最后（同类按主机名）。纯函数，便于测试。
  static List<DerpProbe> sortByLatency(List<DerpProbe> probes) {
    final sorted = [...probes];
    sorted.sort((a, b) {
      final la = a.latencyMs, lb = b.latencyMs;
      if (la == null && lb == null) return a.host.compareTo(b.host);
      if (la == null) return 1;
      if (lb == null) return -1;
      final c = la.compareTo(lb);
      return c != 0 ? c : a.host.compareTo(b.host);
    });
    return sorted;
  }
}

class DerpProbe {
  const DerpProbe({
    required this.host,
    required this.latencyMs,
    this.isServer = false,
    this.error,
  });

  final String host;
  final int? latencyMs;

  /// 是否为服务器自身的内嵌 DERP。
  final bool isServer;
  final String? error;

  bool get reachable => latencyMs != null;
}

/// `/bootstrap-dns` 不可用（未启用内嵌 DERP、或反向代理未放行该路径）。
class DerpUnavailableException implements Exception {
  DerpUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}
