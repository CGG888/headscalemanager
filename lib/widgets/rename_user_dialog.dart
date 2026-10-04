import 'package:flutter/material.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/l10n/l10n.dart';

class RenameUserDialog extends StatefulWidget {
  final User user;
  final VoidCallback onUserRenamed;

  const RenameUserDialog({
    super.key,
    required this.user,
    required this.onUserRenamed,
  });

  @override
  State<RenameUserDialog> createState() => _RenameUserDialogState();
}

class _RenameUserDialogState extends State<RenameUserDialog> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final l10n = L10n(locale);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.t('Renommer l\'utilisateur', 'Rename User')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.t("Attention : Renommer un utilisateur peut impacter vos ACLs si vous utilisez son ancien nom manuellement.", "Warning: Renaming a user may impact your ACLs if you manually referenced the old name."),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.t('Nouveau nom', 'New name'),
                hintText: 'ex: jean',
                helperText: l10n.t('Lettres minuscules, chiffres, tirets', 'Lowercase letters, numbers, dashes'),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.t('Requis', 'Required');
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.t('Annuler', 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.t('Renommer', 'Rename')),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();
    final locale = context.read<AppProvider>().locale;
    final l10n = L10n(locale);

    // Strict Validation (DNS or Email for Headscale usernames)
    if (!isValidHeadscaleUser(newName)) {
      // Si c'est un échec, on propose une version sanitisée DNS par défaut (le plus sûr)
      final sanitized = sanitizeDns1123Subdomain(newName);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.t('Format Invalide', 'Invalid Format')),
          content: Text(l10n.t('Le nom "$newName" n\'est pas valide.\nHeadscale accepte :\n- Un nom simple (a-z, 0-9, -)\n- Une adresse email (user@domaine.com)\n\nSuggestion (mode simple) : "$sanitized"', 'The name "$newName" is invalid.\nHeadscale accepts:\n- A simple name (a-z, 0-9, -)\n- An email address (user@domain.com)\n\nSuggestion (simple mode): "$sanitized"')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.t('Annuler', 'Cancel'))),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _nameController.text = sanitized;
              },
              child: Text(l10n.t('Utiliser corrigé', 'Use corrected')),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context
          .read<AppProvider>()
          .apiService
          .renameUser(widget.user.id, newName);
      if (!mounted) return;

      widget.onUserRenamed();
      Navigator.of(context).pop();
      showSafeSnackBar(
          context,
          l10n.t('Utilisateur renommé avec succès', 'User renamed successfully'));
    } catch (e) {
      if (!mounted) return;
      showSafeSnackBar(context, '${l10n.t('Erreur', 'Error')}: $e');
      setState(() => _isLoading = false);
    }
  }
}
