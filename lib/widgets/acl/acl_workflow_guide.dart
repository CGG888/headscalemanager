import 'package:flutter/material.dart';
import 'package:headscalemanager/l10n/l10n.dart';

/// Indicateur compact + aide contextuelle pour le mode brouillon local.
class AclWorkflowGuide extends StatelessWidget {
  final L10n l10n;

  const AclWorkflowGuide({super.key, required this.l10n});

  static Future<void> showHelpDialog(BuildContext context, {required L10n l10n}) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit_note, color: Colors.amber.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.t('Brouillon local', 'Local draft', '本地草稿'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.t('Le serveur n\'a pas été modifié. Vous pouvez tester sans risque.', 'The server has not been changed. You can test safely.', '服务器未被修改，可以放心测试。'),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t('Que faire :', 'What to do:', '操作步骤：'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _stepText(
                l10n,
                '1',
                l10n.t('« Composer une règle » — inutile d\'effacer vos ACL/grants existants', '« Compose a rule » — no need to erase existing ACLs/grants', '「编写规则」——无需清除现有的 ACL/Grants'),
              ),
              _stepText(
                l10n,
                '2',
                l10n.t('Ajoutez vos grants (onglet Grants)', 'Add your grants (Grants tab)', '添加你的授权（Grants 标签页）'),
              ),
              _stepText(
                l10n,
                '3',
                l10n.t('Supprimez « tout autoriser » (onglet ACLs) si présent', 'Remove « allow all » (ACLs tab) if present', '若存在「全部允许」（ACLs 标签页），请删除'),
              ),
              _stepText(
                l10n,
                '4',
                l10n.t('Menu ⋮ > « Exporter vers le serveur » pour publier', '⋮ menu > « Export to Server » to publish', '菜单 ⋮ >「导出到服务器」以发布'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.t('Compris', 'Got it', '明白了')),
          ),
        ],
      ),
    );
  }

  static Widget _stepText(L10n l10n, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number.', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: Colors.amber.shade700),
          const SizedBox(width: 6),
          Text(
            l10n.t('Brouillon local', 'Local draft', '本地草稿'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.amber.shade800,
            ),
          ),
          IconButton(
            icon: Icon(Icons.help_outline, size: 20, color: Colors.amber.shade800),
            tooltip: l10n.t('Aide brouillon', 'Draft help', '草稿帮助'),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => showHelpDialog(context, l10n: l10n),
          ),
        ],
      ),
    );
  }
}
