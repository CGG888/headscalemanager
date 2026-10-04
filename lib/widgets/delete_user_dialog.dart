import 'package:flutter/material.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/l10n/l10n.dart';
// For debugPrint

/// Dialogue de confirmation pour la suppression d'un utilisateur.
///
/// Affiche un message de confirmation et, si l'utilisateur confirme,
/// supprime l'utilisateur via l'API Headscale.
class DeleteUserDialog extends StatelessWidget {
  /// L'utilisateur à supprimer.
  final User user;

  /// Fonction de rappel appelée après la suppression réussie de l'utilisateur.
  final VoidCallback onUserDeleted;

  const DeleteUserDialog({
    super.key,
    required this.user,
    required this.onUserDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return AlertDialog(
      title: Text(l10n.t('Supprimer l\'utilisateur ?', 'Delete user?', '删除用户？')),
      content: Text(l10n.t('Êtes-vous sûr de vouloir supprimer ${user.name} ?\n\nNote : La suppression échouera si l\'utilisateur possède encore des appareils.', 'Are you sure you want to delete ${user.name}?\n\nNote: Deletion will fail if the user still owns devices.', '确定要删除 ${user.name} 吗？\n\n注意：如果该用户仍拥有设备，删除将失败。')),
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
              await provider.apiService.deleteUser(user.id);
              if (!context.mounted) return;
              Navigator.of(context).pop(); // Ferme le dialogue de confirmation
              onUserDeleted(); // Appelle le callback pour rafraîchir la liste
              showSafeSnackBar(
                  context,
                  l10n.t('Utilisateur ${user.name} supprimé.', 'User ${user.name} deleted.', '用户 ${user.name} 已删除。'));
            } catch (e) {
              debugPrint(
                  'Erreur lors de la suppression de l\'utilisateur : $e');
              Navigator.of(context).pop();
              showSafeSnackBar(
                  context,
                  l10n.t('Échec de la suppression de l\'utilisateur : $e', 'Failed to delete user: $e', '删除用户失败：$e'));
            }
          },
        ),
      ],
    );
  }
}
