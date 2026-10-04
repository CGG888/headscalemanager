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
