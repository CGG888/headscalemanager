import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/l10n/l10n.dart';
// For debugPrint

/// Dialogue pour créer un nouvel utilisateur Headscale.
///
/// Permet à l'utilisateur de saisir un nom d'utilisateur. Le dialogue gère
/// la logique d'ajout du suffixe de domaine et l'appel à l'API Headscale.
class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return AlertDialog(
      title: Text(l10n.t('Créer un utilisateur', 'Create user', '创建用户')),
      content: TextField(
        controller: _nameController,
        decoration: InputDecoration(
            hintText: l10n.t('Nom de l\'utilisateur', 'Username', '用户名')),
      ),
      actions: [
        TextButton(
          child: Text(l10n.t('Annuler', 'Cancel', '取消')),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(l10n.t('Créer', 'Create', '创建')),
          onPressed: () async {
            final String name = _nameController.text.trim();
            if (name.isEmpty) {
              Navigator.of(context).pop(false);
              return;
            }

            final serverUrl = appProvider.activeServer?.url;
            final String? baseDomain = serverUrl?.extractBaseDomain();

            String suffix = '';
            if (baseDomain != null && baseDomain.isNotEmpty) {
              suffix = '@$baseDomain';
            } else {
              suffix = '@headscale.local'; // A generic fallback
            }

            String finalName = name;
            if (!name.contains('@')) {
              finalName = '$name$suffix';
            }

            try {
              // Étape 2 : Vérification des collisions
              final existingUsers = await appProvider.apiService.getUsers();
              final normalizedNewName = normalizeUserName(finalName);

              bool collision = false;
              String suggestedName = '';

              for (var existingUser in existingUsers) {
                if (existingUser.name.toLowerCase() ==
                        finalName.toLowerCase() ||
                    normalizeUserName(existingUser.name) == normalizedNewName) {
                  collision = true;
                  // Suggestion de nom simple
                  suggestedName = '${name}1';
                  break;
                }
              }

              if (collision && context.mounted) {
                final bool? proceed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.t('Conflit détecté', 'Conflict detected', '检测到冲突')),
                    content: Text(l10n.t('Un utilisateur avec ce nom ou générant le même tag existe déjà. Voulez-vous essayer avec "$suggestedName" ?', 'A user with this name or generating the same tag already exists. Would you like to try with "$suggestedName" ?', '已存在同名用户或会生成相同标签的用户。是否改用「$suggestedName」？')),
                    actions: [
                      TextButton(
                        child: Text(l10n.t('Annuler', 'Cancel', '取消')),
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                      TextButton(
                        child: Text(l10n.t('Utiliser $suggestedName', 'Use $suggestedName', '使用 $suggestedName')),
                        onPressed: () {
                          _nameController.text = suggestedName;
                          Navigator.of(ctx).pop(true);
                        },
                      ),
                    ],
                  ),
                );
                if (proceed != true) return;
                // Si on a changé le nom, on relance la logique de création avec le nouveau nom au prochain clic ou on peut boucler ici.
                // Pour faire simple, on s'arrête là et l'utilisateur reclique sur "Créer" après la mise à jour du texte.
                return;
              }

              await appProvider.apiService.createUser(finalName);
              if (context.mounted) {
                Navigator.of(context).pop(true); // Success
              }
            } catch (e) {
              debugPrint('Erreur lors de la création de l\'utilisateur : $e');
              if (context.mounted) {
                showSafeSnackBar(
                    context,
                    l10n.t('Échec de la création de l\'utilisateur : $e', 'Failed to create user: $e', '创建用户失败：$e'));
                Navigator.of(context).pop(false); // Failure
              }
            }
          },
        ),
      ],
    );
  }
}
