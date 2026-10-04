import 'package:flutter/material.dart';
import 'package:headscalemanager/l10n/l10n.dart';
import 'package:headscalemanager/screens/client_commands_screen.dart';
import 'package:headscalemanager/widgets/whats_new_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

/// Écran d'aide de l'application.
///
/// Fournit des informations sur les prérequis, l'installation du serveur Headscale,
/// et un guide d'utilisation de l'application page par page.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Builder(builder: (context) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.t('Aide et Guide d\'Utilisation', 'Help and User Guide', '帮助与使用指南'),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.new_releases_rounded,
                            color: Theme.of(context).colorScheme.primary),
                        tooltip: context.l10n.t('Nouveautés', 'What\'s New', '更新日志'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => const WhatsNewDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildBodyText(
                    context,
                    context.l10n.t('Bienvenue dans le guide d\'utilisation de l\'application Headscale Manager !', 'Welcome to the Headscale Manager app user guide!', '欢迎查阅 Headscale Manager 应用使用指南！'),
                  ),
                  const SizedBox(height: 8),
                  _buildBodyText(
                    context,
                    context.l10n.t('Cette application vous permet de gérer facilement votre serveur Headscale. Ce guide vous aidera à configurer votre serveur et à utiliser l\'application.', 'This application allows you to easily manage your Headscale server. This guide will help you configure your server and use the application.', '本应用让你轻松管理 Headscale 服务器。本指南将帮助你配置服务器并使用本应用。'),
                  ),
                  const SizedBox(height: 24),

                  // Carte pour la bibliothèque de commandes
                  _buildCommandsCard(context),
                  const SizedBox(height: 24),

                  // Section API
                  _buildSectionTitle(context, context.l10n.t('Fonctionnement : API', 'How it works: API', '工作原理：API')),
                  _buildInfoCard(context, children: [
                    _buildBodyText(context,
                        context.l10n.t('L\'application utilise des appels directs à l\'API de Headscale pour toutes les opérations de gestion.', 'The application uses direct calls to the Headscale API for all management operations.', '本应用的所有管理操作都直接调用 Headscale API。')),
                    const SizedBox(height: 16),
                    _buildSubTitle(context, context.l10n.t('Actions directes (via API) :', 'Direct Actions (via API):', '直接操作（通过 API）：')),
                    const SizedBox(height: 8),
                    _buildCodeBlock(
                      context,
                      context.l10n.t('Ces actions sont effectuées directement par l\'application :\n'
                      '- Lister les utilisateurs et les nœuds.\n'
                      '- Créer et supprimer des utilisateurs.\n'
                      '- Créer et invalider des clés de pré-authentification.\n'
                      '- Gérer les clés d\'API.\n'
                      '- Déplacer un nœud vers un autre utilisateur.\n'
                      '- Supprimer un nœud.\n'
                      '- Activer/Désactiver les routes (subnets et exit node).', 'These actions are performed directly by the application:\n'
                      '- List users and nodes.\n'
                      '- Create and delete users.\n'
                      '- Create and invalidate pre-authentication keys.\n'
                      '- Manage API keys.\n'
                      '- Move a node to another user.\n'
                      '- Delete a node.\n'
                      '- Enable/Disable routes (subnets and exit node).', '以下操作由应用直接执行：\n- 列出用户与节点。\n- 创建和删除用户。\n- 创建和吊销预认证密钥。\n- 管理 API 密钥。\n- 将节点移动到其他用户。\n- 删除节点。\n- 启用/禁用路由（子网与出口节点）。'),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Section Tutoriel
                  _buildSectionTitle(context,
                      context.l10n.t('Tutoriel : Ajouter un appareil et le configurer', 'Tutorial: Add and configure a device', '教程：添加并配置设备')),
                  _buildInfoCard(context, children: [
                    _buildBodyText(context,
                        context.l10n.t('Voici les étapes complètes pour ajouter un nouvel appareil (nœud) à votre réseau Headscale.', 'Here are the complete steps to add a new device (node) to your Headscale network.', '以下是将新设备（节点）加入 Headscale 网络的完整步骤。')),
                    const SizedBox(height: 16),
                    _buildSubTitle(context, context.l10n.t('Étape 1 : Créer un utilisateur', 'Step 1: Create a user', '第 1 步：创建用户')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Si ce n\'est pas déjà fait, allez dans l\'onglet "Utilisateurs" et créez un nouvel utilisateur (par exemple, "mon-user").', 'If not already done, go to the "Users" tab and create a new user (e.g., "my-user").', '如果还没有用户，请进入「用户」标签页并创建一个新用户（例如「mon-user」）。')),
                    const SizedBox(height: 16),
                    _buildSubTitle(
                        context, context.l10n.t('Étape 2 : Enregistrer l\'appareil', 'Step 2: Register the device', '第 2 步：注册设备')),
                    const SizedBox(height: 8),
                    _buildBodyText(
                        context, context.l10n.t('Il existe deux méthodes principales :', 'There are two main methods:', '主要有两种方法：')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('A) Avec une clé de pré-authentification (Recommandé)', 'A) With a pre-authentication key (Recommended)', 'A) 使用预认证密钥（推荐）'),
                        isBold: true),
                    const SizedBox(height: 4),
                    _buildBodyText(
                      context,
                      context.l10n.t('1. Dans l\'onglet "Utilisateurs", cliquez sur l\'icône de clé et créez une clé pour votre utilisateur. Même si aucune case n\'est cochée, il est nécessaire de mettre 1 jour d\'expiration de la clé pour générer une clé valide.\n'
                      '2. Copiez la commande `tailscale up ...` fournie.\n'
                      '3. Exécutez cette commande sur l\'appareil que vous souhaitez ajouter. Il sera automatiquement enregistré et apparaîtra dans votre tableau de bord.', '1. In the "Users" tab, click the key icon and create a key for your user. Even if no boxes are checked, it is necessary to set a 1-day expiration for the key to generate a valid key.\n'
                      '2. Copy the provided `tailscale up ...` command.\n'
                      '3. Run this command on the device you want to add. It will be automatically registered and will appear on your dashboard.', '1. 在「用户」标签页中，点击密钥图标并为你的用户创建一个密钥。即使没有勾选任何选项，也必须把密钥有效期设为 1 天才能生成有效密钥。\n2. 复制生成的 `tailscale up ...` 命令。\n3. 在要添加的设备上执行该命令。设备会自动注册并出现在仪表盘中。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('B) Enregistrement via l\'application (pour les clients mobiles)', 'B) Registration via the application (for mobile clients)', 'B) 通过应用注册（适用于移动客户端）'),
                        isBold: true),
                    const SizedBox(height: 4),
                    _buildBodyText(
                      context,
                      context.l10n.t('1.  Sur l\'appareil client (iOS/Android) : Dans l\'application Tailscale, allez dans les paramètres, sélectionnez "Use alternate server", et collez l\'URL de votre serveur Headscale.\n'
                      '2.  Dans l\'application Headscale Manager : Après avoir effectué l\'étape 1, le client Tailscale vous fournira une URL d\'enregistrement unique. Dans l\'application Headscale Manager, allez dans les détails de l\'utilisateur, cliquez sur "Enregistrer un nouvel appareil", et collez l\'URL fournie par le client. L\'appareil sera enregistré directement via l\'API.', '1. On the client device (iOS/Android): In the Tailscale app, go to settings, select "Use alternate server", and paste your Headscale server URL.\n'
                      '2. In the Headscale Manager app: After completing step 1, the Tailscale client will provide you with a unique registration URL. In the Headscale Manager app, go to the user details, click "Register a new device", and paste the URL provided by the client. The device will be registered directly via the API.', '1.  在客户端设备（iOS/Android）上：在 Tailscale 应用中进入设置，选择「Use alternate server」，并粘贴你的 Headscale 服务器 URL。\n2.  在 Headscale Manager 应用中：完成第 1 步后，Tailscale 客户端会提供一个唯一的注册 URL。在 Headscale Manager 应用中进入用户详情，点击「注册新设备」，粘贴客户端提供的 URL。设备将通过 API 直接注册。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 16),
                    _buildSubTitle(context,
                        context.l10n.t('Étape 3 (Optionnel) : Renommer le nœud et ajouter des tags', 'Step 3 (Optional): Rename the node and add tags', '第 3 步（选填）：重命名节点并添加标签')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Une fois le nœud apparu dans le tableau de bord, vous pouvez le configurer. C\'est une étape cruciale si vous utilisez les ACLs basées sur les tags.', 'Once the node appears on the dashboard, you can configure it. This is a crucial step if you use tag-based ACLs.', '节点出现在仪表盘后即可进行配置。如果你使用基于标签的 ACL，这一步非常关键。')),
                    const SizedBox(height: 8),
                    _buildBodyText(
                      context,
                      context.l10n.t('1. Allez dans les détails du nœud en cliquant dessus.\n'
                      '2. Utilisez le menu pour le renommer (par exemple, "mon-telephone").\n'
                      '3. Cliquez sur l\'icône de crayon pour modifier les tags. Ajoutez les tags pertinents (par exemple, `tag:user-phone`, `tag:user-laptop`). L\'application mettra à jour les tags directement via l\'API.', '1. Go to the node details by clicking on it.\n'
                      '2. Use the menu to rename it (e.g., "my-phone").\n'
                      '3. Click the pencil icon to edit the tags. Add the relevant tags (e.g., `tag:user-phone`, `tag:user-laptop`). The application will update the tags directly via the API.', '1. 点击节点进入其详情。\n2. 使用菜单重命名（例如「mon-telephone」）。\n3. 点击铅笔图标编辑标签。添加相关标签（例如 `tag:user-phone`、`tag:user-laptop`）。应用将通过 API 直接更新标签。'),
                      isSmall: true,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Section Prérequis
                  _buildSectionTitle(context,
                      context.l10n.t('1. Prérequis et Installation du Serveur Headscale', '1. Prerequisites and Headscale Server Installation', '1. Headscale 服务器的前置条件与安装')),
                  _buildInfoCard(context, children: [
                    _buildBodyText(context,
                        context.l10n.t('Pour utiliser cette application, vous devez disposer d\'un serveur Headscale fonctionnel. Voici comment le configurer :', 'To use this application, you must have a functional Headscale server. Here\'s how to set it up:', '要使用本应用，你需要一个正常运行的 Headscale 服务器。以下是配置方法：')),
                    const SizedBox(height: 16),
                    _buildSubTitle(
                        context, context.l10n.t('1.1. Installation de Headscale avec Docker', '1.1. Installing Headscale with Docker', '1.1. 使用 Docker 安装 Headscale')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Il est recommandé d\'installer Headscale via Docker en utilisant l\'image officielle `headscale/headscale`. Assurez-vous de configurer la persistance des données en montant les volumes nécessaires.', 'It is recommended to install Headscale via Docker using the official `headscale/headscale` image. Make sure to configure data persistence by mounting the necessary volumes.', '建议使用官方镜像 `headscale/headscale` 通过 Docker 安装 Headscale。请务必挂载必要的卷以配置数据持久化。')),
                    const SizedBox(height: 8),
                    _buildBodyText(
                        context, context.l10n.t('Exemple de commande Docker (à adapter) :', 'Example Docker command (to be adapted):', 'Docker 命令示例（需自行调整）：')),
                    const SizedBox(height: 4),
                    _buildCodeBlock(
                      context,
                      '''docker run -d --name headscale 
  -v <chemin_local_config>:/etc/headscale 
  -v <chemin_local_data>:/var/lib/headscale 
  -p 8080:8080 
  headscale/headscale:latest''',
                    ),
                    const SizedBox(height: 8),
                    _buildBodyText(
                      context,
                      context.l10n.t('- `<chemin_local_config>` : Chemin sur votre machine hôte où se trouvera le fichier `config.yaml`.\n'
                      '- `<chemin_local_data>` : Chemin sur votre machine hôte pour la persistance des données de Headscale (base de données, etc.).', '- `<local_config_path>`: Path on your host machine where the `config.yaml` file will be located.\n'
                      '- `<local_data_path>`: Path on your host machine for Headscale data persistence (database, etc.).', '- `<chemin_local_config>`：宿主机上 `config.yaml` 文件所在的路径。\n- `<chemin_local_data>`：宿主机上用于 Headscale 数据持久化的路径（数据库等）。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 16),
                    _buildSubTitle(context, context.l10n.t('1.2. Fichiers de Configuration', '1.2. Configuration Files', '1.2. 配置文件')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Dans le volume de configuration (`<chemin_local_config>`), vous aurez besoin de deux fichiers :', 'In the configuration volume (`<local_config_path>`), you will need two files:', '在配置卷（`<chemin_local_config>`）中，你需要两个文件：')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('- **`config.yaml`** : Le fichier de configuration principal de Headscale. Voici un exemple de configuration "clé en main" :', '- **`config.yaml`**: The main configuration file for Headscale. Here is a "turnkey" configuration example:', '- **`config.yaml`**：Headscale 的主要配置文件。以下是一份「开箱即用」的配置示例：')),
                    const SizedBox(height: 4),
                    _buildCodeBlock(
                      context,
                      '''server_url: https://<VOTRE_FQDN_PUBLIC>:8081
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 127.0.0.1:50443
grpc_allow_insecure: false
noise:
  private_key_path: /var/lib/headscale/noise_private.key
prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48
  allocation: sequential
derp:
  server:
    enabled: false
    region_id: 999
    region_code: "headscale"
    region_name: "Headscale Embedded DERP"
    verify_clients: true
    stun_listen_addr: "0.0.0.0:3478"
    private_key_path: /var/lib/headscale/derp_server_private.key
    automatically_add_embedded_derp_region: true
    ipv4: 1.2.3.4
    ipv6: 2001:db8::1
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  paths: []
  auto_update_enabled: true
  update_frequency: 24h
disable_check_updates: false
ephemeral_node_inactivity_timeout: 30m
database:
  type: sqlite
  debug: false
  gorm:
    prepare_stmt: true
    parameterized_queries: true
    skip_err_record_not_found: true
    slow_threshold: 1000
  sqlite:
    path: /var/lib/headscale/db.sqlite
    write_ahead_log: true
    wal_autocheckpoint: 1000
acme_url: https://acme-v02.api.letsencrypt.org/directory
acme_email: ""
tls_letsencrypt_hostname: ""
tls_letsencrypt_cache_dir: /var/lib/headscale/cache
tls_letsencrypt_challenge_type: HTTP-01
tls_letsencrypt_listen: ":http"
tls_cert_path: ""
tls_key_path: ""
log:
  level: info
  format: text
policy:
   mode: database
   path: ""
dns:
  magic_dns: true
  base_domain: <VOTRE_DOMAINE_DE_BASE>.com
  override_local_dns: false
  nameservers:
    global:
      - 1.1.1.1
      - 1.0.0.1
      - 2606:4700:4700::1111
      - 2606:4700:4700::1001
    split:
      {}
  search_domains: []
  extra_records: []
unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: "0770"
logtail:
  enabled: false
randomize_client_port: false
preauthkey_expiry: 5m
routes:
   enabled: true''',
                    ),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('**N\'oubliez pas de remplacer `<VOTRE_FQDN_PUBLIC>` par le nom de domaine public que vous utiliserez.**', '**Don\'t forget to replace `<YOUR_PUBLIC_FQDN>` with the public domain name you will be using.**', '**别忘了把 `<VOTRE_FQDN_PUBLIC>` 替换为你实际使用的公网域名。**'),
                        isBold: true),
                    const SizedBox(height: 16),
                    _buildSubTitle(context,
                        context.l10n.t('1.3. Configuration d\'un Proxy Inverse (Recommandé)', '1.3. Configuring a Reverse Proxy (Recommended)', '1.3. 配置反向代理（推荐）')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Pour des raisons de sécurité et d\'accessibilité, il est fortement recommandé de placer votre serveur Headscale derrière un proxy inverse (comme Nginx, Caddy, ou Traefik).', 'For security and accessibility reasons, it is highly recommended to place your Headscale server behind a reverse proxy (like Nginx, Caddy, or Traefik).', '出于安全和可访问性的考虑，强烈建议将 Headscale 服务器置于反向代理之后（如 Nginx、Caddy 或 Traefik）。')),
                    const SizedBox(height: 8),
                    _buildBodyText(context, context.l10n.t('Assurez-vous que :', 'Make sure that:', '请确保：')),
                    const SizedBox(height: 4),
                    _buildBodyText(
                      context,
                      context.l10n.t('- Vous avez un **FQDN (Fully Qualified Domain Name) public** (ex: `headscale.mondomaine.com`).\n'
                      '- Vous avez un **certificat SSL/TLS valide** pour ce FQDN (ex: via Let\'s Encrypt).\n'
                      '- Le proxy inverse redirige le **port externe HTTPS (8081)** vers le **port interne HTTP (8080)** de votre conteneur Headscale.', '- You have a **public FQDN (Fully Qualified Domain Name)** (e.g., `headscale.mydomain.com`).\n'
                      '- You have a **valid SSL/TLS certificate** for this FQDN (e.g., via Let\'s Encrypt).\n'
                      '- The reverse proxy redirects the **external HTTPS port (8081)** to the **internal HTTP port (8080)** of your Headscale container.', '- 你拥有一个**公网 FQDN（完全限定域名）**（例如 `headscale.mondomaine.com`）。\n- 你为该 FQDN 拥有**有效的 SSL/TLS 证书**（例如通过 Let’s Encrypt 获取）。\n- 反向代理将 **HTTPS 外部端口（8081）** 重定向到 Headscale 容器的 **HTTP 内部端口（8080）**。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 16),
                    _buildSubTitle(
                        context, context.l10n.t('1.4. Génération de la Clé API Headscale', '1.4. Generating the Headscale API Key', '1.4. 生成 Headscale API 密钥')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Une fois votre serveur Headscale opérationnel et accessible via votre FQDN public, vous devrez générer une clé API pour que l\'application puisse s\'y connecter.', 'Once your Headscale server is operational and accessible via your public FQDN, you will need to generate an API key for the application to connect to it.', '当你的 Headscale 服务器正常运行并可通过公网 FQDN 访问后，需要生成一个 API 密钥，让应用能够连接它。')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Connectez-vous à votre serveur Headscale (par exemple, via SSH sur la machine hôte de Docker) et utilisez la commande :', 'Connect to your Headscale server (e.g., via SSH on the Docker host machine) and use the command:', '登录你的 Headscale 服务器（例如通过 SSH 连接运行 Docker 的主机），并执行以下命令：')),
                    const SizedBox(height: 4),
                    _buildCodeBlock(context, 'headscale apikeys create'),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('**Gardez précieusement cette clé API unique dans un gestionnaire de mots de passe.** Elle est essentielle pour l\'authentification de l\'application.', '**Keep this unique API key safe in a password manager.** It is essential for application authentication.', '**请将这个唯一的 API 密钥妥善保存在密码管理器中。** 它是应用身份认证的关键。'),
                        isBold: true),
                  ]),
                  const SizedBox(height: 24),

                  const SizedBox(height: 24),
                  _buildSectionTitle(
                      context, context.l10n.t('2. Configuration de l\'Application', '2. Application Configuration', '2. 应用配置')),
                  _buildInfoCard(context, children: [
                    _buildBodyText(
                        context, context.l10n.t('Dans l\'application Headscale Manager :', 'In the Headscale Manager application:', '在 Headscale Manager 应用中：')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('1.  Allez dans l\'écran **Paramètres** (icône d\'engrenage en haut à droite).', '1.  Go to the **Settings** screen (gear icon in the top right).', '1.  进入 **设置** 屏幕（右上角的齿轮图标）。')),
                    const SizedBox(height: 4),
                    _buildBodyText(context,
                        context.l10n.t('2.  Entrez l\'**adresse publique de votre serveur Headscale** (votre FQDN public, ex: `https://headscale.mondomaine.com`).', '2.  Enter the **public address of your Headscale server** (your public FQDN, e.g., `https://headscale.mydomain.com`).', '2.  输入 **Headscale 服务器的公网地址**（你的公网 FQDN，例如：`https://headscale.mondomaine.com`）。')),
                    const SizedBox(height: 4),
                    _buildBodyText(context,
                        context.l10n.t('3.  Collez la **clé API** que vous avez générée précédemment.', '3.  Paste the **API key** you generated earlier.', '3.  粘贴你之前生成的 **API 密钥**。')),
                    const SizedBox(height: 4),
                    _buildBodyText(context,
                        context.l10n.t('4.  Sauvegardez les paramètres. L\'application est maintenant prête à se connecter à votre serveur !', '4.  Save the settings. The application is now ready to connect to your server!', '4.  保存设置。应用现在已准备好连接到你的服务器！')),
                  ]),
                  const SizedBox(height: 24),

                  _buildSectionTitle(
                      context, context.l10n.t('3. Utilisation de l\'Application', '3. Using the Application', '3. 应用使用')),
                  _buildInfoCard(context, children: [
                    _buildBodyText(context,
                        context.l10n.t('L\'application est divisée en plusieurs sections accessibles via la barre de navigation inférieure :', 'The application is divided into several sections accessible via the bottom navigation bar:', '应用分为多个部分，可通过底部导航栏访问：')),
                    const SizedBox(height: 16),
                    _buildSubTitle(context, context.l10n.t('3.1. Tableau de Bord (Dashboard)', '3.1. Dashboard', '3.1. 仪表盘（Dashboard）')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Cet écran affiche un aperçu de l\'état de votre réseau Headscale. Vous y trouverez des informations sur le nombre de nœuds en ligne/hors ligne, le nombre d\'utilisateurs, etc. Les nœuds sont regroupés par utilisateur et peuvent être développés pour afficher plus de détails. Taper sur un nœud vous mènera à son écran de détails.', 'This screen displays an overview of the status of your Headscale network. You will find information on the number of online/offline nodes, the number of users, etc. Nodes are grouped by user and can be expanded to show more details. Tapping on a node will take you to its details screen.', '此屏幕显示 Headscale 网络状态的概览。你可以查看在线/离线节点数量、用户数量等信息。节点按用户分组，可以展开查看更详细的内容。点击节点将进入其详情屏幕。')),
                    const SizedBox(height: 8),
                    _buildBodyText(context, context.l10n.t('**Boutons et Fonctionnalités :**', '**Buttons and Features:**', '**按钮与功能：**'),
                        isBold: true),
                    const SizedBox(height: 4),
                    _buildBodyText(
                      context,
                      context.l10n.t('- **Développer/Réduire les groupes d\'utilisateurs :** Tapez sur le nom d\'un utilisateur pour afficher ou masquer les nœuds qui lui sont associés.\n'
                      '- **Afficher les détails du nœud :** Tapez sur n\'importe quel nœud dans la liste pour naviguer vers son écran de détails (`Détails du Nœud`).\n'
                      '- **Gérer les clés d\'API (icône \'api\') :** Ouvre un écran pour gérer les clés d\'API de votre serveur Headscale.', '- **Expand/Collapse user groups:** Tap on a user\'s name to show or hide the nodes associated with them.\n'
                      '- **Show node details:** Tap on any node in the list to navigate to its details screen (`Node Details`).\n'
                      '- **Manage API keys (api icon):** Opens a screen to manage the API keys of your Headscale server.', '- **展开/收起用户分组：** 点击用户名可显示或隐藏其关联的节点。\n- **查看节点详情：** 点击列表中任意节点，即可跳转到其详情屏幕（`节点详情`）。\n- **管理 API 密钥（api 图标）：** 打开一个屏幕，用于管理 Headscale 服务器的 API 密钥。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 16),
                    _buildSubTitle(context, context.l10n.t('3.2. Utilisateurs (Users)', '3.2. Users', '3.2. 用户（Users）')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Gérez les utilisateurs de votre serveur Headscale. Vous pouvez voir la liste des utilisateurs existants, en créer de nouveaux et les supprimer.', 'Manage the users of your Headscale server. You can see the list of existing users, create new ones, and delete them.', '管理 Headscale 服务器的用户。你可以查看现有用户列表、创建新用户以及删除用户。')),
                    const SizedBox(height: 8),
                    _buildBodyText(context, context.l10n.t('**Boutons et Fonctionnalités :**', '**Buttons and Features:**', '**按钮与功能：**'),
                        isBold: true),
                    const SizedBox(height: 4),
                    _buildBodyText(
                      context,
                      context.l10n.t('- **Ajouter Utilisateur (icône \'+\' en bas à droite) :** Ouvre un dialogue pour créer un nouvel utilisateur. Entrez simplement le nom d\'utilisateur souhaité. L\'application ajoutera automatiquement `le suffixe de domaine de votre serveur Headscale (par exemple, \'@votre_domaine.com\')` au nom d\'utilisateur si non présent.\n'
                      '- **Gérer les clés de pré-authentification (icône \'vpn_key\' en bas à droite) :** Ouvre un écran pour gérer les clés de pré-authentification de votre serveur Headscale.\n'
                      '- **Supprimer Utilisateur (icône de poubelle à côté de chaque utilisateur) :** Supprime l\'utilisateur sélectionné. Une confirmation vous sera demandée. Notez que la suppression échouera si l\'utilisateur possède encore des appareils.\n'
                      '- **Détails Utilisateur (clic sur un utilisateur) :** Affiche les détails de l\'utilisateur, y compris les nœuds qui lui sont associés et les clés de pré-authentification.', '- **Add User (+ icon at the bottom right):** Opens a dialog to create a new user. Simply enter the desired username. The application will automatically add `the domain suffix of your Headscale server (e.g., \'@your_domain.com\')` to the username if not present.\n'
                      '- **Manage pre-authentication keys (vpn_key icon at the bottom right):** Opens a screen to manage the pre-authentication keys of your Headscale server.\n'
                      '- **Delete User (trash can icon next to each user):** Deletes the selected user. A confirmation will be requested. Note that deletion will fail if the user still has devices.\n'
                      '- **User Details (click on a user):** Displays user details, including associated nodes and pre-authentication keys.', '- **添加用户（右下角的 + 图标）：** 打开对话框创建新用户。只需输入想要的用户名。如果用户名中没有域名后缀，应用会自动加上 `Headscale 服务器的域名后缀（例如 @votre_domaine.com）`。\n- **管理预认证密钥（右下角的 vpn_key 图标）：** 打开一个屏幕，用于管理 Headscale 服务器的预认证密钥。\n- **删除用户（每个用户旁的垃圾桶图标）：** 删除所选用户，操作前会要求确认。请注意，如果该用户仍有设备，删除将失败。\n- **用户详情（点击用户）：** 显示用户详情，包括其关联的节点和预认证密钥。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 16),
                    _buildSubTitle(context, context.l10n.t('3.3. ACLs (Access Control Lists)', '3.3. ACLs (Access Control Lists)', '3.3. ACL（访问控制列表）')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Cette section vous permet de générer et de gérer la politique de contrôle d\'accès de votre réseau.', 'This section allows you to generate and manage your network\'s access control policy.', '此部分用于生成和管理网络的访问控制策略。')),
                    const SizedBox(height: 16),
                    _buildBodyText(
                      context,
                      context.l10n.t('**Note Importante :** L\'ajout d\'un ou plusieurs utilisateurs peut nécessiter une mise à jour de la politique ACL pour que leurs appareils fonctionnent correctement.', '**Important Note:** Adding one or more users may require an update to the ACL policy for their devices to work correctly.', '**重要提示：** 添加一个或多个用户后，可能需要更新 ACL 策略，其设备才能正常工作。'),
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('**Principe de base : Isolation Stricte par Utilisateur**', '**Basic Principle: Strict User Isolation**', '**基本原则：按用户严格隔离**'),
                        isBold: true),
                    const SizedBox(height: 4),
                    _buildBodyText(
                      context,
                      context.l10n.t('Le générateur de politique de cette application est basé sur un principe de sécurité fondamental : **chaque utilisateur est isolé dans sa propre "bulle"**. Par défaut :\n'
                      '- Les appareils d\'un utilisateur ne peuvent communiquer qu\'avec les autres appareils de ce même utilisateur.\n'
                      '- Si un utilisateur possède un **exit node**, seuls ses propres appareils peuvent l\'utiliser.\n'
                      '- Si un utilisateur partage un **sous-réseau local**, seuls ses propres appareils peuvent y accéder.\n'
                      '- Jean ne peut pas voir ou contacter les appareils, exit nodes ou sous-réseaux de Clarisse, et vice-versa.', 'The policy generator in this application is based on a fundamental security principle: **each user is isolated in their own "bubble"**. By default:\n'
                      '- A user\'s devices can only communicate with other devices of the same user.\n'
                      '- If a user has an **exit node**, only their own devices can use it.\n'
                      '- If a user shares a **local subnet**, only their own devices can access it.\n'
                      '- John cannot see or contact the devices, exit nodes, or subnets of Clarisse, and vice versa.', '本应用的策略生成器基于一个基本安全原则：**每个用户被隔离在自己的「气泡」中**。默认情况下：\n- 用户的设备只能与同一用户的其他设备通信。\n- 如果用户拥有 **出口节点**，则只有其自己的设备可以使用它。\n- 如果用户共享了 **本地子网**，则只有其自己的设备可以访问。\n- Jean 无法看到或联系 Clarisse 的设备、出口节点或子网，反之亦然。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 16),
                    _buildBodyText(context,
                        context.l10n.t('**Moteurs ACL (v2.0)**', '**ACL Engines (v2.0)**', '**ACL 引擎（v2.0）**'), isBold: true),
                    const SizedBox(height: 4),
                    _buildBodyText(
                      context,
                      context.l10n.t('- **Legacy** : tags fusionnés (ancien format).\n'
                      '- **Standard** : tags séparés (Identity vs Capability).\n'
                      '- **Grants V29** : grants Headscale ≥ 0.29 avec routage **via** pour isoler les LAN identiques entre utilisateurs.\n'
                      'Sélection dans Paramètres. L\'écran ACL affiche des onglets Grants / ACLs / JSON.', '- **Legacy**: merged tags (old format).\n'
                      '- **Standard**: split tags (Identity vs Capability).\n'
                      '- **Grants V29**: Headscale ≥ 0.29 grants with **via** routing to isolate identical LAN CIDRs across users.\n'
                      'Select in Settings. ACL screen has Grants / ACLs / JSON tabs.', '- **Legacy**：合并标签（旧格式）。\n- **Standard**：拆分标签（Identity 与 Capability）。\n- **Grants V29**：Headscale ≥ 0.29 的 grants，使用 **via** 路由隔离不同用户间相同的 LAN。\n在设置中选择。ACL 屏幕包含 Grants / ACLs / JSON 标签页。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 16),
                    _buildBodyText(
                        context, context.l10n.t('**Workflow d\'utilisation de la page ACL :**', '**Workflow for using the ACL page:**', '**ACL 页面使用流程：**'),
                        isBold: true),
                    const SizedBox(height: 4),
                    _buildBodyText(
                      context,
                      context.l10n.t('La page ACL a deux fonctions principales :', 'The ACL page has two main functions:', 'ACL 页面有两个主要功能：'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 8),
                    _buildBodyText(
                      context,
                      context.l10n.t('**1. Générer la politique de base sécurisée :**\n'
                      '- Appuyez sur le bouton **Générer la Politique**.\n'
                      '- L\'application va analyser tous vos utilisateurs et appareils et créer une politique ACL sécurisée.\n'
                      '- La politique générée s\'affiche dans le champ de texte pour inspection.\n'
                      '- Utilisez le menu (⋮) et sélectionnez **Exporter vers le serveur** pour appliquer les règles.', '**1. Generate the secure base policy:**\n'
                      '- Press the **Generate Policy** button.\n'
                      '- The application will analyze all your users and devices and create a secure ACL policy.\n'
                      '- The generated policy is displayed in the text field for inspection.\n'
                      '- Use the menu (⋮) and select **Export to server** to apply the rules.', '**1. 生成安全的基础策略：**\n- 点击 **生成策略** 按钮。\n- 应用会分析你所有的用户和设备，创建一份安全的 ACL 策略。\n- 生成的策略会显示在文本框中，供你检查。\n- 使用菜单（⋮）并选择 **导出到服务器** 来应用规则。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 8),
                    _buildBodyText(
                      context,
                      context.l10n.t('**2. Créer des exceptions pour la maintenance :**\n'
                      '- Si vous avez besoin d\'autoriser temporairement un appareil de Jean à communiquer avec un appareil de Clarisse, utilisez la section **Autorisations Spécifiques**.\n'
                      '- Sélectionnez un tag `Source` et un tag `Destination`.\n'
                      '- Cliquez sur **Ajouter et Appliquer**.\n'
                      '- La politique sera **automatiquement mise à jour et appliquée** sur le serveur.\n'
                      '- Pour retirer l\'autorisation, cliquez simplement sur la croix (x) de la règle active.', '**2. Create exceptions for maintenance:**\n'
                      '- If you need to temporarily allow a device from John to communicate with a device from Clarisse, use the **Specific Permissions** section.\n'
                      '- Select a `Source` tag and a `Destination` tag.\n'
                      '- Click **Add and Apply**.\n'
                      '- The policy will be **automatically updated and applied** on the server.\n'
                      '- To remove the permission, simply click the cross (x) on the active rule.', '**2. 为维护创建例外：**\n- 如果需要临时允许 Jean 的设备与 Clarisse 的设备通信，请使用 **特定授权** 部分。\n- 选择一个 `Source` 标签和一个 `Destination` 标签。\n- 点击 **添加并应用**。\n- 策略将**自动更新并应用**到服务器。\n- 要移除授权，只需点击活动规则上的叉号（x）。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 16),
                    _buildSubTitle(context, context.l10n.t('3.4. Testeur ACL (ACL Tester)', '3.4. ACL Tester', '3.4. ACL 测试器（ACL Tester）')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Cette nouvelle page vous permet de tester et de visualiser l\'impact de différentes politiques ACL sans les appliquer directement à votre serveur Headscale. C\'est un environnement sûr pour expérimenter.', 'This new page allows you to test and visualize the impact of different ACL policies without applying them directly to your Headscale server. It is a safe environment for experimentation.', '这个新页面让你可以测试并直观查看不同 ACL 策略的影响，而无需直接应用到 Headscale 服务器。这是一个可以安全试验的环境。')),
                    const SizedBox(height: 8),
                    _buildBodyText(context, context.l10n.t('**Fonctionnalités :**', '**Features:**', '**功能：**'),
                        isBold: true),
                    const SizedBox(height: 4),
                    _buildBodyText(
                      context,
                      context.l10n.t('- **Génération de Politique :** Similaire à la page ACL principale, vous pouvez générer une politique basée sur vos utilisateurs et nœuds existants.\n'
                      '- **Règles Temporaires :** Ajoutez et supprimez des règles temporaires pour voir comment elles affectent la politique générée.\n'
                      '- **Visualisation Instantanée :** La politique ACL résultante est affichée en temps réel dans un champ de texte, vous permettant de l\'inspecter.\n'
                      '- **Exportation Optionnelle :** Une fois satisfait du résultat, vous pouvez choisir d\'exporter la politique vers votre serveur Headscale.', '- **Policy Generation:** Similar to the main ACL page, you can generate a policy based on your existing users and nodes.\n'
                      '- **Temporary Rules:** Add and remove temporary rules to see how they affect the generated policy.\n'
                      '- **Instant Visualization:** The resulting ACL policy is displayed in real-time in a text field, allowing you to inspect it.\n'
                      '- **Optional Export:** Once satisfied with the result, you can choose to export the policy to your Headscale server.', '- **策略生成：** 与主 ACL 页面类似，你可以基于现有用户和节点生成策略。\n- **临时规则：** 添加和删除临时规则，查看它们如何影响生成的策略。\n- **即时可视化：** 生成的 ACL 策略会实时显示在文本框中，方便你检查。\n- **可选导出：** 对结果满意后，你可以选择将策略导出到 Headscale 服务器。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 16),
                    _buildSubTitle(context, context.l10n.t('3.5. Partages Taildrive (v0.29.0+)', '3.5. Taildrive Shares (v0.29.0+)', '3.5. Taildrive 分享（v0.29.0+）')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Taildrive permet de partager des dossiers entre vos appareils directement via votre réseau Headscale. Cette fonctionnalité nécessite Headscale v0.29.0 ou supérieur.', 'Taildrive allows you to share folders between your devices directly via your Headscale network. This feature requires Headscale v0.29.0 or higher.', 'Taildrive 可以让你直接通过 Headscale 网络在设备之间共享文件夹。此功能需要 Headscale v0.29.0 或更高版本。')),
                    const SizedBox(height: 8),
                    _buildBodyText(context, context.l10n.t('**Fonctionnement :**', '**How it works:**', '**工作方式：**'),
                        isBold: true),
                    const SizedBox(height: 4),
                    _buildBodyText(
                      context,
                      context.l10n.t('- **Activer automatiquement** : Si votre serveur est en v0.29.0+, l\'option Taildrive apparaît dans le menu ACL (icône 📁).\n'
                      '- **Créer un partage** : Sélectionnez un nœud source, un bénéficiaire, un nom de partage, un chemin local et les permissions (lecture seule ou lecture/écriture).\n'
                      '- **Génération ACL automatique** : Les règles ACL nécessaires (nodeAttrs et grants) sont automatiquement ajoutées à votre politique.\n'
                      '- **Intégration complète** : Les politiques générées incluent `drive:share` pour les sources et `drive:access` pour les destinataires, avec les permissions `tailscale.com/cap/drive`.', '- **Automatic activation:** If your server is v0.29.0+, the Taildrive option appears in the ACL menu (📁 icon).\n'
                      '- **Create a share:** Select a source node, recipient, share name, local path, and permissions (read-only or read/write).\n'
                      '- **Automatic ACL generation:** The necessary ACL rules (nodeAttrs and grants) are automatically added to your policy.\n'
                      '- **Full integration:** Generated policies include `drive:share` for sources and `drive:access` for recipients, with `tailscale.com/cap/drive` permissions.', '- **自动启用**：如果你的服务器为 v0.29.0+，ACL 菜单中会出现 Taildrive 选项（📁 图标）。\n- **创建共享**：选择源节点、接收者、共享名称、本地路径和权限（只读或读写）。\n- **自动生成 ACL**：所需的 ACL 规则（nodeAttrs 和 grants）会自动添加到你的策略中。\n- **完整集成**：生成的策略会为源包含 `drive:share`，为接收方包含 `drive:access`，以及 `tailscale.com/cap/drive` 权限。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 8),
                    _buildBodyText(context, context.l10n.t('**Requirements :**', '**Requirements:**', '**要求：**'),
                        isBold: true),
                    const SizedBox(height: 4),
                    _buildBodyText(
                      context,
                      context.l10n.t('- Serveur Headscale **v0.29.0 ou supérieur**\n'
                      '- Clients Tailscale avec support Taildrive\n'
                      '- Politique ACL générée et appliquée au serveur', '- Headscale server **v0.29.0 or higher**\n'
                      '- Tailscale clients with Taildrive support\n'
                      '- ACL policy generated and applied to the server', '- Headscale 服务器 **v0.29.0 或更高版本**\n- 支持 Taildrive 的 Tailscale 客户端\n- 已生成并应用到服务器的 ACL 策略'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 16),
                    _buildSubTitle(context, context.l10n.t('3.6. Vue d\'ensemble du réseau', '3.6. Network Overview', '3.6. 网络概览视图')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Cet écran, accessible depuis la barre de navigation, offre une vue dynamique et en temps réel de votre topologie réseau du point de vue de l\'appareil actuel. Il est particulièrement utile pour diagnostiquer les connexions et vérifier quel `exit node` est utilisé.', 'This screen, accessible from the navigation bar, offers a dynamic, real-time view of your network topology from the perspective of the current device. It is particularly useful for diagnosing connections and checking which `exit node` is being used.', '该页面可从导航栏进入，从当前设备的角度动态、实时地展示你的网络拓扑。它特别适合用于诊断连接情况，以及确认正在使用哪个 `出口节点`。')),
                    const SizedBox(height: 8),
                    _buildBodyText(context, context.l10n.t('**Fonctionnalités principales :**', '**Main Features:**', '**主要功能：**'),
                        isBold: true),
                    const SizedBox(height: 4),
                    _buildBodyText(
                      context,
                      context.l10n.t('- **Sélecteur de Nœud Actuel :** En haut de la page, un menu déroulant vous permet de sélectionner l\'appareil que vous considérez comme votre point de départ.\n'
                      '- **Visualisation du Chemin :** Un graphique simple montre le chemin réseau depuis votre appareil sélectionné vers Internet. Si le trafic passe par un `exit node` de votre réseau Headscale, celui-ci sera affiché comme intermédiaire.\n'
                      '- **Détection d\'Exit Node :** La page effectue un `traceroute` vers une destination publique (Google DNS) pour cartographier les sauts. Si l\'un des sauts correspond à l\'adresse IP d\'un de vos nœuds, ce dernier est identifié comme l\'exit node en cours d\'utilisation.\n'
                      '- **Statut des Pings :** Une liste de tous les autres nœuds de votre réseau s\'affiche avec leur statut (en ligne/hors ligne) et la latence moyenne.\n'
                      '- **Détails du Traceroute :** Une section dépliable vous montre le résultat brut du `traceroute`, listant chaque saut (adresse IP) entre votre appareil et la destination finale.', '- **Current Node Selector:** At the top of the page, a dropdown menu allows you to select the device you consider your starting point.\n'
                      '- **Path Visualization:** A simple graph shows the network path from your selected device to the Internet. If traffic passes through an `exit node` on your Headscale network, it will be displayed as an intermediary.\n'
                      '- **Exit Node Detection:** The page performs a `traceroute` to a public destination (Google DNS) to map the hops. If one of the hops matches the IP address of one of your nodes, that node is identified as the exit node currently in use.\n'
                      '- **Ping Status:** A list of all other nodes on your network is displayed with their status (online/offline) and average latency.\n'
                      '- **Traceroute Details:** An expandable section shows you the raw `traceroute` result, listing each hop (IP address) between your device and the final destination.', '- **当前节点选择器：** 页面顶部的下拉菜单可让你选择作为起点的设备。\n- **路径可视化：** 简单的图表展示从所选设备到互联网的网络路径。如果流量经过 Headscale 网络中的 `出口节点`，该节点会作为中间节点显示。\n- **出口节点检测：** 页面会对公共目标（Google DNS）执行 `traceroute` 以绘制各跳。如果其中某一跳的 IP 地址与你某个节点的地址匹配，该节点就会被识别为当前使用的出口节点。\n- **Ping 状态：** 列出网络中所有其他节点及其状态（在线/离线）和平均延迟。\n- **Traceroute 详情：** 可折叠区域会显示 `traceroute` 的原始结果，列出你的设备与最终目标之间的每一跳（IP 地址）。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 16),
                    _buildSubTitle(context, context.l10n.t('3.7. Commandes Clients', '3.7. Client Commands', '3.7. 客户端命令')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Cette page, accessible depuis la barre de navigation, fournit une bibliothèque de commandes en ligne de commande (`CLI`) pour le client Tailscale. Elle est conçue pour vous aider à trouver rapidement la commande dont vous avez besoin.', 'This page, accessible from the navigation bar, provides a library of command-line interface (`CLI`) commands for the Tailscale client. It is designed to help you quickly find the command you need for various tasks.', '该页面可从导航栏进入，提供 Tailscale 客户端的命令行（`CLI`）命令库，帮助你快速找到所需的命令。')),
                    const SizedBox(height: 8),
                    _buildBodyText(context, context.l10n.t('**Fonctionnalités :**', '**Features:**', '**功能：**'),
                        isBold: true),
                    const SizedBox(height: 4),
                    _buildBodyText(
                      context,
                      context.l10n.t('- **Filtres :** Vous pouvez filtrer les commandes par plateforme (Windows/Linux) et par catégorie.\n'
                      '- **Commandes dynamiques :** Certaines commandes sont pré-remplies avec les informations de votre serveur.\n'
                      '- **Configuration et Copie :** Pour les commandes complexes, une boîte de dialogue vous permet de configurer les paramètres avant de copier la commande finale.', '- **Filters:** You can filter commands by platform (Windows/Linux) and by category.\n'
                      '- **Dynamic Commands:** Some commands are pre-filled with information from your server.\n'
                      '- **Configuration and Copy:** For complex commands, a dialog allows you to configure the parameters before copying the final command.', '- **筛选：** 可以按平台（Windows/Linux）和类别筛选命令。\n- **动态命令：** 部分命令会预先填入你的服务器信息。\n- **配置与复制：** 对于复杂命令，可通过对话框先配置参数，再复制最终命令。'),
                      isSmall: true,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Section Fonctionnalités Avancées
                  _buildSectionTitle(context, context.l10n.t('4. Fonctionnalités Avancées', '4. Advanced Features', '4. 高级功能')),
                  _buildInfoCard(context, children: [
                    _buildBodyText(context,
                        context.l10n.t('Cette section décrit les fonctionnalités avancées qui simplifient la gestion de la sécurité et la surveillance de votre réseau.', 'This section describes advanced features that simplify security management and network monitoring.', '本节介绍可简化安全管理与网络监控的高级功能。')),
                    const SizedBox(height: 16),
                    _buildSubTitle(context,
                        context.l10n.t('4.1. Gestion des Permissions Simplifiée (ACLs)', '4.1. Simplified Permission Management (ACLs)', '4.1. 简化的权限管理（ACL）')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Headscale Manager introduit plusieurs mécanismes pour rendre la gestion des listes de contrôle d\'accès (ACLs) plus intuitive et moins sujette aux erreurs.', 'Headscale Manager introduces several mechanisms to make Access Control List (ACL) management more intuitive and less error-prone.', 'Headscale Manager 引入了多种机制，让访问控制列表（ACL）管理更直观、更不易出错。')),
                    const SizedBox(height: 16),
                    _buildBodyText(
                        context, context.l10n.t('A. Automatisation depuis le Tableau de Bord', 'A. Automation from the Dashboard', 'A. 从仪表盘自动化'),
                        isBold: true),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('Le tableau de bord est désormais votre centre de commande pour les permissions courantes. Lorsque des nœuds demandent à partager des sous-réseaux ou à devenir un "Exit Node", des icônes d\'avertissement apparaissent.', 'The dashboard is now your command center for common permissions. When nodes request to share subnets or become an "Exit Node", warning icons appear.', '仪表盘现在是你处理常见权限的命令中心。当节点请求共享子网或成为「出口节点」时，会出现警告图标。')),
                    const SizedBox(height: 8),
                    _buildBodyText(context, context.l10n.t('**Approbation en un clic :**', '**One-Click Approval:**', '**一键批准：**'),
                        isBold: true),
                    _buildBodyText(
                      context,
                      context.l10n.t('1. **Ajoute les tags pertinents** au nœud (ex: `;lan-sharer` ou `;exit-node`).\n'
                      '2. **Approuve les routes** demandées.\n'
                      '3. **Régénère et applique la politique ACL complète**.\n'
                      '*Avantage :* Plus besoin de modifier manuellement les tags et la politique ACL. Tout est fait en une seule étape.', '1. **Adds the relevant tags** to the node (e.g., `;lan-sharer` or `;exit-node`).\n'
                      '2. **Approves the requested routes**.\n'
                      '3. **Regenerates and applies the full ACL policy**.\n'
                      '*Benefit:* No more need to manually edit tags and the ACL policy. Everything is done in a single step.', '1. **添加相关标签**到节点（例如 `;lan-sharer` 或 `;exit-node`）。\n2. **批准请求的路由**。\n3. **重新生成并应用完整的 ACL 策略**。\n*优势：* 不再需要手动修改标签和 ACL 策略，一步即可完成。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 8),
                    _buildBodyText(context, context.l10n.t('**Nettoyage intelligent :**', '**Smart Cleanup:**', '**智能清理：**'),
                        isBold: true),
                    _buildBodyText(
                      context,
                      context.l10n.t('Si un client désactive le partage, une icône bleue apparaît. Le nettoyage :\n'
                      '1. **Retire les tags** obsolètes.\n'
                      '2. **Supprime les routes** non annoncées.\n'
                      '3. **Régénère la politique ACL** pour révoquer les permissions.\n'
                      '*Avantage :* Maintient votre configuration propre et synchronisée.', 'If a client disables sharing, a blue icon appears. The cleanup process:\n'
                      '1. **Removes obsolete tags**.\n'
                      '2. **Deletes unadvertised routes**.\n'
                      '3. **Regenerates the ACL policy** to revoke permissions.\n'
                      '*Benefit:* Keeps your configuration clean and synchronized.', '如果客户端停用共享，会出现蓝色图标。清理过程：\n1. **移除过时的标签**。\n2. **删除不再通告的路由**。\n3. **重新生成 ACL 策略**以撤销权限。\n*优势：* 保持配置整洁且同步。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 16),
                    _buildBodyText(context,
                        context.l10n.t('B. Autorisations Spécifiques (Exceptions ACL)', 'B. Specific Permissions (ACL Exceptions)', 'B. 特定授权（ACL 例外）'),
                        isBold: true),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('La page "ACLs" permet de créer des exceptions à la règle d\'isolation par utilisateur (ex: autoriser l\'accès entre appareils de `Jean` et `Clarisse`).', 'The "ACLs" page allows creating exceptions to the user isolation rule (e.g., allowing access between devices of `John` and `Jane`).', '「ACL」页面可以创建用户隔离规则的例外（例如允许 `Jean` 与 `Clarisse` 的设备之间互相访问）。')),
                    const SizedBox(height: 8),
                    _buildBodyText(context,
                        context.l10n.t('**Cas Spécifique : Accès aux Sous-réseaux Partagés**', '**Specific Case: Access to Shared Subnets**', '**特殊情况：访问已共享的子网**'),
                        isBold: true),
                    _buildBodyText(
                      context,
                      context.l10n.t('Si la destination partage des sous-réseaux, vous pouvez donner un **Accès Complet** ou un **Accès Personnalisé** (IPs/ports spécifiques), offrant un contrôle très fin.', 'If the destination shares subnets, you can grant **Full Access** or **Custom Access** (specific IPs/ports), providing very fine-grained control.', '如果目标共享了子网，你可以授予**完全访问**或**自定义访问**（指定 IP/端口），实现非常精细的控制。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 16),
                    _buildSubTitle(
                        context, context.l10n.t('4.2. Notifications et Surveillance', '4.2. Notifications and Monitoring', '4.2. 通知与监控')),
                    const SizedBox(height: 8),
                    _buildBodyText(context, context.l10n.t('A. Notifications en Tâche de Fond', 'A. Background Notifications', 'A. 后台通知'),
                        isBold: true),
                    _buildBodyText(
                      context,
                      context.l10n.t('Activez dans les **Paramètres**. L\'application vérifie toutes les 15 minutes et vous notifie si une approbation ou un nettoyage est requis.', 'Enable in **Settings**. The app checks every 15 minutes and notifies you if an approval or cleanup is required.', '在**设置**中启用。应用每 15 分钟检查一次，若需要审批或清理就会通知你。'),
                      isSmall: true,
                    ),
                    const SizedBox(height: 8),
                    _buildBodyText(
                        context, context.l10n.t('B. Surveillance du Statut par Nœud', 'B. Per-Node Status Monitoring', 'B. 按节点监控状态'),
                        isBold: true),
                    _buildBodyText(
                      context,
                      context.l10n.t('Sur la page de **détails d\'un nœud**, activez **"Surveiller le statut"** pour être notifié chaque fois que ce nœud passe de "en ligne" à "hors ligne", ou vice-versa.', 'On a **node\'s detail page**, enable **"Monitor Status"** to be notified whenever that node goes from "online" to "offline", or vice-versa.', '在**节点详情**页面启用**「监控状态」**，即可在该节点从「在线」变为「离线」或反向变化时收到通知。'),
                      isSmall: true,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  _buildInfoCard(context, children: [
                    _buildBodyText(
                      context,
                      context.l10n.t('**Note Importante sur les Modifications des Nœuds :**\n'
                      'Toute modification apportée à un nœud (ajout, renommage, déplacement, modification des tags, activation/désactivation de routes) via cette application est enregistrée immédiatement dans la base de données de Headscale. Cependant, pour que ces changements soient réellement pris en compte par les autres nœuds du réseau et que la nouvelle configuration soit propagée, il est souvent nécessaire de redémarrer le service Headscale sur votre serveur. Headscale pousse les informations de sa base de données aux autres nœuds principalement au démarrage du service.', '**Important Note on Node Modifications:**\n'
                      'Any modification made to a node (addition, renaming, moving, tag modification, enabling/disabling routes) via this application is immediately saved in the Headscale database. However, for these changes to be truly taken into account by other nodes on the network and for the new configuration to be propagated, it is often necessary to restart the Headscale service on your server. Headscale pushes information from its database to other nodes mainly when the service starts.', '**关于节点修改的重要提示：**\n通过本应用对节点所做的任何修改（添加、重命名、移动、修改标签、启用/停用路由）都会立即保存到 Headscale 数据库中。不过，要让这些更改真正被网络中的其他节点接受并传播新配置，通常需要重启服务器上的 Headscale 服务。Headscale 主要在服务启动时把数据库中的信息推送给其他节点。'),
                      isBold: true,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  _buildBodyText(context,
                      context.l10n.t('Pour toute question ou problème, veuillez consulter la documentation officielle de Headscale ou les ressources de la communauté.', 'For any questions or issues, please consult the official Headscale documentation or community resources.', '如有任何疑问或问题，请查阅 Headscale 官方文档或社区资源。')),
                  const SizedBox(height: 24),

                  // Carte GitHub
                  _buildLinkCard(context),
                  const SizedBox(height: 16),
                ],
              ),
            );
          }),
        ));
  }

  Widget _buildCommandsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      color: theme.colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(Icons.storage,
            color: theme.colorScheme.onPrimary, size: 32),
        title: Text(
          context.l10n.t('Bibliothèque de Commandes Client', 'Client Command Library', '客户端命令库'),
          style: TextStyle(
              fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimary),
        ),
        subtitle: Text(
          context.l10n.t('Trouvez des commandes CLI Tailscale utiles.', 'Find useful Tailscale CLI commands.', '查找有用的 Tailscale CLI 命令。'),
          style: TextStyle(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.8)),
        ),
        trailing:
            Icon(Icons.arrow_forward_ios, color: theme.colorScheme.onPrimary),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ClientCommandsScreen()),
          );
        },
      ),
    );
  }

  Widget _buildLinkCard(BuildContext context) {
    final Uri githubUri =
        Uri.parse('https://github.com/hkdone/headscalemanager');
    const String githubUrl = 'https://github.com/hkdone/headscalemanager';

    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () async {
          if (await canLaunchUrl(githubUri)) {
            await launchUrl(githubUri, mode: LaunchMode.externalApplication);
          }
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.code_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  githubUrl,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy,
                    color: Theme.of(context).colorScheme.primary),
                onPressed: () async {
                  await Clipboard.setData(const ClipboardData(text: githubUrl));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(context.l10n.t('Lien GitHub copié !', 'GitHub link copied!', 'GitHub 链接已复制！'),
                            style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onPrimary)),
                        backgroundColor: Theme.of(context).colorScheme.primary),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context,
      {required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 16.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  Widget _buildSubTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _buildBodyText(BuildContext context, String text,
      {bool isBold = false, bool isSmall = false}) {
    // Utiliser RichText pour gérer le gras avec les astérisques
    List<TextSpan> spans = [];
    text.splitMapJoin(
      RegExp(r'\*\*(.*?)\*\*'),
      onMatch: (m) {
        spans.add(TextSpan(
          text: m.group(1),
          style: TextStyle(
            fontSize: isSmall ? 13 : 15,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight:
                FontWeight.bold, // Toujours en gras pour ce qui est matché
            height: 1.5,
          ),
        ));
        return '';
      },
      onNonMatch: (n) {
        spans.add(TextSpan(
          text: n,
          style: TextStyle(
            fontSize: isSmall ? 13 : 15,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            height: 1.5,
          ),
        ));
        return '';
      },
    );

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildCodeBlock(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      width: double.infinity,
      child: SelectableText(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontFamily: 'monospace', fontSize: 12.5),
      ),
    );
  }
}
