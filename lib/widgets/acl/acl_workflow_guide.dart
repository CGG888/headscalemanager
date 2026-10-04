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
                l10n.t('Brouillon local', 'Local draft'),
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
                l10n.t('Le serveur n\'a pas été modifié. Vous pouvez tester sans risque.', 'The server has not been changed. You can test safely.'),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t('Que faire :', 'What to do:'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _stepText(
                l10n,
                '1',
                l10n.t('« Composer une règle » — inutile d\'effacer vos ACL/grants existants', '« Compose a rule » — no need to erase existing ACLs/grants'),
              ),
              _stepText(
                l10n,
                '2',
                l10n.t('Ajoutez vos grants (onglet Grants)', 'Add your grants (Grants tab)'),
              ),
              _stepText(
                l10n,
                '3',
                l10n.t('Supprimez « tout autoriser » (onglet ACLs) si présent', 'Remove « allow all » (ACLs tab) if present'),
              ),
              _stepText(
                l10n,
                '4',
                l10n.t('Menu ⋮ > « Exporter vers le serveur » pour publier', '⋮ menu > « Export to Server » to publish'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.t('Compris', 'Got it')),
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
            l10n.t('Brouillon local', 'Local draft'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.amber.shade800,
            ),
          ),
          IconButton(
            icon: Icon(Icons.help_outline, size: 20, color: Colors.amber.shade800),
            tooltip: l10n.t('Aide brouillon', 'Draft help'),
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
