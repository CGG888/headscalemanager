import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/l10n/l10n.dart';

// Types de commandes
enum CommandType {
  static, // Commande statique
  dynamic, // Commande avec paramètres personnalisables
  serverBased, // Commande basée sur les données du serveur
  interactive, // Commande avec interface interactive
}

// Types de paramètres
enum ParameterType {
  text, // Texte libre
  ipAddress, // Adresse IP
  subnet, // Sous-réseau (CIDR)
  nodeSelect, // Sélection de nœud
  userSelect, // Sélection d'utilisateur
  authKeySelect, // Sélection de clé d'auth
  routeSelect, // Sélection de route
  boolean, // Booléen
  number, // Nombre
}

// Paramètre de commande
class CommandParameter {
  final String id;
  final String label;
  final String description;
  final ParameterType type;
  final bool required;
  final String? defaultValue;
  final List<String>? options;
  final String? placeholder;
  final String? validation;

  const CommandParameter({
    required this.id,
    required this.label,
    required this.description,
    required this.type,
    this.required = true,
    this.defaultValue,
    this.options,
    this.placeholder,
    this.validation,
  });

  factory CommandParameter.fromJson(Map<String, dynamic> json) {
    return CommandParameter(
      id: json['id'] as String,
      label: json['label'] as String,
      description: json['description'] as String,
      type: ParameterType.values.firstWhere(
        (t) => t.toString() == 'ParameterType.${json['type']}',
        orElse: () => ParameterType.text,
      ),
      required: json['required'] as bool? ?? true,
      defaultValue: json['defaultValue'] as String?,
      options:
          json['options'] != null ? List<String>.from(json['options']) : null,
      placeholder: json['placeholder'] as String?,
      validation: json['validation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'description': description,
      'type': type.toString().split('.').last,
      'required': required,
      'defaultValue': defaultValue,
      'options': options,
      'placeholder': placeholder,
      'validation': validation,
    };
  }
}

class ClientCommand {
  final String id;
  final String title;
  final String description;
  final String windowsCommand;
  final String linuxCommand;
  final CommandCategory category;
  final List<String> tags;
  final bool requiresElevation;
  final String? notes;
  final CommandType type;
  final List<CommandParameter>? parameters;
  final bool isDynamic;

  /// 该命令在 Windows 上是否可用。
  ///
  /// 此前由 [windowsCommand] 是否包含法语文案 "Non applicable" 推断，
  /// 一旦把命令文案本地化就会静默失效，故改为显式字段。
  final bool isWindowsSupported;

  const ClientCommand({
    required this.id,
    required this.title,
    required this.description,
    required this.windowsCommand,
    required this.linuxCommand,
    required this.category,
    required this.tags,
    this.requiresElevation = false,
    this.notes,
    this.type = CommandType.static,
    this.parameters,
    this.isDynamic = false,
    this.isWindowsSupported = true,
  });

  factory ClientCommand.fromJson(Map<String, dynamic> json) {
    return ClientCommand(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      windowsCommand: json['windowsCommand'] as String,
      linuxCommand: json['linuxCommand'] as String,
      category: CommandCategory.fromStored(json['category'] as String?),
      tags: List<String>.from(json['tags'] as List),
      requiresElevation: json['requiresElevation'] as bool? ?? false,
      notes: json['notes'] as String?,
      type: CommandType.values.firstWhere(
        (t) => t.toString() == 'CommandType.${json['type'] ?? 'static'}',
        orElse: () => CommandType.static,
      ),
      parameters: json['parameters'] != null
          ? (json['parameters'] as List)
              .map((p) => CommandParameter.fromJson(p))
              .toList()
          : null,
      isDynamic: json['isDynamic'] as bool? ?? false,
      isWindowsSupported: json['isWindowsSupported'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'windowsCommand': windowsCommand,
      'linuxCommand': linuxCommand,
      'category': category.key,
      'tags': tags,
      'requiresElevation': requiresElevation,
      'notes': notes,
      'type': type.toString().split('.').last,
      'parameters': parameters?.map((p) => p.toJson()).toList(),
      'isDynamic': isDynamic,
      'isWindowsSupported': isWindowsSupported,
    };
  }

  String getCommandForPlatform(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return windowsCommand;
      case 'linux':
        return linuxCommand;
      default:
        return windowsCommand;
    }
  }

  // Générer la commande avec les paramètres fournis
  String generateCommand(String platform, Map<String, String> parameterValues) {
    String command = getCommandForPlatform(platform);

    // Remplacer les placeholders par les valeurs
    parameterValues.forEach((key, value) {
      command = command.replaceAll('{$key}', value);
    });

    // Nettoyer les placeholders non remplis et les espaces en trop
    command = command
        .replaceAll(RegExp(r'\s?\{[a-zA-Z0-9_]+\}\s?'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return command;
  }
}

// Catégories prédéfinies
// 命令分类：与界面语言解耦的稳定枚举。
//
// 过滤、配色、图标等逻辑只依赖枚举值本身；展示文案由 [label] 提供；
// 持久化使用 [key]（ASCII），因此切换界面语言不会污染已有数据。
enum CommandCategory {
  connection,
  routing,
  troubleshooting,
  configuration,
  monitoring,
  security,
  maintenance,
  serverSpecific,
  other;

  /// 序列化用的稳定标识（禁止本地化）。
  String get key => name;

  /// 从 [key] 还原；无法识别时回退到 [other]。
  static CommandCategory fromKey(String? key) =>
      values.firstWhere((c) => c.key == key, orElse: () => other);

  /// 兼容历史数据：旧版本曾把本地化后的分类名直接写进 category 字段。
  static CommandCategory fromStored(String? value) {
    if (value == null) return other;
    for (final c in values) {
      if (c.key == value) return c;
    }
    return switch (value) {
      'Connexion' || 'Connection' => connection,
      'Routage' || 'Routing' => routing,
      'Dépannage' || 'Troubleshooting' => troubleshooting,
      'Configuration' => configuration,
      'Surveillance' || 'Monitoring' => monitoring,
      'Sécurité' || 'Security' => security,
      'Maintenance' => maintenance,
      'Spécifique Serveur' || 'Server Specific' => serverSpecific,
      _ => other,
    };
  }

  /// 展示文案。
  String label(L10n l10n) => switch (this) {
        connection => l10n.t('Connexion', 'Connection', '连接'),
        routing => l10n.t('Routage', 'Routing', '路由'),
        troubleshooting => l10n.t('Dépannage', 'Troubleshooting', '故障排查'),
        configuration => 'Configuration',
        monitoring => l10n.t('Surveillance', 'Monitoring', '监控'),
        security => l10n.t('Sécurité', 'Security', '安全'),
        maintenance => 'Maintenance',
        serverSpecific => l10n.t('Spécifique Serveur', 'Server Specific', '服务器专属'),
        other => l10n.t('Autre', 'Other', '其他'),
      };
}

// Générateur de commandes dynamiques
class DynamicCommandGenerator {
  // Générer des commandes basées sur le serveur actuel
  static List<ClientCommand> generateServerBasedCommands(String serverUrl,
      {required L10n l10n}) {
    return [
      // Connexion avec serveur personnalisé
      ClientCommand(
        id: 'connect_to_server',
        title: l10n.t('Connexion au serveur configuré', 'Connect to configured server', '连接到已配置的服务器'),
        description: l10n.t('Se connecter au serveur Headscale configuré dans l\'application', 'Connect to the Headscale server configured in the application', '连接到应用中配置的 Headscale 服务器'),
        windowsCommand: 'tailscale up --login-server=$serverUrl',
        linuxCommand: 'sudo tailscale up --login-server=$serverUrl',
        category: CommandCategory.connection,
        tags: ['connexion', 'serveur', 'up'],
        type: CommandType.serverBased,
        isDynamic: false,
      ),

      // Connexion avec clé d'auth personnalisée
      ClientCommand(
        id: 'connect_with_custom_key',
        title: l10n.t('Connexion avec clé pré-authentifiée', 'Connect with pre-auth key', '使用预认证密钥连接'),
        description: l10n.t('Se connecter avec une clé pré-authentifiée (à saisir manuellement)', 'Connect with a pre-authentication key (enter manually)', '使用预认证密钥连接（需手动输入）'),
        windowsCommand:
            'tailscale up --login-server=$serverUrl --authkey={authkey}',
        linuxCommand:
            'sudo tailscale up --login-server=$serverUrl --authkey={authkey}',
        category: CommandCategory.connection,
        tags: ['connexion', 'authkey', 'up'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'authkey',
            label: l10n.t('Clé d\'authentification', 'Authentication key', '认证密钥'),
            description: l10n.t('Entrez votre clé pré-authentifiée', 'Enter your pre-auth key', '输入你的预认证密钥'),
            type: ParameterType.text,
            placeholder:
              'nodekey-xxxxx 或 tskey-xxxxx',
          ),
        ],
      ),
    ];
  }

  // Générer des commandes basées sur les nœuds existants
  static List<ClientCommand> generateNodeBasedCommands(List<Node> nodes,
      {required L10n l10n}) {
    List<ClientCommand> commands = [];

    // Commandes pour utiliser des nœuds de sortie existants
    final exitNodes = nodes.where((n) => n.isExitNode && n.online).toList();
    if (exitNodes.isNotEmpty) {
      commands.add(
        ClientCommand(
          id: 'use_specific_exit_node',
          title: l10n.t('Utiliser un nœud de sortie spécifique', 'Use a specific exit node', '使用指定的出口节点'),
          description: l10n.t('Router le trafic via un nœud de sortie disponible', 'Route traffic through an available exit node', '通过可用出口节点路由流量'),
          windowsCommand:
              'tailscale up --login-server={server_url} --exit-node={node_name}',
          linuxCommand:
              'sudo tailscale up --login-server={server_url} --exit-node={node_name}',
          category: CommandCategory.routing,
          tags: ['exit-node', 'routing', 'spécifique', 'serveur'],
          type: CommandType.dynamic,
          isDynamic: true,
          parameters: [
            CommandParameter(
              id: 'server_url',
              label: l10n.t('URL du serveur Headscale', 'Headscale server URL', 'Headscale 服务器 URL'),
              description: l10n.t('URL de votre serveur Headscale', 'Your Headscale server URL', '你的 Headscale 服务器 URL'),
              type: ParameterType.text,
              placeholder: 'https://headscale.example.com',
              required: true,
            ),
            CommandParameter(
              id: 'node_name',
              label: l10n.t('Nœud de sortie', 'Exit node', '出口节点'),
              description: l10n.t('Sélectionnez un nœud de sortie disponible', 'Select an available exit node', '选择可用的出口节点'),
              type: ParameterType.nodeSelect,
              options: exitNodes.map((n) => n.name).toList(),
            ),
          ],
        ),
      );
    }

    // Commandes pour ping vers des nœuds spécifiques
    if (nodes.isNotEmpty) {
      commands.add(
        ClientCommand(
          id: 'ping_specific_node',
          title: l10n.t('Ping vers un nœud spécifique', 'Ping a specific node', 'Ping 指定节点'),
          description: l10n.t('Tester la connectivité vers un nœud du réseau', 'Test connectivity to a network node', '测试到网络节点的连通性'),
          windowsCommand: 'tailscale ping {node_ip}',
          linuxCommand: 'tailscale ping {node_ip}',
          category:
              CommandCategory.troubleshooting,
          tags: ['ping', 'test', 'spécifique'],
          type: CommandType.dynamic,
          isDynamic: true,
          parameters: [
            CommandParameter(
              id: 'node_ip',
              label: l10n.t('Nœud cible', 'Target node', '目标节点'),
              description: l10n.t('Sélectionnez un nœud à tester', 'Select a node to test', '选择要测试的节点'),
              type: ParameterType.nodeSelect,
              options: nodes
                  .map((n) => n.ipAddresses.first.isNotEmpty
                      ? '${n.name} (${n.ipAddresses.first})'
                      : n.name)
                  .toList(),
            ),
          ],
        ),
      );
    }

    return commands;
  }

  // Générer des commandes basées sur les routes existantes
  static List<ClientCommand> generateRouteBasedCommands(List<Node> nodes,
      {required L10n l10n}) {
    List<ClientCommand> commands = [];

    // Collecter toutes les routes partagées
    final allRoutes = <String>{};
    for (var node in nodes) {
      allRoutes.addAll(node.sharedRoutes);
    }

    if (allRoutes.isNotEmpty) {
      // Commande pour annoncer des routes spécifiques
      commands.add(
        ClientCommand(
          id: 'advertise_specific_routes',
          title: l10n.t('Annoncer des routes spécifiques', 'Advertise specific routes', '通告指定路由'),
          description: l10n.t('Annoncer des routes de sous-réseau personnalisées', 'Advertise custom subnet routes', '通告自定义子网路由'),
          windowsCommand:
              'tailscale up --login-server={server_url} --advertise-routes={routes}',
          linuxCommand:
              'sudo tailscale up --login-server={server_url} --advertise-routes={routes}',
          category: CommandCategory.routing,
          tags: ['routes', 'subnet', 'personnalisé', 'serveur'],
          type: CommandType.dynamic,
          isDynamic: true,
          parameters: [
            CommandParameter(
              id: 'server_url',
              label: l10n.t('URL du serveur Headscale', 'Headscale server URL', 'Headscale 服务器 URL'),
              description: l10n.t('URL de votre serveur Headscale', 'Your Headscale server URL', '你的 Headscale 服务器 URL'),
              type: ParameterType.text,
              placeholder: 'https://headscale.example.com',
              required: true,
            ),
            CommandParameter(
              id: 'routes',
              label: l10n.t('Routes à annoncer', 'Routes to advertise', '待通告路由'),
              description: l10n.t('Entrez les routes séparées par des virgules (ex: 192.168.1.0/24,10.0.0.0/8)', 'Enter routes separated by commas (e.g. 192.168.1.0/24,10.0.0.0/8)', '输入以逗号分隔的路由（例如 192.168.1.0/24,10.0.0.0/8）'),
              type: ParameterType.text,
              placeholder: '192.168.1.0/24,10.0.0.0/8',
              validation:
                  r'^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2})(,\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2})*$',
            ),
          ],
        ),
      );
    }

    return commands;
  }

  // Générer des commandes interactives
  static List<ClientCommand> generateInteractiveCommands({required L10n l10n}) {
    return [
      // Configuration personnalisée complète
      ClientCommand(
        id: 'custom_setup',
        title: l10n.t('Configuration personnalisée', 'Custom Setup', '自定义配置'),
        description: l10n.t('Configuration complète avec paramètres personnalisés', 'Full setup with custom parameters', '使用自定义参数的完整配置'),
        windowsCommand:
            'tailscale up --login-server={server_url} --hostname={hostname} {additional_params}',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --hostname={hostname} {additional_params}',
        category: CommandCategory.configuration,
        tags: ['configuration', 'personnalisé', 'complet'],
        type: CommandType.interactive,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: l10n.t('URL du serveur', 'Server URL', '服务器 URL'),
            description: l10n.t('URL de votre serveur Headscale', 'Your Headscale server URL', '你的 Headscale 服务器 URL'),
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
          ),
          CommandParameter(
            id: 'hostname',
            label: l10n.t('Nom d\'hôte', 'Hostname', '主机名'),
            description: l10n.t('Nom personnalisé pour ce nœud', 'Custom name for this node', '此节点的自定义名称'),
            type: ParameterType.text,
            placeholder: 'mon-ordinateur',
            required: false,
          ),
          CommandParameter(
            id: 'accept_routes',
            label: l10n.t('Accepter les routes', 'Accept routes', '接受路由'),
            description: l10n.t('Accepter les routes annoncées par d\'autres nœuds', 'Accept routes advertised by other nodes', '接受其他节点通告的路由'),
            type: ParameterType.boolean,
            defaultValue: 'false',
          ),
          CommandParameter(
            id: 'advertise_exit_node',
            label: l10n.t('Devenir nœud de sortie', 'Become exit node', '成为出口节点'),
            description: l10n.t('Configurer ce nœud comme point de sortie Internet', 'Configure this node as an Internet exit point', '将此节点配置为互联网出口节点'),
            type: ParameterType.boolean,
            defaultValue: 'false',
          ),
          CommandParameter(
            id: 'enable_ssh',
            label: l10n.t('Activer SSH', 'Enable SSH', '启用 SSH'),
            description: l10n.t('Activer l\'accès SSH via Tailscale', 'Enable SSH access via Tailscale', '启用通过 Tailscale 的 SSH 访问'),
            type: ParameterType.boolean,
            defaultValue: 'false',
          ),
        ],
      ),

      // Commande de routage avancé
      ClientCommand(
        id: 'advanced_routing',
        title: l10n.t('Configuration de routage avancée', 'Advanced routing configuration', '高级路由配置'),
        description: l10n.t('Configuration avancée des routes et du routage', 'Advanced route and routing configuration', '路由与转发的高级配置'),
        windowsCommand:
            'tailscale up --login-server={server_url} --advertise-routes={routes} {exit_node_param} {accept_routes_param}',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --advertise-routes={routes} {exit_node_param} {accept_routes_param}',
        category: CommandCategory.routing,
        tags: ['routing', 'avancé', 'personnalisé', 'serveur'],
        type: CommandType.interactive,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: l10n.t('URL du serveur Headscale', 'Headscale server URL', 'Headscale 服务器 URL'),
            description: l10n.t('URL de votre serveur Headscale', 'Your Headscale server URL', '你的 Headscale 服务器 URL'),
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
          CommandParameter(
            id: 'routes',
            label: l10n.t('Routes à annoncer', 'Routes to advertise', '待通告路由'),
            description: l10n.t('Routes de sous-réseau à partager', 'Subnet routes to share', '要分享的子网路由'),
            type: ParameterType.text,
            placeholder: '192.168.1.0/24,10.0.0.0/8',
            required: false,
          ),
          CommandParameter(
            id: 'use_exit_node',
            label: l10n.t('Utiliser comme nœud de sortie', 'Use as exit node', '用作出口节点'),
            description: l10n.t('Configurer ce nœud pour router le trafic Internet', 'Configure this node to route Internet traffic', '将此节点配置为转发互联网流量'),
            type: ParameterType.boolean,
            defaultValue: 'false',
          ),
          CommandParameter(
            id: 'accept_routes',
            label: l10n.t('Accepter les routes', 'Accept routes', '接受路由'),
            description: l10n.t('Accepter les routes des autres nœuds', 'Accept routes from other nodes', '接受其他节点的路由'),
            type: ParameterType.boolean,
            defaultValue: 'true',
          ),
        ],
      ),
    ];
  }

  // Générer toutes les commandes (statiques + dynamiques)
  static List<ClientCommand> generateAllCommands({
    String? serverUrl,
    List<Node>? nodes,
    List<PreAuthKey>? authKeys,
    List<User>? users,
    required L10n l10n,
  }) {
    List<ClientCommand> allCommands = [];

    // Commandes statiques de base
    allCommands.addAll(_getStaticCommands(l10n: l10n));

    // Commandes basées sur le serveur
    if (serverUrl != null) {
      allCommands.addAll(generateServerBasedCommands(serverUrl, l10n: l10n));
    }

    // Commandes basées sur les nœuds
    if (nodes != null && nodes.isNotEmpty) {
      allCommands.addAll(generateNodeBasedCommands(nodes, l10n: l10n));
      allCommands.addAll(generateRouteBasedCommands(nodes, l10n: l10n));
    }

    // Commandes interactives
    allCommands.addAll(generateInteractiveCommands(l10n: l10n));

    return allCommands;
  }

  // Commandes statiques de base
  static List<ClientCommand> _getStaticCommands({required L10n l10n}) {
    return [
      // WEB UI
      ClientCommand(
        id: 'web_ui',
        title:
            l10n.t("Ouvrir l'interface web locale", "Open local web interface", '打开本地 Web 界面'),
        description: l10n.t("Ouvre l'interface web locale du client Tailscale pour voir les pairs et le statut (si supporté par le client).", "Opens the local Tailscale client web interface to view peers and status (if supported by the client).", '打开 Tailscale 客户端的本地 Web 界面，查看对端与状态（取决于客户端是否支持）。'),
        windowsCommand: 'tailscale web',
        linuxCommand: 'tailscale web',
        category: CommandCategory.monitoring,
        tags: ['web', 'ui', 'interface', 'monitoring'],
        notes: l10n.t("Cette commande peut ouvrir un navigateur directement ou afficher une URL à copier.", "This command may open a browser directly or display a URL to copy.", '该命令可能直接打开浏览器，或显示一个可复制的 URL。'),
      ),

      // SERVE
      ClientCommand(
        id: 'serve',
        title: l10n.t("Exposer un service (Serve)", "Expose a service (Serve)", '暴露服务（Serve）'),
        description: l10n.t("Partage un service local (ex: serveur web) sur le réseau Tailscale.", "Shares a local service (e.g., web server) on the Tailscale network.", '把本地服务（例如 Web 服务器）共享到 Tailscale 网络。'),
        windowsCommand: 'tailscale serve {protocol} /{port}',
        linuxCommand: 'tailscale serve {protocol} /{port}',
        category: CommandCategory.routing,
        tags: ['serve', 'proxy', 'https', 'tcp'],
        type: CommandType.interactive,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'protocol',
            label: l10n.t('Protocole', 'Protocol', '协议'),
            description: l10n.t('Protocole à utiliser (https, http, tcp). Par défaut https.', 'Protocol to use (https, http, tcp). Default is https.', '要使用的协议（https、http、tcp）。默认 https。'),
            type: ParameterType.text,
            defaultValue: 'https',
            options: ['https', 'http', 'tcp'],
            required: false,
          ),
          CommandParameter(
            id: 'port',
            label: l10n.t('Port local du service', 'Local service port', '服务本地端口'),
            description: l10n.t('Le port sur lequel votre service écoute en local.', 'The port your service is listening on locally.', '你的服务在本地监听的端口。'),
            type: ParameterType.number,
            placeholder: '80, 3000, 8080...',
            required: true,
          ),
        ],
      ),

      // FILE
      ClientCommand(
        id: 'file_cp',
        title:
            l10n.t("Envoyer un fichier (Taildrop)", "Send a file (Taildrop)", '发送文件（Taildrop）'),
        description: l10n.t("Envoyer un fichier à une autre de vos machines.", "Send a file to another of your machines.", '把文件发送到你的另一台设备。'),
        windowsCommand: 'tailscale file cp {filepath} {target_node}:',
        linuxCommand: 'tailscale file cp {filepath} {target_node}:',
        category: CommandCategory.maintenance,
        tags: ['file', 'taildrop', 'send', 'cp'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'filepath',
            label: l10n.t('Chemin du fichier', 'File path', '文件路径'),
            description: l10n.t('Chemin complet du fichier à envoyer.', 'Full path of the file to send.', '要发送的文件的完整路径。'),
            type: ParameterType.text,
            placeholder: 'C:\\Users\\...\\report.pdf ou /home/.../report.pdf',
            required: true,
          ),
          CommandParameter(
            id: 'target_node',
            label: l10n.t('Machine de destination', 'Target machine', '目标设备'),
            description: l10n.t('Le nom ou l\'IP de la machine à qui envoyer le fichier.', 'The name or IP of the machine to send the file to.', '要发送文件的设备名称或 IP。'),
            type: ParameterType.nodeSelect,
            required: true,
          ),
        ],
      ),
      ClientCommand(
        id: 'file_get',
        title: l10n.t("Recevoir des fichiers (Taildrop)", "Receive files (Taildrop)", '接收文件（Taildrop）'),
        description: l10n.t("Vérifier et recevoir les fichiers en attente de réception.", "Check for and receive incoming files.", '检查并接收待接收的文件。'),
        windowsCommand: 'tailscale file get',
        linuxCommand: 'tailscale file get',
        category: CommandCategory.maintenance,
        tags: ['file', 'taildrop', 'get', 'receive'],
      ),

      // DEBUG
      ClientCommand(
        id: 'debug_derp',
        title:
            l10n.t("Debug: Statut des relais DERP", "Debug: DERP relay status", '调试：DERP 中继状态'),
        description: l10n.t("Affiche la latence des serveurs relais DERP.", "Displays latency to DERP relay servers.", '显示 DERP 中继服务器的延迟。'),
        windowsCommand: 'tailscale debug derp',
        linuxCommand: 'tailscale debug derp',
        category:
            CommandCategory.troubleshooting,
        tags: ['debug', 'derp', 'relay', 'latency'],
      ),

      // UP FLAGS
      ClientCommand(
        id: 'force_reauth',
        title:
            l10n.t("Forcer la ré-authentification", "Force re-authentication", '强制重新认证'),
        description: l10n.t("Force une nouvelle authentification du client.", "Forces client re-authentication.", '强制客户端重新认证。'),
        windowsCommand: 'tailscale up --force-reauth',
        linuxCommand: 'sudo tailscale up --force-reauth',
        category: CommandCategory.connection,
        tags: ['up', 'reauth', 'login'],
      ),
      ClientCommand(
        id: 'shields_up',
        title: l10n.t("Activer 'Shields Up'", "Enable 'Shields Up'", '启用「Shields Up」'),
        description: l10n.t("Bloque toutes les connexions entrantes, même depuis votre réseau Tailscale.", "Blocks all incoming connections, even from your Tailscale network.", '阻止所有传入连接，包括来自 Tailscale 网络的连接。'),
        windowsCommand: 'tailscale up --shields-up',
        linuxCommand: 'sudo tailscale up --shields-up',
        category: CommandCategory.security,
        tags: ['up', 'firewall', 'shields', 'security'],
      ),
      ClientCommand(
        id: 'exit_node_allow_lan',
        title: l10n.t("Autoriser l'accès LAN en mode Exit Node", "Allow LAN access in Exit Node mode", '在出口节点模式下允许局域网访问'),
        description: l10n.t("Permet à la machine d'accéder à son propre réseau local physique tout en utilisant un exit node.", "Allows the machine to access its own physical LAN while using an exit node.", '在使用出口节点时，仍允许本机访问其所在的物理局域网。'),
        windowsCommand: 'tailscale up --exit-node-allow-lan-access=true',
        linuxCommand: 'sudo tailscale up --exit-node-allow-lan-access=true',
        category: CommandCategory.routing,
        tags: ['up', 'exit-node', 'lan', 'routing'],
      ),

      // CONNEXION
      ClientCommand(
        id: 'connect_basic',
        title: l10n.t('Connexion simple', 'Simple connection', '简单连接'),
        description: l10n.t('Se connecter à Tailscale en spécifiant un serveur Headscale', 'Connect to Tailscale specifying a Headscale server', '连接 Tailscale 并指定 Headscale 服务器'),
        windowsCommand: 'tailscale up --login-server={server_url}',
        linuxCommand: 'sudo tailscale up --login-server={server_url}',
        category: CommandCategory.connection,
        tags: ['connexion', 'up', 'simple', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: l10n.t('URL du serveur Headscale', 'Headscale server URL', 'Headscale 服务器 URL'),
            description: l10n.t('Entrez l\'URL de votre serveur Headscale', 'Enter your Headscale server URL', '输入你的 Headscale 服务器 URL'),
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'connect_with_authkey',
        title: l10n.t('Connexion avec clé d\'authentification', 'Connection with auth key', '使用认证密钥连接'),
        description: l10n.t('Se connecter à un serveur Headscale avec une clé pré-authentifiée', 'Connect to a Headscale server with a pre-auth key', '使用预认证密钥连接到 Headscale 服务器'),
        windowsCommand:
            'tailscale up --login-server={server_url} --authkey={authkey}',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --authkey={authkey}',
        category: CommandCategory.connection,
        tags: ['connexion', 'up', 'authkey', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: l10n.t('URL du serveur Headscale', 'Headscale server URL', 'Headscale 服务器 URL'),
            description: l10n.t('Entrez l\'URL de votre serveur Headscale', 'Enter your Headscale server URL', '输入你的 Headscale 服务器 URL'),
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
          CommandParameter(
            id: 'authkey',
            label: l10n.t('Clé d\'authentification', 'Auth key', '认证密钥'),
            description: l10n.t('Entrez votre clé pré-authentifiée', 'Enter your pre-auth key', '输入你的预认证密钥'),
            type: ParameterType.text,
            placeholder:
              'nodekey-xxxxx 或 tskey-xxxxx',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'connect_with_routes',
        title: l10n.t('Connexion avec routes personnalisées', 'Connection with custom routes', '使用自定义路由连接'),
        description: l10n.t('Se connecter en annonçant des routes spécifiques', 'Connect while advertising specific routes', '连接并通告指定路由'),
        windowsCommand:
            'tailscale up --login-server={server_url} --advertise-routes={routes}',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --advertise-routes={routes}',
        category: CommandCategory.connection,
        tags: ['connexion', 'up', 'routes', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: l10n.t('URL du serveur Headscale', 'Headscale server URL', 'Headscale 服务器 URL'),
            description: l10n.t('Entrez l\'URL de votre serveur Headscale', 'Enter your Headscale server URL', '输入你的 Headscale 服务器 URL'),
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
          CommandParameter(
            id: 'routes',
            label: l10n.t('Routes à annoncer', 'Routes to advertise', '待通告路由'),
            description: l10n.t('Entrez les routes séparées par des virgules', 'Enter routes separated by commas', '输入以逗号分隔的路由'),
            type: ParameterType.text,
            placeholder: '192.168.1.0/24,10.0.0.0/8',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'disconnect',
        title: l10n.t('Déconnexion', 'Disconnect', '断开连接'),
        description: l10n.t('Se déconnecter du réseau Headscale', 'Disconnect from Headscale network', '断开与 Headscale 网络的连接'),
        windowsCommand: 'tailscale down',
        linuxCommand: 'sudo tailscale down',
        category: CommandCategory.connection,
        tags: ['déconnexion', 'down'],
      ),

      ClientCommand(
        id: 'logout',
        title: l10n.t('Déconnexion complète', 'Full logout', '完全注销'),
        description: l10n.t('Se déconnecter et supprimer les informations d\'authentification', 'Disconnect and remove authentication info', '断开连接并删除认证信息'),
        windowsCommand: 'tailscale logout',
        linuxCommand: 'sudo tailscale logout',
        category: CommandCategory.connection,
        tags: ['logout', 'reset'],
      ),

      // SURVEILLANCE
      ClientCommand(
        id: 'status',
        title: l10n.t('Statut de connexion', 'Connection status', '连接状态'),
        description: l10n.t('Afficher le statut actuel de Tailscale', 'Show current Tailscale status', '显示 Tailscale 当前状态'),
        windowsCommand: 'tailscale status',
        linuxCommand: 'tailscale status',
        category: CommandCategory.monitoring,
        tags: ['status', 'info'],
      ),

      ClientCommand(
        id: 'ip_info',
        title: l10n.t('Informations IP', 'IP Information', 'IP 信息'),
        description: l10n.t('Afficher l\'adresse IP Tailscale', 'Show Tailscale IP address', '显示 Tailscale IP 地址'),
        windowsCommand: 'tailscale ip',
        linuxCommand: 'tailscale ip',
        category: CommandCategory.monitoring,
        tags: ['ip', 'address'],
      ),

      ClientCommand(
        id: 'netcheck',
        title:
            l10n.t('Test de connectivité réseau', 'Network connectivity test', '网络连通性测试'),
        description: l10n.t('Tester la connectivité réseau et les performances', 'Test network connectivity and performance', '测试网络连通性和性能'),
        windowsCommand: 'tailscale netcheck',
        linuxCommand: 'tailscale netcheck',
        category:
            CommandCategory.troubleshooting,
        tags: ['network', 'test', 'connectivity'],
      ),

      // CONFIGURATION
      ClientCommand(
        id: 'accept_routes',
        title: l10n.t('Accepter les routes', 'Accept routes', '接受路由'),
        description: l10n.t('Accepter les routes annoncées par d\'autres nœuds', 'Accept routes advertised by other nodes', '接受其他节点通告的路由'),
        windowsCommand:
            'tailscale up --login-server={server_url} --accept-routes',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --accept-routes',
        category: CommandCategory.configuration,
        tags: ['routes', 'accept', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: l10n.t('URL du serveur Headscale', 'Headscale server URL', 'Headscale 服务器 URL'),
            description: l10n.t('Nécessaire pour s\'assurer que la commande est appliquée au bon réseau', 'Required to ensure command applies to the correct network', '用于确保命令作用在正确的网络'),
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'disable_key_expiry',
        title: l10n.t('Désactiver expiration clé', 'Disable key expiry', '禁用密钥过期'),
        description: l10n.t('Empêcher l\'expiration automatique de la clé', 'Prevent automatic key expiration', '防止密钥自动过期'),
        windowsCommand: 'tailscale up --login-server={server_url} --timeout=0',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --timeout=0',
        category: CommandCategory.configuration,
        tags: ['key', 'expiry', 'timeout', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: l10n.t('URL du serveur Headscale', 'Headscale server URL', 'Headscale 服务器 URL'),
            description: l10n.t('Nécessaire pour s\'assurer que la commande est appliquée au bon réseau', 'Required to ensure command applies to the correct network', '用于确保命令作用在正确的网络'),
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      // SÉCURITÉ
      ClientCommand(
        id: 'enable_ssh',
        title: l10n.t('Activer SSH Tailscale', 'Enable Tailscale SSH', '启用 Tailscale SSH'),
        description: l10n.t('Activer l\'accès SSH via Tailscale', 'Enable SSH access via Tailscale', '启用通过 Tailscale 的 SSH 访问'),
        windowsCommand: 'tailscale up --login-server={server_url} --ssh',
        linuxCommand: 'sudo tailscale up --login-server={server_url} --ssh',
        category: CommandCategory.security,
        tags: ['ssh', 'remote', 'serveur'],
        requiresElevation: true,
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: l10n.t('URL du serveur Headscale', 'Headscale server URL', 'Headscale 服务器 URL'),
            description: l10n.t('Nécessaire pour s\'assurer que la commande est appliquée au bon réseau', 'Required to ensure command applies to the correct network', '用于确保命令作用在正确的网络'),
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'disable_ssh',
        title: l10n.t('Désactiver SSH Tailscale', 'Disable Tailscale SSH', '禁用 Tailscale SSH'),
        description: l10n.t('Désactiver l\'accès SSH via Tailscale', 'Disable SSH access via Tailscale', '禁用通过 Tailscale 的 SSH 访问'),
        windowsCommand: 'tailscale up --login-server={server_url} --ssh=false',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --ssh=false',
        category: CommandCategory.security,
        tags: ['ssh', 'disable', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: l10n.t('URL du serveur Headscale', 'Headscale server URL', 'Headscale 服务器 URL'),
            description: l10n.t('Nécessaire pour s\'assurer que la commande est appliquée au bon réseau', 'Required to ensure command applies to the correct network', '用于确保命令作用在正确的网络'),
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      // MAINTENANCE
      ClientCommand(
        id: 'update',
        title: l10n.t('Mettre à jour Tailscale', 'Update Tailscale', '更新 Tailscale'),
        description: l10n.t('Mettre à jour vers la dernière version', 'Update to the latest version', '更新到最新版本'),
        windowsCommand: 'tailscale update',
        linuxCommand: 'sudo tailscale update',
        category: CommandCategory.maintenance,
        tags: ['update', 'upgrade'],
        requiresElevation: true,
      ),

      ClientCommand(
        id: 'version',
        title: l10n.t('Version Tailscale', 'Tailscale Version', 'Tailscale 版本'),
        description:
            l10n.t('Afficher la version installée', 'Show installed version', '显示已安装版本'),
        windowsCommand: 'tailscale version',
        linuxCommand: 'tailscale version',
        category: CommandCategory.maintenance,
        tags: ['version', 'info'],
      ),

      ClientCommand(
        id: 'bugreport',
        title: l10n.t('Rapport de bug', 'Bug report', '缺陷报告'),
        description: l10n.t('Générer un rapport de diagnostic', 'Generate a diagnostic report', '生成诊断报告'),
        windowsCommand: 'tailscale bugreport',
        linuxCommand: 'sudo tailscale bugreport',
        category:
            CommandCategory.troubleshooting,
        tags: ['bug', 'diagnostic', 'support'],
      ),

      // LINUX SPÉCIFIQUES
      ClientCommand(
        id: 'enable_ip_forwarding',
        title: l10n.t('Activer IP forwarding (Linux)', 'Enable IP forwarding (Linux)', '启用 IP 转发（Linux）'),
        description: l10n.t('Activer le transfert IP pour le routage de sous-réseau', 'Enable IP forwarding for subnet routing', '启用 IP 转发以支持子网路由'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand:
            'echo \'net.ipv4.ip_forward = 1\' | sudo tee -a /etc/sysctl.conf && echo \'net.ipv6.conf.all.forwarding = 1\' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p',
        category: CommandCategory.configuration,
        tags: ['linux', 'forwarding', 'routing'],
        requiresElevation: true,
        notes: l10n.t('Requis sur Linux pour annoncer des routes de sous-réseau', 'Required on Linux to advertise subnet routes', 'Linux 上通告子网路由所必需'),
      ),

      ClientCommand(
        id: 'install_tailscale_debian',
        title: l10n.t('Installer Tailscale (Debian/Ubuntu)', 'Install Tailscale (Debian/Ubuntu)', '安装 Tailscale（Debian/Ubuntu）'),
        description: l10n.t('Installer Tailscale sur les systèmes basés sur Debian', 'Install Tailscale on Debian-based systems', '在基于 Debian 的系统上安装 Tailscale'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand: 'curl -fsSL https://tailscale.com/install.sh | sh',
        category: CommandCategory.maintenance,
        tags: ['linux', 'install', 'debian', 'ubuntu'],
        requiresElevation: true,
        notes: l10n.t('Installation automatique pour Debian, Ubuntu et dérivés', 'Automatic installation for Debian, Ubuntu and derivatives', 'Debian、Ubuntu 及衍生版自动安装'),
      ),

      ClientCommand(
        id: 'install_tailscale_rhel',
        title: l10n.t('Installer Tailscale (RHEL/CentOS/Fedora)', 'Install Tailscale (RHEL/CentOS/Fedora)', '安装 Tailscale（RHEL/CentOS/Fedora）'),
        description: l10n.t('Installer Tailscale sur les systèmes Red Hat', 'Install Tailscale on Red Hat systems', '在 Red Hat 系统上安装 Tailscale'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand:
            'sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/8/tailscale.repo && sudo dnf install tailscale',
        category: CommandCategory.maintenance,
        tags: ['linux', 'install', 'rhel', 'centos', 'fedora'],
        requiresElevation: true,
        notes: l10n.t('Installation pour Red Hat Enterprise Linux, CentOS, Fedora', 'Installation for Red Hat Enterprise Linux, CentOS, Fedora', '在 Red Hat Enterprise Linux、CentOS、Fedora 上安装'),
      ),

      ClientCommand(
        id: 'install_tailscale_arch',
        title: l10n.t('Installer Tailscale (Arch Linux)', 'Install Tailscale (Arch Linux)', '安装 Tailscale（Arch Linux）'),
        description: l10n.t('Installer Tailscale sur Arch Linux', 'Install Tailscale on Arch Linux', '在 Arch Linux 上安装 Tailscale'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand: 'sudo pacman -S tailscale',
        category: CommandCategory.maintenance,
        tags: ['linux', 'install', 'arch'],
        requiresElevation: true,
        notes: l10n.t('Installation via le gestionnaire de paquets pacman', 'Installation via pacman package manager', '通过 pacman 包管理器安装'),
      ),

      ClientCommand(
        id: 'enable_tailscale_service',
        title: l10n.t('Activer le service Tailscale (Linux)', 'Enable Tailscale service (Linux)', '启用 Tailscale 服务（Linux）'),
        description: l10n.t('Activer et démarrer le service Tailscale au boot', 'Enable and start Tailscale service at boot', '开机时启用并启动 Tailscale 服务'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand: 'sudo systemctl enable --now tailscaled',
        category: CommandCategory.configuration,
        tags: ['linux', 'service', 'systemd'],
        requiresElevation: true,
        notes: l10n.t('Active le démon Tailscale et le démarre automatiquement', 'Enables Tailscale daemon and starts it automatically', '启用 Tailscale 守护进程并自动启动'),
      ),

      ClientCommand(
        id: 'check_tailscale_service',
        title: l10n.t('Vérifier le service Tailscale (Linux)', 'Check Tailscale service (Linux)', '检查 Tailscale 服务（Linux）'),
        description: l10n.t('Vérifier le statut du service Tailscale', 'Check Tailscale service status', '检查 Tailscale 服务状态'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand: 'sudo systemctl status tailscaled',
        category:
            CommandCategory.troubleshooting,
        tags: ['linux', 'service', 'status'],
        requiresElevation: false,
        notes: l10n.t('Affiche l\'état du démon Tailscale', 'Shows Tailscale daemon status', '显示 Tailscale 守护进程状态'),
      ),

      ClientCommand(
        id: 'restart_tailscale_service',
        title: l10n.t('Redémarrer le service Tailscale (Linux)', 'Restart Tailscale service (Linux)', '重启 Tailscale 服务（Linux）'),
        description:
            l10n.t('Redémarrer le démon Tailscale', 'Restart Tailscale daemon', '重启 Tailscale 守护进程'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand: 'sudo systemctl restart tailscaled',
        category:
            CommandCategory.troubleshooting,
        tags: ['linux', 'service', 'restart'],
        requiresElevation: true,
        notes: l10n.t('Redémarre le service en cas de problème', 'Restarts the service in case of issues', '出现问题时重启服务'),
      ),

      ClientCommand(
        id: 'check_firewall_ufw',
        title: l10n.t('Configurer UFW pour Tailscale (Linux)', 'Configure UFW for Tailscale (Linux)', '为 Tailscale 配置 UFW（Linux）'),
        description: l10n.t('Configurer le pare-feu UFW pour autoriser Tailscale', 'Configure UFW firewall to allow Tailscale', '配置 UFW 防火墙以允许 Tailscale'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand:
            'sudo ufw allow in on tailscale0 && sudo ufw allow out on tailscale0',
        category: CommandCategory.security,
        tags: ['linux', 'firewall', 'ufw'],
        requiresElevation: true,
        notes: l10n.t('Configure UFW pour autoriser le trafic Tailscale', 'Configures UFW to allow Tailscale traffic', '配置 UFW 以允许 Tailscale 流量'),
      ),

      ClientCommand(
        id: 'check_firewall_iptables',
        title: l10n.t('Configurer iptables pour Tailscale (Linux)', 'Configure iptables for Tailscale (Linux)', '为 Tailscale 配置 iptables（Linux）'),
        description: l10n.t('Configurer iptables pour autoriser Tailscale', 'Configure iptables to allow Tailscale', '配置 iptables 以允许 Tailscale'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand:
            'sudo iptables -I INPUT -i tailscale0 -j ACCEPT && sudo iptables -I FORWARD -i tailscale0 -j ACCEPT && sudo iptables -I FORWARD -o tailscale0 -j ACCEPT',
        category: CommandCategory.security,
        tags: ['linux', 'firewall', 'iptables'],
        requiresElevation: true,
        notes: l10n.t('Configure iptables pour autoriser le trafic Tailscale', 'Configures iptables to allow Tailscale traffic', '配置 iptables 以允许 Tailscale 流量'),
      ),

      ClientCommand(
        id: 'setup_subnet_router_linux',
        title: l10n.t('Configurer routeur de sous-réseau (Linux)', 'Configure subnet router (Linux)', '配置子网路由（Linux）'),
        description: l10n.t('Configuration complète pour devenir un routeur de sous-réseau', 'Full configuration to become a subnet router', '成为子网路由器的完整配置'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand:
            'echo \'net.ipv4.ip_forward = 1\' | sudo tee -a /etc/sysctl.conf && echo \'net.ipv6.conf.all.forwarding = 1\' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p && sudo tailscale up --login-server={server_url} --advertise-routes=192.168.1.0/24 --accept-routes',
        category: CommandCategory.routing,
        tags: ['linux', 'subnet', 'router', 'forwarding', 'serveur'],
        requiresElevation: true,
        notes: l10n.t('Active le forwarding IP et configure le routage de sous-réseau. Remplacez les routes par les vôtres.', 'Enables IP forwarding and configures subnet routing. Replace routes with yours.', '启用 IP 转发并配置子网路由。请替换为你自己的路由。'),
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: l10n.t('URL du serveur Headscale', 'Headscale server URL', 'Headscale 服务器 URL'),
            description: l10n.t('URL de votre serveur Headscale', 'Your Headscale server URL', '你的 Headscale 服务器 URL'),
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'check_tailscale_logs',
        title: l10n.t('Consulter les logs Tailscale (Linux)', 'View Tailscale logs (Linux)', '查看 Tailscale 日志（Linux）'),
        description: l10n.t('Afficher les logs du service Tailscale', 'Show logs of Tailscale service', '显示 Tailscale 服务日志'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand: 'sudo journalctl -u tailscaled -f',
        category:
            CommandCategory.troubleshooting,
        tags: ['linux', 'logs', 'debug'],
        requiresElevation: false,
        notes: l10n.t('Affiche les logs en temps réel du démon Tailscale', 'Shows real-time logs of the Tailscale daemon', '实时显示 Tailscale 守护进程日志'),
      ),

      ClientCommand(
        id: 'uninstall_tailscale_debian',
        title: l10n.t('Désinstaller Tailscale (Debian/Ubuntu)', 'Uninstall Tailscale (Debian/Ubuntu)', '卸载 Tailscale（Debian/Ubuntu）'),
        description: l10n.t('Désinstaller complètement Tailscale', 'Uninstall Tailscale completely', '完全卸载 Tailscale'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand: 'sudo apt remove tailscale && sudo apt purge tailscale',
        category: CommandCategory.maintenance,
        tags: ['linux', 'uninstall', 'debian', 'ubuntu'],
        requiresElevation: true,
        notes: l10n.t('Supprime Tailscale et ses fichiers de configuration', 'Removes Tailscale and its configuration files', '卸载 Tailscale 及其配置文件'),
      ),

      ClientCommand(
        id: 'backup_tailscale_config',
        title: l10n.t('Sauvegarder la configuration Tailscale (Linux)', 'Backup Tailscale configuration (Linux)', '备份 Tailscale 配置（Linux）'),
        description: l10n.t('Sauvegarder les fichiers de configuration Tailscale', 'Backup Tailscale configuration files', '备份 Tailscale 配置文件'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand:
            'sudo tar -czf ~/tailscale-backup-\$(date +%Y%m%d).tar.gz /var/lib/tailscale/',
        category: CommandCategory.maintenance,
        tags: ['linux', 'backup', 'configuration'],
        requiresElevation: true,
        notes: l10n.t('Crée une archive de sauvegarde dans le répertoire home', 'Creates a backup archive in the home directory', '在 home 目录中创建备份归档'),
      ),

      ClientCommand(
        id: 'check_network_interfaces',
        title: l10n.t('Vérifier les interfaces réseau (Linux)', 'Check network interfaces (Linux)', '检查网络接口（Linux）'),
        description: l10n.t('Afficher toutes les interfaces réseau incluant Tailscale', 'Show all network interfaces including Tailscale', '显示包括 Tailscale 在内的所有网络接口'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand:
            'ip addr show && echo "--- Routes Tailscale ---" && ip route show table 52',
        category:
            CommandCategory.troubleshooting,
        tags: ['linux', 'network', 'interfaces'],
        requiresElevation: false,
        notes: l10n.t('Affiche les interfaces et les routes Tailscale', 'Shows interfaces and Tailscale routes', '显示 Tailscale 接口与路由'),
      ),

      ClientCommand(
        id: 'setup_exit_node_linux',
        title: l10n.t('Configurer nœud de sortie (Linux)', 'Configure exit node (Linux)', '配置出口节点（Linux）'),
        description: l10n.t('Configuration complète pour devenir un nœud de sortie', 'Full configuration to become an exit node', '成为出口节点的完整配置'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand:
            'echo \'net.ipv4.ip_forward = 1\' | sudo tee -a /etc/sysctl.conf && echo \'net.ipv6.conf.all.forwarding = 1\' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p && sudo tailscale up --login-server={server_url} --advertise-exit-node',
        category: CommandCategory.routing,
        tags: ['linux', 'exit-node', 'forwarding', 'serveur'],
        requiresElevation: true,
        notes: l10n.t('Active le forwarding et configure ce nœud comme point de sortie Internet', 'Enables forwarding and configures this node as an Internet exit point', '启用转发并将此节点配置为互联网出口节点'),
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: l10n.t('URL du serveur Headscale', 'Headscale server URL', 'Headscale 服务器 URL'),
            description: l10n.t('URL de votre serveur Headscale', 'Your Headscale server URL', '你的 Headscale 服务器 URL'),
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'configure_dns_linux',
        title: l10n.t('Configurer DNS Tailscale (Linux)', 'Configure Tailscale DNS (Linux)', '配置 Tailscale DNS（Linux）'),
        description: l10n.t('Configurer la résolution DNS via Tailscale', 'Configure DNS resolution via Tailscale', '通过 Tailscale 配置 DNS 解析'),
        windowsCommand: 'echo "Non applicable sur Windows"',
        isWindowsSupported: false,
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --accept-dns=true',
        category: CommandCategory.configuration,
        tags: ['linux', 'dns', 'resolution', 'serveur'],
        requiresElevation: true,
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: l10n.t('URL du serveur Headscale', 'Headscale server URL', 'Headscale 服务器 URL'),
            description: l10n.t('URL de votre serveur Headscale', 'Your Headscale server URL', '你的 Headscale 服务器 URL'),
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),
    ];
  }
}
