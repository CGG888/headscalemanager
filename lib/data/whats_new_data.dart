import 'package:headscalemanager/l10n/l10n.dart';

class WhatsNewVersion {
  final String version;
  final String title;
  final String description;
  final String verification;

  const WhatsNewVersion({
    required this.version,
    required this.title,
    required this.description,
    required this.verification,
  });

  static List<WhatsNewVersion> getVersions(L10n l10n) {
    return [
      WhatsNewVersion(
        version: '2.7.0',
        title: l10n.t('Release 2.7.0 — Alertes réglables et suivi des changements', 'Release 2.7.0 — Configurable alerts and change tracking', 'Release 2.7.0 — 告警可配置与变更对比'),
        description: l10n.t('Les alertes deviennent réglables : quelles notifications recevoir, combien de jours à l\'avance pour l\'expiration des clés, et après combien de jours hors ligne un nœud est considéré comme abandonné. Une nouvelle page compare la politique ACL actuelle à une référence enregistrée sur l\'appareil et liste les règles ajoutées, supprimées ou modifiées. L\'historique des opérations peut être copié en texte. Enfin, un appui long sur un nœud affiche son système, sa version, son relais DERP et sa latence par région.', 'Alerts are now configurable: which notifications to receive, how many days ahead to warn about key expiry, and how many days offline before a node counts as abandoned. A new page compares the current ACL policy against a baseline stored on the device and lists the rules added, removed or changed. The operation history can be copied as text. Finally, long-pressing a node shows its OS, version, DERP relay and per-region latency.', '告警可配置：选择接收哪些通知、密钥到期提前多少天提醒、离线多少天算作可清理节点。新增「策略变更对比」页：把当前 ACL 策略与保存在本机的基线比较，列出新增/删除/修改的规则。操作记录支持一键复制为文本。此外，**长按节点**可直接查看其系统、客户端版本、DERP 中继与各区域延迟。'),
        verification: l10n.t('Page Alertes, page Changements de politique, appui long sur un nœud', 'The Alerts page, the Policy changes page, and a long press on a node', '告警设置页、策略变更对比页，以及长按某个节点'),
      ),
      WhatsNewVersion(
        version: '2.6.0',
        title: l10n.t('Release 2.6.0 — Appareils non autorisés et historique des opérations', 'Release 2.6.0 — Unauthorized devices and operation history', 'Release 2.6.0 — 未授权设备与操作记录'),
        description: l10n.t('Une page liste les appareils dont la clé n\'est pas autorisée (authorized = false), avec leur système, version et relais DERP, et permet d\'expirer leur clé ou de les supprimer. L\'application enregistre aussi localement les opérations destructrices (suppressions et expirations groupées, approbations de routes, création de clés) : qui, quoi, quand et avec quel résultat. Cet historique reste sur l\'appareil et disparaît avec l\'application.', 'A page lists the devices whose key is not authorized (authorized = false), with their OS, version and DERP relay, and lets you expire their key or delete them. The app also records destructive operations locally (batch deletions and expirations, route approvals, key creation): who, what, when and with what outcome. That history stays on the device and disappears with the app.', '新增「未授权设备」页：列出 `authorized = false` 的设备（含系统、版本、DERP 中继），可直接过期其密钥或删除。App 还会在本地记录破坏性操作（批量删除/过期密钥、批准路由、创建密钥）：做了什么、对象、时间与结果。该记录仅保存在本机，随 App 卸载消失。'),
        verification: l10n.t('Icônes bouclier et horloge de l\'en-tête', 'The shield and clock icons in the header', '顶部盾牌与时钟图标'),
      ),
      WhatsNewVersion(
        version: '2.5.0',
        title: l10n.t('Release 2.5.0 — Détails réseau par appareil et outils d\'exploitation', 'Release 2.5.0 — Per-device network details and operations tooling', 'Release 2.5.0 — 设备网络详情与运维工具'),
        description: l10n.t('La fiche d\'un nœud affiche désormais les données de l\'API device : système, version du client, relais DERP réellement utilisé, latence mesurée par le client pour chaque région, points de terminaison publics et type de NAT. S\'ajoutent : un bilan réseau regroupant toutes les anomalies (avec nettoyage groupé des nœuds hors ligne), l\'analyse de visibilité des ACL et leurs règles à risque, un assistant d\'ajout d\'appareil (QR code + commande), une vue multi-serveurs, et des rappels d\'expiration de clé par paliers.', 'A node page now shows the device API data: OS, client version, the DERP relay actually in use, the latency the client measured per region, public endpoints and NAT shape. Also new: a network health page gathering every anomaly (with grouped cleanup of long-offline nodes), ACL visibility analysis with risky rules, an add-a-device wizard (QR code + command), a multi-server view, and tiered key-expiry reminders.', '节点页面现在显示 device API 的数据：操作系统、客户端版本、**实际使用的 DERP 中继**、客户端实测的各区域延迟、公网端点与 NAT 形态。另新增：网络体检（含长期离线节点的一键清理）、ACL 可达性与风险审计、新设备接入向导（二维码 + 命令）、多服务器总览，以及分档的密钥到期提醒。'),
        verification: l10n.t('Fiche d\'un nœud, puis les icônes de l\'en-tête', 'A node page, then the header icons', '进入任一节点详情，以及顶部的各个图标'),
      ),
      WhatsNewVersion(
        version: '2.4.0',
        title: l10n.t('Release 2.4.0 — Bilan réseau et opérations groupées', 'Release 2.4.0 — Network health and batch operations', 'Release 2.4.0 — 网络体检与批量操作'),
        description: l10n.t('La politique ACL est désormais vérifiée avant l\'enregistrement, avec réparation en un clic (références utilisateur sans « @ »). Un bilan réseau regroupe toutes les anomalies détectables (clés expirées ou proches, routes en attente, nœuds sans IP, conflits de routes, tags non déclarés, problème de politique) avec l\'action correspondante. Une page d\'opérations groupées permet d\'approuver les routes, d\'expirer les clés ou de supprimer plusieurs nœuds à la fois, avec un compte rendu des échecs. Enfin, la vue réseau n\'affiche plus tous les nœuds comme hors ligne : l\'état vient du serveur et la latence mesurée est celle vers le serveur.', 'The ACL policy is now validated before saving, with one-click repair (user references missing "@"). A network health page groups every detectable anomaly (expired or soon-to-expire keys, routes awaiting approval, nodes without IP, route conflicts, undeclared tags, policy problems) with the matching action. A batch operations page approves routes, expires keys or deletes several nodes at once, reporting failures. Finally, the network view no longer shows every node as offline: status comes from the server and the latency shown is the one towards the server.', '保存 ACL 策略前会先校验，并可一键修复（缺少「@」的用户引用）。新增「网络体检」页，把可发现的异常汇总在一起（密钥过期/临期、待批准路由、无 IP 节点、路由冲突、未声明标签、策略问题）并给出对应操作。新增「批量操作」页，可一次批准路由、过期密钥或删除多个节点，并汇报失败项。另外，网络页不再把所有节点显示为离线：状态以服务端为准，延迟显示的是到服务器的往返。'),
        verification: l10n.t('Onglet réseau, puis les icônes bouclier et liste de l\'en-tête', 'Network tab, then the shield and checklist icons in the header', '网络页，以及顶部的盾牌与清单图标'),
      ),
      WhatsNewVersion(
        version: '2.3.0',
        title: l10n.t('Release 2.3.0 — Relais DERP et détails réseau', 'Release 2.3.0 — DERP relays and network details', 'Release 2.3.0 — DERP 中继与网络详情'),
        description: l10n.t('La vue d\'ensemble du réseau affiche désormais les relais DERP avec la latence mesurée depuis cet appareil, le plus rapide étant mis en évidence. La fiche d\'un nœud indique l\'expiration de sa clé, sa date et sa méthode d\'enregistrement, ses routes de sous-réseau ainsi que les clés de nœud et DISCO ; la liste des machines signale les clés expirées ou proches de l\'expiration.', 'The network overview now lists DERP relays with the latency measured from this device, highlighting the fastest one. A node\'s page shows its key expiry, registration date and method, subnet routes and the node/DISCO keys; the machine list flags keys that have expired or are about to.', '网络概览现在会列出 DERP 中继以及从本机测得的延迟，并高亮最快的一个。节点页面显示密钥到期时间、注册时间与方式、子网路由以及节点密钥/DISCO 密钥；机器列表会标记密钥已过期或即将到期的节点。'),
        verification: l10n.t('Vue d\'ensemble du réseau, puis la fiche d\'un nœud', 'Network overview, then a node\'s page', '网络概览，然后进入某个节点详情'),
      ),
      WhatsNewVersion(
        version: '2.2.3',
        title: l10n.t('Release 2.2.3 — Signature permanente', 'Release 2.2.3 — Permanent signing key', 'Release 2.2.3 — 使用固定签名密钥'),
        description: l10n.t('Les versions publiées sont désormais signées avec une clé de signature permanente, ce qui permet les mises à jour par-dessus une installation existante. Si vous avez installé une version de test antérieure (v2.2.2 ou avant), désinstallez-la d\'abord : la clé a changé.', 'Published builds are now signed with a permanent signing key, so future updates install over an existing installation. If you installed an earlier test build (v2.2.2 or before), uninstall it first - the key has changed.', '今后发布的安装包使用固定的正式签名密钥，可以直接覆盖升级。如果你装过更早的测试版（v2.2.2 及以前），请先卸载再安装——签名密钥变了。'),
        verification: l10n.t('Installer l\'APK depuis la page Releases', 'Install the APK from the Releases page', '从 Releases 页面下载并安装 APK'),
      ),
      WhatsNewVersion(
        version: '2.2.2',
        title: l10n.t('Release 2.2.2 — Signature de l\'APK corrigée', 'Release 2.2.2 — APK signing fixed', 'Release 2.2.2 — 修复安装包签名'),
        description: l10n.t('Les APK sont désormais signés avec les trois schémas v1 (JAR), v2 et v3. Certains installateurs (systèmes anciens, ROM personnalisées) ne vérifient que la signature v1 et refusaient l\'installation avec « paquet sans fichier de signature ».', 'APKs are now signed with all three schemes - v1 (JAR), v2 and v3. Some installers (older systems, custom ROMs) only check the v1 signature and refused to install with "package has no signature file".', '安装包现在同时带有 v1（JAR）、v2、v3 三种签名。部分安装器（旧系统、定制 ROM）只校验 v1 签名，此前会以「安装包没有签名文件」为由拒绝安装。'),
        verification: l10n.t('Installer l\'APK depuis la page Releases', 'Install the APK from the Releases page', '从 Releases 页面下载并安装 APK'),
      ),
      WhatsNewVersion(
        version: '2.2.1',
        title: l10n.t('Release 2.2.1 — Correctifs ACL et IP publique', 'Release 2.2.1 — ACL and public IP fixes', 'Release 2.2.1 — 修复 ACL 保存与公网 IP 获取'),
        description: l10n.t('1) Correction d\'une erreur 500 à l\'enregistrement de la politique ACL en présence d\'utilisateurs locaux (créés en CLI, sans « @ ») : les groupes utilisent désormais la forme exigée par Headscale (nom@). 2) L\'IP publique n\'est plus demandée à un seul service : plusieurs sources sont essayées avec un délai d\'attente, et un échec n\'affiche plus d\'erreur ni ne bloque le traceroute (l\'étiquette affiche « — »).', '1) Fixed a 500 error when saving the ACL policy while local (CLI-created, non-OIDC) users exist: groups now use the form Headscale requires (name@). 2) The public IP is no longer fetched from a single service: several sources are tried with a timeout, and a failure no longer shows an error or blocks the traceroute (the label shows "—").', '1) 修复存在本地用户（CLI 创建、无邮箱）时保存 ACL 策略报 500 的问题：策略中的用户引用现在写成 Headscale 要求的「用户名@」。2) 公网 IP 不再只依赖单一第三方服务：改用多个源并带超时；取不到时不再弹错误、也不再拖住路由追踪（标签显示「—」）。'),
        verification: l10n.t('ACL > onglet JSON > Enregistrer sur le serveur ; Vue d\'ensemble du réseau', 'ACL > JSON tab > Save to server; Network overview', 'ACL > JSON 页签 > 保存到服务器；网络概览'),
      ),
      WhatsNewVersion(
        version: '2.2.0',
        title: l10n.t('Release 2.2.0 — Prise en charge du chinois', 'Release 2.2.0 — Chinese support', 'Release 2.2.0 — 新增中文支持'),
        description: l10n.t('Interface disponible en français, anglais et chinois simplifié, avec suivi de la langue du système au premier lancement. Traduction complète de l\'application, du guide d\'aide intégré et des messages d\'erreur de l\'API.', 'Interface available in French, English and Simplified Chinese, following the system language on first launch. Full translation of the app, the built-in help guide and the API error messages.', '界面支持法语、英语和简体中文，首次启动跟随系统语言。应用界面、内置帮助指南与 API 报错信息均已完整翻译。'),
        verification: l10n.t('Paramètres > Langue > 中文', 'Settings > Language > Chinese', '设置 > 语言 > 中文'),
      ),
      WhatsNewVersion(
        version: '2.1.7',
        title: l10n.t('Release 2.1.7 — Normalisation des tags OIDC', 'Release 2.1.7 — OIDC Tag Normalization', 'Release 2.1.7 — OIDC 标签规范化'),
        description: l10n.t('Correction de l\'initialisation des tags pour les utilisateurs OIDC : normalisation automatique des noms contenant des points ou caractères spéciaux (conformité Tailscale/Headscale) et auto-résolution des permissions tagOwners.', 'Fixed tag initialization for OIDC users: automatic normalization of names containing dots or special characters (Tailscale/Headscale compliance) and auto-resolution of tagOwners permissions.', '修复 OIDC 用户的标签初始化：自动规范化含有点或特殊字符的名称（符合 Tailscale/Headscale 规范），并自动解析 tagOwners 权限。'),
        verification: l10n.t('Utilisateur OIDC > Détails > Initialiser le Tag > Sauvegarder', 'OIDC User > Details > Initialize Tag > Save', 'OIDC 用户 > 详情 > 初始化标签 > 保存'),
      ),
      WhatsNewVersion(
        version: '2.1.6',
        title: l10n.t('Release 2.1.6 — Affichage bord à bord', 'Release 2.1.6 — Edge-to-edge display', 'Release 2.1.6 — 边到边显示'),
        description: l10n.t('Conformité Android 15+ : affichage bord à bord (edge-to-edge) avec gestion correcte des encarts système (barre de statut et navigation).', 'Android 15+ compliance: edge-to-edge display with proper system inset handling (status and navigation bars).', 'Android 15+ 合规：边到边（edge-to-edge）显示，并正确处理系统内边距（状态栏与导航栏）。'),
        verification: l10n.t('Play Console > affichage bord à bord', 'Play Console > edge-to-edge display', 'Play Console > 边到边显示'),
      ),
      WhatsNewVersion(
        version: '2.1.5',
        title: l10n.t('Release 2.1.5 — Cible Android 16', 'Release 2.1.5 — Android 16 target', 'Release 2.1.5 — 目标 Android 16'),
        description: l10n.t('Mise à jour du niveau d\'API cible vers Android 16 (API 36) pour rester conforme aux exigences Google Play Store.', 'Updated target API level to Android 16 (API 36) to meet Google Play Store requirements.', '将目标 API 级别更新到 Android 16（API 36），以满足 Google Play Store 的要求。'),
        verification: l10n.t('Play Console > conformité niveau d\'API cible', 'Play Console > target API level compliance', 'Play Console > 目标 API 级别合规'),
      ),
      WhatsNewVersion(
        version: '2.1.3',
        title: l10n.t('Release 2.1.3 — Puzzle & persistance', 'Release 2.1.3 — Puzzle & persistence', 'Release 2.1.3 — Puzzle 与持久化'),
        description: l10n.t('Correction de la sauvegarde des noms et icônes dans le Puzzle ACL (SharedPreferences + migration des clés Grants V29). Renommage possible sur la colonne Via.', 'Fixed ACL Puzzle name and icon persistence (SharedPreferences + Grants V29 key migration). Rename enabled on Via column.', '修复 ACL 拼图中名称与图标的保存（SharedPreferences + Grants V29 密钥迁移）。Via 列现可重命名。'),
        verification: l10n.t('Puzzle > personnaliser une règle > fermer l\'app > rouvrir', 'Puzzle > customize a rule > close app > reopen', 'Puzzle > 自定义规则 > 关闭应用 > 重新打开'),
      ),
      WhatsNewVersion(
        version: '2.1.2',
        title: l10n.t('Release 2.1.2 — ACL plus clair', 'Release 2.1.2 — Clearer ACL UI', 'Release 2.1.2 — 更清晰的 ACL 界面'),
        description: l10n.t('Écran ACL simplifié : guide pas-à-pas en brouillon, défilement sur toute la page, formulaire avancé replié, bandeau migration sans lien Rollback confus, SafeArea corrigé sur le composeur de grants.', 'Simplified ACL screen: step-by-step draft guide, full-page scroll, collapsed advanced form, migration banner without confusing Rollback link, SafeArea fix on grant composer.', '简化的 ACL 界面：分步草稿指南、整页滚动、高级表单折叠、去掉令人困惑的回滚链接的迁移横幅、Grants 编写器的 SafeArea 修复。'),
        verification: l10n.t('ACL > brouillon local : guide 4 étapes | Composeur : bouton Suivant visible', 'ACL > local draft: 4-step guide | Composer: Next button visible', 'ACL > 本地草稿：4 步指南 | 编写器：下一步按钮可见'),
      ),
      WhatsNewVersion(
        version: '2.1.1',
        title: l10n.t('Release 2.1.1 — Backup & brouillon ACL', 'Release 2.1.1 — ACL Backup & Draft', 'Release 2.1.1 — 备份与 ACL 草稿'),
        description: l10n.t('Export et import de la policy ACL en JSON (backup daté), workflow « repartir de zéro » en brouillon local (tout autoriser sans toucher au serveur), bandeau brouillon non publié, et correction des radios du composeur d\'édition.', 'Export and import ACL policy as JSON (dated backup), « start from scratch » workflow as local draft (allow all without touching the server), unpublished draft banner, and edit composer radio fixes.', 'ACL 策略支持 JSON 导出与导入（带日期备份）、「从零开始」工作流以本地草稿实现（全部允许且不改动服务器）、未发布草稿横幅，并修复了编辑器的单选按钮。'),
        verification: l10n.t('ACL > ⋮ > Exporter backup JSON | Importer depuis JSON | Repartir : tout autoriser… > Brouillon local', 'ACL > ⋮ > Export JSON Backup | Import from JSON | Start over: allow all… > Local draft', 'ACL > ⋮ > 导出 JSON 备份 | 从 JSON 导入 | 重新开始：全部允许…… > 本地草稿'),
      ),
      WhatsNewVersion(
        version: '2.1.0',
        title: l10n.t('Release 2.1.0 — Composeur de Grants', 'Release 2.1.0 — Grant Composer', 'Release 2.1.0 — Grants 编排器'),
        description: l10n.t('Nouveau composeur guidé de règles Grants V29 (templates LAN, Internet, intra-flotte, IP), édition inline des grants, bandeau post-migration, et picker routeur par nœud dans le Puzzle. Disponible uniquement en mode Grants V29 sur Headscale ≥ 0.29.', 'New guided Grants V29 rule composer (LAN, Internet, intra-fleet, IP templates), inline grant editing, post-migration banner, and per-node router picker in Puzzle. Available only in Grants V29 mode on Headscale ≥ 0.29.', '全新的 Grants V29 规则引导式编辑器（局域网、Internet、集群内、IP 模板）、授权内联编辑、迁移后横幅，以及拼图视图中按节点选择路由器。仅在 Headscale ≥ 0.29 的 Grants V29 模式下可用。'),
        verification: l10n.t('ACL > Composeur | Tap grant pour éditer | Fiche nœud > icône baguette', 'ACL > Composer | Tap grant to edit | Node detail > wand icon', 'ACL > 编写器 | 点击授权进行编辑 | 节点详情 > 魔杖图标'),
      ),
      WhatsNewVersion(
        version: '2.0.0',
        title: l10n.t('Release 2.0.0 — Grants, Via & UI ACL', 'Release 2.0.0 — Grants, Via & ACL UI', 'Release 2.0.0 — Grants、Via 与 ACL 界面'),
        description: l10n.t('Refonte complète de l\'écran ACL (onglets Grants/ACLs/JSON), Puzzle 3 colonnes avec routage via, graphe ACL enrichi, wizard de migration Grants V29, rollback moteur, et avertissements utilisateurs sans nœud tagué.', 'Full ACL screen overhaul (Grants/ACLs/JSON tabs), 3-column Puzzle with via routing, enhanced ACL graph, Grants V29 migration wizard, engine rollback, and warnings for users without tagged nodes.', 'ACL 界面全面重构（Grants/ACLs/JSON 标签页）、支持 via 路由的三列 Puzzle、增强的 ACL 图表、Grants V29 迁移向导、引擎回滚，以及无标签节点用户的警告。'),
        verification: l10n.t('ACL > onglets | Puzzle > colonne Via | Paramètres > Migration Grants V29', 'ACL > tabs | Puzzle > Via column | Settings > Grants V29 migration', 'ACL > 标签页 | 拼图 > Via 列 | 设置 > Grants V29 迁移'),
      ),
      WhatsNewVersion(
        version: '1.10.0',
        title: l10n.t('Moteur Grants V29 (via)', 'Grants V29 Engine (via)', 'Grants V29 引擎（via）'),
        description: l10n.t('Nouveau moteur ACL basé sur les grants Headscale 0.29+ avec routage via pour les sous-réseaux LAN et exit nodes. Résout les collisions quand plusieurs utilisateurs partagent le même CIDR (ex. 192.168.1.0/24). Sélectionnable dans Paramètres > Moteur de génération ACL. Activation automatique sur serveurs ≥ 0.29 si aucun choix explicite.', 'New ACL engine based on Headscale 0.29+ grants with via routing for LAN subnets and exit nodes. Resolves collisions when multiple users share the same CIDR (e.g. 192.168.1.0/24). Selectable in Settings > ACL Generation Engine. Auto-enabled on servers ≥ 0.29 when no explicit choice was made.', '新的 ACL 引擎基于 Headscale 0.29+ 的 Grants，并通过 via 路由支持局域网子网和出口节点。可解决多个用户共享同一 CIDR（如 192.168.1.0/24）时的冲突。可在「设置 > ACL 生成引擎」中选择。在 ≥ 0.29 的服务器上，若未明确选择则自动启用。'),
        verification: l10n.t('Paramètres > Moteur ACL > Grants V29. Nécessite Headscale 0.29.0+.', 'Settings > ACL Engine > Grants V29. Requires Headscale 0.29.0+.', '设置 > ACL 引擎 > Grants V29。需要 Headscale 0.29.0+。'),
      ),
      WhatsNewVersion(
        version: '1.9.0',
        title: l10n.t('Support Officiel Taildrive (Headscale v0.29.0+)', 'Official Taildrive Support (Headscale v0.29.0+)', '官方 Taildrive 支持（Headscale v0.29.0+）'),
        description: l10n.t('Taildrive est désormais pleinement supporté ! Intégration complète avec les nodeAttrs (drive:share, drive:access) et les grants (tailscale.com/cap/drive). La fonctionnalité est activée automatiquement pour les serveurs Headscale v0.29.0 et supérieurs. Accédez directement à la gestion des partages depuis le menu ACL (icône dossier partagé).', 'Taildrive is now fully supported! Complete integration with nodeAttrs (drive:share, drive:access) and grants (tailscale.com/cap/drive). The feature is automatically enabled for Headscale servers v0.29.0 and above. Access share management directly from the ACL menu (shared folder icon).', 'Taildrive 现已获得完整支持！与 nodeAttrs（drive:share、drive:access）和 grants（tailscale.com/cap/drive）完全集成。该功能会为 Headscale v0.29.0 及更高版本的服务器自动启用。可从 ACL 菜单（共享文件夹图标）直接管理分享。'),
        verification: l10n.t('Menu ACL > icône dossier partagé (📁). Nécessite Headscale v0.29.0+.', 'ACL Menu > shared folder icon (📁). Requires Headscale v0.29.0+.', 'ACL 菜单 > 共享文件夹图标（📁）。需要 Headscale v0.29.0+。'),
      ),
      WhatsNewVersion(
        version: '1.8.0',
        title: l10n.t('Personnalisation Utilisateurs & Appareils', 'User & Device Personalization', '用户与设备个性化'),
        description: l10n.t('Affichage en Liste ou Grille persistant pour les utilisateurs. Mémos d\'administration persistants avec sauvegarde automatique intelligente dans le détail utilisateur. Auto-détection intelligente et sélecteur d\'icônes d\'appareils. Curseur de seuil de latence ping avec coloration dynamique des alertes dans les logs et graphique épuré.', 'Persistent Grid/List toggle for the users screen. Administration notes with smart auto-save in user details. Default device icon auto-detection & manual selection override. Ping latency threshold slider with reactive visual highlights in logs and graphs.', '用户界面的列表/网格视图切换可持久保存。用户详情中的管理备忘持久保存并支持智能自动保存。设备图标智能自动检测与手动选择。ping 延迟阈值滑块，日志中告警动态着色，图表更简洁。'),
        verification: l10n.t('Écran Utilisateurs > changer de vue ; Détails Utilisateur > zone mémos ; Détail Appareil > clic icône ou outils de diagnostic.', 'Users Screen > toggle view; User Details > notes area; Device Details > click icon or diagnostic tools.', '用户界面 > 切换视图；用户详情 > 备忘录区域；设备详情 > 点击图标或诊断工具。'),
      ),
      WhatsNewVersion(
        version: '1.7.1',
        title: l10n.t('Stabilité Android & Puzzle ACL', 'Android Stability & ACL Puzzle', 'Android 稳定性与 ACL 拼图'),
        description: l10n.t('Correctif majeur résolvant un écran noir au démarrage causé par des erreurs de déchiffrement du Keystore Android lors des mises à jour. Ajout de la personnalisation riche des couleurs et icônes d\'en-têtes de blocs du Puzzle ACL avec adaptation automatique des contrastes (luminance) et retour à la ligne intelligent pour les noms longs. Désactivation explicative de Taildrive.', 'Major hotfix resolving a black screen on startup caused by Android Keystore decryption errors during updates. Adds rich color and icon customization for ACL Puzzle block headers with automatic contrast adjustment (luminance) and smart text wrapping for long names. Explanatory Taildrive disabling.', '重大热修复：解决更新时因 Android Keystore 解密错误导致的启动黑屏。新增 ACL 拼图区块标题的颜色与图标丰富自定义，支持自动对比度调整（亮度）以及长名称智能换行。补充 Taildrive 停用说明。'),
        verification: l10n.t('Écran ACL > Puzzle View > Bouton de réglages (tune) sur chaque bloc', 'ACL Screen > Puzzle View > settings button (tune) on each block', 'ACL 界面 > 拼图视图 > 每个区块上的设置按钮（tune）'),
      ),
      WhatsNewVersion(
        version: '1.6.0',
        title: l10n.t('Partage de fichiers (Taildrive)', 'File Sharing (Taildrive)', '文件分享（Taildrive）'),
        description: l10n.t('Intégration de Taildrive ! Partagez des dossiers entre vos appareils directement via les ACL. Inclut un filtre de connectivité intelligent pour ne proposer que des partages fonctionnels.', 'Taildrive Integration! Share folders between your devices directly via ACLs. Includes an intelligent connectivity filter to only suggest functional shares.', 'Taildrive 集成！可直接通过 ACL 在你的设备之间分享文件夹。内置智能连接性过滤，只推荐可用的分享。'),
        verification: l10n.t('Écran ACL > Bouton (+) > Partages Taildrive', 'User Screen > (+) Button > Taildrive Shares', 'ACL 界面 > (+) 按钮 > Taildrive 分享'),
      ),
      WhatsNewVersion(
        version: '1.5.105',
        title: l10n.t('Connexion OIDC & Corrections Importantes', 'OIDC Connection & Important Fixes', 'OIDC 连接与重要修复'),
        description: l10n.t('Nouveau : Choix entre connexion Classique et OIDC lors de l\u2019ajout d\u2019un appareil. Correction automatique des utilisateurs OIDC créés sans nom (email utilisé comme nom). Correction d\u2019un bug d\u2019affichage du graphe ACL. Suppression des warnings de dépréciation.', 'New: Choose between Classic and OIDC connection when adding a device. Auto-fix for OIDC users created without a name (email used as name). Fixed ACL graph display bug. Removed deprecation warnings.', '新增：添加设备时可选择经典登录或 OIDC。自动修复创建时没有名称的 OIDC 用户（使用邮箱作为名称）。修复 ACL 图谱显示问题。移除弃用警告。'),
        verification: l10n.t('Écran Utilisateur > Nouvel Appareil > choisir le mode de connexion.', 'User Screen > New Device > choose connection mode.', '用户界面 > 新设备 > 选择连接方式。'),
      ),
      WhatsNewVersion(
        version: '1.5.104',
        title: l10n.t('Gestion des Clés API Restaurée', 'API Key Management Restored', 'API 密钥管理已恢复'),
        description: l10n.t('L\'écran de gestion des clés API est de retour ! Accessible depuis les Paramètres avec un design modernisé. Gérez vos clés d\'administration en toute sécurité.', 'The API Key management screen is back! Accessible from Settings with a modernized design. Manage your admin keys securely.', 'API 密钥管理界面回归！可从设置进入，设计焕然一新。安全管理你的管理员密钥。'),
        verification: l10n.t('Paramètres > Bouton (+) > Clés API', 'Settings > (+) Button > API Keys', '设置 > (+) 按钮 > API 密钥'),
      ),
      WhatsNewVersion(
        version: '1.5.103',
        title: l10n.t('Support des Commentaires ACL (HuJSON)', 'ACL Comments Support (HuJSON)', 'ACL 注释支持（HuJSON）'),
        description: l10n.t('Les commentaires (//) dans vos ACL sont désormais correctement gérés par les vues Graphique et Puzzle. Plus de crash lors de la visualisation de configurations complexes !', 'Comments (//) in your ACLs are now correctly handled by Graph and Puzzle views. No more crashes when viewing complex configurations!', 'ACL 中的注释（//）现已能被图形视图和拼图视图正确处理。查看复杂配置时不再崩溃！'),
        verification: l10n.t('Ajoutez un commentaire "// test" dans l\'éditeur ACL et ouvrez la vue Puzzle.', 'Add a "// test" comment in the ACL editor and open the Puzzle view.', '在 ACL 编辑器中添加「// test」注释，然后打开拼图视图。'),
      ),
      WhatsNewVersion(
        version: '1.5.102',
        title:
            l10n.t('Support OIDC Avancé & ACLs', 'Advanced OIDC & ACL Support', '高级 OIDC 与 ACL 支持'),
        description: l10n.t('Mise à jour majeure pour OIDC ! Support des noms d\'utilisateurs type email (user@domaine.com) pour s\'aligner avec les ACLs. Correction des nœuds "orphelins" via matching par ID. Ajout de l\'auto-tagging pour les nouveaux appareils OIDC.', 'Major OIDC update! Support for email-style usernames (user@domain.com) to align with ACLs. Fixed "orphaned" nodes via ID-based matching. Added auto-tagging for new OIDC devices.', 'OIDC 重大更新！支持邮箱形式的用户名（user@domain.com），以便与 ACL 保持一致。通过 ID 匹配修复了「孤儿」节点。为新的 OIDC 设备新增自动打标签功能。'),
        verification: l10n.t('Renommez votre utilisateur en "email" et voyez vos nœuds réapparaître automatiquement.', 'Rename your user to "email" format and watch your nodes reappear automatically.', '将你的用户重命名为「email」格式，你的节点会自动重新出现。'),
      ),
      WhatsNewVersion(
        version: '1.4.97',
        title: l10n.t('Renommer l\'Utilisateur (OIDC)', 'Rename User (OIDC)', '重命名用户（OIDC）'),
        description: l10n.t('Vous pouvez maintenant renommer les utilisateurs ! Idéal pour corriger les identifiants techniques (ID) générés par OIDC (Google) en noms lisibles (ex: "Jean").', 'You can now rename users! Perfect for fixing technical IDs generated by OIDC (Google) into readable names (e.g., "John").', '现在可以重命名用户了！非常适合把 OIDC（Google）生成的技术标识（ID）改为可读名称（例如「Jean」）。'),
        verification: l10n.t('Option "Renommer" disponible dans le menu (...) de la liste des utilisateurs.', '"Rename" option available in the User List (...) menu.', '用户列表的 (...) 菜单中提供「重命名」选项。'),
      ),
      WhatsNewVersion(
        version: '1.4.96',
        title: l10n.t('Historique des Versions & Nettoyage', 'Version History & Cleanup', '版本历史与清理'),
        description: l10n.t('Ajout de cet écran "Nouveautés" pour suivre les évolutions de l\'application. Nettoyage du code et suppression des fichiers de tests obsolètes pour une meilleure stabilité.', 'Added this "What\'s New" screen to track application changes. Code cleanup and removal of obsolete test files for better stability.', '新增此「更新日志」界面以跟踪应用变化。清理代码并删除过时的测试文件，提升稳定性。'),
        verification: l10n.t('Vous consultez actuellement cet écran !', 'You are currently viewing this screen!', '你当前正在查看此界面！'),
      ),
    ];
  }
}
