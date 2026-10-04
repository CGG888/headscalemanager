import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class PolicyDiffDialog extends StatelessWidget {
  final Map<String, dynamic> currentPolicy;
  final Map<String, dynamic> newPolicy;
  final L10n l10n;

  const PolicyDiffDialog({
    super.key,
    required this.currentPolicy,
    required this.newPolicy,
    required this.l10n,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Map<String, dynamic> currentPolicy,
    required Map<String, dynamic> newPolicy,
    required L10n l10n,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => PolicyDiffDialog(
        currentPolicy: currentPolicy,
        newPolicy: newPolicy,
        l10n: l10n,
      ),
    );
  }

  String _summarize(Map<String, dynamic> policy) {
    final grants = (policy['grants'] as List?)?.length ?? 0;
    final acls = (policy['acls'] as List?)?.length ?? 0;
    final groups = (policy['groups'] as Map?)?.length ?? 0;
    return l10n.t('$grants grants, $acls acls, $groups groupes', '$grants grants, $acls acls, $groups groups');
  }

  @override
  Widget build(BuildContext context) {
    const encoder = JsonEncoder.withIndent('  ');
    final changed = encoder.convert(currentPolicy) != encoder.convert(newPolicy);

    return AlertDialog(
      title: Text(l10n.t('Aperçu des changements', 'Change preview')),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.t('Politique actuelle :', 'Current policy:'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(_summarize(currentPolicy)),
              const SizedBox(height: 12),
              Text(l10n.t('Nouvelle politique :', 'New policy:'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(_summarize(newPolicy)),
              const SizedBox(height: 12),
              Text(
                changed
                    ? (l10n.t('Le JSON sera modifié avant export.', 'JSON will be modified before export.'))
                    : (l10n.t('Aucune différence détectée.', 'No difference detected.')),
                style: TextStyle(
                  color: changed ? Colors.orange : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.t('Annuler', 'Cancel')),
        ),
        ElevatedButton(
          onPressed: changed ? () => Navigator.pop(context, true) : null,
          child: Text(l10n.t('Confirmer export', 'Confirm export')),
        ),
      ],
    );
  }
}
