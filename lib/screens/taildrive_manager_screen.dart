import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/taildrive_share.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/models/version_info.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class TaildriveManagerScreen extends StatefulWidget {
  const TaildriveManagerScreen({super.key});

  @override
  State<TaildriveManagerScreen> createState() => _TaildriveManagerScreenState();
}

class _TaildriveManagerScreenState extends State<TaildriveManagerScreen> {
  bool _isLoading = true;
  List<Node> _allNodes = [];
  List<User> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final appProvider = context.read<AppProvider>();
      final apiService = appProvider.apiService;
      _allNodes = await apiService.getNodes();
      _allUsers = await apiService.getUsers();
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final l10n = L10n(appProvider.locale);
    final shares = appProvider.taildriveShares;

    final supportsTaildrive = VersionInfo.checkVersionAtLeast(
        appProvider.serverVersion, '0.29.0');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('Partages Taildrive', 'Taildrive Shares')),
      ),
      body: Column(
        children: [
          if (!supportsTaildrive)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade900, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('Version de Headscale incompatible', 'Incompatible Headscale Version'),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.t('Votre serveur tourne sous la version ${appProvider.serverVersion}. Les partages Taildrive nécessitent Headscale 0.29.0+ pour fonctionner. Les règles d\'accès ACL ne seront pas appliquées.', 'Your server is running version ${appProvider.serverVersion}. Taildrive shares require Headscale 0.29.0+ to function. Access rules will not be active on the server.'),
                          style: TextStyle(
                            color: Colors.red.shade100,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : shares.isEmpty
                    ? _buildEmptyState(l10n)
                    : ListView.builder(
                        itemCount: shares.length,
                        itemBuilder: (context, index) {
                          final share = shares[index];
                          final sourceNode = _allNodes.firstWhere(
                            (n) => n.id == share.sourceNodeId,
                            orElse: () => Node(
                              id: '',
                              machineKey: '',
                              hostname: '',
                              name: l10n.t('Nœud inconnu', 'Unknown Node'),
                              user: '',
                              userId: '',
                              ipAddresses: [],
                              online: false,
                              lastSeen: DateTime.now(),
                              sharedRoutes: [],
                              availableRoutes: [],
                              isExitNode: false,
                              isLanSharer: false,
                              tags: [],
                              baseDomain: '',
                              endpoint: '',
                            ),
                          );

                          final domain = sourceNode.baseDomain.isNotEmpty ? sourceNode.baseDomain : 'tailnet';
                          final clientUrl = 'http://100.100.100.100:8080/$domain/${sourceNode.name}/${share.shareName}';
                          final hostCommand = 'tailscale drive share ${share.shareName} "${share.localPath}"';

                          return Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: share.accessMode == TaildriveAccessMode.rw 
                                          ? const Color(0xFF10B981) 
                                          : const Color(0xFF3B82F6),
                                      width: 5,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.folder, color: Colors.amber, size: 28),
                                              const SizedBox(width: 10),
                                              Text(
                                                share.shareName,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: (share.accessMode == TaildriveAccessMode.rw 
                                                      ? const Color(0xFF10B981).withValues(alpha: 0.15) 
                                                      : const Color(0xFF3B82F6).withValues(alpha: 0.15)),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  share.accessMode == TaildriveAccessMode.rw 
                                                      ? (l10n.t('Lecture/Écriture', 'Read/Write'))
                                                      : (l10n.t('Lecture seule', 'Read-only')),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: share.accessMode == TaildriveAccessMode.rw 
                                                        ? const Color(0xFF10B981) 
                                                        : const Color(0xFF3B82F6),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                                onPressed: () => _confirmDelete(share.id, l10n),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildDetailRow(
                                        icon: Icons.computer,
                                        label: l10n.t('Machine Source', 'Source Machine'),
                                        value: sourceNode.name,
                                      ),
                                      const SizedBox(height: 6),
                                      _buildDetailRow(
                                        icon: Icons.person_outline,
                                        label: l10n.t('Bénéficiaire', 'Recipient'),
                                        value: share.recipient,
                                      ),
                                      const SizedBox(height: 6),
                                      _buildDetailRow(
                                        icon: Icons.folder_open_outlined,
                                        label: l10n.t('Dossier partagé', 'Shared folder'),
                                        value: share.localPath,
                                        isPath: true,
                                      ),
                                      const Divider(height: 24, thickness: 1),
                                      Text(
                                        l10n.t('1. Lancer ce partage sur la machine Windows/Linux/Mac :', '1. Start this share on the Windows/Linux/Mac machine:'),
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                                      ),
                                      const SizedBox(height: 6),
                                      _buildCliBox(
                                        context: context,
                                        text: hostCommand,
                                        l10n: l10n,
                                        snackbarMsg: l10n.t('Commande de partage copiée !', 'Share command copied!'),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        l10n.t('2. URL de connexion WebDAV pour les clients (Android, VLC...) :', '2. WebDAV connection URL for clients (Android, VLC...):'),
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                                      ),
                                      const SizedBox(height: 6),
                                      _buildCliBox(
                                        context: context,
                                        text: clientUrl,
                                        l10n: l10n,
                                        isLink: true,
                                        snackbarMsg: l10n.t('URL de connexion WebDAV copiée !', 'WebDAV connection URL copied!'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddShareDialog(l10n),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(L10n l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            l10n.t('Aucun partage configuré', 'No shares configured'),
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.t('Cliquez sur + pour créer votre premier partage de dossiers sécurisé.', 'Click + to create your first secure folder share.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String shareId, L10n l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('Supprimer le partage', 'Delete Share')),
        content: Text(l10n.t('Êtes-vous sûr de vouloir supprimer ce partage ?', 'Are you sure you want to delete this share?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.t('Annuler', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.t('Supprimer', 'Delete'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AppProvider>().deleteTaildriveShare(shareId);
    }
  }

  void _showAddShareDialog(L10n l10n) {
    showDialog(
      context: context,
      builder: (context) => _AddTaildriveShareDialog(
        allNodes: _allNodes,
        allUsers: _allUsers,
        l10n: l10n,
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isPath = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
              children: [
                TextSpan(
                  text: '$label : ',
                  style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: isPath ? 'monospace' : null,
                    color: isPath ? Colors.deepOrange.shade700 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCliBox({
    required BuildContext context,
    required String text,
    required L10n l10n,
    required String snackbarMsg,
    bool isLink = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.lightGreenAccent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.copy, size: 18, color: Colors.lightGreenAccent),
            tooltip: l10n.t('Copier', 'Copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.lightGreenAccent),
                      const SizedBox(width: 10),
                      Text(snackbarMsg),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AddTaildriveShareDialog extends StatefulWidget {
  final List<Node> allNodes;
  final List<User> allUsers;
  final L10n l10n;

  const _AddTaildriveShareDialog({
    required this.allNodes,
    required this.allUsers,
    required this.l10n,
  });

  @override
  State<_AddTaildriveShareDialog> createState() =>
      __AddTaildriveShareDialogState();
}

class __AddTaildriveShareDialogState extends State<_AddTaildriveShareDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pathController = TextEditingController();
  Node? _selectedSourceNode;
  String? _selectedRecipient;
  TaildriveAccessMode _accessMode = TaildriveAccessMode.ro;



  // To properly implement the filter, I need the temporary rules.
  List<String> _filteredRecipients = [];

  @override
  void initState() {
    super.initState();
    _loadFilteredRecipients();
  }

  Future<void> _loadFilteredRecipients() async {
    final appProvider = context.read<AppProvider>();
    final serverId = appProvider.activeServer?.id;
    if (serverId == null) return;

    final rules = await appProvider.storageService.getTemporaryRules(serverId);

    setState(() {
      _updateRecipients(rules);
    });
  }

  void _updateRecipients(List<Map<String, dynamic>> rules) {
    if (_selectedSourceNode == null) {
      _filteredRecipients = [];
      return;
    }

    final accessibleUsers = <String>{};
    final selectedOwner = _selectedSourceNode!.getNormalizedOwner();
    final matchedUser = widget.allUsers.firstWhere(
      (u) => normalizeUserName(u.name) == selectedOwner,
      orElse: () => User(id: '', name: selectedOwner),
    );
    accessibleUsers.add(matchedUser.name);

    // 2. Analyser les règles spécifiques pour trouver d'autres bénéficiaires valides
    for (var rule in rules) {
      final src = rule['src'] as String;
      final dst = rule['dst'] as String;

      // On vérifie si la source du partage (notre nœud sélectionné) est concernée par cette règle
      bool isSourceInRule = false;
      
      // Match par utilisateur/groupe
      final selectedOwner = _selectedSourceNode!.getNormalizedOwner();
      if (src == 'group:$selectedOwner' || src == selectedOwner) {
        isSourceInRule = true;
      }
      // Match par IP
      for (var ip in _selectedSourceNode!.ipAddresses) {
        if (src.contains(ip)) {
          isSourceInRule = true;
          break;
        }
      }
      // Match par tag
      for (var tag in _selectedSourceNode!.tags) {
        if (src == tag) {
          isSourceInRule = true;
          break;
        }
      }

      if (isSourceInRule) {
        // Si notre nœud est la source de la règle, la destination est un bénéficiaire potentiel
        _addRecipientFromRuleTarget(dst, accessibleUsers);
      }

      // Comme les règles de tags sont bidirectionnelles dans notre générateur, 
      // on vérifie aussi si notre nœud est la destination de la règle
      bool isDestInRule = false;
      if (dst == 'group:$selectedOwner' || dst == selectedOwner) {
        isDestInRule = true;
      }
      for (var ip in _selectedSourceNode!.ipAddresses) {
        if (dst.contains(ip)) {
          isDestInRule = true;
          break;
        }
      }
      for (var tag in _selectedSourceNode!.tags) {
        if (dst == tag) {
          isDestInRule = true;
          break;
        }
      }

      if (isDestInRule) {
        _addRecipientFromRuleTarget(src, accessibleUsers);
      }
    }

    // On transforme les noms d'utilisateurs en liste triée
    _filteredRecipients = accessibleUsers.toList();
    _filteredRecipients.sort((a, b) {
      final selectedOwner = _selectedSourceNode!.getNormalizedOwner();
      final matchedUser = widget.allUsers.firstWhere(
        (u) => normalizeUserName(u.name) == selectedOwner,
        orElse: () => User(id: '', name: selectedOwner),
      );
      if (a == matchedUser.name) return -1;
      if (b == matchedUser.name) return 1;
      return a.compareTo(b);
    });
  }

  void _addRecipientFromRuleTarget(String target, Set<String> recipients) {
    if (target.startsWith('group:')) {
      final groupName = target.replaceFirst('group:', '');
      final matchedUser = widget.allUsers.firstWhere(
        (u) => normalizeUserName(u.name) == groupName,
        orElse: () => User(id: '', name: groupName),
      );
      recipients.add(matchedUser.name);
    } else if (target.startsWith('tag:')) {
      // Pour les tags, on cherche l'utilisateur propriétaire du tag
      for (var node in widget.allNodes) {
        if (node.tags.contains(target)) {
          final owner = node.getNormalizedOwner();
          final matchedUser = widget.allUsers.firstWhere(
            (u) => normalizeUserName(u.name) == owner,
            orElse: () => User(id: '', name: owner),
          );
          recipients.add(matchedUser.name);
        }
      }
    } else {
      // Pour les IPs, on cherche le nœud correspondant
      for (var node in widget.allNodes) {
        for (var ip in node.ipAddresses) {
          if (target.contains(ip)) {
            final owner = node.getNormalizedOwner();
            final matchedUser = widget.allUsers.firstWhere(
              (u) => normalizeUserName(u.name) == owner,
              orElse: () => User(id: '', name: owner),
            );
            recipients.add(matchedUser.name);
            break;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.t('Ajouter un partage', 'Add Share')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Node>(
                initialValue: _selectedSourceNode,
                decoration: InputDecoration(
                  labelText: widget.l10n.t('Nœud Source', 'Source Node'),
                ),
                items: widget.allNodes.map((n) {
                  return DropdownMenuItem(value: n, child: Text(n.name));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedSourceNode = val;
                    _selectedRecipient = null;
                    _loadFilteredRecipients();
                  });
                },
                validator: (val) => val == null
                    ? (widget.l10n.t('Obligatoire', 'Required'))
                    : null,
              ),
              const SizedBox(height: 16),
              if (_selectedSourceNode != null) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedRecipient,
                  decoration: InputDecoration(
                    labelText: widget.l10n.t('Bénéficiaire', 'Recipient'),
                    helperText: widget.l10n.t('Utilisateurs autorisés à voir le partage', 'Users allowed to see the share'),
                  ),
                  items: _filteredRecipients.map((u) {
                    final isSameUser = normalizeUserName(u) == _selectedSourceNode!.getNormalizedOwner();
                    return DropdownMenuItem(
                      value: u,
                      child: Text(isSameUser ? '$u (${widget.l10n.t('Propriétaire', 'Owner')})' : u),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedRecipient = val),
                  validator: (val) => val == null
                      ? (widget.l10n.t('Obligatoire', 'Required'))
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: widget.l10n.t('Nom du partage', 'Share Name'),
                    hintText: 'ex: Documents',
                  ),
                  validator: (val) => val == null || val.isEmpty
                      ? (widget.l10n.t('Obligatoire', 'Required'))
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pathController,
                  decoration: InputDecoration(
                    labelText: widget.l10n.t('Chemin local', 'Local Path'),
                    hintText: 'ex: /home/user/docs or C:\\Data',
                  ),
                  validator: (val) => val == null || val.isEmpty
                      ? (widget.l10n.t('Obligatoire', 'Required'))
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TaildriveAccessMode>(
                  initialValue: _accessMode,
                  decoration: InputDecoration(
                    labelText: widget.l10n.t('Permissions', 'Permissions'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: TaildriveAccessMode.ro,
                      child: Text(widget.l10n.t('Lecture seule', 'Read-only')),
                    ),
                    DropdownMenuItem(
                      value: TaildriveAccessMode.rw,
                      child: Text(widget.l10n.t('Lecture/Écriture', 'Read/Write')),
                    ),
                  ],
                  onChanged: (val) => setState(() => _accessMode = val!),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.l10n.t('Annuler', 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _selectedSourceNode == null ? null : _handleSave,
          child: Text(widget.l10n.t('Ajouter', 'Add')),
        ),
      ],
    );
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final share = TaildriveShare(
        sourceNodeId: _selectedSourceNode!.id,
        shareName: _nameController.text.trim(),
        localPath: _pathController.text.trim(),
        recipient: _selectedRecipient!,
        accessMode: _accessMode,
      );

      context.read<AppProvider>().addTaildriveShare(share);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.l10n.t('Partage ajouté. N\'oubliez pas de régénérer la politique ACL.', 'Share added. Don\'t forget to regenerate the ACL policy.')),
          action: SnackBarAction(
            label: widget.l10n.t('ACL', 'ACL'),
            onPressed: () {
              // Navigation already handled by stack
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }
}
