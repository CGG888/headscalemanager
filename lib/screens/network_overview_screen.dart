import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:dart_ping/dart_ping.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:headscalemanager/l10n/l10n.dart';
import 'package:headscalemanager/services/derp_service.dart';

class NetworkOverviewScreen extends StatefulWidget {
  const NetworkOverviewScreen({super.key});

  @override
  State<NetworkOverviewScreen> createState() => _NetworkOverviewScreenState();
}

class PingResult {
  final bool isOnline;
  final double? averageLatency;

  PingResult({required this.isOnline, this.averageLatency});
}

class _NetworkOverviewScreenState extends State<NetworkOverviewScreen> {
  List<Node> _nodes = [];
  bool _isLoading = true;
  Node? _selectedNode;
  final Map<String, PingResult> _pingResults = {};
  final Map<String, StreamSubscription<PingData>> _pingSubscriptions = {};
  String? _publicIp;
  /// 公网 IP 取不到时用于把标签显示成 "—"，而不是一直显示 "..."（加载中）。
  bool _publicIpUnavailable = false;

  /// DERP 中继探测结果（延迟升序）与状态。
  ///
  /// Headscale 的 API 不提供 DERP 信息，节点走哪个中继只有该设备自己知道；
  /// 但"中继列表 + 从本机到各中继的延迟"可以像 Tailscale 的 netcheck 那样探测
  /// （Headplane 就是把 netcheck 编译成 WASM 在浏览器里做同样的事）。
  List<DerpProbe> _derpProbes = const [];
  bool _isProbingDerp = false;
  String? _derpError;

  /// 是否尝试直接探测节点的**内网地址**。
  ///
  /// 默认关闭：那些地址（100.64.0.0/10）只有当**手机自己也在同一 tailnet 内**时才
  /// 可达。此前无条件探测，结果必然是全部失败并被显示成"离线"——既误导又无用。
  /// 节点状态一律以服务端上报的 `online` 为准。
  bool _pingNodes = false;

  /// 本机到 Headscale 的往返延迟（公开的 `GET /version`）——这是本机真能测的东西。
  int? _serverLatencyMs;
  bool _isMeasuringServer = false;
  List<String> _traceRouteHops = [];
  bool _isTracingRoute = false;
  Node? _exitNodeInUse;
  int _traceRouteGeneration = 0;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);
    // Incrémente la génération pour invalider les traceroutes précédents.
    _traceRouteGeneration++;
    final currentGeneration = _traceRouteGeneration;

    setState(() {
      _isLoading = true;
      _exitNodeInUse = null;
      _traceRouteHops.clear();
    });

    try {
      // Étape 1: Toujours récupérer les nœuds en premier.
      await _fetchNodes();

      // Si l'écran est toujours monté et que la génération est actuelle.
      if (mounted && _traceRouteGeneration == currentGeneration) {
        // Étape 2: lancer le traceroute et, en parallèle, compléter l'IP publique
        // (cette dernière est optionnelle et ne doit rien bloquer).
        _fetchPublicIpAndTrace(currentGeneration);
        // Le sondage DERP est indépendant lui aussi : il ne bloque rien.
        unawaited(_probeDerp());
        // La latence mesurée vers le serveur est, elle, toujours joignable.
        unawaited(_measureServerLatency());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${l10n.t('Erreur lors du rafraîchissement', 'Refresh error', '刷新出错')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 延迟卡片：本机到服务器的往返延迟（本机真能测的）+ 节点直连探测开关。
  ///
  /// 之所以分两层：节点的内网地址（100.64.0.0/10）只有手机自己接入同一 tailnet
  /// 时才可达，此前无条件 ping 会**把所有节点显示成离线**。默认显示服务端上报的
  /// 状态，直连探测改为显式开启。
  Widget _buildLatencyCard() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.speed, size: 20),
            title: Text(l10n.t('Latence du serveur', 'Server latency', '服务器延迟'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(l10n.t(
              'Aller-retour vers Headscale depuis ce téléphone.',
              'Round trip to Headscale from this phone.',
              '从本机到 Headscale 的往返延迟。',
            )),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isMeasuringServer
                      ? '…'
                      : (_serverLatencyMs != null
                          ? '$_serverLatencyMs ms'
                          : '—'),
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: l10n.t('Mesurer', 'Measure', '测量'),
                  onPressed: _isMeasuringServer ? null : _measureServerLatency,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            value: _pingNodes,
            onChanged: (value) {
              setState(() => _pingNodes = value);
              _startPinging();
            },
            title: Text(l10n.t('Sonder les nœuds directement',
                'Probe nodes directly', '直接探测节点延迟')),
            subtitle: Text(l10n.t(
              'Les adresses des nœuds (100.64.x.x) ne sont joignables que si ce téléphone est dans le tailnet ; sinon l\'état affiché provient de Headscale.',
              'Node addresses (100.64.x.x) are only reachable when this phone is in the tailnet; otherwise the status shown comes from Headscale.',
              '节点内网地址（100.64.x.x）只有在手机接入同一 tailnet 时才可达；否则显示的状态来自 Headscale。',
            )),
          ),
        ],
      ),
    );
  }

  /// 测量本机到服务器的往返延迟。
  ///
  /// 用公开的 `GET /version`（不需要 API 密钥、开销极小），这才是"从这台手机出发"
  /// 有意义的延迟指标。
  Future<void> _measureServerLatency() async {
    final url = context.read<AppProvider>().activeServer?.url;
    if (url == null || url.isEmpty || !mounted) return;
    setState(() => _isMeasuringServer = true);
    try {
      final watch = Stopwatch()..start();
      final response =
          await http.get(Uri.parse('$url/version')).timeout(const Duration(seconds: 5));
      watch.stop();
      if (!mounted) return;
      setState(() {
        _serverLatencyMs =
            response.statusCode == 200 ? watch.elapsedMilliseconds : null;
        _isMeasuringServer = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverLatencyMs = null;
        _isMeasuringServer = false;
      });
    }
  }

  Future<void> _fetchNodes() async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final nodes = await appProvider.apiService.getNodes();
      if (!mounted) return;
      final selectedNodeId = _selectedNode?.id;
      setState(() {
        _nodes = nodes;
        if (selectedNodeId != null) {
          try {
            _selectedNode =
                _nodes.firstWhere((node) => node.id == selectedNodeId);
          } catch (e) {
            _selectedNode = _nodes.isNotEmpty ? _nodes.first : null;
          }
        } else {
          _selectedNode = _nodes.isNotEmpty ? _nodes.first : null;
        }
      });
      _startPinging();
    } catch (e) {
      if (!mounted) return;
      final locale = context.read<AppProvider>().locale;
      final l10n = L10n(locale);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${l10n.t('Erreur lors de la récupération des nœuds', 'Error fetching nodes', '获取节点出错')}: $e')),
      );
    }
  }

  /// 依次尝试的第三方公网 IP 服务（返回 JSON 或纯文本）。
  ///
  /// 用多个源是因为单个服务在部分网络下不可达：例如 `api.ipify.org` 在中国大陆网络
  /// 经常被 DNS 污染或直接拒绝连接（报 `Connection refused`），一旦只依赖它，
  /// 这个可选信息就会变成一条红色错误提示，还会连带拖住 traceroute。
  static const List<String> _publicIpSources = [
    'https://api.ipify.org?format=json',
    'https://api64.ipify.org?format=json',
    'https://icanhazip.com',
    'https://ifconfig.me/ip',
  ];

  /// 逐个尝试各源，任一成功即返回；全部失败返回 null。
  Future<String?> _fetchPublicIp() async {
    for (final source in _publicIpSources) {
      try {
        final response = await http
            .get(Uri.parse(source))
            .timeout(const Duration(seconds: 4));
        if (response.statusCode != 200) continue;
        final ip = _parsePublicIp(response.body);
        if (ip != null) return ip;
      } catch (_) {
        // 该源不可用（被墙 / DNS 污染 / 超时 / 证书问题），换下一个
      }
    }
    return null;
  }

  /// 兼容两种响应格式：ipify 的 `{"ip":"..."}` 与纯文本端点。
  String? _parsePublicIp(String body) {
    final text = body.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('{')) {
      try {
        final decoded = json.decode(text);
        final ip = decoded is Map ? decoded['ip'] : null;
        return ip is String && ip.trim().isNotEmpty ? ip.trim() : null;
      } catch (_) {
        return null;
      }
    }
    // 纯文本端点直接返回 IP；带 HTML/空格的（例如被劫持到的门户页）一律丢弃。
    if (text.length > 64 || text.contains('<') || text.contains(' ')) return null;
    return text;
  }

  void _fetchPublicIpAndTrace(int generation) {
    // traceroute 与公网 IP 之间没有任何依赖：立即开始，不要被第三方服务拖住。
    _startTraceRoute(generation);
    unawaited(_loadPublicIp(generation));
  }

  /// 异步补充公网 IP。它只是拓扑图上的装饰性标签，失败就显示 "—"，不再弹错误提示。
  Future<void> _loadPublicIp(int generation) async {
    final ip = await _fetchPublicIp();
    if (!mounted || _traceRouteGeneration != generation) return;
    setState(() {
      _publicIp = ip;
      _publicIpUnavailable = ip == null;
    });
  }

  /// 探测各 DERP 中继的延迟。
  ///
  /// 数据来源与 Headplane 相同：服务器需要启用内嵌 DERP（此时 Headscale 才注册
  /// `/bootstrap-dns` 与 `/derp/*`），否则这些路径不存在 —— 此时不报错，只提示。
  Future<void> _probeDerp() async {
    final serverUrl = context.read<AppProvider>().activeServer?.url;
    if (serverUrl == null || serverUrl.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _isProbingDerp = true;
      _derpError = null;
    });

    final service = DerpService(baseUrl: serverUrl);
    try {
      final probes = await service.probeAll();
      if (!mounted) return;
      setState(() {
        _derpProbes = probes;
        _isProbingDerp = false;
        _derpError = probes.isEmpty ? 'empty' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _derpError = e.toString();
        _isProbingDerp = false;
      });
    } finally {
      service.close();
    }
  }

  void _startTraceRoute(int generation) async {
    // Si une autre actualisation a été lancée, on ne commence pas un nouveau traceroute.
    if (_traceRouteGeneration != generation) return;

    setState(() {
      _isTracingRoute = true;
      // On s'assure de vider les données pour la nouvelle trace.
      _traceRouteHops.clear();
      _exitNodeInUse = null;
    });

    const String targetIp = '8.8.8.8'; // Google DNS

    for (int ttl = 1; ttl <= 30; ttl++) {
      // Vérifie à chaque itération si une nouvelle actualisation a été demandée.
      if (_traceRouteGeneration != generation || !mounted) break;

      final ping = Ping(targetIp, count: 1, ttl: ttl, timeout: 2);
      final completer = Completer<PingData?>();

      final StreamSubscription sub = ping.stream.listen((data) {
        if (!completer.isCompleted) {
          completer.complete(data);
        }
      });

      // Gère le cas où aucun paquet n'est reçu (timeout)
      Future.delayed(const Duration(seconds: 3), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      final PingData? data = await completer.future;
      sub.cancel(); // Annule l'abonnement pour éviter les fuites

      String hopIp = '*';
      if (data?.response?.ip != null) {
        hopIp = data!.response!.ip!;
        // Correction: La librairie de ping ajoute parfois un ':' à la fin de l'IP en mode traceroute.
        if (hopIp.endsWith(':')) {
          hopIp = hopIp.substring(0, hopIp.length - 1);
        }
      }

      // Log de débogage : Affiche chaque saut.
      // print('Génération $generation - Saut $ttl: $hopIp');

      // N'applique les changements que si la génération est toujours valide.
      if (_traceRouteGeneration == generation && mounted) {
        setState(() {
          // Crée une nouvelle liste pour garantir la reconstruction du widget.
          _traceRouteHops = [..._traceRouteHops, hopIp];
          // Vérifie si le saut correspond à un exit node
          if (hopIp != '*') {
            try {
              // On cherche si le saut correspond à N'IMPORTE QUEL nœud du réseau.
              final gatewayNode = _nodes.firstWhere(
                (node) => node.ipAddresses.contains(hopIp),
              );
              _exitNodeInUse = gatewayNode;
            } catch (e) {
              // Pas un exit node, on continue
            }
          }
        });
      }

      // On s'arrête uniquement si on atteint la destination finale.
      // La détection d'un exit node ne doit pas interrompre le traceroute complet.
      if (hopIp == targetIp) {
        break;
      }
    }

    if (mounted && _traceRouteGeneration == generation) {
      // print('--- Fin du Traceroute (Génération $generation) ---');
      setState(() {
        _isTracingRoute = false;
      });
    }
  }

  void _startPinging() {
    for (var sub in _pingSubscriptions.values) {
      sub.cancel();
    }
    _pingSubscriptions.clear();

    // 未开启时不做无意义的探测：节点内网地址在手机未接入 tailnet 时不可达，
    // 之前的实现因此把所有节点都显示成"离线"。
    if (!_pingNodes) {
      _pingResults.clear();
      return;
    }

    for (var node in _nodes) {
      if (node.ipAddresses.isNotEmpty) {
        final ip = node.ipAddresses.first;
        final ping = Ping(ip, count: 5, interval: 1);
        final responses = <PingResponse>[];

        _pingSubscriptions[node.id] = ping.stream.listen(
          (PingData data) {
            // On ne compte que les réponses valides (avec un temps de réponse) et sans erreur.
            if (data.response != null && data.error == null) {
              responses.add(data.response!);
            }
          },
          onDone: () {
            if (!mounted) return;
            setState(() {
              if (responses.isNotEmpty) {
                final totalTime = responses
                    .map((r) => r.time?.inMilliseconds ?? 0)
                    .reduce((a, b) => a + b);
                _pingResults[node.id] = PingResult(
                  isOnline: true,
                  averageLatency: totalTime / responses.length,
                );
              } else {
                _pingResults[node.id] = PingResult(isOnline: false);
              }
            });
          },
        );
      }
    }
  }

  @override
  void dispose() {
    for (var sub in _pingSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('Vue d\'ensemble du réseau', 'Network Overview', '网络概览')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  /// DERP 中继卡片：中继列表 + 从**本机**测得的延迟（最快的高亮）。
  ///
  /// 说明写清楚边界：Headscale API 不提供"某台机器用哪个中继"，所以这里给的是
  /// 中继列表与本机延迟——这恰好也是客户端挑选 home 中继所依据的信息。
  Widget _buildDerpCard() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
    );
    final fastest = _derpProbes.isNotEmpty && _derpProbes.first.reachable
        ? _derpProbes.first
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.t('Relais DERP', 'DERP relays', 'DERP 中继'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isProbingDerp)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: l10n.t('Mesurer à nouveau', 'Measure again', '重新测量'),
                    onPressed: _probeDerp,
                  ),
              ],
            ),
            if (muted != null)
              Text(
                l10n.t(
                  'Latence mesurée depuis cet appareil. Le relais réellement utilisé par une machine ne se voit que sur cette machine (commande « tailscale status »).',
                  'Latency measured from this device. The relay a given machine actually uses is only visible on that machine (run “tailscale status”).',
                  '延迟从本机测得。某台机器实际使用的中继只能在该机器上查看（执行 `tailscale status`）。',
                ),
                style: muted,
              ),
            if (_derpProbes.isNotEmpty) const SizedBox(height: 8),
            for (final probe in _derpProbes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        probe.isServer
                            ? l10n.t('Serveur (DERP intégré)', 'Server (embedded DERP)',
                                '服务器内嵌 DERP')
                            : probe.host,
                        style: TextStyle(
                          fontWeight: identical(probe, fastest)
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (identical(probe, fastest))
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l10n.t('Le plus rapide', 'Fastest', '最快'),
                          style: const TextStyle(fontSize: 11, color: Colors.green),
                        ),
                      ),
                    Text(
                      probe.reachable
                          ? '${probe.latencyMs} ms'
                          : l10n.t('Inaccessible', 'Unreachable', '不可达'),
                      style: TextStyle(
                        color: probe.reachable ? null : theme.disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
            if (_derpError != null && _derpProbes.isEmpty && !_isProbingDerp)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.t(
                    'Aucun relais DERP détecté. Le DERP intégré est-il activé côté Headscale, et /bootstrap-dns ainsi que /derp/* sont-ils autorisés par le proxy inverse ?',
                    'No DERP relay detected. Is embedded DERP enabled on Headscale, and are /bootstrap-dns and /derp/* allowed through your reverse proxy?',
                    '未检测到 DERP 中继。请确认 Headscale 已启用内嵌 DERP，且反向代理放行了 /bootstrap-dns 与 /derp/*。',
                  ),
                  style: muted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {    // Exclut le nœud sélectionné de la liste à afficher pour le ping.
    final nodesToDisplay =
        _nodes.where((node) => node.id != _selectedNode?.id).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildNodeSelector(),
          _buildLatencyCard(),
          _buildNetworkVisualizer(),
          _buildDerpCard(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: nodesToDisplay.length,
            itemBuilder: (context, index) {
              final node = nodesToDisplay[index];
              final result = _pingResults[node.id];
              final latency = result?.averageLatency;
              // 开启了直接探测但没收到回应：多半是因为手机不在 tailnet 内
              final pingFailed = _pingNodes && result != null && !result.isOnline;

              return ListTile(
                leading: CircleAvatar(
                  // 状态以**服务端上报**为准，而不是本机 ping 的结果
                  backgroundColor: node.online ? Colors.green : Colors.red,
                  radius: 10,
                ),
                title: Text(node.name),
                subtitle: Text(node.ipAddresses.join(', ')),
                trailing: latency != null
                    ? Text('${latency.toStringAsFixed(2)} ms')
                    : (pingFailed
                        ? Text(
                            context.l10n.t('Injoignable d\'ici',
                                'Unreachable from here', '本机不可达'),
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).disabledColor),
                          )
                        : null),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkVisualizer() {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              l10n.t('Visualisation du chemin réseau', 'Network Path Visualization', '网络路径可视化'),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildVisualizerNode(
                    context,
                    l10n.t('Mon Appareil', 'My Device', '我的设备'),
                    Icons.phone_iphone,
                    _selectedNode?.name ?? (l10n.t('N/A', 'N/A', '不适用'))),
                if (_exitNodeInUse != null) ...[
                  Icon(Icons.arrow_forward,
                      color: Theme.of(context).textTheme.bodyMedium?.color),
                  _buildVisualizerNode(
                      context, 'Exit Node', Icons.router, _exitNodeInUse!.name),
                ],
                Icon(Icons.arrow_forward,
                    color: Theme.of(context).textTheme.bodyMedium?.color),
                _buildVisualizerNode(context, 'Internet', Icons.cloud,
                    _publicIp ?? (_publicIpUnavailable ? '—' : '...')),
              ],
            ),
            if (_isTracingRoute) ...[
              const SizedBox(height: 10),
              CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary),
              Text(
                  l10n.t('Traceroute en cours...', 'Traceroute in progress...', 'Traceroute 进行中……'),
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (_traceRouteHops.isNotEmpty) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: Text(
                    l10n.t('Détails du traceroute', 'Traceroute Details', '路由追踪详情'),
                    style: Theme.of(context).textTheme.titleMedium),
                children: _traceRouteHops.map((hop) {
                  String nodeName = '';
                  try {
                    final node =
                        _nodes.firstWhere((n) => n.ipAddresses.contains(hop));
                    nodeName = ' (${node.name})';
                  } catch (e) {
                    // Ce n'est pas un nœud connu
                  }
                  return ListTile(
                    dense: true,
                    title: Text(
                        '${_traceRouteHops.indexOf(hop) + 1}: $hop$nodeName',
                        style: Theme.of(context).textTheme.bodyMedium),
                  );
                }).toList(),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildVisualizerNode(
      BuildContext context, String title, IconData icon, String subtitle) {
    return Column(
      children: [
        Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildNodeSelector() {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButton<Node>(
        value: _selectedNode,
        hint: Text(l10n.t('Sélectionnez un nœud', 'Select a node', '选择节点'),
            style: Theme.of(context).textTheme.bodyMedium),
        isExpanded: true,
        onChanged: (Node? newValue) {
          setState(() {
            _selectedNode = newValue;
          });
        },
        items: _nodes.map<DropdownMenuItem<Node>>((Node node) {
          return DropdownMenuItem<Node>(
            value: node,
            child:
                Text(node.name, style: Theme.of(context).textTheme.bodyMedium),
          );
        }).toList(),
      ),
    );
  }
}
