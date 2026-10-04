import 'package:flutter/material.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/l10n/l10n.dart';

/// Dialogue pour créer une nouvelle clé de pré-authentification avec gestion des tags ACL.
class CreatePreAuthKeyDialog extends StatefulWidget {
  final Future<List<User>> usersFuture;

  const CreatePreAuthKeyDialog({super.key, required this.usersFuture});

  @override
  State<CreatePreAuthKeyDialog> createState() => _CreatePreAuthKeyDialogState();
}

class _CreatePreAuthKeyDialogState extends State<CreatePreAuthKeyDialog> {
  User? _selectedUser;
  bool _isReusable = false;
  bool _isEphemeral = false;
  bool _isExitNode = false;
  bool _isLanSharer = false;
  final TextEditingController _expirationController = TextEditingController();

  @override
  void dispose() {
    _expirationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);

    return AlertDialog(
      title: Text(l10n.t('Créer une clé de pré-authentification', 'Create Pre-Auth Key', '创建预认证密钥')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sélecteur d'utilisateur pour la clé de pré-authentification.
            FutureBuilder<List<User>>(
              future: widget.usersFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final users = snapshot.data!;
                if (_selectedUser == null && users.isNotEmpty) {
                  _selectedUser = users
                      .first; // Sélectionne le premier utilisateur par défaut
                }
                return DropdownButtonFormField<User>(
                  isExpanded: true,
                  initialValue: _selectedUser,
                  items: users.map((user) {
                    return DropdownMenuItem<User>(
                      value: user,
                      child: Text(user.name),
                    );
                  }).toList(),
                  onChanged: (user) {
                    setState(() {
                      _selectedUser = user;
                    });
                  },
                  decoration: InputDecoration(
                    labelText:
                        l10n.t('Sélectionner un utilisateur', 'Select a user', '选择用户'),
                    border: const OutlineInputBorder(),
                  ),
                );
              },
            ),
            // Option pour rendre la clé réutilisable.
            CheckboxListTile(
              title: Text(l10n.t('Réutilisable', 'Reusable', '可复用')),
              value: _isReusable,
              onChanged: (value) {
                setState(() {
                  _isReusable = value!;
                });
              },
            ),
            // Option pour rendre la clé éphémère.
            CheckboxListTile(
              title: Text(l10n.t('Éphémère', 'Ephemeral', '临时')),
              value: _isEphemeral,
              onChanged: (value) {
                setState(() {
                  _isEphemeral = value!;
                });
              },
            ),
            // Champ pour la durée d'expiration en jours.
            TextFormField(
              controller: _expirationController,
              decoration: InputDecoration(
                labelText: l10n.t('Expiration en jours (facultatif)', 'Expiration in days (optional)', '有效期天数（选填）'),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Text(l10n.t('Tags ACL (Nouveau)', 'ACL Tags (New)', 'ACL 标签（新）'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            CheckboxListTile(
              title: const Text('Exit Node'),
              subtitle: Text(l10n.t('Autoriser ce nœud à être une sortie internet.', 'Allow this node to be an internet exit.', '允许此节点作为互联网出口。')),
              value: _isExitNode,
              onChanged: (value) {
                setState(() {
                  _isExitNode = value!;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('LAN Sharer'),
              subtitle: Text(l10n.t('Autoriser ce nœud à partager son réseau local.', 'Allow this node to share its local network.', '允许此节点共享其局域网。')),
              value: _isLanSharer,
              onChanged: (value) {
                setState(() {
                  _isLanSharer = value!;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text(l10n.t('Annuler', 'Cancel', '取消')),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(l10n.t('Créer', 'Create', '创建')),
          onPressed: () async {
            if (_selectedUser != null) {
              final expirationText = _expirationController.text.trim();
              // Par défaut, 1 jour si le champ est vide ou invalide.
              int expirationDays = 1;
              if (expirationText.isNotEmpty) {
                final parsedDays = int.tryParse(expirationText);
                // Utilise la valeur analysée uniquement si c'est un nombre positif.
                if (parsedDays != null && parsedDays > 0) {
                  expirationDays = parsedDays;
                }
              }
              final expiration =
                  DateTime.now().add(Duration(days: expirationDays));

              // Construction des tags ACL
              final List<String> aclTags = [];
              if (_selectedUser != null) {
                String baseTag =
                    'tag:${normalizeUserName(_selectedUser!.name)}-client';
                if (_isExitNode) {
                  baseTag += ';exit-node';
                }
                if (_isLanSharer) {
                  baseTag += ';lan-sharer';
                }
                aclTags.add(baseTag);
              }

              try {
                final key = await provider.apiService.createPreAuthKey(
                  _selectedUser!.id,
                  _isReusable,
                  _isEphemeral,
                  expiration: expiration,
                  aclTags: aclTags,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop(key); // Return the created key
              } catch (e) {
                debugPrint('Erreur lors de la création de la clé : $e');
                showSafeSnackBar(
                    context,
                    l10n.t('Échec de la création de la clé : $e', 'Failed to create key: $e', '创建密钥失败：$e'));
                Navigator.of(context).pop(); // Pop the dialog on error
              }
            }
          },
        ),
      ],
    );
  }
}
