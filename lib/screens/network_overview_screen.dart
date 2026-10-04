import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:dart_ping/dart_ping.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:headscalemanager/l10n/l10n.dart';

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

  Widget _buildContent() {
    // Exclut le nœud sélectionné de la liste à afficher pour le ping.
    final nodesToDisplay =
        _nodes.where((node) => node.id != _selectedNode?.id).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildNodeSelector(),
          _buildNetworkVisualizer(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: nodesToDisplay.length,
            itemBuilder: (context, index) {
              final node = nodesToDisplay[index];
              final result = _pingResults[node.id];
              final isOnline = result?.isOnline ?? false;
              final latency = result?.averageLatency;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isOnline ? Colors.green : Colors.red,
                  radius: 10,
                ),
                title: Text(node.name),
                subtitle: Text(node.ipAddresses.join(', ')),
                trailing: latency != null
                    ? Text('${latency.toStringAsFixed(2)} ms')
                    : null,
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
