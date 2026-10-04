import 'package:flutter/material.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/l10n/l10n.dart';
// For debugPrint

/// Dialogue de confirmation pour la suppression d'une clé de pré-authentification.
///
/// Affiche un message de confirmation et, si l'utilisateur confirme,
/// supprime la clé via l'API Headscale.
class DeletePreAuthKeyDialog extends StatelessWidget {
  /// La clé de pré-authentification à supprimer.
  final PreAuthKey preAuthKey;

  /// Fonction de rappel appelée après la suppression réussie de la clé.
  final VoidCallback onKeyDeleted;

  const DeletePreAuthKeyDialog({
    super.key,
    required this.preAuthKey,
    required this.onKeyDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return AlertDialog(
      title: Text(l10n.t('Supprimer la clé ?', 'Delete key?', '删除密钥？')),
      content: Text(l10n.t('Êtes-vous sûr de vouloir supprimer la clé ${preAuthKey.key} ?', 'Are you sure you want to delete the key ${preAuthKey.key}?', '确定要删除密钥 ${preAuthKey.key} 吗？')),
      actions: [
        TextButton(
          child: Text(l10n.t('Annuler', 'Cancel', '取消')),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(l10n.t('Supprimer', 'Delete', '删除'),
              style: const TextStyle(color: Colors.red)),
          onPressed: () async {
            try {
              await provider.apiService
                  .expirePreAuthKey(preAuthKey.user!.id, preAuthKey.key);
              if (!context.mounted) return;
              Navigator.of(context).pop(); // Ferme le dialogue de confirmation
              onKeyDeleted(); // Appelle le callback pour rafraîchir la liste
              showSafeSnackBar(
                  context,
                  l10n.t('Clé expirée avec succès.', 'Key expired successfully.', '密钥已成功过期。'));
            } catch (e) {
              debugPrint('Erreur lors de l\'expiration de la clé : $e');
              Navigator.of(context).pop();
              showSafeSnackBar(
                  context,
                  l10n.t('Échec de l\'expiration de la clé : $e', 'Failed to expire key: $e', '密钥过期失败：$e'));
            }
          },
        ),
      ],
    );
  }
}
