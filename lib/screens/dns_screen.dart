import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:share_plus/share_plus.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class DnsScreen extends StatefulWidget {
  const DnsScreen({super.key});

  @override
  State<DnsScreen> createState() => _DnsScreenState();
}

class _DnsScreenState extends State<DnsScreen> {
  List<Node> _nodes = [];
  List<Node> _filteredNodes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isHelpCardExpanded = false;
  Map<String, String> _customDnsRecords = {}; // nodeId -> alias

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final apiService = appProvider.apiService;
      final serverId = appProvider.activeServer?.id;

      final nodes = await apiService.getNodes();

      Map<String, String> customRecords = {};
      if (serverId != null) {
        customRecords =
            await appProvider.storageService.getCustomDnsRecords(serverId);
      }

      if (mounted) {
        setState(() {
          _nodes = nodes;
          _filteredNodes = _applyFilter(nodes, _searchQuery);
          _isLoading = false;
          _customDnsRecords = customRecords;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final l10n = L10n(context.read<AppProvider>().locale);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${l10n.t('Erreur lors de la récupération', 'Error fetching data', '获取数据出错')}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  List<Node> _applyFilter(List<Node> nodes, String query) {
    if (query.isEmpty) return nodes;
    final queryLower = query.toLowerCase();
    return nodes.where((node) {
      final customAlias = _customDnsRecords[node.id]?.toLowerCase() ?? '';
      return node.name.toLowerCase().contains(queryLower) ||
          node.fqdn.toLowerCase().contains(queryLower) ||
          customAlias.contains(queryLower) ||
          node.ipAddresses.any((ip) => ip.contains(queryLower));
    }).toList();
  }

  void _filterNodes(String query) {
    setState(() {
      _searchQuery = query;
      _filteredNodes = _applyFilter(_nodes, query);
    });
  }

  Future<void> _saveCustomRecord(String nodeId, String alias) async {
    final appProvider = context.read<AppProvider>();
    final serverId = appProvider.activeServer?.id;
    if (serverId == null) return;

    if (alias.trim().isEmpty) {
      _customDnsRecords.remove(nodeId);
    } else {
      _customDnsRecords[nodeId] = alias.trim();
    }

    await appProvider.storageService
        .saveCustomDnsRecords(serverId, _customDnsRecords);
    _filterNodes(_searchQuery); // Re-apply filter to update view
  }

  String _getIpv4(Node node) =>
      node.ipAddresses.firstWhere((ip) => !ip.contains(':'), orElse: () => '');
  String _getIpv6(Node node) =>
      node.ipAddresses.firstWhere((ip) => ip.contains(':'), orElse: () => '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n(context.watch<AppProvider>().locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('Vue DNS', 'DNS View', 'DNS 视图')),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: Column(
          children: [
            _buildWarningBanner(context, l10n),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  labelText: l10n.t('Rechercher par nom, FQDN, alias ou IP', 'Search by name, FQDN, alias, or IP', '按名称、FQDN、别名或 IP 搜索'),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.cardColor,
                ),
                onChanged: _filterNodes,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredNodes.isEmpty
                      ? Center(
                          child: Text(
                              l10n.t('Aucun nœud trouvé', 'No nodes found', '未找到节点')))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _filteredNodes.length,
                          itemBuilder: (context, index) {
                            final node = _filteredNodes[index];
                            final ipv4 = _getIpv4(node);
                            final ipv6 = _getIpv6(node);
                            final customAlias = _customDnsRecords[node.id];

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 8),
                              color: theme.cardColor,
                              child: ListTile(
                                isThreeLine: true,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(node.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                    ),
                                    if (customAlias != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: isValidDns1123Subdomain(
                                                    customAlias)
                                                ? theme.colorScheme
                                                    .tertiaryContainer
                                                : Colors.red.withValues(
                                                    alpha: 0.2), // Alert color
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isValidDns1123Subdomain(
                                                      customAlias)
                                                  ? Icons.bookmark
                                                  : Icons.warning_amber_rounded,
                                              size: 12,
                                              color: isValidDns1123Subdomain(
                                                      customAlias)
                                                  ? theme.colorScheme
                                                      .onTertiaryContainer
                                                  : Colors.red,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              customAlias,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                      color: isValidDns1123Subdomain(
                                                              customAlias)
                                                          ? theme.colorScheme
                                                              .onTertiaryContainer
                                                          : Colors.red,
                                                      fontWeight:
                                                          FontWeight.bold),
                                            ),
                                            if (!isValidDns1123Subdomain(
                                                customAlias))
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 4.0),
                                                child: InkWell(
                                                  onTap: () {
                                                    final sanitized =
                                                        sanitizeDns1123Subdomain(
                                                            customAlias);
                                                    showDialog(
                                                        context: context,
                                                        builder: (ctx) =>
                                                            AlertDialog(
                                                                title: Text(l10n.t('Réparer Alias', 'Fix Alias', '修复别名')),
                                                                content: Text(l10n.t('Cet alias est invalide pour la v0.27+.\nRemplacement suggéré : "$sanitized"', 'This alias is invalid for v0.27+.\nSuggested replacement: "$sanitized"', '该别名在 v0.27+ 中无效。\n建议替换为：「$sanitized」')),
                                                                actions: [
                                                                  TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                              ctx),
                                                                      child: Text(l10n.t('Ignorer', 'Ignore', '忽略'))),
                                                                  TextButton(
                                                                      onPressed:
                                                                          () {
                                                                        _saveCustomRecord(
                                                                            node.id,
                                                                            sanitized);
                                                                        Navigator.pop(
                                                                            ctx);
                                                                      },
                                                                      child: Text(l10n.t('Corriger', 'Fix', '修复'))),
                                                                ]));
                                                  },
                                                  child: const Icon(
                                                      Icons.build_circle,
                                                      size: 14,
                                                      color: Colors.red),
                                                ),
                                              )
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(node.fqdn,
                                        style: const TextStyle(
                                            fontFamily: 'monospace')),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8.0,
                                      runSpacing: 8.0,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        _buildActionButton(
                                            context, l10n, 'DNS', node.fqdn),
                                        if (ipv4.isNotEmpty)
                                          _buildActionButton(
                                              context, l10n, 'IPv4', ipv4),
                                        if (ipv6.isNotEmpty)
                                          _buildActionButton(
                                              context, l10n, 'IPv6', ipv6),
                                        IconButton(
                                            onPressed: () =>
                                                _showEditAliasDialog(
                                                    context, node, customAlias),
                                            tooltip: l10n.t('Ajouter/Modifier un alias DNS (Mémo local)', 'Add/Edit DNS Alias (Local Memo)', '添加/编辑 DNS 别名（本地备忘）'),
                                            icon: Icon(Icons.edit_note,
                                                color:
                                                    theme.colorScheme.primary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            _buildHelpCard(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner(BuildContext context, L10n l10n) {
    return Container(
      width: double.infinity,
      color: Colors.amber.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.t("Les noms affichés sont estimés. Les configurations serveur (MagicDNS/Extra Records) ne sont pas visibles ici mais fonctionnent correctement.", "Displayed names are estimated. Server-side custom MagicDNS/Extra Records are not visible here but work correctly.", '显示的名称是推算的。服务器配置（MagicDNS/Extra Records）在这里不可见，但会正常工作。'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange[800],
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditAliasDialog(
      BuildContext context, Node node, String? currentAlias) {
    final l10n = L10n(context.read<AppProvider>().locale);
    final controller = TextEditingController(text: currentAlias);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('Alias DNS (Mémo Local)', 'DNS Alias (Local Memo)', 'DNS 别名（本地备忘）')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.t("Cet alias est uniquement sauvegardé localement sur cet appareil pour votre référence. Assurez-vous d'ajouter cet enregistrement dans le fichier 'config.yaml' de votre serveur Headscale pour qu'il soit effectif sur le réseau.", "This alias is only saved locally on this device for your reference. Make sure to add this record to your Headscale server's 'config.yaml' for it to work on the network.", '此别名仅保存在本机供你参考。要让它在网络中生效，请把该记录添加到 Headscale 服务器的「config.yaml」文件中。'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: l10n.t('Nom DNS personnalisé', 'Custom DNS Name', '自定义 DNS 名称'),
                hintText: 'ex: nas.home',
                border: const OutlineInputBorder(),
                helperText: l10n.t('Lettres minuscules, chiffres et tirets uniquement.', 'Lowercase letters, numbers, and hyphens only.', '仅限小写字母、数字和连字符。'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.t('Annuler', 'Cancel', '取消')),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty && !isValidDns1123Subdomain(text)) {
                final sanitized = sanitizeDns1123Subdomain(text);
                showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                          title:
                              Text(l10n.t('Format Invalide', 'Invalid Format', '格式无效')),
                          content: Text(l10n.t('Le nom "$text" ne respecte pas le format DNS (RFC 1123).\nVoulez-vous utiliser "$sanitized" à la place ?', 'The name "$text" does not match DNS format (RFC 1123).\nDo you want to use "$sanitized" instead?', '名称 "$text" 不符合 DNS 格式（RFC 1123）。\n是否改用 "$sanitized"？')),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(l10n.t('Annuler', 'Cancel', '取消'))),
                            TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx); // Close alert
                                  _saveCustomRecord(
                                      node.id, sanitized); // Save corrected
                                  Navigator.pop(context); // Close edit dialog
                                },
                                child: Text(l10n.t('Utiliser corrigé', 'Use corrected', '使用修正后的值'))),
                          ],
                        ));
                return;
              }
              _saveCustomRecord(node.id, text);
              Navigator.pop(context);
            },
            child: Text(l10n.t('Sauvegarder', 'Save', '保存')),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, L10n l10n, String label, String value) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      onSelected: (choice) {
        if (choice == 'copy') {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label ${l10n.t('copié', 'copied', '已复制')}!')));
        } else if (choice == 'share') {
          SharePlus.instance.share(ShareParams(
            text: value,
            subject: 'DNS Info: $label',
          ));
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'copy',
          child: ListTile(
            leading: const Icon(Icons.copy),
            title: Text(l10n.t('Copier', 'Copy', '复制')),
          ),
        ),
        PopupMenuItem<String>(
          value: 'share',
          child: ListTile(
            leading: const Icon(Icons.share),
            title: Text(l10n.t('Partager', 'Share', '分享')),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildHelpCard(BuildContext context, L10n l10n) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ExpansionTile(
        initiallyExpanded: _isHelpCardExpanded,
        onExpansionChanged: (bool expanded) {
          setState(() {
            _isHelpCardExpanded = expanded;
          });
        },
        title: Text(
          l10n.t("Noms DNS Personnalisés", "Custom DNS Names", '自定义 DNS 名称'),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: theme.dividerColor),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: theme.dividerColor),
        ),
        backgroundColor: theme.cardColor,
        collapsedBackgroundColor: theme.cardColor,
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              l10n.t("Pour assigner un nom DNS à un service sur votre réseau local (ex: nas.votre.domaine pointant vers 192.168.1.100), vous devez modifier la section 'dns_config.extra_records' dans votre fichier config.yaml sur le serveur Headscale et redémarrer le service. Cette action ne peut pas être effectuée depuis l'application.", "To assign a DNS name to a service on your local network (e.g., nas.your.domain pointing to 192.168.1.100), you must edit the 'dns_config.extra_records' section in your config.yaml file on the Headscale server and restart the service. This action cannot be performed from the application.", '要为局域网内的服务分配 DNS 名称（例如把 nas.your.domain 指向 192.168.1.100），需要在 Headscale 服务器的 config.yaml 中修改 dns_config.extra_records 段并重启服务。此操作无法在应用内完成。'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
